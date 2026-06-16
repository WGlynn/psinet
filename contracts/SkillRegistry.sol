// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HarbergerNFT.sol";
import "./erc8004/IReputationRegistry.sol";

/**
 * @title SkillRegistry
 * @dev Decentralized registry for AI agent skills with Harberger taxation
 *
 * INTEGRATION WITH SKILL SEEKERS:
 * Skill Seekers (https://github.com/yusufkaraaslan/Skill_Seekers) automatically
 * extracts skills from documentation, GitHub repos, and PDFs. This contract
 * creates a decentralized marketplace for those skills.
 *
 * WORKFLOW:
 * 1. Skill Seekers scrapes docs/code → generates skill package
 * 2. Skill package uploaded to IPFS (content-addressed)
 * 3. Agent registers skill in this contract (Harberger NFT)
 * 4. Skill is always for sale at self-assessed price
 * 5. Users can purchase/license skills
 * 6. CRPC validation ensures skill quality
 *
 * HARBERGER BENEFITS:
 * - Prevents skill hoarding (unused skills taxed)
 * - Ensures active maintenance (must update to justify value)
 * - Fair pricing (market-driven self-assessment)
 * - Continuous creator revenue (tax distribution)
 * - Always-liquid marketplace (instant purchases)
 *
 * EXAMPLE SKILLS:
 * - "React Expert" (extracted from React docs)
 * - "Solidity Auditor" (extracted from OpenZeppelin + GitHub)
 * - "Godot Game Dev" (extracted from Godot docs + examples)
 * - "FastAPI Backend" (extracted from FastAPI docs + repos)
 */
contract SkillRegistry is HarbergerNFT {
    IReputationRegistry public reputationRegistry;

    // Skill metadata
    struct Skill {
        string name;
        string description;
        string ipfsHash; // Skill package on IPFS (from Skill Seekers)
        string[] tags; // e.g., ["python", "fastapi", "backend"]
        address creator;
        uint256 agentId; // ERC-8004 agent identity
        uint256 createdAt;
        uint256 lastUpdated;
        SkillType skillType;
        uint256 usageCount; // How many times licensed/used
        uint256 qualityScore; // 0-100 from CRPC validation
        bool verified; // CRPC verified
        // Context Quality Incentives
        uint256 compressionRatio; // 1-100 (higher = better compression)
        uint256 originalSizeBytes; // Original uncompressed size
        uint256 compressedSizeBytes; // Compressed size
        uint256 reliabilitySuccessCount; // Successful validations
        uint256 reliabilityFailureCount; // Failed validations
    }

    enum SkillType {
        DOCUMENTATION, // Scraped from docs
        CODE_ANALYSIS, // Extracted from GitHub
        PDF_KNOWLEDGE, // Extracted from PDFs
        UNIFIED // Combined sources
    }

    // Licensing
    struct License {
        uint256 skillId;
        address licensee;
        uint256 expiresAt;
        uint256 pricePaid;
        bool active;
    }

    mapping(uint256 => Skill) public skills;
    mapping(uint256 => License[]) public skillLicenses;
    mapping(address => uint256[]) private _userSkills;
    mapping(string => uint256[]) private _taggedSkills; // tag → skill IDs

    uint256 private _skillIdCounter;

    uint256 public constant MIN_SKILL_VALUE = 100 * 10**18; // 100 PSI minimum
    uint256 public constant LICENSE_DURATION = 90 days; // 3 months

    event SkillRegistered(
        uint256 indexed skillId,
        address indexed creator,
        string name,
        string ipfsHash,
        uint256 initialValue
    );
    event SkillUpdated(uint256 indexed skillId, string newIpfsHash);
    event SkillLicensed(
        uint256 indexed skillId,
        address indexed licensee,
        uint256 price,
        uint256 expiresAt
    );
    event SkillVerified(uint256 indexed skillId, uint256 qualityScore);
    event SkillUsed(uint256 indexed skillId, address indexed user);
    event CompressionUpdated(
        uint256 indexed skillId,
        uint256 compressionRatio,
        uint256 originalSize,
        uint256 compressedSize
    );
    event ReliabilityRecorded(
        uint256 indexed skillId,
        bool success,
        uint256 successCount,
        uint256 failureCount
    );

    constructor(
        address _psiToken,
        address _rewardPool,
        address _treasury,
        address _reputationRegistry
    ) HarbergerNFT(
        "PsiNet Skill Registry (Harberger)",
        "PSISKILL-H",
        _psiToken,
        _rewardPool,
        _treasury
    ) {
        reputationRegistry = IReputationRegistry(_reputationRegistry);
        _skillIdCounter = 1; // Start at 1
    }

    /**
     * @dev Register a new skill from Skill Seekers output
     * @param name Skill name (e.g., "React Expert")
     * @param description Human-readable description
     * @param ipfsHash IPFS hash of skill package (from Skill Seekers)
     * @param tags Searchable tags (e.g., ["react", "javascript", "frontend"])
     * @param skillType Type of skill source
     * @param initialValue Initial self-assessed value in PSI
     * @param agentId ERC-8004 agent ID (optional, 0 if none)
     */
    function registerSkill(
        string calldata name,
        string calldata description,
        string calldata ipfsHash,
        string[] calldata tags,
        SkillType skillType,
        uint256 initialValue,
        uint256 agentId
    ) external returns (uint256 skillId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(ipfsHash).length > 0, "IPFS hash required");
        require(initialValue >= MIN_SKILL_VALUE, "Minimum value not met");
        require(tags.length > 0 && tags.length <= 10, "1-10 tags required");

        skillId = _skillIdCounter;
        _skillIdCounter++;

        // Mint Harberger NFT
        _mint(msg.sender, skillId);

        // Register Harberger asset
        _registerAsset(skillId, msg.sender, initialValue);

        // Store skill metadata
        skills[skillId] = Skill({
            name: name,
            description: description,
            ipfsHash: ipfsHash,
            tags: tags,
            creator: msg.sender,
            agentId: agentId,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            skillType: skillType,
            usageCount: 0,
            qualityScore: 0,
            verified: false
        });

        // Index by tags
        for (uint256 i = 0; i < tags.length; i++) {
            _taggedSkills[tags[i]].push(skillId);
        }

        // Track user skills
        _userSkills[msg.sender].push(skillId);

        emit SkillRegistered(skillId, msg.sender, name, ipfsHash, initialValue);

        return skillId;
    }

    /**
     * @dev Update skill package (e.g., new version from Skill Seekers)
     * Only owner can update
     */
    function updateSkill(
        uint256 skillId,
        string calldata newIpfsHash,
        string calldata newDescription
    ) external {
        require(ownerOf(skillId) == msg.sender, "Not owner");
        require(bytes(newIpfsHash).length > 0, "IPFS hash required");

        Skill storage skill = skills[skillId];
        skill.ipfsHash = newIpfsHash;
        skill.description = newDescription;
        skill.lastUpdated = block.timestamp;

        emit SkillUpdated(skillId, newIpfsHash);
    }

    /**
     * @dev Update compression metrics for a skill
     * Better compression = lower prices = more competitive
     * Only owner can update compression data
     */
    function updateCompression(
        uint256 skillId,
        uint256 originalSize,
        uint256 compressedSize
    ) external {
        require(_exists(skillId), "Skill does not exist");
        require(ownerOf(skillId) == msg.sender, "Not owner");
        require(originalSize > 0 && compressedSize > 0, "Invalid sizes");
        require(compressedSize <= originalSize, "Compressed must be <= original");

        Skill storage skill = skills[skillId];
        skill.originalSizeBytes = originalSize;
        skill.compressedSizeBytes = compressedSize;

        // Calculate compression ratio (0-100 scale)
        // 10x compression (compress to 10%) = ratio 100
        // 2x compression (compress to 50%) = ratio 50
        // 1x compression (no compression) = ratio 0
        uint256 compressionPercent = ((originalSize - compressedSize) * 100) / originalSize;
        skill.compressionRatio = compressionPercent;

        emit CompressionUpdated(skillId, skill.compressionRatio, originalSize, compressedSize);
    }

    /**
     * @dev Record validation result for reliability tracking
     * This is called by validators or the owner after testing
     * High reliability = lower prices = more competitive
     */
    function recordValidation(uint256 skillId, bool success) external {
        require(_exists(skillId), "Skill does not exist");
        // Only owner or validators can record validation results
        // In production, this should be restricted to ValidationRegistry
        require(
            ownerOf(skillId) == msg.sender || msg.sender == address(this),
            "Not authorized"
        );

        Skill storage skill = skills[skillId];

        if (success) {
            skill.reliabilitySuccessCount++;
        } else {
            skill.reliabilityFailureCount++;
        }

        emit ReliabilityRecorded(
            skillId,
            success,
            skill.reliabilitySuccessCount,
            skill.reliabilityFailureCount
        );
    }

    /**
     * @dev Calculate quality-weighted price for a skill
     * Better quality/compression/reliability = lower effective price = more competitive
     *
     * Quality multiplier (0.5x to 1.5x):
     *   Quality 100 → 0.5x, Quality 50 → 1x, Quality 0 → 1.5x
     *
     * Usage bonus (0.8x to 1.2x):
     *   High usage (100+) → 0.8x, Low usage (0) → 1.2x
     *
     * Compression bonus (0.7x to 1.3x):
     *   High compression (100) → 0.7x, Medium (50) → 1x, Low (0) → 1.3x
     *
     * Reliability bonus (0.6x to 1.4x):
     *   High reliability (100%) → 0.6x, Medium (50%) → 1x, Low (0%) → 1.4x
     *
     * Best case: 0.5 × 0.8 × 0.7 × 0.6 = 0.168x (83% discount!)
     * Worst case: 1.5 × 1.2 × 1.3 × 1.4 = 3.276x (228% premium)
     */
    function getQualityWeightedPrice(uint256 skillId) public view returns (uint256) {
        require(_exists(skillId), "Skill does not exist");

        Skill storage skill = skills[skillId];
        uint256 basePrice = assets[skillId].selfAssessedValue / 10; // 10% of value

        // Quality multiplier (50-150%)
        uint256 qualityMultiplier = 150 - (skill.qualityScore / 2);

        // Usage/reliability bonus (80-120%)
        uint256 usageMultiplier = 120;
        if (skill.usageCount > 100) {
            usageMultiplier = 80; // Popular, proven skills get discount
        } else if (skill.usageCount > 10) {
            usageMultiplier = 100;
        }

        // Compression bonus (70-130%)
        uint256 compressionMultiplier = 130 - (skill.compressionRatio * 6 / 10);
        if (compressionMultiplier < 70) compressionMultiplier = 70;
        if (compressionMultiplier > 130) compressionMultiplier = 130;

        // Reliability bonus (60-140%)
        uint256 reliabilityMultiplier = 100;
        uint256 totalValidations = skill.reliabilitySuccessCount + skill.reliabilityFailureCount;
        if (totalValidations > 0) {
            uint256 reliabilityPercent = (skill.reliabilitySuccessCount * 100) / totalValidations;
            // Reliability 100% → 60, Reliability 50% → 100, Reliability 0% → 140
            reliabilityMultiplier = 140 - (reliabilityPercent * 8 / 10);
        }

        // Apply all multipliers
        uint256 effectivePrice = (basePrice * qualityMultiplier * usageMultiplier * compressionMultiplier * reliabilityMultiplier) / (100 * 100 * 100 * 100);

        return effectivePrice;
    }

    /**
     * @dev License a skill for use (doesn't transfer ownership)
     * User pays quality-weighted price for LICENSE_DURATION
     */
    function licenseSkill(uint256 skillId) external nonReentrant {
        require(_exists(skillId), "Skill does not exist");

        Skill storage skill = skills[skillId];

        // Use quality-weighted pricing
        uint256 licensePrice = getQualityWeightedPrice(skillId);

        // Transfer PSI from licensee to skill owner
        psiToken.transferFrom(msg.sender, ownerOf(skillId), licensePrice);

        // Create license
        License memory newLicense = License({
            skillId: skillId,
            licensee: msg.sender,
            expiresAt: block.timestamp + LICENSE_DURATION,
            pricePaid: licensePrice,
            active: true
        });

        skillLicenses[skillId].push(newLicense);
        skill.usageCount++;

        emit SkillLicensed(
            skillId,
            msg.sender,
            licensePrice,
            block.timestamp + LICENSE_DURATION
        );
    }

    /**
     * @dev Record skill usage (for analytics and reputation)
     */
    function recordSkillUsage(uint256 skillId) external {
        require(_exists(skillId), "Skill does not exist");
        require(hasActiveLicense(skillId, msg.sender) || ownerOf(skillId) == msg.sender, "No license");

        skills[skillId].usageCount++;

        emit SkillUsed(skillId, msg.sender);
    }

    /**
     * @dev Verify skill quality via CRPC (admin/validator only)
     */
    function verifySkill(uint256 skillId, uint256 qualityScore)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_exists(skillId), "Skill does not exist");
        require(qualityScore <= 100, "Score must be 0-100");

        Skill storage skill = skills[skillId];
        skill.qualityScore = qualityScore;
        skill.verified = true;

        emit SkillVerified(skillId, qualityScore);
    }

    /**
     * @dev Check if user has active license for skill
     */
    function hasActiveLicense(uint256 skillId, address user)
        public
        view
        returns (bool)
    {
        License[] memory licenses = skillLicenses[skillId];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (
                licenses[i].licensee == user &&
                licenses[i].active &&
                licenses[i].expiresAt > block.timestamp
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Search skills by tag
     */
    function getSkillsByTag(string calldata tag)
        external
        view
        returns (uint256[] memory)
    {
        return _taggedSkills[tag];
    }

    /**
     * @dev Get all skills created by user
     */
    function getSkillsByCreator(address creator)
        external
        view
        returns (uint256[] memory)
    {
        return _userSkills[creator];
    }

    /**
     * @dev Get compression metrics for a skill
     * Returns (compressionRatio, originalSize, compressedSize)
     */
    function getCompressionMetrics(uint256 skillId)
        external
        view
        returns (uint256, uint256, uint256)
    {
        require(_exists(skillId), "Skill does not exist");
        Skill storage skill = skills[skillId];
        return (skill.compressionRatio, skill.originalSizeBytes, skill.compressedSizeBytes);
    }

    /**
     * @dev Get reliability metrics for a skill
     * Returns (reliabilityPercent, successCount, failureCount)
     */
    function getReliabilityMetrics(uint256 skillId)
        external
        view
        returns (uint256, uint256, uint256)
    {
        require(_exists(skillId), "Skill does not exist");
        Skill storage skill = skills[skillId];

        uint256 totalValidations = skill.reliabilitySuccessCount + skill.reliabilityFailureCount;
        uint256 reliabilityPercent = totalValidations > 0
            ? (skill.reliabilitySuccessCount * 100) / totalValidations
            : 100; // Default to 100% if no validations yet

        return (reliabilityPercent, skill.reliabilitySuccessCount, skill.reliabilityFailureCount);
    }

    /**
     * @dev Get comprehensive quality breakdown for a skill
     * Returns all pricing components for transparency
     */
    function getQualityBreakdown(uint256 skillId)
        external
        view
        returns (
            uint256 basePrice,
            uint256 qualityScore,
            uint256 compressionRatio,
            uint256 reliabilityPercent,
            uint256 usageCount,
            uint256 finalPrice
        )
    {
        require(_exists(skillId), "Skill does not exist");
        Skill storage skill = skills[skillId];

        basePrice = assets[skillId].selfAssessedValue / 10;
        qualityScore = skill.qualityScore;
        compressionRatio = skill.compressionRatio;
        usageCount = skill.usageCount;

        uint256 totalValidations = skill.reliabilitySuccessCount + skill.reliabilityFailureCount;
        reliabilityPercent = totalValidations > 0
            ? (skill.reliabilitySuccessCount * 100) / totalValidations
            : 100;

        finalPrice = getQualityWeightedPrice(skillId);

        return (basePrice, qualityScore, compressionRatio, reliabilityPercent, usageCount, finalPrice);
    }

    /**
     * @dev Get skill details with Harberger data
     */
    function getSkillFullInfo(uint256 skillId)
        external
        view
        returns (
            string memory name,
            string memory description,
            string memory ipfsHash,
            address owner,
            address creator,
            uint256 selfAssessedValue,
            uint256 taxOwed,
            uint256 usageCount,
            uint256 qualityScore,
            bool verified,
            string[] memory tags
        )
    {
        require(_exists(skillId), "Skill does not exist");

        Skill storage skill = skills[skillId];

        return (
            skill.name,
            skill.description,
            skill.ipfsHash,
            ownerOf(skillId),
            skill.creator,
            assets[skillId].selfAssessedValue,
            calculateTaxOwed(skillId),
            skill.usageCount,
            skill.qualityScore,
            skill.verified,
            skill.tags
        );
    }

    /**
     * @dev Find high-quality skills by tag and minimum quality score
     */
    function findQualitySkills(string calldata tag, uint256 minQualityScore)
        external
        view
        returns (uint256[] memory qualitySkillIds)
    {
        uint256[] memory taggedSkills = _taggedSkills[tag];
        uint256 count = 0;
        uint256[] memory temp = new uint256[](taggedSkills.length);

        for (uint256 i = 0; i < taggedSkills.length; i++) {
            uint256 skillId = taggedSkills[i];
            if (
                _exists(skillId) &&
                skills[skillId].verified &&
                skills[skillId].qualityScore >= minQualityScore
            ) {
                temp[count] = skillId;
                count++;
            }
        }

        // Trim array
        qualitySkillIds = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            qualitySkillIds[j] = temp[j];
        }

        return qualitySkillIds;
    }

    /**
     * @dev Find trending skills (most used recently)
     */
    function getTrendingSkills(uint256 limit)
        external
        view
        returns (uint256[] memory trendingIds)
    {
        uint256 totalSkills = _skillIdCounter - 1;
        if (limit > totalSkills) limit = totalSkills;

        // Simple bubble sort by usage count
        uint256[] memory allIds = new uint256[](totalSkills);
        uint256[] memory usageCounts = new uint256[](totalSkills);
        uint256 idx = 0;

        for (uint256 i = 1; i < _skillIdCounter; i++) {
            if (_exists(i)) {
                allIds[idx] = i;
                usageCounts[idx] = skills[i].usageCount;
                idx++;
            }
        }

        // Sort descending by usage
        for (uint256 i = 0; i < totalSkills; i++) {
            for (uint256 j = i + 1; j < totalSkills; j++) {
                if (usageCounts[j] > usageCounts[i]) {
                    (usageCounts[i], usageCounts[j]) = (usageCounts[j], usageCounts[i]);
                    (allIds[i], allIds[j]) = (allIds[j], allIds[i]);
                }
            }
        }

        // Return top N
        trendingIds = new uint256[](limit);
        for (uint256 k = 0; k < limit; k++) {
            trendingIds[k] = allIds[k];
        }

        return trendingIds;
    }

    /**
     * @dev Get recommended assessment based on usage and quality
     */
    function recommendedSkillAssessment(uint256 skillId)
        public
        view
        returns (uint256 recommended, string memory reason)
    {
        require(_exists(skillId), "Skill does not exist");

        Skill storage skill = skills[skillId];
        uint256 currentValue = assets[skillId].selfAssessedValue;

        // Base value on usage
        uint256 usageValue = skill.usageCount * 10 * 10**18; // 10 PSI per use

        // Quality multiplier
        uint256 qualityMultiplier = skill.verified
            ? 100 + skill.qualityScore
            : 100;

        recommended = (usageValue * qualityMultiplier) / 100;

        // Ensure minimum
        if (recommended < MIN_SKILL_VALUE) {
            recommended = MIN_SKILL_VALUE;
        }

        // Provide reasoning
        if (recommended > currentValue * 2) {
            reason = "High usage + quality - consider raising assessment";
        } else if (recommended < currentValue / 2) {
            reason = "Low usage - lower assessment to avoid buyout";
        } else {
            reason = "Current assessment is reasonable";
        }

        return (recommended, reason);
    }

    /**
     * @dev Get registry statistics
     */
    function getRegistryStats()
        external
        view
        returns (
            uint256 totalSkills,
            uint256 totalVerified,
            uint256 totalUsage,
            uint256 averageQuality,
            uint256 totalValue
        )
    {
        totalSkills = _skillIdCounter - 1;

        uint256 verifiedCount = 0;
        uint256 sumQuality = 0;
        uint256 sumValue = 0;
        uint256 sumUsage = 0;

        for (uint256 i = 1; i < _skillIdCounter; i++) {
            if (_exists(i)) {
                Skill storage skill = skills[i];

                if (skill.verified) {
                    verifiedCount++;
                    sumQuality += skill.qualityScore;
                }

                sumUsage += skill.usageCount;
                sumValue += assets[i].selfAssessedValue;
            }
        }

        averageQuality = verifiedCount > 0 ? sumQuality / verifiedCount : 0;

        return (
            totalSkills,
            verifiedCount,
            sumUsage,
            averageQuality,
            sumValue
        );
    }

    /**
     * @dev Override transfer to update user tracking
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // Remove from old owner's list
        _removeUserSkill(from, tokenId);

        // Add to new owner's list
        _userSkills[to].push(tokenId);

        super._transfer(from, to, tokenId);
    }

    function _removeUserSkill(address user, uint256 skillId) internal {
        uint256[] storage skillIds = _userSkills[user];
        for (uint256 i = 0; i < skillIds.length; i++) {
            if (skillIds[i] == skillId) {
                skillIds[i] = skillIds[skillIds.length - 1];
                skillIds.pop();
                break;
            }
        }
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        try this.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }
}
