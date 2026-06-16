const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting FULL ΨNet Deployment...\n");
  console.log("=" .repeat(60));

  const [deployer] = await hre.ethers.getSigners();
  const network = hre.network.name;

  console.log("📋 Deployment Details:");
  console.log("  Network:", network);
  console.log("  Deployer:", deployer.address);
  console.log("  Balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH\n");

  const deployed = {};
  const config = getDeploymentConfig(network);

  console.log("⚙️  Configuration:");
  console.log("  Treasury:", config.treasury);
  console.log("  Reward Pool:", config.rewardPool);
  console.log("  Reputation Min Stake:", hre.ethers.formatEther(config.minimumReputationStake), "ETH");
  console.log("  Validation Request Stake:", hre.ethers.formatEther(config.minimumRequestStake), "ETH");
  console.log("  Validator Min Stake:", hre.ethers.formatEther(config.minimumValidatorStake), "ETH\n");

  console.log("⚠️  IMPORTANT: Phase 0 critical fixes have been applied!");
  console.log("  ✅ Shapley hyperinflation capped");
  console.log("  ✅ Cycle detection added");
  console.log("  ✅ Recursive DoS prevented");
  console.log("  ✅ Reputation time-weighting smoothed");
  console.log("  ✅ Circuit breakers enabled\n");
  console.log("=" .repeat(60));
  console.log();

  // ========== Phase 1: Core Token Infrastructure ==========
  console.log("📦 PHASE 1: Core Token Infrastructure");
  console.log("-".repeat(60));

  // 1. Deploy PsiToken
  console.log("📝 [1/12] Deploying PsiToken...");
  const PsiToken = await hre.ethers.getContractFactory("PsiToken");
  const psiToken = await PsiToken.deploy();
  await psiToken.waitForDeployment();
  deployed.PsiToken = await psiToken.getAddress();
  console.log("  ✅ PsiToken deployed at:", deployed.PsiToken);
  console.log("     Initial supply: 100M PSI (10% of max)");
  console.log("     Max supply: 1B PSI");
  console.log("     Daily mint limit: 1M PSI");
  console.log();

  // 2. Deploy PsiNetEconomics
  console.log("📝 [2/12] Deploying PsiNetEconomics...");
  const PsiNetEconomics = await hre.ethers.getContractFactory("PsiNetEconomics");
  const economics = await PsiNetEconomics.deploy(deployed.PsiToken);
  await economics.waitForDeployment();
  deployed.PsiNetEconomics = await economics.getAddress();
  console.log("  ✅ PsiNetEconomics deployed at:", deployed.PsiNetEconomics);
  console.log();

  // ========== Phase 2: ERC-8004 Registries ==========
  console.log("📦 PHASE 2: ERC-8004 Registries");
  console.log("-".repeat(60));

  // 3. Deploy IdentityRegistry
  console.log("📝 [3/12] Deploying IdentityRegistry...");
  const IdentityRegistry = await hre.ethers.getContractFactory("IdentityRegistry");
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  deployed.IdentityRegistry = await identityRegistry.getAddress();
  console.log("  ✅ IdentityRegistry deployed at:", deployed.IdentityRegistry);
  console.log();

  // 4. Deploy ReputationRegistry
  console.log("📝 [4/12] Deploying ReputationRegistry...");
  const ReputationRegistry = await hre.ethers.getContractFactory("ReputationRegistry");
  const reputationRegistry = await ReputationRegistry.deploy(
    deployed.IdentityRegistry,
    config.minimumReputationStake
  );
  await reputationRegistry.waitForDeployment();
  deployed.ReputationRegistry = await reputationRegistry.getAddress();
  console.log("  ✅ ReputationRegistry deployed at:", deployed.ReputationRegistry);
  console.log("     Minimum stake:", hre.ethers.formatEther(config.minimumReputationStake), "ETH");
  console.log();

  // 5. Deploy ValidationRegistry
  console.log("📝 [5/12] Deploying ValidationRegistry...");
  const ValidationRegistry = await hre.ethers.getContractFactory("ValidationRegistry");
  const validationRegistry = await ValidationRegistry.deploy(
    deployed.IdentityRegistry,
    config.minimumRequestStake,
    config.minimumValidatorStake
  );
  await validationRegistry.waitForDeployment();
  deployed.ValidationRegistry = await validationRegistry.getAddress();
  console.log("  ✅ ValidationRegistry deployed at:", deployed.ValidationRegistry);
  console.log("     Request stake:", hre.ethers.formatEther(config.minimumRequestStake), "ETH");
  console.log("     Validator stake:", hre.ethers.formatEther(config.minimumValidatorStake), "ETH");
  console.log();

  // ========== Phase 3: Economic Mechanisms ==========
  console.log("📦 PHASE 3: Economic Mechanisms");
  console.log("-".repeat(60));

  // 6. Deploy ShapleyReferrals
  console.log("📝 [6/12] Deploying ShapleyReferrals...");
  console.log("  ⚠️  Phase 0 Fix #0.1 Applied: Coalition bonuses capped at 50k PSI");
  console.log("  ⚠️  Phase 0 Fix #0.2 Applied: Cycle detection enabled");
  console.log("  ⚠️  Phase 0 Fix #0.3 Applied: Iterative network counting");
  const ShapleyReferrals = await hre.ethers.getContractFactory("ShapleyReferrals");
  const shapleyReferrals = await ShapleyReferrals.deploy(
    deployed.PsiToken,
    deployed.ReputationRegistry
  );
  await shapleyReferrals.waitForDeployment();
  deployed.ShapleyReferrals = await shapleyReferrals.getAddress();
  console.log("  ✅ ShapleyReferrals deployed at:", deployed.ShapleyReferrals);
  console.log("     Max coalition size for rewards: 10");
  console.log("     Max coalition value: 50,000 PSI");
  console.log();

  // 7. Deploy HarbergerNFT
  console.log("📝 [7/12] Deploying HarbergerNFT...");
  const HarbergerNFT = await hre.ethers.getContractFactory("HarbergerNFT");
  const harbergerNFT = await HarbergerNFT.deploy(
    "ΨNet Harberger NFT",
    "ΨNFT",
    deployed.PsiToken,
    config.rewardPool,
    config.treasury
  );
  await harbergerNFT.waitForDeployment();
  deployed.HarbergerNFT = await harbergerNFT.getAddress();
  console.log("  ✅ HarbergerNFT deployed at:", deployed.HarbergerNFT);
  console.log("     Tax rate: 5% APR");
  console.log();

  // 8. Deploy HarbergerIdentityRegistry
  console.log("📝 [8/12] Deploying HarbergerIdentityRegistry...");
  const HarbergerIdentityRegistry = await hre.ethers.getContractFactory("HarbergerIdentityRegistry");
  const harbergerIdentityRegistry = await HarbergerIdentityRegistry.deploy(
    deployed.PsiToken,
    deployed.IdentityRegistry,
    config.rewardPool,
    config.treasury
  );
  await harbergerIdentityRegistry.waitForDeployment();
  deployed.HarbergerIdentityRegistry = await harbergerIdentityRegistry.getAddress();
  console.log("  ✅ HarbergerIdentityRegistry deployed at:", deployed.HarbergerIdentityRegistry);
  console.log();

  // 9. Deploy HarbergerValidator
  console.log("📝 [9/12] Deploying HarbergerValidator...");
  const HarbergerValidator = await hre.ethers.getContractFactory("HarbergerValidator");
  const harbergerValidator = await HarbergerValidator.deploy(
    deployed.PsiToken,
    deployed.ValidationRegistry,
    config.rewardPool,
    config.treasury
  );
  await harbergerValidator.waitForDeployment();
  deployed.HarbergerValidator = await harbergerValidator.getAddress();
  console.log("  ✅ HarbergerValidator deployed at:", deployed.HarbergerValidator);
  console.log();

  // ========== Phase 4: Validation System ==========
  console.log("📦 PHASE 4: Validation System");
  console.log("-".repeat(60));

  // 10. Deploy CRPCValidator
  console.log("📝 [10/12] Deploying CRPCValidator...");
  console.log("  ⚠️  Note: CRPC implementation needs Phase 1 fix (pairwise comparison)");
  const CRPCValidator = await hre.ethers.getContractFactory("CRPCValidator");
  const crpcValidator = await CRPCValidator.deploy(
    deployed.ValidationRegistry,
    deployed.ReputationRegistry
  );
  await crpcValidator.waitForDeployment();
  deployed.CRPCValidator = await crpcValidator.getAddress();
  console.log("  ✅ CRPCValidator deployed at:", deployed.CRPCValidator);
  console.log();

  // 11. Deploy CRPCIntegration
  console.log("📝 [11/12] Deploying CRPCIntegration...");
  const CRPCIntegration = await hre.ethers.getContractFactory("CRPCIntegration");
  const crpcIntegration = await CRPCIntegration.deploy(
    deployed.IdentityRegistry,
    deployed.ReputationRegistry,
    deployed.ValidationRegistry,
    deployed.CRPCValidator
  );
  await crpcIntegration.waitForDeployment();
  deployed.CRPCIntegration = await crpcIntegration.getAddress();
  console.log("  ✅ CRPCIntegration deployed at:", deployed.CRPCIntegration);
  console.log();

  // ========== Phase 5: Marketplace ==========
  console.log("📦 PHASE 5: Marketplace");
  console.log("-".repeat(60));

  // 12. Deploy SkillRegistry
  console.log("📝 [12/12] Deploying SkillRegistry...");
  const SkillRegistry = await hre.ethers.getContractFactory("SkillRegistry");
  const skillRegistry = await SkillRegistry.deploy(
    deployed.PsiToken,
    config.rewardPool,
    config.treasury,
    deployed.ReputationRegistry
  );
  await skillRegistry.waitForDeployment();
  deployed.SkillRegistry = await skillRegistry.getAddress();
  console.log("  ✅ SkillRegistry deployed at:", deployed.SkillRegistry);
  console.log("     Min skill value: 100 PSI");
  console.log("     License duration: 90 days");
  console.log();

  // ========== Post-Deployment Setup ==========
  console.log("📦 POST-DEPLOYMENT SETUP");
  console.log("-".repeat(60));

  console.log("🔐 Granting roles...");

  // Grant MINTER_ROLE to ShapleyReferrals and Economics
  await psiToken.grantRole(await psiToken.MINTER_ROLE(), deployed.ShapleyReferrals);
  console.log("  ✅ Granted MINTER_ROLE to ShapleyReferrals");

  await psiToken.grantRole(await psiToken.MINTER_ROLE(), deployed.PsiNetEconomics);
  console.log("  ✅ Granted MINTER_ROLE to PsiNetEconomics");

  // Grant REWARDER_ROLE to Economics
  await psiToken.grantRole(await psiToken.REWARDER_ROLE(), deployed.PsiNetEconomics);
  console.log("  ✅ Granted REWARDER_ROLE to PsiNetEconomics");

  console.log();

  // ========== Save Deployment Info ==========
  const deploymentInfo = {
    network: network,
    chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    blockNumber: await hre.ethers.provider.getBlockNumber(),
    configuration: {
      treasury: config.treasury,
      rewardPool: config.rewardPool,
      minimumReputationStake: hre.ethers.formatEther(config.minimumReputationStake),
      minimumRequestStake: hre.ethers.formatEther(config.minimumRequestStake),
      minimumValidatorStake: hre.ethers.formatEther(config.minimumValidatorStake),
    },
    contracts: deployed,
    phase0Fixes: {
      applied: true,
      fixes: [
        "Fix #0.1: Shapley coalition bonuses capped",
        "Fix #0.2: Cycle detection added",
        "Fix #0.3: Iterative network counting",
        "Fix #0.4: Smooth reputation time-weighting",
        "Fix #0.5: Circuit breakers enabled"
      ]
    }
  };

  // Save deployment info
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(deploymentsDir, `${network}-full.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));

  console.log("💾 Deployment info saved to:", deploymentFile);
  console.log();

  // ========== Print Summary ==========
  console.log("=" .repeat(60));
  console.log("🎉 FULL DEPLOYMENT COMPLETE!");
  console.log("=" .repeat(60));
  console.log();
  console.log("📊 Deployed Contracts:");
  console.log();

  Object.entries(deployed).forEach(([name, address], index) => {
    const phase = index < 2 ? "Phase 1" : index < 5 ? "Phase 2" : index < 9 ? "Phase 3" : index < 11 ? "Phase 4" : "Phase 5";
    console.log(`  ${(index + 1).toString().padStart(2)}. ${name.padEnd(30)} ${address} [${phase}]`);
  });

  console.log();
  console.log("=" .repeat(60));
  console.log();

  if (network !== "hardhat" && network !== "localhost") {
    console.log("🔍 Verification Commands:");
    console.log("-".repeat(60));
    console.log(`npx hardhat verify --network ${network} ${deployed.PsiToken}`);
    console.log(`npx hardhat verify --network ${network} ${deployed.PsiNetEconomics} ${deployed.PsiToken}`);
    console.log(`npx hardhat verify --network ${network} ${deployed.IdentityRegistry}`);
    console.log(`npx hardhat verify --network ${network} ${deployed.ReputationRegistry} ${deployed.IdentityRegistry} ${config.minimumReputationStake}`);
    console.log(`npx hardhat verify --network ${network} ${deployed.ValidationRegistry} ${deployed.IdentityRegistry} ${config.minimumRequestStake} ${config.minimumValidatorStake}`);
    console.log("# ... (see full list in deployments/${network}-full.json)");
    console.log();
  }

  console.log("📚 Next Steps:");
  console.log("-".repeat(60));
  console.log("  1. Run integration tests:");
  console.log("     npm test");
  console.log();
  console.log("  2. Update frontend with contract addresses:");
  console.log(`     cp deployments/${network}-full.json frontend/src/contracts/`);
  console.log();
  console.log("  3. Set up circuit breakers (admin only):");
  console.log("     - Monitor daily mint limits");
  console.log("     - Prepare emergency pause procedures");
  console.log();
  console.log("  4. Initialize first agents:");
  console.log("     - Register agents in IdentityRegistry");
  console.log("     - Build initial reputation");
  console.log("     - Create first skills in SkillRegistry");
  console.log();
  console.log("  5. Monitor for issues:");
  console.log("     - Watch Shapley coalition sizes");
  console.log("     - Monitor PSI mint rates");
  console.log("     - Track validation accuracy");
  console.log();
  console.log("⚠️  SECURITY REMINDERS:");
  console.log("-".repeat(60));
  console.log("  ⚠️  Transfer admin roles to multisig for production");
  console.log("  ⚠️  Enable timelock for sensitive operations");
  console.log("  ⚠️  Get professional audit before mainnet launch");
  console.log("  ⚠️  Monitor circuit breaker triggers");
  console.log("  ⚠️  Test emergency pause/unpause procedures");
  console.log();
  console.log("🌐 Integration guide: See DEPLOYMENT_GUIDE.md and ACTION_PLAN.md");
  console.log();
}

function getDeploymentConfig(network) {
  // Configuration per network
  const configs = {
    localhost: {
      treasury: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // First test account
      rewardPool: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      minimumReputationStake: hre.ethers.parseEther("0.01"),
      minimumRequestStake: hre.ethers.parseEther("0.01"),
      minimumValidatorStake: hre.ethers.parseEther("0.05"),
    },
    sepolia: {
      treasury: process.env.TREASURY_ADDRESS || "0x0000000000000000000000000000000000000000",
      rewardPool: process.env.REWARD_POOL_ADDRESS || "0x0000000000000000000000000000000000000000",
      minimumReputationStake: hre.ethers.parseEther("0.01"),
      minimumRequestStake: hre.ethers.parseEther("0.01"),
      minimumValidatorStake: hre.ethers.parseEther("0.05"),
    },
    mainnet: {
      treasury: process.env.TREASURY_ADDRESS, // Must be multisig
      rewardPool: process.env.REWARD_POOL_ADDRESS, // Must be secure contract
      minimumReputationStake: hre.ethers.parseEther("0.1"),
      minimumRequestStake: hre.ethers.parseEther("0.1"),
      minimumValidatorStake: hre.ethers.parseEther("0.5"),
    },
  };

  return configs[network] || configs.localhost;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error();
    console.error("=" .repeat(60));
    console.error("❌ DEPLOYMENT FAILED!");
    console.error("=" .repeat(60));
    console.error();
    console.error("Error:", error.message);
    console.error();
    if (error.stack) {
      console.error("Stack trace:");
      console.error(error.stack);
    }
    console.error();
    console.error("💡 Troubleshooting:");
    console.error("  1. Check that all contracts compile: npx hardhat compile");
    console.error("  2. Verify deployer has sufficient balance");
    console.error("  3. Check network connectivity");
    console.error("  4. Review DEPLOYMENT_GUIDE.md for common issues");
    console.error();
    process.exit(1);
  });
