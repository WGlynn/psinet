// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PsiToken.sol";

/**
 * @title HarbergerNFT
 * @dev Base contract implementing Harberger taxation for NFTs
 *
 * HARBERGER TAX PRINCIPLES:
 * 1. Owner self-assesses value of their NFT
 * 2. Owner pays periodic tax (e.g., 5% APR) on self-assessed value
 * 3. Anyone can buy the NFT at self-assessed price (always for sale!)
 * 4. Tax revenue distributed to: creators, rewards pool, treasury
 *
 * BENEFITS:
 * - Discourages speculation and hoarding
 * - Improves market liquidity (always for sale at known price)
 * - Generates sustainable creator royalties
 * - Encourages productive use of NFTs
 * - Promotes honest valuation (overvalue = high tax, undervalue = forced sale)
 * - Prevents monopolization
 *
 * ALIGNMENT WITH ΨNET:
 * - Reduces rent extraction (core principle)
 * - Reduces information asymmetry (honest self-assessment)
 * - Positive-sum economics (tax → rewards)
 * - Increases liquidity (always tradeable)
 */
abstract contract HarbergerNFT is ERC721, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    PsiToken public psiToken;

    // Harberger tax configuration
    uint256 public constant TAX_RATE_BPS = 500; // 5% annual tax rate (500 basis points)
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    // Tax distribution (must sum to 10000 = 100%)
    uint256 public constant TAX_TO_CREATOR = 4000; // 40% to original creator
    uint256 public constant TAX_TO_REWARDS = 4000; // 40% to reward pool
    uint256 public constant TAX_TO_TREASURY = 2000; // 20% to treasury

    struct AssetData {
        uint256 selfAssessedValue; // Owner's declared price (in PSI)
        uint256 lastTaxPayment; // Timestamp of last tax payment
        uint256 accumulatedTax; // Unpaid tax debt
        address creator; // Original creator (receives tax share)
        bool exists;
    }

    mapping(uint256 => AssetData) public assets;

    address public rewardPool;
    address public treasury;

    uint256 public totalTaxCollected;
    uint256 public totalCreatorRoyalties;

    event SelfAssessmentUpdated(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 oldValue,
        uint256 newValue
    );
    event TaxPaid(uint256 indexed tokenId, address indexed payer, uint256 amount);
    event ForcedSale(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );
    event TaxDistributed(
        uint256 indexed tokenId,
        uint256 toCreator,
        uint256 toRewards,
        uint256 toTreasury
    );
    event AssetForfeited(uint256 indexed tokenId, address indexed previousOwner, uint256 unpaidTax);

    constructor(
        string memory name,
        string memory symbol,
        address _psiToken,
        address _rewardPool,
        address _treasury
    ) ERC721(name, symbol) {
        psiToken = PsiToken(_psiToken);
        rewardPool = _rewardPool;
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Calculate tax owed since last payment
     * Tax = selfAssessedValue × taxRate × (timeSinceLastPayment / 1 year)
     */
    function calculateTaxOwed(uint256 tokenId) public view returns (uint256) {
        AssetData storage asset = assets[tokenId];
        if (!asset.exists || asset.selfAssessedValue == 0) return 0;

        uint256 timeElapsed = block.timestamp - asset.lastTaxPayment;
        uint256 annualTax = (asset.selfAssessedValue * TAX_RATE_BPS) / 10000;
        uint256 taxOwed = (annualTax * timeElapsed) / SECONDS_PER_YEAR;

        return asset.accumulatedTax + taxOwed;
    }

    /**
     * @dev Update self-assessed value
     * Higher value = higher tax burden
     * Lower value = risk of forced sale
     */
    function updateSelfAssessment(uint256 tokenId, uint256 newValue) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        AssetData storage asset = assets[tokenId];

        // First, collect any accumulated tax at old valuation
        uint256 taxOwed = calculateTaxOwed(tokenId);
        if (taxOwed > 0) {
            asset.accumulatedTax = taxOwed;
        }

        uint256 oldValue = asset.selfAssessedValue;
        asset.selfAssessedValue = newValue;
        asset.lastTaxPayment = block.timestamp; // Reset tax clock

        emit SelfAssessmentUpdated(tokenId, msg.sender, oldValue, newValue);
    }

    /**
     * @dev Pay accumulated tax to maintain ownership
     */
    function payTax(uint256 tokenId) external nonReentrant {
        require(assets[tokenId].exists, "Asset does not exist");

        uint256 taxOwed = calculateTaxOwed(tokenId);
        require(taxOwed > 0, "No tax owed");

        AssetData storage asset = assets[tokenId];

        // Transfer PSI from payer
        psiToken.transferFrom(msg.sender, address(this), taxOwed);

        // Distribute tax
        _distributeTax(tokenId, taxOwed);

        // Reset tax accounting
        asset.accumulatedTax = 0;
        asset.lastTaxPayment = block.timestamp;

        totalTaxCollected += taxOwed;

        emit TaxPaid(tokenId, msg.sender, taxOwed);
    }

    /**
     * @dev Distribute collected tax according to allocation
     */
    function _distributeTax(uint256 tokenId, uint256 taxAmount) internal {
        AssetData storage asset = assets[tokenId];

        uint256 toCreator = (taxAmount * TAX_TO_CREATOR) / 10000;
        uint256 toRewards = (taxAmount * TAX_TO_REWARDS) / 10000;
        uint256 toTreasury = (taxAmount * TAX_TO_TREASURY) / 10000;

        // Send to creator
        if (asset.creator != address(0) && toCreator > 0) {
            psiToken.transfer(asset.creator, toCreator);
            totalCreatorRoyalties += toCreator;
        }

        // Send to reward pool
        if (rewardPool != address(0) && toRewards > 0) {
            psiToken.transfer(rewardPool, toRewards);
        }

        // Send to treasury
        if (treasury != address(0) && toTreasury > 0) {
            psiToken.transfer(treasury, toTreasury);
        }

        emit TaxDistributed(tokenId, toCreator, toRewards, toTreasury);
    }

    /**
     * @dev FORCED SALE: Buy NFT at self-assessed price
     * This is the core Harberger mechanism - assets are always for sale!
     */
    function forcedPurchase(uint256 tokenId) external nonReentrant {
        require(assets[tokenId].exists, "Asset does not exist");
        require(ownerOf(tokenId) != msg.sender, "Already owner");

        AssetData storage asset = assets[tokenId];
        require(asset.selfAssessedValue > 0, "Asset not for sale (value = 0)");

        address currentOwner = ownerOf(tokenId);
        uint256 price = asset.selfAssessedValue;

        // Calculate any unpaid tax
        uint256 taxOwed = calculateTaxOwed(tokenId);

        // Buyer pays the self-assessed price
        psiToken.transferFrom(msg.sender, currentOwner, price);

        // Handle unpaid taxes
        if (taxOwed > 0) {
            // Deduct tax from seller's proceeds (if they received enough)
            // In practice, we require buyer to pay tax or seller forfeits
            try psiToken.transferFrom(currentOwner, address(this), taxOwed) {
                _distributeTax(tokenId, taxOwed);
                asset.accumulatedTax = 0;
            } catch {
                // Seller couldn't pay tax - forfeit, tax waived
                asset.accumulatedTax = 0;
            }
        }

        // Transfer NFT
        _transfer(currentOwner, msg.sender, tokenId);

        // Reset tax clock for new owner
        asset.lastTaxPayment = block.timestamp;
        // New owner must set their own assessment
        // For now, inherit previous assessment as starting point

        emit ForcedSale(tokenId, currentOwner, msg.sender, price);
    }

    /**
     * @dev Forfeit asset if unable to pay tax
     * Asset goes to treasury or reward pool
     */
    function forfeitAsset(uint256 tokenId) external {
        require(assets[tokenId].exists, "Asset does not exist");

        address currentOwner = ownerOf(tokenId);
        uint256 taxOwed = calculateTaxOwed(tokenId);

        // Only owner can voluntarily forfeit, or anyone if tax debt is very high
        require(
            msg.sender == currentOwner ||
            taxOwed >= assets[tokenId].selfAssessedValue,
            "Cannot forfeit"
        );

        AssetData storage asset = assets[tokenId];

        // Transfer to treasury
        _transfer(currentOwner, treasury, tokenId);

        // Reset assessment
        asset.selfAssessedValue = 0;
        asset.accumulatedTax = 0;
        asset.lastTaxPayment = block.timestamp;

        emit AssetForfeited(tokenId, currentOwner, taxOwed);
    }

    /**
     * @dev Check if asset is at risk of forced sale (undervalued)
     */
    function isUndervalued(uint256 tokenId, uint256 marketEstimate)
        public
        view
        returns (bool)
    {
        return assets[tokenId].selfAssessedValue < marketEstimate;
    }

    /**
     * @dev Check if owner is overpaying tax (overvalued)
     */
    function isOvervalued(uint256 tokenId, uint256 marketEstimate)
        public
        view
        returns (bool)
    {
        return assets[tokenId].selfAssessedValue > marketEstimate;
    }

    /**
     * @dev Get effective annual tax burden for an owner
     */
    function getAnnualTaxBurden(uint256 tokenId) public view returns (uint256) {
        uint256 value = assets[tokenId].selfAssessedValue;
        return (value * TAX_RATE_BPS) / 10000; // 5% of self-assessed value
    }

    /**
     * @dev Calculate monthly tax payment
     */
    function getMonthlyTax(uint256 tokenId) public view returns (uint256) {
        return getAnnualTaxBurden(tokenId) / 12;
    }

    /**
     * @dev Get time until next tax payment due (recommendation: monthly)
     */
    function timeUntilTaxDue(uint256 tokenId) public view returns (uint256) {
        AssetData storage asset = assets[tokenId];
        uint256 monthInSeconds = 30 days;
        uint256 timeSincePayment = block.timestamp - asset.lastTaxPayment;

        if (timeSincePayment >= monthInSeconds) {
            return 0; // Overdue
        }

        return monthInSeconds - timeSincePayment;
    }

    /**
     * @dev Check if asset is at risk of forfeiture (high unpaid tax)
     */
    function isAtRiskOfForfeiture(uint256 tokenId) public view returns (bool) {
        uint256 taxOwed = calculateTaxOwed(tokenId);
        uint256 value = assets[tokenId].selfAssessedValue;

        // At risk if tax owed exceeds 50% of asset value
        return taxOwed >= (value / 2);
    }

    /**
     * @dev Helper: Register new asset (for subclasses)
     */
    function _registerAsset(
        uint256 tokenId,
        address creator,
        uint256 initialValue
    ) internal {
        require(!assets[tokenId].exists, "Asset already exists");

        assets[tokenId] = AssetData({
            selfAssessedValue: initialValue,
            lastTaxPayment: block.timestamp,
            accumulatedTax: 0,
            creator: creator,
            exists: true
        });
    }

    /**
     * @dev Compare Harberger model vs traditional ownership
     */
    function compareToTraditional(uint256 tokenId, uint256 holdingPeriodYears)
        public
        view
        returns (
            uint256 harbergerCost,
            uint256 traditionalCost,
            uint256 liquidityBenefit
        )
    {
        uint256 annualTax = getAnnualTaxBurden(tokenId);
        harbergerCost = annualTax * holdingPeriodYears;

        // Traditional: one-time creator royalty (e.g., 10%)
        traditionalCost = (assets[tokenId].selfAssessedValue * 1000) / 10000;

        // Liquidity benefit: Harberger assets are always liquid
        // Estimate: 20% premium for instant liquidity
        liquidityBenefit = (assets[tokenId].selfAssessedValue * 2000) / 10000;

        return (harbergerCost, traditionalCost, liquidityBenefit);
    }

    /**
     * @dev Get complete asset information
     */
    function getAssetInfo(uint256 tokenId)
        public
        view
        returns (
            address owner,
            uint256 selfAssessedValue,
            uint256 taxOwed,
            uint256 annualTax,
            address creator,
            bool atRisk
        )
    {
        AssetData storage asset = assets[tokenId];

        return (
            ownerOf(tokenId),
            asset.selfAssessedValue,
            calculateTaxOwed(tokenId),
            getAnnualTaxBurden(tokenId),
            asset.creator,
            isAtRiskOfForfeiture(tokenId)
        );
    }

    /**
     * @dev Admin: Update tax parameters (if needed)
     */
    function updateAddresses(address _rewardPool, address _treasury)
        external
        onlyRole(ADMIN_ROLE)
    {
        rewardPool = _rewardPool;
        treasury = _treasury;
    }
}
