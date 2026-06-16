// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IReputationRegistry.sol";
import "./IIdentityRegistry.sol";

/**
 * @title ReputationRegistry
 * @dev ERC-8004 compliant Reputation Registry implementation for ΨNet
 * @notice Manages feedback and reputation scores for AI agents
 *
 * This contract implements a sophisticated reputation system with:
 * - Multiple feedback types (positive, negative, neutral, dispute)
 * - Staked feedback for higher confidence signals
 * - Dispute resolution mechanism
 * - On-chain reputation scoring
 */
contract ReputationRegistry is
    IReputationRegistry,
    AccessControl,
    ReentrancyGuard
{
    bytes32 public constant DISPUTE_RESOLVER_ROLE = keccak256("DISPUTE_RESOLVER_ROLE");

    IIdentityRegistry public immutable identityRegistry;

    // Minimum stake required for staked feedback (in wei)
    uint256 public minimumStake;

    // Counter for feedback IDs
    uint256 private _nextFeedbackId;

    // Mapping from feedback ID to Feedback struct
    mapping(uint256 => Feedback) private _feedbacks;

    // Mapping from agent ID to array of feedback IDs
    mapping(uint256 => uint256[]) private _agentFeedbacks;

    // Mapping from reviewer address to array of feedback IDs they posted
    mapping(address => uint256[]) private _reviewerFeedbacks;

    // Mapping from agent ID to computed reputation score
    mapping(uint256 => uint256) private _reputationScores;

    // Mapping from agent ID to feedback type counts
    mapping(uint256 => mapping(FeedbackType => uint256)) private _feedbackCounts;

    constructor(address _identityRegistry, uint256 _minimumStake) {
        require(_identityRegistry != address(0), "ReputationRegistry: invalid identity registry");

        identityRegistry = IIdentityRegistry(_identityRegistry);
        minimumStake = _minimumStake;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISPUTE_RESOLVER_ROLE, msg.sender);

        _nextFeedbackId = 1;
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function postFeedback(
        uint256 agentId,
        FeedbackType feedbackType,
        uint8 rating,
        string calldata contextHash,
        string calldata metadata
    ) external payable override returns (uint256 feedbackId) {
        return _postFeedbackInternal(
            agentId,
            feedbackType,
            rating,
            contextHash,
            metadata,
            0 // No stake for regular feedback
        );
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function postStakedFeedback(
        uint256 agentId,
        FeedbackType feedbackType,
        uint8 rating,
        string calldata contextHash,
        string calldata metadata
    ) external payable override returns (uint256 feedbackId) {
        require(msg.value >= minimumStake, "ReputationRegistry: insufficient stake");

        return _postFeedbackInternal(
            agentId,
            feedbackType,
            rating,
            contextHash,
            metadata,
            msg.value
        );
    }

    /**
     * @dev Internal function to post feedback
     */
    function _postFeedbackInternal(
        uint256 agentId,
        FeedbackType feedbackType,
        uint8 rating,
        string calldata contextHash,
        string calldata metadata,
        uint256 stake
    ) private returns (uint256 feedbackId) {
        require(rating <= 100, "ReputationRegistry: rating must be 0-100");
        require(
            identityRegistry.isAgentActive(agentId),
            "ReputationRegistry: agent does not exist or is inactive"
        );

        feedbackId = _nextFeedbackId++;

        _feedbacks[feedbackId] = Feedback({
            reviewer: msg.sender,
            agentId: agentId,
            feedbackType: feedbackType,
            rating: rating,
            contextHash: contextHash,
            metadata: metadata,
            timestamp: block.timestamp,
            stake: stake,
            disputed: false
        });

        _agentFeedbacks[agentId].push(feedbackId);
        _reviewerFeedbacks[msg.sender].push(feedbackId);
        _feedbackCounts[agentId][feedbackType]++;

        // Update reputation score
        _updateReputationScore(agentId);

        emit FeedbackPosted(
            feedbackId,
            agentId,
            msg.sender,
            feedbackType,
            rating,
            contextHash
        );
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function disputeFeedback(uint256 feedbackId, string calldata disputeReason)
        external
        override
    {
        Feedback storage feedback = _feedbacks[feedbackId];
        require(feedback.timestamp > 0, "ReputationRegistry: feedback does not exist");
        require(!feedback.disputed, "ReputationRegistry: feedback already disputed");

        address agentOwner = identityRegistry.getAgentOwner(feedback.agentId);
        require(
            msg.sender == agentOwner || hasRole(DISPUTE_RESOLVER_ROLE, msg.sender),
            "ReputationRegistry: caller not authorized to dispute"
        );

        feedback.disputed = true;
        emit FeedbackDisputed(feedbackId, msg.sender, disputeReason);
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function resolveDispute(
        uint256 feedbackId,
        bool removeFeedback,
        bool slashStake
    ) external override onlyRole(DISPUTE_RESOLVER_ROLE) nonReentrant {
        Feedback storage feedback = _feedbacks[feedbackId];
        require(feedback.timestamp > 0, "ReputationRegistry: feedback does not exist");
        require(feedback.disputed, "ReputationRegistry: feedback not under dispute");

        if (removeFeedback) {
            // Decrement the feedback count
            _feedbackCounts[feedback.agentId][feedback.feedbackType]--;

            // Mark as removed (we keep the data for audit trail)
            feedback.disputed = false;
            feedback.rating = 0;

            // Update reputation score
            _updateReputationScore(feedback.agentId);
        } else {
            // Dispute resolved, keep feedback
            feedback.disputed = false;
        }

        // Handle stake
        if (feedback.stake > 0) {
            if (slashStake) {
                // Slash stake to resolver or treasury
                (bool success, ) = msg.sender.call{value: feedback.stake}("");
                require(success, "ReputationRegistry: stake transfer failed");
            } else {
                // Return stake to reviewer
                (bool success, ) = feedback.reviewer.call{value: feedback.stake}("");
                require(success, "ReputationRegistry: stake return failed");
            }
            feedback.stake = 0;
        }

        emit DisputeResolved(feedbackId, removeFeedback, msg.sender);
    }

    /**
     * @dev Update reputation score for an agent
     * Uses a weighted average algorithm considering:
     * - Feedback type (positive/negative/neutral)
     * - Rating value
     * - Stake amount (higher weight for staked feedback)
     * - Recency (more recent feedback has higher weight)
     */
    function _updateReputationScore(uint256 agentId) private {
        uint256[] memory feedbackIds = _agentFeedbacks[agentId];
        if (feedbackIds.length == 0) {
            _reputationScores[agentId] = 5000; // Default neutral score (50.00)
            return;
        }

        uint256 totalWeightedScore = 0;
        uint256 totalWeight = 0;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < feedbackIds.length; i++) {
            Feedback memory feedback = _feedbacks[feedbackIds[i]];

            // Skip disputed or removed feedback
            if (feedback.disputed || feedback.rating == 0) continue;

            // FIX #0.4: Smooth exponential decay instead of cliff
            uint256 age = currentTime - feedback.timestamp;
            uint256 timeWeight;

            if (age <= 30 days) {
                timeWeight = 1000; // Very recent: 10x weight
            } else if (age <= 90 days) {
                timeWeight = 500; // Recent: 5x weight
            } else if (age <= 180 days) {
                timeWeight = 200; // Medium: 2x weight
            } else if (age <= 365 days) {
                timeWeight = 100; // Old: 1x weight
            } else {
                // Exponential decay after 1 year
                uint256 yearsOld = (age - 365 days) / 365 days;
                timeWeight = 100 / (2 ** yearsOld); // Halve every year
                if (timeWeight < 10) timeWeight = 10; // Minimum 0.1x
            }

            // FIX #0.4: Cap stake weight to prevent dominance (was 2x, now 1.5x max)
            uint256 stakeWeight = feedback.stake > 0 ? 150 : 100;

            // Total weight for this feedback (normalize to base 100)
            uint256 weight = (timeWeight * stakeWeight) / 100;

            // Calculate score based on feedback type
            uint256 score;
            if (feedback.feedbackType == FeedbackType.POSITIVE) {
                score = uint256(feedback.rating) * 100; // Scale to 0-10000
            } else if (feedback.feedbackType == FeedbackType.NEGATIVE) {
                score = (100 - uint256(feedback.rating)) * 100;
            } else {
                score = 5000; // Neutral feedback
            }

            totalWeightedScore += score * weight;
            totalWeight += weight;
        }

        _reputationScores[agentId] = totalWeight > 0
            ? totalWeightedScore / totalWeight
            : 5000;

        emit ReputationUpdated(
            agentId,
            _reputationScores[agentId],
            feedbackIds.length
        );
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getFeedback(uint256 feedbackId)
        external
        view
        override
        returns (Feedback memory)
    {
        require(
            _feedbacks[feedbackId].timestamp > 0,
            "ReputationRegistry: feedback does not exist"
        );
        return _feedbacks[feedbackId];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getAgentFeedback(uint256 agentId)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _agentFeedbacks[agentId];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getFeedbackCountByType(uint256 agentId, FeedbackType feedbackType)
        external
        view
        override
        returns (uint256)
    {
        return _feedbackCounts[agentId][feedbackType];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getReputationScore(uint256 agentId)
        external
        view
        override
        returns (uint256 score, uint256 feedbackCount)
    {
        score = _reputationScores[agentId];
        feedbackCount = _agentFeedbacks[agentId].length;

        // If no score computed yet, return default
        if (score == 0 && feedbackCount == 0) {
            score = 5000; // 50.00 default
        }
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getFeedbackByReviewer(address reviewer)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _reviewerFeedbacks[reviewer];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function isDisputeResolver(address resolver)
        external
        view
        override
        returns (bool)
    {
        return hasRole(DISPUTE_RESOLVER_ROLE, resolver);
    }

    /**
     * @dev Update minimum stake (admin only)
     */
    function setMinimumStake(uint256 newMinimumStake)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        minimumStake = newMinimumStake;
    }
}
