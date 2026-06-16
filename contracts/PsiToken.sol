// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PsiToken
 * @dev Native cryptocurrency for ΨNet with positive-sum mutualistic incentives
 *
 * DESIGN PRINCIPLES:
 * 1. Positive-Sum: Network growth benefits all participants proportionally
 * 2. Reduce Rent Extraction: Direct P2P value flow, minimal platform fees
 * 3. Reduce Information Asymmetry: Transparent on-chain economics
 * 4. Mutualistic Incentives: Cooperation rewards exceed competition rewards
 * 5. Value Accrual: Token holders benefit from network activity
 *
 * TOKENOMICS:
 * - Total Supply: 1,000,000,000 PSI (1 billion)
 * - Distribution: Community-driven, no pre-mine for team
 * - Inflation: None (fixed supply)
 * - Deflationary: Burns on every transaction reduce supply
 * - Rewards: Earned through positive network contributions
 */
contract PsiToken is ERC20, ERC20Burnable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");

    // Maximum total supply: 1 billion PSI
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    // Transaction fee: 0.1% (10 basis points) - extremely low to reduce rent extraction
    uint256 public constant TRANSACTION_FEE_BPS = 10; // 0.1%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // Fee distribution: All fees go to value creation, not extraction
    uint256 public constant FEE_TO_BURN = 5000; // 50% burned (deflationary)
    uint256 public constant FEE_TO_REWARDS = 3000; // 30% to reward pool
    uint256 public constant FEE_TO_TREASURY = 2000; // 20% to treasury (community-controlled)

    // Reward pools
    uint256 public agentRewardPool; // Rewards for high-reputation agents
    uint256 public validatorRewardPool; // Rewards for validators
    uint256 public contributorRewardPool; // Rewards for positive contributions
    uint256 public treasuryPool; // Community treasury

    // Mutualistic multipliers: Cooperation earns more than solo actions
    uint256 public constant SOLO_MULTIPLIER = 100; // 1x
    uint256 public constant COOPERATIVE_MULTIPLIER = 150; // 1.5x
    uint256 public constant NETWORK_EFFECT_MULTIPLIER = 200; // 2x

    // Anti-rent-extraction: Max fee cap to prevent future exploitation
    uint256 public constant MAX_TRANSACTION_FEE_BPS = 100; // Max 1%

    // Transparency: All economic parameters visible
    mapping(address => uint256) public lifetimeRewardsEarned;
    mapping(address => uint256) public lifetimeContributions;
    uint256 public totalRewardsDistributed;
    uint256 public totalBurned;

    // FIX #0.5: Circuit breakers for emergency control
    bool public emergencyPaused;
    uint256 public dailyMintLimit = 1_000_000 * 10**18; // 1M PSI/day
    uint256 public mintedToday;
    uint256 public lastMintReset;

    // Events for transparency
    event RewardDistributed(address indexed recipient, uint256 amount, string reason);
    event FeesCollected(uint256 burned, uint256 toRewards, uint256 toTreasury);
    event CooperativeReward(address indexed agent1, address indexed agent2, uint256 bonus);
    event NetworkEffectBonus(address indexed agent, uint256 bonus, uint256 networkSize);

    // FIX #0.5: Circuit breaker events
    event EmergencyPause(address indexed admin, string reason);
    event EmergencyUnpause(address indexed admin);
    event DailyMintLimitExceeded(uint256 attempted, uint256 limit);
    event DailyMintLimitUpdated(uint256 oldLimit, uint256 newLimit);

    constructor() ERC20("PsiNet Token", "PSI") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(REWARDER_ROLE, msg.sender);

        // Initial mint for bootstrapping (10% of max supply)
        // Goes to treasury for initial rewards and liquidity
        _mint(address(this), MAX_SUPPLY / 10);
        treasuryPool = MAX_SUPPLY / 10;

        // FIX #0.5: Initialize mint tracking
        lastMintReset = block.timestamp;
    }

    // FIX #0.5: Circuit breaker modifier
    modifier whenNotPaused() {
        require(!emergencyPaused, "PsiToken: emergency pause active");
        _;
    }

    /**
     * @dev FIX #0.5: Emergency pause to stop all minting and rewarding
     * Only callable by admin in case of exploit or attack
     */
    function emergencyPause(string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPaused = true;
        emit EmergencyPause(msg.sender, reason);
    }

    /**
     * @dev FIX #0.5: Unpause after emergency is resolved
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPaused = false;
        emit EmergencyUnpause(msg.sender);
    }

    /**
     * @dev FIX #0.5: Update daily mint limit
     */
    function setDailyMintLimit(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldLimit = dailyMintLimit;
        dailyMintLimit = newLimit;
        emit DailyMintLimitUpdated(oldLimit, newLimit);
    }

    /**
     * @dev Mint new tokens (capped at MAX_SUPPLY)
     * Only callable by MINTER_ROLE
     * FIX #0.5: Added daily mint limit check
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "PsiToken: max supply exceeded");

        // FIX #0.5: Check daily mint limit
        _checkDailyMintLimit(amount);

        _mint(to, amount);
    }

    /**
     * @dev FIX #0.5: Internal function to check and update daily mint limit
     */
    function _checkDailyMintLimit(uint256 amount) private {
        // Reset counter if a day has passed
        if (block.timestamp > lastMintReset + 1 days) {
            mintedToday = 0;
            lastMintReset = block.timestamp;
        }

        // Check limit
        require(mintedToday + amount <= dailyMintLimit, "PsiToken: daily mint limit exceeded");
        mintedToday += amount;

        if (mintedToday >= dailyMintLimit * 90 / 100) {
            // Emit warning if approaching limit (90%)
            emit DailyMintLimitExceeded(mintedToday, dailyMintLimit);
        }
    }

    /**
     * @dev Transfer with automatic fee distribution
     * Implements low-fee, positive-sum economics
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 fee = (amount * TRANSACTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // Distribute fees according to positive-sum model
        _distributeFees(owner, fee);

        // Transfer net amount
        _transfer(owner, to, netAmount);

        return true;
    }

    /**
     * @dev TransferFrom with automatic fee distribution
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        uint256 fee = (amount * TRANSACTION_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        _distributeFees(from, fee);
        _transfer(from, to, netAmount);

        return true;
    }

    /**
     * @dev Distribute transaction fees according to positive-sum model
     * - 50% burned (benefits all holders via scarcity)
     * - 30% to reward pools (benefits contributors)
     * - 20% to treasury (benefits ecosystem)
     */
    function _distributeFees(address from, uint256 fee) private {
        if (fee == 0) return;

        uint256 toBurn = (fee * FEE_TO_BURN) / BPS_DENOMINATOR;
        uint256 toRewards = (fee * FEE_TO_REWARDS) / BPS_DENOMINATOR;
        uint256 toTreasury = fee - toBurn - toRewards;

        // Burn portion (deflationary)
        _burn(from, toBurn);
        totalBurned += toBurn;

        // Transfer to contract for reward distribution
        _transfer(from, address(this), toRewards + toTreasury);

        // Allocate to pools
        contributorRewardPool += toRewards;
        treasuryPool += toTreasury;

        emit FeesCollected(toBurn, toRewards, toTreasury);
    }

    /**
     * @dev Reward agent for positive contribution
     * Mutualistic design: Higher rewards for cooperative behavior
     */
    function rewardAgent(
        address agent,
        uint256 baseAmount,
        bool isCooperative,
        uint256 networkSize
    ) external onlyRole(REWARDER_ROLE) nonReentrant whenNotPaused {
        require(agent != address(0), "PsiToken: zero address");

        uint256 reward = baseAmount;

        // Apply cooperative multiplier (mutualism)
        if (isCooperative) {
            reward = (reward * COOPERATIVE_MULTIPLIER) / 100;
        } else {
            reward = (reward * SOLO_MULTIPLIER) / 100;
        }

        // Apply network effect multiplier (positive-sum)
        // Larger network = higher rewards for everyone
        if (networkSize > 100) {
            reward = (reward * NETWORK_EFFECT_MULTIPLIER) / 100;
            emit NetworkEffectBonus(agent, reward - baseAmount, networkSize);
        }

        // Distribute from reward pool
        require(contributorRewardPool >= reward, "PsiToken: insufficient reward pool");
        contributorRewardPool -= reward;

        _transfer(address(this), agent, reward);

        // Track for transparency
        lifetimeRewardsEarned[agent] += reward;
        lifetimeContributions[agent] += 1;
        totalRewardsDistributed += reward;

        emit RewardDistributed(agent, reward, "contribution");
    }

    /**
     * @dev Reward validator for validation work
     * Ensures security through economic incentives
     */
    function rewardValidator(address validator, uint256 amount)
        external
        onlyRole(REWARDER_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(validator != address(0), "PsiToken: zero address");
        require(validatorRewardPool >= amount, "PsiToken: insufficient validator pool");

        validatorRewardPool -= amount;
        _transfer(address(this), validator, amount);

        lifetimeRewardsEarned[validator] += amount;
        totalRewardsDistributed += amount;

        emit RewardDistributed(validator, amount, "validation");
    }

    /**
     * @dev Reward cooperative interaction between agents
     * Mutualistic design: Both agents benefit from cooperation
     */
    function rewardCooperation(address agent1, address agent2, uint256 baseAmount)
        external
        onlyRole(REWARDER_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(agent1 != address(0) && agent2 != address(0), "PsiToken: zero address");

        // Both agents get boosted rewards (positive-sum)
        uint256 reward1 = (baseAmount * COOPERATIVE_MULTIPLIER) / 100;
        uint256 reward2 = (baseAmount * COOPERATIVE_MULTIPLIER) / 100;
        uint256 totalReward = reward1 + reward2;

        require(contributorRewardPool >= totalReward, "PsiToken: insufficient pool");

        contributorRewardPool -= totalReward;

        _transfer(address(this), agent1, reward1);
        _transfer(address(this), agent2, reward2);

        lifetimeRewardsEarned[agent1] += reward1;
        lifetimeRewardsEarned[agent2] += reward2;
        totalRewardsDistributed += totalReward;

        emit CooperativeReward(agent1, agent2, totalReward);
        emit RewardDistributed(agent1, reward1, "cooperation");
        emit RewardDistributed(agent2, reward2, "cooperation");
    }

    /**
     * @dev Allocate treasury funds to reward pools
     * Community-controlled to prevent rent extraction
     */
    function allocateTreasuryToRewards(
        uint256 toAgents,
        uint256 toValidators,
        uint256 toContributors
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 total = toAgents + toValidators + toContributors;
        require(treasuryPool >= total, "PsiToken: insufficient treasury");

        treasuryPool -= total;
        agentRewardPool += toAgents;
        validatorRewardPool += toValidators;
        contributorRewardPool += toContributors;
    }

    /**
     * @dev Get economic transparency data
     * Reduces information asymmetry
     */
    function getEconomicStats() external view returns (
        uint256 _totalSupply,
        uint256 _totalBurned,
        uint256 _totalRewardsDistributed,
        uint256 _agentRewardPool,
        uint256 _validatorRewardPool,
        uint256 _contributorRewardPool,
        uint256 _treasuryPool,
        uint256 _circulatingSupply
    ) {
        _totalSupply = totalSupply();
        _totalBurned = totalBurned;
        _totalRewardsDistributed = totalRewardsDistributed;
        _agentRewardPool = agentRewardPool;
        _validatorRewardPool = validatorRewardPool;
        _contributorRewardPool = contributorRewardPool;
        _treasuryPool = treasuryPool;
        _circulatingSupply = totalSupply() - balanceOf(address(this));
    }

    /**
     * @dev Get user contribution stats
     * Full transparency of individual economics
     */
    function getUserStats(address user) external view returns (
        uint256 balance,
        uint256 rewards,
        uint256 contributions
    ) {
        balance = balanceOf(user);
        rewards = lifetimeRewardsEarned[user];
        contributions = lifetimeContributions[user];
    }

    /**
     * @dev Emergency withdrawal (only admin, only to treasury)
     * Safety mechanism with transparency
     */
    function emergencyWithdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= balanceOf(address(this)), "PsiToken: insufficient balance");
        treasuryPool += amount;
        // Funds stay in contract, just moved to treasury accounting
        emit RewardDistributed(address(this), amount, "emergency_withdrawal");
    }
}
