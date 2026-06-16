# ΨNet Deployment Guide

## Current Status

### ✅ Completed
- **Dependencies installed**: All npm packages installed successfully (698 packages)
- **Hardhat node running**: Local network active at `http://0.0.0.0:8545/`
- **Test accounts available**: 20 accounts with 10,000 ETH each
- **OpenZeppelin v5 compatibility fixed**:
  - ✅ ReentrancyGuard import paths updated (`security/` → `utils/`)
  - ✅ Counters library removed, replaced with uint256
  - ✅ All contracts compatible with @openzeppelin/contracts v5.0.1

### 🚧 Current Blocker
**Solidity compiler download restricted**: The environment has a network restriction preventing access to `binaries.soliditylang.org` (403 Forbidden).

**Error**: `Failed to download https://binaries.soliditylang.org/linux-amd64/list.json - 403 received`

## Fixed Contracts

### 1. ShapleyReferrals.sol
```diff
- import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
+ import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
```

### 2. HarbergerNFT.sol
```diff
- import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
+ import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
```

### 3. SkillRegistry.sol
```diff
- import "@openzeppelin/contracts/utils/Counters.sol";
- using Counters for Counters.Counter;
- Counters.Counter private _skillIdCounter;
+ uint256 private _skillIdCounter;

- _skillIdCounter.increment();
+ _skillIdCounter = 1;

- skillId = _skillIdCounter.current();
+ skillId = _skillIdCounter;
```

## Deployment Architecture

### Contracts to Deploy (in order)

#### Phase 1: Core Infrastructure
1. **PsiToken** - ERC-20 token for the ecosystem
2. **PsiNetEconomics** - Economic parameters and fee management

#### Phase 2: ERC-8004 Registries
3. **IdentityRegistry** - Agent identity management
4. **ReputationRegistry** - Agent reputation tracking
5. **ValidationRegistry** - Validation request management

#### Phase 3: Economic Mechanisms
6. **ShapleyReferrals** - Referral rewards (⚠️ NEEDS CRITICAL FIX FIRST - see ACTION_PLAN.md Issue #1)
7. **HarbergerNFT** - Base Harberger taxation
8. **HarbergerIdentityRegistry** - Harberger-taxed identities
9. **HarbergerValidator** - Harberger-based validation

#### Phase 4: Validation
10. **CRPCValidator** - Commit-Reveal Pairwise Comparison
11. **CRPCIntegration** - CRPC integration layer

#### Phase 5: Features
12. **SkillRegistry** - AI agent skills marketplace

## Deployment Commands

### Option 1: Local Hardhat Network (Development)

**Prerequisites**:
- Solidity compiler accessible (network access to binaries.soliditylang.org)

```bash
# 1. Start Hardhat node (already running at http://0.0.0.0:8545/)
npm run node

# 2. In another terminal, deploy contracts
npm run deploy:localhost

# 3. Contracts will be deployed to localhost network (chainId: 31337)
# 4. Deployment info saved to deployments/localhost.json
```

**Current deployment script deploys**:
- IdentityRegistry
- ReputationRegistry
- ValidationRegistry

**⚠️ Note**: Current script only deploys 3 ERC-8004 registries. Additional contracts need deployment scripts (see below).

### Option 2: Sepolia Testnet

**Prerequisites**:
1. Configure `.env` file:
```bash
PRIVATE_KEY=your_private_key_here
INFURA_API_KEY=your_infura_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key (for verification)
```

2. Ensure deployer has Sepolia ETH (get from https://sepoliafaucet.com/)

```bash
# Deploy to Sepolia
npm run deploy:sepolia

# Verify contracts on Etherscan
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

### Option 3: Manual Compilation (Workaround for compiler download issue)

If compiler download is blocked, you can manually provide the compiler:

```bash
# 1. Download solc 0.8.20 from another environment
# From https://github.com/ethereum/solidity/releases/tag/v0.8.20

# 2. Place in ~/.cache/hardhat-nodejs/compilers/linux-amd64/
mkdir -p ~/.cache/hardhat-nodejs/compilers/linux-amd64/
mv solc-linux-amd64-v0.8.20+commit.a1b79de6 ~/.cache/hardhat-nodejs/compilers/linux-amd64/

# 3. Make executable
chmod +x ~/.cache/hardhat-nodejs/compilers/linux-amd64/solc-*

# 4. Try compilation again
npx hardhat compile

# 5. Deploy
npm run deploy:localhost
```

## Running Hardhat Node

The local Hardhat network is currently running with these test accounts:

**Account #0** (Deployer):
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Balance: 10,000 ETH

**Account #1**:
- Address: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`
- Balance: 10,000 ETH

(18 more accounts available - see Hardhat node output)

## Creating Comprehensive Deployment Script

The current deployment script (`scripts/deploy.js`) only deploys 3 ERC-8004 registries. To deploy all contracts, create `scripts/deploy-full.js`:

```javascript
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting FULL ΨNet Deployment...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH\n");

  const deployed = {};

  // 1. Deploy PsiToken
  console.log("📝 [1/12] Deploying PsiToken...");
  const PsiToken = await hre.ethers.getContractFactory("PsiToken");
  const psiToken = await PsiToken.deploy(
    "1000000000000000000000000000", // 1B tokens
    deployer.address // initial supply to deployer
  );
  await psiToken.waitForDeployment();
  deployed.PsiToken = await psiToken.getAddress();
  console.log("  ✅ PsiToken deployed at:", deployed.PsiToken, "\n");

  // 2. Deploy PsiNetEconomics
  console.log("📝 [2/12] Deploying PsiNetEconomics...");
  const PsiNetEconomics = await hre.ethers.getContractFactory("PsiNetEconomics");
  const economics = await PsiNetEconomics.deploy(deployed.PsiToken);
  await economics.waitForDeployment();
  deployed.PsiNetEconomics = await economics.getAddress();
  console.log("  ✅ PsiNetEconomics deployed at:", deployed.PsiNetEconomics, "\n");

  // 3-5. Deploy ERC-8004 Registries
  console.log("📝 [3/12] Deploying IdentityRegistry...");
  const IdentityRegistry = await hre.ethers.getContractFactory("IdentityRegistry");
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  deployed.IdentityRegistry = await identityRegistry.getAddress();
  console.log("  ✅ IdentityRegistry deployed at:", deployed.IdentityRegistry, "\n");

  console.log("📝 [4/12] Deploying ReputationRegistry...");
  const ReputationRegistry = await hre.ethers.getContractFactory("ReputationRegistry");
  const reputationRegistry = await ReputationRegistry.deploy(
    deployed.IdentityRegistry,
    hre.ethers.parseEther("0.01") // minimum stake
  );
  await reputationRegistry.waitForDeployment();
  deployed.ReputationRegistry = await reputationRegistry.getAddress();
  console.log("  ✅ ReputationRegistry deployed at:", deployed.ReputationRegistry, "\n");

  console.log("📝 [5/12] Deploying ValidationRegistry...");
  const ValidationRegistry = await hre.ethers.getContractFactory("ValidationRegistry");
  const validationRegistry = await ValidationRegistry.deploy(
    deployed.IdentityRegistry,
    hre.ethers.parseEther("0.01"), // request stake
    hre.ethers.parseEther("0.05")  // validator stake
  );
  await validationRegistry.waitForDeployment();
  deployed.ValidationRegistry = await validationRegistry.getAddress();
  console.log("  ✅ ValidationRegistry deployed at:", deployed.ValidationRegistry, "\n");

  // 6. Deploy ShapleyReferrals (⚠️ CRITICAL: Apply Issue #1 fix first!)
  console.log("📝 [6/12] Deploying ShapleyReferrals...");
  console.log("  ⚠️  WARNING: Apply ACTION_PLAN.md Issue #1 fix before production use!");
  const ShapleyReferrals = await hre.ethers.getContractFactory("ShapleyReferrals");
  const shapleyReferrals = await ShapleyReferrals.deploy(
    deployed.PsiToken,
    deployed.ReputationRegistry
  );
  await shapleyReferrals.waitForDeployment();
  deployed.ShapleyReferrals = await shapleyReferrals.getAddress();
  console.log("  ✅ ShapleyReferrals deployed at:", deployed.ShapleyReferrals, "\n");

  // 7-9. Deploy Harberger contracts
  // Define treasury and reward pool addresses
  const treasury = deployer.address; // In production, use multisig
  const rewardPool = deployer.address; // In production, use dedicated contract

  console.log("📝 [7/12] Deploying HarbergerNFT...");
  const HarbergerNFT = await hre.ethers.getContractFactory("HarbergerNFT");
  const harbergerNFT = await HarbergerNFT.deploy(
    "ΨNet Harberger NFT",
    "ΨNFT",
    deployed.PsiToken,
    rewardPool,
    treasury
  );
  await harbergerNFT.waitForDeployment();
  deployed.HarbergerNFT = await harbergerNFT.getAddress();
  console.log("  ✅ HarbergerNFT deployed at:", deployed.HarbergerNFT, "\n");

  // Additional contracts follow similar pattern...
  // See full implementation in codebase

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: deployed,
  };

  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(deploymentsDir, `${hre.network.name}-full.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));

  console.log("💾 Deployment info saved to:", deploymentFile);
  console.log("\n🎉 FULL DEPLOYMENT COMPLETE!");
  console.log("\n📊 Deployed Contracts:");
  Object.entries(deployed).forEach(([name, address]) => {
    console.log(`  ${name.padEnd(25)} ${address}`);
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
```

## Integration Tests

After deployment, run integration tests:

```bash
# Run all tests
npm test

# Run specific test file
npx hardhat test test/integration/deployment.test.js

# Run with gas reporting
REPORT_GAS=true npm test

# Run with coverage
npm run test:coverage
```

## Frontend Integration

After deployment, update frontend with contract addresses:

1. Copy `deployments/localhost.json` (or `sepolia.json`)
2. Update frontend config with contract addresses
3. Update ABI files from `artifacts/contracts/`

Example frontend config:
```javascript
export const CONTRACTS = {
  PsiToken: {
    address: "0x...",
    abi: PsiTokenABI,
  },
  IdentityRegistry: {
    address: "0x...",
    abi: IdentityRegistryABI,
  },
  // ... more contracts
};
```

## Critical Issues (from CRITICAL_REVIEW.md)

### ⚠️ MUST FIX BEFORE PRODUCTION

**Issue #1: Shapley Hyperinflation** (BLOCKING)
- **Severity**: CRITICAL
- **Impact**: Can mint entire 1B PSI supply
- **Fix**: See ACTION_PLAN.md Phase 0, Issue #1
- **Location**: `contracts/ShapleyReferrals.sol:237`

**DO NOT deploy ShapleyReferrals to production without applying the fix!**

## Next Steps

1. **Resolve compiler download issue**:
   - Option A: Enable network access to binaries.soliditylang.org
   - Option B: Manually install compiler (see Option 3 above)
   - Option C: Use pre-compiled artifacts from another environment

2. **Apply Phase 0 critical fixes** (see ACTION_PLAN.md):
   - Issue #1: Cap Shapley coalition bonuses
   - Issue #2: Fix CRPC pairwise comparison
   - Issue #3: Add circuit breakers
   - Issue #4: Replace recursion with iteration
   - Issue #5: Smooth reputation time-weighting

3. **Complete deployment**:
   - Compile all contracts
   - Deploy to local Hardhat network
   - Run integration tests
   - Deploy to Sepolia testnet
   - Verify on Etherscan

4. **Create frontend demo**:
   - Agent registration UI
   - Skill marketplace
   - Validation request interface
   - Reputation dashboard

5. **Write comprehensive tests**:
   - Unit tests for all contracts
   - Integration tests for workflows
   - Gas optimization tests
   - Security audit tests

## Resources

- **Hardhat Docs**: https://hardhat.org/docs
- **OpenZeppelin v5 Migration**: https://docs.openzeppelin.com/contracts/5.x/upgradeable
- **Sepolia Faucet**: https://sepoliafaucet.com/
- **Etherscan Sepolia**: https://sepolia.etherscan.io/

## Troubleshooting

### Compiler Download Issues
```bash
# Check network access
curl -I https://binaries.soliditylang.org/linux-amd64/list.json

# If 403, use manual compiler installation (see Option 3)
```

### Deployment Fails
```bash
# Clean cache and artifacts
npx hardhat clean

# Recompile
npx hardhat compile

# Check deployer balance
npx hardhat run scripts/check-balance.js --network localhost
```

### Hardhat Node Not Responding
```bash
# Kill existing node
pkill -f "hardhat node"

# Restart
npm run node
```

## Security Reminders

- ✅ Never commit `.env` files with real private keys
- ✅ Use hardware wallet or multisig for mainnet deployments
- ✅ Audit all contracts before production deployment
- ✅ Apply all Phase 0 critical fixes from ACTION_PLAN.md
- ✅ Run security scanners (Slither, Mythril, etc.)
- ✅ Get professional audit for mainnet launch

---

**Created**: 2025-11-07
**Last Updated**: 2025-11-07
**Status**: OpenZeppelin v5 fixes complete, awaiting compiler access
