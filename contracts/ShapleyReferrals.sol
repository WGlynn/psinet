// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PsiToken.sol";
import "./erc8004/IReputationRegistry.sol";

/**
 * @title ShapleyReferrals
 * @dev Implements Shapley value-based referral rewards for ΨNet
 *
 * Key Innovation: Instead of flat-rate referrals, this contract uses cooperative game theory
 * to fairly distribute rewards based on synergistic contributions.
 *
 * Two-Layer Reward System:
 * 1. Local Fairness: Referrer and referee split immediate reward (both benefit!)
 * 2. Global Fairness: Entire referral chain earns retroactive bonuses via Shapley values
 *
 * Example: A → B → C → D → E
 * - When B joins: A gets 50 PSI, B gets 50 PSI (immediate split)
 * - When C joins: A, B, C all earn retroactive bonuses based on coalition value
 * - As chain grows: Earlier members continue earning from downstream synergies
 *
 * This creates exponential incentives for:
 * - Quality referrals (not spam)
 * - Helping your referees succeed
 * - Building deep, engaged networks
 */
contract ShapleyReferrals is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    PsiToken public psiToken;
    IReputationRegistry public reputationRegistry;

    // Reward parameters
    uint256 public constant BASE_REFERRAL_REWARD = 100 * 10**18; // 100 PSI split between referrer & referee
    uint256 public constant CHAIN_DEPTH_BONUS = 20 * 10**18; // 20 PSI per depth level
    uint256 public constant COALITION_SIZE_BONUS = 50 * 10**18; // 50 PSI per 3 members
    uint256 public constant MAX_SHAPLEY_DEPTH = 5; // Limit coalition calculation depth for gas efficiency
    uint256 public constant MAX_COALITION_SIZE_FOR_REWARDS = 10; // Cap coalition size for hyperinflation protection

    // Referral tree structure
    struct User {
        address userAddress;
        address referrer; // Who referred this user
        address[] referees; // Who this user referred
        uint256 joinedAt;
        uint256 totalEarned;
        uint256 chainDepth; // Distance from root
        bool exists;
    }

    struct Coalition {
        address[] members;
        uint256 totalValue;
        uint256 calculatedAt;
    }

    mapping(address => User) public users;
    mapping(bytes32 => Coalition) public coalitions; // keccak256(sorted addresses) => Coalition

    uint256 public totalUsers;
    uint256 public totalReferralRewards;

    event UserJoined(address indexed user, address indexed referrer, uint256 immediateReward);
    event ImmediateRewardSplit(address indexed referrer, address indexed referee, uint256 amountEach);
    event RetroactiveBonus(address indexed user, uint256 amount, uint256 coalitionSize);
    event CoalitionValueCalculated(bytes32 indexed coalitionId, uint256 value, uint256 memberCount);
    event ShapleyDistribution(bytes32 indexed coalitionId, address indexed user, uint256 shapleyValue);

    constructor(address _psiToken, address _reputationRegistry) {
        psiToken = PsiToken(_psiToken);
        reputationRegistry = IReputationRegistry(_reputationRegistry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Register a new user with optional referrer
     * Implements immediate reward split: both referrer and referee benefit
     */
    function joinWithReferral(address referrer) external nonReentrant {
        require(!users[msg.sender].exists, "User already exists");
        require(referrer != msg.sender, "Cannot refer yourself");

        if (referrer != address(0)) {
            require(users[referrer].exists, "Referrer must be registered");
            // FIX #0.2: Prevent cycles in referral chain
            require(!_isInChain(referrer, msg.sender), "Cycle detected in referral chain");
        }

        // Calculate chain depth
        uint256 depth = 0;
        if (referrer != address(0)) {
            depth = users[referrer].chainDepth + 1;
        }

        // Register user
        users[msg.sender] = User({
            userAddress: msg.sender,
            referrer: referrer,
            referees: new address[](0),
            joinedAt: block.timestamp,
            totalEarned: 0,
            chainDepth: depth,
            exists: true
        });

        if (referrer != address(0)) {
            users[referrer].referees.push(msg.sender);
        }

        totalUsers++;

        // IMMEDIATE REWARD SPLIT (Local Fairness)
        if (referrer != address(0)) {
            uint256 splitAmount = BASE_REFERRAL_REWARD / 2; // 50 PSI each

            // Both parties benefit!
            psiToken.rewardAgent(referrer, splitAmount, true, totalUsers);
            psiToken.rewardAgent(msg.sender, splitAmount, true, totalUsers);

            users[referrer].totalEarned += splitAmount;
            users[msg.sender].totalEarned += splitAmount;
            totalReferralRewards += BASE_REFERRAL_REWARD;

            emit ImmediateRewardSplit(referrer, msg.sender, splitAmount);
        }

        emit UserJoined(msg.sender, referrer, BASE_REFERRAL_REWARD / 2);

        // RETROACTIVE COALITION BONUSES (Global Fairness)
        // Calculate and distribute Shapley values for the coalition
        if (referrer != address(0)) {
            _distributeCoalitionBonuses(msg.sender);
        }
    }

    /**
     * @dev Join without a referrer (genesis user)
     */
    function join() external nonReentrant {
        require(!users[msg.sender].exists, "User already exists");

        users[msg.sender] = User({
            userAddress: msg.sender,
            referrer: address(0),
            referees: new address[](0),
            joinedAt: block.timestamp,
            totalEarned: 0,
            chainDepth: 0,
            exists: true
        });

        totalUsers++;
        emit UserJoined(msg.sender, address(0), 0);
    }

    /**
     * @dev Calculate and distribute retroactive bonuses to coalition members
     * Uses Shapley value approximation for gas efficiency
     */
    function _distributeCoalitionBonuses(address newMember) internal {
        // Build coalition: new member + ancestors up to MAX_SHAPLEY_DEPTH
        address[] memory coalition = _buildCoalition(newMember);

        if (coalition.length < 2) return; // Need at least 2 for synergy

        // Calculate total coalition value
        uint256 coalitionValue = _calculateCoalitionValue(coalition);

        // Calculate Shapley values for each member
        uint256[] memory shapleyValues = _approximateShapleyValues(coalition, coalitionValue);

        // Distribute bonuses
        bytes32 coalitionId = _getCoalitionId(coalition);
        emit CoalitionValueCalculated(coalitionId, coalitionValue, coalition.length);

        for (uint256 i = 0; i < coalition.length; i++) {
            if (shapleyValues[i] > 0) {
                psiToken.rewardAgent(coalition[i], shapleyValues[i], true, totalUsers);
                users[coalition[i]].totalEarned += shapleyValues[i];
                totalReferralRewards += shapleyValues[i];

                emit RetroactiveBonus(coalition[i], shapleyValues[i], coalition.length);
                emit ShapleyDistribution(coalitionId, coalition[i], shapleyValues[i]);
            }
        }

        // Store coalition data
        coalitions[coalitionId] = Coalition({
            members: coalition,
            totalValue: coalitionValue,
            calculatedAt: block.timestamp
        });
    }

    /**
     * @dev Build coalition by traversing up the referral chain
     */
    function _buildCoalition(address member) internal view returns (address[] memory) {
        address[] memory coalition = new address[](MAX_SHAPLEY_DEPTH + 1);
        uint256 count = 0;
        address current = member;

        // Traverse up the chain
        while (current != address(0) && count < MAX_SHAPLEY_DEPTH + 1) {
            coalition[count] = current;
            count++;
            current = users[current].referrer;
        }

        // Trim array to actual size
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = coalition[i];
        }

        return result;
    }

    /**
     * @dev Calculate total value created by coalition
     * Value function: v(S) = base * |S| + depth_bonus + size_bonus + network_effect
     */
    function _calculateCoalitionValue(address[] memory coalition) internal view returns (uint256) {
        uint256 size = coalition.length;

        // FIX #0.1: Cap coalition size for value calculation to prevent hyperinflation
        if (size > MAX_COALITION_SIZE_FOR_REWARDS) {
            size = MAX_COALITION_SIZE_FOR_REWARDS;
        }

        // Base value: 20 PSI per member
        uint256 baseValue = 20 * 10**18 * size;

        // Chain depth bonus: deeper chains create more value
        uint256 depthBonus = CHAIN_DEPTH_BONUS * (size - 1);

        // Size bonus: groups of 3+ get bonus (synergy!)
        uint256 sizeBonus = (size / 3) * COALITION_SIZE_BONUS;

        // Network effect: Metcalfe's Law (value ∝ n²)
        uint256 networkEffect = (size * size * 10 * 10**18) / 100; // Scaled down

        // FIX #0.1: Cap network effect to prevent quadratic explosion
        if (networkEffect > 10_000 * 10**18) {
            networkEffect = 10_000 * 10**18; // Cap at 10k PSI
        }

        // Activity multiplier: engaged users create more value
        uint256 activityMultiplier = _calculateActivityMultiplier(coalition);

        uint256 totalValue = baseValue + depthBonus + sizeBonus + networkEffect;
        totalValue = (totalValue * activityMultiplier) / 100;

        // FIX #0.1: Global maximum coalition value cap
        if (totalValue > 50_000 * 10**18) {
            totalValue = 50_000 * 10**18; // Cap at 50k PSI total
        }

        return totalValue;
    }

    /**
     * @dev Calculate activity multiplier based on user engagement
     * Higher reputation = higher multiplier
     */
    function _calculateActivityMultiplier(address[] memory coalition) internal view returns (uint256) {
        uint256 totalReputation = 0;
        uint256 memberCount = 0;

        for (uint256 i = 0; i < coalition.length; i++) {
            // Try to get reputation score (may fail if user not registered in reputation system)
            try reputationRegistry.getReputationScore(uint256(uint160(coalition[i]))) returns (
                uint256 score,
                uint256 /* feedbackCount */
            ) {
                totalReputation += score;
                memberCount++;
            } catch {
                // If reputation check fails, use neutral multiplier
                memberCount++;
            }
        }

        if (memberCount == 0) return 100; // 1x multiplier

        uint256 avgReputation = totalReputation / memberCount;

        // Reputation 0-50: 100% (1x)
        // Reputation 50-100: 100-150% (1x-1.5x)
        if (avgReputation <= 50) {
            return 100;
        } else {
            return 100 + ((avgReputation - 50) * 100) / 100; // Linear scaling
        }
    }

    /**
     * @dev Approximate Shapley values using efficient algorithm
     * For gas efficiency, uses simplified calculation instead of full permutation
     *
     * Approximation: Each member gets base share + bonus for position in chain
     * - Root (referrer of all): highest share
     * - Middle members: proportional share
     * - Leaf (newest): smallest share but still meaningful
     */
    function _approximateShapleyValues(
        address[] memory coalition,
        uint256 totalValue
    ) internal view returns (uint256[] memory) {
        uint256 size = coalition.length;
        uint256[] memory shares = new uint256[](size);

        // Weight distribution: earlier in chain = higher weight
        // Root gets 2x, each subsequent member gets slightly less
        uint256 totalWeight = 0;
        uint256[] memory weights = new uint256[](size);

        for (uint256 i = 0; i < size; i++) {
            // Reverse order: coalition[0] is newest, coalition[size-1] is root
            uint256 position = size - i; // Root = size, newest = 1
            weights[i] = position * position; // Quadratic weighting
            totalWeight += weights[i];
        }

        // Distribute value proportionally
        for (uint256 i = 0; i < size; i++) {
            shares[i] = (totalValue * weights[i]) / totalWeight;
        }

        return shares;
    }

    /**
     * @dev Generate unique coalition ID from sorted member addresses
     */
    function _getCoalitionId(address[] memory members) internal pure returns (bytes32) {
        // Sort addresses (simple bubble sort, ok for small arrays)
        address[] memory sorted = new address[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            sorted[i] = members[i];
        }

        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (sorted[i] > sorted[j]) {
                    address temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }

        return keccak256(abi.encodePacked(sorted));
    }

    /**
     * @dev Get user's referral chain (ancestors)
     */
    function getReferralChain(address user) external view returns (address[] memory) {
        require(users[user].exists, "User not found");
        return _buildCoalition(user);
    }

    /**
     * @dev Get user's direct referees
     */
    function getReferees(address user) external view returns (address[] memory) {
        require(users[user].exists, "User not found");
        return users[user].referees;
    }

    /**
     * @dev Get user's total network size (recursive)
     */
    function getNetworkSize(address user) external view returns (uint256) {
        require(users[user].exists, "User not found");
        // FIX #0.3: Use iterative BFS instead of unbounded recursion
        return _countNetworkIterative(user);
    }

    /**
     * @dev FIX #0.3: Iterative network counting to prevent DoS via deep recursion
     * Uses BFS with depth and size limits
     */
    function _countNetworkIterative(address root) internal view returns (uint256) {
        uint256 count = 0;
        uint256 maxDepth = 20; // Reasonable depth limit
        uint256 maxNodes = 1000; // Maximum nodes to count

        // Use array as queue for BFS
        address[] memory queue = new address[](maxNodes);
        uint256 front = 0;
        uint256 back = 0;

        queue[back++] = root;

        while (front < back && count < maxNodes) {
            address current = queue[front++];
            count++;

            address[] memory referees = users[current].referees;

            // Only traverse up to maxDepth
            if (users[current].chainDepth < users[root].chainDepth + maxDepth) {
                for (uint256 i = 0; i < referees.length && back < maxNodes; i++) {
                    queue[back++] = referees[i];
                }
            }
        }

        return count;
    }

    /**
     * @dev FIX #0.2: Check if descendant is in the chain of ancestor
     * Prevents cycles in referral graph
     */
    function _isInChain(address ancestor, address descendant) internal view returns (bool) {
        address current = ancestor;
        uint256 depth = 0;
        uint256 maxDepth = 100; // Prevent infinite loops

        while (current != address(0) && depth < maxDepth) {
            if (current == descendant) {
                return true;
            }
            current = users[current].referrer;
            depth++;
        }

        return false;
    }

    /**
     * @dev Calculate potential earnings for a user if they refer someone
     * Shows the power of Shapley vs flat rate
     */
    function estimateReferralValue(address user) external view returns (
        uint256 immediateReward,
        uint256 estimatedCoalitionBonus,
        uint256 totalEstimate
    ) {
        require(users[user].exists, "User not found");

        // Immediate split reward
        immediateReward = BASE_REFERRAL_REWARD / 2;

        // Estimate coalition bonus based on current chain
        address[] memory currentChain = _buildCoalition(user);
        address[] memory futureCoalition = new address[](currentChain.length + 1);

        for (uint256 i = 0; i < currentChain.length; i++) {
            futureCoalition[i + 1] = currentChain[i];
        }
        futureCoalition[0] = address(0xdead); // Placeholder for new member

        uint256 futureValue = _calculateCoalitionValue(futureCoalition);
        uint256[] memory futureShares = _approximateShapleyValues(futureCoalition, futureValue);

        // User's share (they're at position 1 in futureCoalition)
        estimatedCoalitionBonus = futureShares[1];

        totalEstimate = immediateReward + estimatedCoalitionBonus;

        return (immediateReward, estimatedCoalitionBonus, totalEstimate);
    }

    /**
     * @dev Compare Shapley model earnings vs flat-rate model
     */
    function compareToFlatRate(address user) external view returns (
        uint256 shapleyEarnings,
        uint256 flatRateEarnings,
        uint256 percentageIncrease
    ) {
        require(users[user].exists, "User not found");

        shapleyEarnings = users[user].totalEarned;

        // In flat rate model: only direct referrals count
        uint256 directReferrals = users[user].referees.length;
        flatRateEarnings = directReferrals * BASE_REFERRAL_REWARD;

        if (flatRateEarnings == 0) {
            percentageIncrease = 0;
        } else {
            percentageIncrease = ((shapleyEarnings - flatRateEarnings) * 100) / flatRateEarnings;
        }

        return (shapleyEarnings, flatRateEarnings, percentageIncrease);
    }
}
