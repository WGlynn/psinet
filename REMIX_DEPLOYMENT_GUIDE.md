# ΨNet Remix IDE Deployment Guide

**Date**: 2025-11-07
**Purpose**: Deploy and test ΨNet contracts using Remix IDE (no local compiler required)
**Browser**: https://remix.ethereum.org

---

## Quick Start

### Step 1: Access Remix IDE
1. Open your browser and go to **https://remix.ethereum.org**
2. You'll see the Remix IDE interface with a file explorer on the left

### Step 2: Create New Workspace
1. Click the **workspace** dropdown (top-left)
2. Select **"Create Blank"**
3. Name it: `PsiNet`
4. Click **Create**

---

## Contract Upload Instructions

### Option A: Manual Upload (Recommended)

Upload contracts in this order to avoid dependency issues:

#### 1. Create Directory Structure
In Remix file explorer:
- Create folder: `contracts`
- Inside `contracts`, create folder: `erc8004`

#### 2. Upload ERC-8004 Interfaces First
Navigate to `contracts/erc8004/` and upload these files **in order**:

```
contracts/erc8004/
├── IIdentityRegistry.sol        ← Upload 1st
├── IReputationRegistry.sol      ← Upload 2nd
├── IValidationRegistry.sol      ← Upload 3rd
├── IdentityRegistry.sol         ← Upload 4th
├── ReputationRegistry.sol       ← Upload 5th
└── ValidationRegistry.sol       ← Upload 6th
```

**How to upload:**
1. Click on `contracts/erc8004/` folder
2. Right-click → **New File**
3. Name it (e.g., `IIdentityRegistry.sol`)
4. Copy-paste the content from your local file
5. Repeat for all 6 files

#### 3. Upload Main Contracts
Navigate to `contracts/` and upload these files:

```
contracts/
├── PsiToken.sol                 ← Upload 1st (fewest dependencies)
├── HarbergerNFT.sol            ← Upload 2nd (base class)
├── ShapleyReferrals.sol        ← Upload 3rd
├── SkillRegistry.sol           ← Upload 4th (uses HarbergerNFT)
├── CRPCValidator.sol           ← Upload 5th
├── CRPCIntegration.sol         ← Upload 6th
├── HarbergerIdentityRegistry.sol ← Upload 7th
├── HarbergerValidator.sol      ← Upload 8th
└── PsiNetEconomics.sol         ← Upload 9th
```

#### 4. Upload OpenZeppelin Dependencies
Remix will auto-import OpenZeppelin contracts when you compile, but you can also:
- Click **File Explorer** → **GitHub** icon
- Import from: `OpenZeppelin/openzeppelin-contracts@v5.0.0`

### Option B: Load from GitHub (If Available)

If your repo is public:
1. Click **GitHub** icon in file explorer
2. Enter your repo URL
3. Select branch: `claude/review-protocol-specs-011CUtLCwoThnXnNBjDbVKkH`
4. Remix will load all files automatically

---

## Compiler Configuration

### Step 1: Select Compiler
1. Click **Solidity Compiler** icon (left sidebar, 2nd icon)
2. **Compiler Version**: Select `0.8.20` from dropdown
3. **EVM Version**: `paris` (default)
4. **Language**: `Solidity`

### Step 2: Compiler Settings
Enable these options:
- ✅ **Auto compile** (optional, for convenience)
- ✅ **Enable optimization**: `200` runs (recommended for deployment)
- ❌ **Hide warnings**: Keep unchecked to see all issues

### Step 3: Advanced Configuration (Optional)
Click **Advanced Configurations** and verify:
```json
{
  "optimizer": {
    "enabled": true,
    "runs": 200
  },
  "evmVersion": "paris"
}
```

---

## Compilation Order

Compile contracts in dependency order to avoid errors:

### Phase 1: Interfaces & Base Contracts
1. ✅ `contracts/erc8004/IIdentityRegistry.sol`
2. ✅ `contracts/erc8004/IReputationRegistry.sol`
3. ✅ `contracts/erc8004/IValidationRegistry.sol`
4. ✅ `contracts/erc8004/IdentityRegistry.sol`
5. ✅ `contracts/erc8004/ReputationRegistry.sol`
6. ✅ `contracts/PsiToken.sol`

### Phase 2: Core Contracts
7. ✅ `contracts/HarbergerNFT.sol`
8. ✅ `contracts/ShapleyReferrals.sol`
9. ✅ `contracts/SkillRegistry.sol` ← **Quality Incentives Here!**

### Phase 3: Advanced Contracts
10. ✅ `contracts/CRPCValidator.sol`
11. ✅ `contracts/erc8004/ValidationRegistry.sol`
12. ✅ `contracts/CRPCIntegration.sol`
13. ✅ `contracts/HarbergerIdentityRegistry.sol`
14. ✅ `contracts/HarbergerValidator.sol`
15. ✅ `contracts/PsiNetEconomics.sol`

**How to compile:**
- Click the contract file
- Click **"Compile [filename]"** button
- Check for green checkmark ✅
- Review any warnings (orange) or errors (red)

---

## Deployment Instructions

### Environment Setup

1. Click **Deploy & Run Transactions** icon (left sidebar, 3rd icon)
2. **Environment**:
   - For testing: `Remix VM (Shanghai)` ← Recommended for initial testing
   - For testnet: `Injected Provider - MetaMask` (requires MetaMask)
3. **Account**: Select an account with test ETH
4. **Gas Limit**: `8000000` (default is fine)
5. **Value**: `0` (unless contract requires ETH)

### Deployment Order

Deploy in this **exact order** to satisfy dependencies:

#### Phase 1: Deploy Token & Registries
```
1. PsiToken
   Constructor args:
   - treasury: [your-address]
   - rewardPool: [your-address]

2. IdentityRegistry
   Constructor args: (none)

3. ReputationRegistry
   Constructor args:
   - _identityRegistry: [IdentityRegistry-address]
   - _minimumStake: 10000000000000000 (0.01 ETH in wei)
```

#### Phase 2: Deploy NFT Systems
```
4. ShapleyReferrals
   Constructor args:
   - _psiToken: [PsiToken-address]
   - _reputationRegistry: [ReputationRegistry-address]

5. SkillRegistry ← QUALITY INCENTIVES!
   Constructor args:
   - _psiToken: [PsiToken-address]
   - _rewardPool: [your-address]
   - _treasury: [your-address]
   - _reputationRegistry: [ReputationRegistry-address]
```

#### Phase 3: Deploy Validation
```
6. ValidationRegistry
   Constructor args:
   - _identityRegistry: [IdentityRegistry-address]
   - _reputationRegistry: [ReputationRegistry-address]

7. CRPCValidator
   Constructor args:
   - _validationRegistry: [ValidationRegistry-address]
   - _reputationRegistry: [ReputationRegistry-address]
```

#### Phase 4: Deploy Advanced Contracts
```
8. CRPCIntegration
9. HarbergerIdentityRegistry
10. HarbergerValidator
11. PsiNetEconomics
```

### How to Deploy Each Contract

1. **Select contract** from dropdown (e.g., "PsiToken")
2. **Enter constructor arguments** (if any) in the fields below
3. Click **"Deploy"** button (orange)
4. Wait for transaction confirmation
5. **Copy deployed address** from console (you'll need this!)
6. Repeat for next contract

**Pro tip**: Keep a text file with deployed addresses:
```
PsiToken: 0x1234...
IdentityRegistry: 0x5678...
ReputationRegistry: 0x9abc...
...
```

---

## Testing Quality Incentive Features

### Test 1: Register a Skill

```javascript
// In Remix, expand SkillRegistry contract
// Call these functions:

1. registerSkill
   - name: "Premium AI Skill"
   - description: "High-quality skill with compression"
   - ipfsHash: "QmTest123"
   - tags: ["ai", "premium"]
   - skillType: 0 (DOCUMENTATION)
   - agentId: 1
   - initialValue: 1000000000000000000000 (1000 PSI)

   → Returns skillId = 1
```

### Test 2: Update Compression

```javascript
2. updateCompression
   - skillId: 1
   - originalSize: 10000
   - compressedSize: 1000

   → Event: CompressionUpdated(1, 90, 10000, 1000)
   → 90% compression ratio!
```

### Test 3: Record Reliability

```javascript
3. recordValidation (call multiple times)
   - skillId: 1
   - success: true

   Call 10 times to establish reliability

   → Event: ReliabilityRecorded(1, true, 10, 0)
```

### Test 4: Check Quality-Weighted Price

```javascript
4. getQualityWeightedPrice
   - skillId: 1

   → Returns: [price in wei]

5. getQualityBreakdown
   - skillId: 1

   → Returns: [basePrice, qualityScore, compressionRatio,
              reliabilityPercent, usageCount, finalPrice]
```

### Test 5: Verify Pricing Formula

With the settings above, you should see:
- Base Price: 100 PSI (10% of 1000 PSI)
- Compression Ratio: 90
- Reliability: 100% (10/10 successes)
- Final Price: ~18-25 PSI (80-85% discount!)

---

## Interacting with Deployed Contracts

### View Functions (Read-Only, No Gas)

In Remix, expand your deployed contract and use blue buttons:

**SkillRegistry**:
- `getCompressionMetrics(skillId)` → View compression data
- `getReliabilityMetrics(skillId)` → View reliability data
- `getQualityBreakdown(skillId)` → See complete pricing breakdown
- `getQualityWeightedPrice(skillId)` → Check current price
- `skills(skillId)` → View all skill metadata

**PsiToken**:
- `balanceOf(address)` → Check token balance
- `totalSupply()` → Check total PSI supply

### Write Functions (Requires Gas)

Use orange buttons for transactions:

**Setup**:
1. Grant MINTER_ROLE to SkillRegistry:
   ```
   PsiToken.grantRole(
     0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6,
     [SkillRegistry-address]
   )
   ```

2. Mint tokens to your account:
   ```
   PsiToken.mint([your-address], 10000000000000000000000)  // 10000 PSI
   ```

3. Approve SkillRegistry to spend tokens:
   ```
   PsiToken.approve([SkillRegistry-address], 115792089237316195423570985008687907853269984665640564039457584007913129639935)
   ```

**Test Transactions**:
- Register skills
- Update compression
- Record validations
- License skills (test quality pricing!)

---

## Troubleshooting

### Compilation Errors

**Error**: `Source file not found`
- **Fix**: Upload all dependencies first (interfaces before implementations)

**Error**: `Identifier not found or not unique`
- **Fix**: Compile parent contracts before child contracts

**Error**: `DeclarationError: Undeclared identifier`
- **Fix**: Check import paths match Remix structure

### Deployment Errors

**Error**: `Gas estimation failed`
- **Fix**: Increase gas limit to 8000000
- **Fix**: Check constructor arguments are correct format

**Error**: `Invalid address`
- **Fix**: Use full address format: `0x1234567890123456789012345678901234567890`
- **Fix**: Deploy dependency contracts first

**Error**: `Transaction reverted`
- **Fix**: Check require() conditions in contract
- **Fix**: Ensure you have enough test ETH

### Common Issues

**Issue**: Contract shows compiled but won't deploy
- **Fix**: Check all constructor parameters are filled
- **Fix**: Verify you selected correct contract from dropdown

**Issue**: Can't call functions after deployment
- **Fix**: Make sure contract is deployed (not just compiled)
- **Fix**: Expand deployed contract to see functions

**Issue**: Transactions fail silently
- **Fix**: Open browser console (F12) to see detailed errors
- **Fix**: Check you have test ETH in selected account

---

## Pro Tips

### 1. Use Remix Console
- Open console (bottom panel) to see:
  - Deployment addresses
  - Transaction hashes
  - Event logs
  - Gas usage

### 2. Pin Important Contracts
- Right-click deployed contract → "Pin"
- Keeps it visible even after page refresh

### 3. Export/Import Workspace
- **Export**: File Explorer → Workspace → Download
- **Import**: File Explorer → Workspace → Load from Filesystem
- Saves your work for later

### 4. Test with Multiple Accounts
- Remix VM provides 10+ test accounts
- Switch accounts to test different user roles
- Simulate multi-user scenarios

### 5. Debug Transactions
- Click transaction in console
- Select "Debug"
- Step through execution line-by-line

### 6. Use Remix Plugins
- **Flattener**: Combines all imports into one file
- **Debugger**: Advanced debugging tools
- **Unit Testing**: Write and run tests in Remix

---

## Expected Results

After successful deployment and testing, you should see:

### Quality Incentive Features Working ✅

1. **Compression Tracking**:
   - Update compression: 10KB → 1KB = 90% ratio
   - Check metrics: `getCompressionMetrics(1)` returns `(90, 10000, 1000)`

2. **Reliability Tracking**:
   - Record 10 successful validations
   - Check metrics: `getReliabilityMetrics(1)` returns `(100, 10, 0)`

3. **Multi-Factor Pricing**:
   - Elite skill (90% compression, 100% reliability): ~18 PSI (82% discount)
   - Poor skill (10% compression, 20% reliability): ~276 PSI (176% premium)

4. **Quality Breakdown**:
   - Frontend-ready data: base price, quality, compression, reliability, usage, final price
   - Transparent pricing for users

5. **Integration with Licensing**:
   - License skill: Pays quality-weighted price
   - Usage count increases: Further discounts apply

---

## Next Steps After Remix Testing

Once contracts are working in Remix:

1. **Document Deployed Addresses**
   - Save all contract addresses
   - Create deployment record

2. **Test All Features**
   - Run through test scenarios
   - Verify quality incentives work correctly
   - Check pricing calculations

3. **Export ABIs**
   - Compiler tab → Compilation Details → ABI
   - Copy ABI for frontend integration

4. **Deploy to Testnet**
   - Switch to "Injected Provider - MetaMask"
   - Connect to Sepolia or Goerli
   - Deploy to public testnet

5. **Frontend Integration**
   - Use deployed addresses and ABIs
   - Follow `FRONTEND_SETUP.md` guide
   - Build React dashboard

---

## Support & Resources

### Remix Documentation
- **Official Docs**: https://remix-ide.readthedocs.io
- **Video Tutorials**: https://www.youtube.com/c/RemixIDE
- **Community Forum**: https://github.com/ethereum/remix-ide/discussions

### ΨNet Resources
- **Implementation Guide**: `QUALITY_INCENTIVES_IMPLEMENTATION.md`
- **Design Document**: `CONTEXT_QUALITY_INCENTIVES.md`
- **Frontend Guide**: `FRONTEND_SETUP.md`
- **Test Suite**: `test/SkillRegistry.QualityIncentives.test.js`

### Getting Help
- Check Remix console for detailed errors
- Review contract code in file explorer
- Use Remix debugger to step through transactions
- Test with small values first

---

## Checklist

Use this checklist to track your progress:

### Setup Phase
- [ ] Opened https://remix.ethereum.org
- [ ] Created new workspace "PsiNet"
- [ ] Created folder structure (contracts, erc8004)
- [ ] Set compiler to 0.8.20
- [ ] Enabled optimization (200 runs)

### Upload Phase
- [ ] Uploaded all ERC-8004 interfaces
- [ ] Uploaded all ERC-8004 implementations
- [ ] Uploaded all main contracts
- [ ] Verified imports work correctly

### Compilation Phase
- [ ] Compiled all interfaces (no errors)
- [ ] Compiled IdentityRegistry ✅
- [ ] Compiled ReputationRegistry ✅
- [ ] Compiled PsiToken ✅
- [ ] Compiled HarbergerNFT ✅
- [ ] Compiled ShapleyReferrals ✅
- [ ] Compiled SkillRegistry ✅ ← Quality incentives!
- [ ] Compiled all validation contracts ✅

### Deployment Phase
- [ ] Deployed PsiToken
- [ ] Deployed IdentityRegistry
- [ ] Deployed ReputationRegistry
- [ ] Deployed ShapleyReferrals
- [ ] Deployed SkillRegistry ← Target contract!
- [ ] Saved all deployment addresses
- [ ] Granted necessary roles/permissions

### Testing Phase
- [ ] Registered test skill
- [ ] Updated compression (90% ratio)
- [ ] Recorded reliability (100%)
- [ ] Checked quality-weighted price
- [ ] Verified pricing discount (~82%)
- [ ] Called getQualityBreakdown()
- [ ] Tested licensing with quality price
- [ ] Verified all events emitted

### Documentation Phase
- [ ] Exported contract ABIs
- [ ] Documented deployment addresses
- [ ] Saved workspace for later
- [ ] Created testing notes

---

**Ready to deploy? Open https://remix.ethereum.org and follow this guide!**

**Status**: All contracts ready for Remix deployment ✅
**Date**: 2025-11-07
**Branch**: `claude/review-protocol-specs-011CUtLCwoThnXnNBjDbVKkH`
