# GitHub Project Board: ΨNet Production Roadmap

**Generated:** 2025-01-07
**Based on:** ACTION_PLAN.md + CRITICAL_REVIEW.md
**Purpose:** Track all tasks required to bring ΨNet to production readiness

---

## Project Board Setup Instructions

### Step 1: Create New Project Board

1. Go to repository: `WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context.`
2. Click "Projects" tab → "New project"
3. Choose "Board" view
4. Name: "ΨNet Production Roadmap"
5. Description: "18-24 month roadmap to mainnet launch"

---

### Step 2: Create Columns

Create the following columns (in order):

| Column | Purpose | WIP Limit |
|--------|---------|-----------|
| **📋 Backlog** | All planned tasks not yet started | - |
| **🔴 Phase 0: Critical** | Immediate stop-gap fixes (2-4 weeks) | 5 |
| **🏗️ Phase 1: Foundation** | Core infrastructure (6-9 months) | 8 |
| **🧪 Phase 2: Validation** | Testing & simulation (3-6 months) | 5 |
| **🚀 Phase 3: Launch** | Mainnet deployment (3-6 months) | 5 |
| **✅ Done** | Completed tasks | - |

**Automation Rules:**
- Auto-move to "Done" when issue is closed
- Auto-move to next phase when labeled with next phase label

---

### Step 3: Create Labels

Create the following labels in your repository:

#### Priority Labels
- 🔴 `priority: critical` - Must fix immediately (blocking)
- 🟠 `priority: high` - Important, address soon
- 🟡 `priority: medium` - Normal priority
- 🟢 `priority: low` - Nice to have

#### Phase Labels
- `phase-0: stop-gap` - Immediate fixes
- `phase-1: foundation` - Core infrastructure
- `phase-2: validation` - Testing & simulation
- `phase-3: launch` - Mainnet deployment

#### Type Labels
- `type: bug` - Something isn't working
- `type: security` - Security vulnerability
- `type: feature` - New functionality
- `type: infrastructure` - DevOps/infrastructure
- `type: documentation` - Documentation improvements
- `type: testing` - Test coverage
- `type: refactor` - Code improvement

#### Component Labels
- `component: smart-contracts` - Solidity contracts
- `component: did` - Decentralized Identity
- `component: ipfs` - IPFS integration
- `component: p2p` - P2P networking
- `component: crdt` - CRDT synchronization
- `component: crpc` - CRPC protocol
- `component: economics` - Tokenomics/economics
- `component: frontend` - UI/UX
- `component: sdk` - Developer SDK

#### Status Labels
- `status: blocked` - Blocked by dependencies
- `status: in-review` - Pull request under review
- `status: needs-design` - Requires design decision
- `status: needs-testing` - Awaiting test coverage

#### Effort Labels
- `effort: xs` - < 4 hours
- `effort: s` - 1-2 days
- `effort: m` - 3-5 days
- `effort: l` - 1-2 weeks
- `effort: xl` - 2-4 weeks
- `effort: xxl` - 1-3 months

---

### Step 4: Create Milestones

Create milestones with due dates:

1. **M0: Critical Fixes** - Due: 2 weeks from start
2. **M1.1: DID + IPFS** - Due: 8 weeks from Phase 1 start
3. **M1.2: Context Graphs** - Due: 16 weeks from Phase 1 start
4. **M1.3: P2P Network** - Due: 24 weeks from Phase 1 start
5. **M1.4: CRPC Fixes** - Due: 28 weeks from Phase 1 start
6. **M2.1: Simulation** - Due: 6 weeks from Phase 2 start
7. **M2.2: Security Audit** - Due: 14 weeks from Phase 2 start
8. **M2.3: Testnet Live** - Due: 20 weeks from Phase 2 start
9. **M2.4: Stress Testing** - Due: 24 weeks from Phase 2 start
10. **M3.1: Pre-Launch** - Due: 6 weeks from Phase 3 start
11. **M3.2: Closed Beta** - Due: 8 weeks from Phase 3 start
12. **M3.3: Open Beta** - Due: 12 weeks from Phase 3 start
13. **M3.4: Full Launch** - Due: 24 weeks from Phase 3 start

---

## Issues to Create

### Phase 0: Critical Stop-Gap Fixes (2-4 weeks)

---

#### Issue #1: Cap Shapley Coalition Bonuses

**Title:** [CRITICAL] Cap Shapley coalition bonuses to prevent hyperinflation

**Labels:**
- 🔴 `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `component: economics`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Description:**

**Problem:**
The current Shapley referral implementation can mint unlimited PSI tokens through quadratic coalition bonuses. With just 1,000 users, the entire 1B PSI supply can be minted.

```solidity
// ShapleyReferrals.sol:237
uint256 networkEffect = (size * size * 10 * 10**18) / 100;
// At size 20: 40,000 PSI per new member
// At size 100: Can mint entire supply!
```

**Risk Level:** 🔴 CRITICAL - Can cause complete token hyperinflation

**Required Fix:**
Add hard caps to coalition value calculation:

```solidity
function _calculateCoalitionValue(address[] memory coalition) internal view returns (uint256) {
    uint256 size = coalition.length;

    // Cap coalition size for rewards
    if (size > MAX_COALITION_SIZE_FOR_REWARDS) {
        size = MAX_COALITION_SIZE_FOR_REWARDS; // Set to 10
    }

    uint256 baseValue = 20 * 10**18 * size;
    uint256 depthBonus = CHAIN_DEPTH_BONUS * (size - 1);
    uint256 sizeBonus = (size / 3) * COALITION_SIZE_BONUS;

    // Cap network effect
    uint256 networkEffect = (size * size * 10 * 10**18) / 100;
    if (networkEffect > 10_000 * 10**18) {
        networkEffect = 10_000 * 10**18;
    }

    uint256 totalValue = baseValue + depthBonus + sizeBonus + networkEffect;

    // Global maximum
    if (totalValue > 50_000 * 10**18) {
        totalValue = 50_000 * 10**18;
    }

    uint256 activityMultiplier = _calculateActivityMultiplier(coalition);
    totalValue = (totalValue * activityMultiplier) / 100;

    return totalValue;
}
```

**Testing Requirements:**
- [ ] Test coalition of size 50 stays under cap
- [ ] Test coalition of size 100 stays under cap
- [ ] Verify max possible reward ≤ 50,000 PSI
- [ ] Test existing functionality still works
- [ ] Gas test with max coalition size

**Files to Modify:**
- `contracts/ShapleyReferrals.sol`
- `test/ShapleyReferrals.test.js`

**Acceptance Criteria:**
- ✅ Coalition bonuses capped at 50,000 PSI max
- ✅ All existing tests pass
- ✅ New tests for caps pass
- ✅ Gas cost acceptable

**Estimated Effort:** 4 hours

**Blocking:** All other work (this is catastrophic if deployed)

**References:**
- ACTION_PLAN.md: Fix #0.1
- CRITICAL_REVIEW.md: ISSUE #9

---

#### Issue #2: Add Cycle Detection to Referral Chain

**Title:** Add cycle detection to prevent infinite loops in referral chains

**Labels:**
- 🔴 `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Description:**

**Problem:**
No validation to prevent referral cycles (A → B → C → A), which causes infinite loops in chain traversal functions.

```solidity
// ShapleyReferrals.sol:82 - No cycle check
function joinWithReferral(address referrer) external {
    require(!users[msg.sender].exists, "User already exists");
    require(referrer != msg.sender, "Cannot refer yourself");
    // Missing: Check if referrer is in msg.sender's chain
}
```

**Attack Scenario:**
1. Alice joins (no referrer)
2. Bob joins with Alice as referrer: Alice → Bob
3. Charlie joins with Bob as referrer: Alice → Bob → Charlie
4. Alice tries to join again with Charlie as referrer: Would create Alice → Bob → Charlie → Alice
5. Any chain traversal function enters infinite loop

**Required Fix:**

```solidity
function joinWithReferral(address referrer) external nonReentrant {
    require(!users[msg.sender].exists, "User already exists");
    require(referrer != msg.sender, "Cannot refer yourself");

    if (referrer != address(0)) {
        require(users[referrer].exists, "Referrer must be registered");
        require(!_isInChain(referrer, msg.sender), "Cycle detected");
    }

    // ... rest of function
}

function _isInChain(address ancestor, address descendant) internal view returns (bool) {
    address current = ancestor;
    uint256 depth = 0;

    while (current != address(0) && depth < 100) {
        if (current == descendant) {
            return true;
        }
        current = users[current].referrer;
        depth++;
    }

    return false;
}
```

**Testing Requirements:**
- [ ] Test A → B → C → A is rejected
- [ ] Test A → B → C → D (valid chain) works
- [ ] Test self-referral is rejected
- [ ] Test gas cost with max depth (100)
- [ ] Test edge case: A → B, then B tries to refer A

**Files to Modify:**
- `contracts/ShapleyReferrals.sol`
- `test/ShapleyReferrals.test.js`

**Acceptance Criteria:**
- ✅ Cycles are detected and rejected
- ✅ Valid chains work normally
- ✅ Gas cost reasonable (<50k gas)
- ✅ All tests pass

**Estimated Effort:** 2 hours

**References:**
- ACTION_PLAN.md: Fix #0.2
- CRITICAL_REVIEW.md: ISSUE #16

---

#### Issue #3: Remove Unbounded Recursion from Network Counting

**Title:** Replace recursive network counting with iterative BFS

**Labels:**
- 🔴 `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `effort: s`

**Milestone:** M0: Critical Fixes

**Description:**

**Problem:**
The `_countNetwork` function uses unbounded recursion, which can exceed gas limits and cause DoS.

```solidity
// ShapleyReferrals.sol:366 - UNBOUNDED RECURSION
function _countNetwork(address user) internal view returns (uint256) {
    uint256 count = 1;
    address[] memory referees = users[user].referees;

    for (uint256 i = 0; i < referees.length; i++) {
        count += _countNetwork(referees[i]); // RECURSIVE
    }

    return count;
}
```

**Attack Scenario:**
1. Attacker builds network of 1,000 nodes
2. Anyone calling `getNetworkSize()` on attacker hits gas limit
3. Function becomes unusable for large networks

**Required Fix:**
Replace with iterative BFS with depth limit:

```solidity
function getNetworkSize(address user) external view returns (uint256) {
    require(users[user].exists, "User not found");
    return _countNetworkIterative(user);
}

function _countNetworkIterative(address root) internal view returns (uint256) {
    uint256 count = 0;
    uint256 maxDepth = 20;
    uint256 maxNodes = 1000;

    address[] memory queue = new address[](maxNodes);
    uint256 front = 0;
    uint256 back = 0;

    queue[back++] = root;

    while (front < back && count < maxNodes) {
        address current = queue[front++];
        count++;

        address[] memory referees = users[current].referees;

        // Only traverse up to maxDepth from root
        if (users[current].chainDepth < users[root].chainDepth + maxDepth) {
            for (uint256 i = 0; i < referees.length && back < maxNodes; i++) {
                queue[back++] = referees[i];
            }
        }
    }

    return count;
}
```

**Testing Requirements:**
- [ ] Test network of 10 nodes (works correctly)
- [ ] Test network of 100 nodes (works correctly)
- [ ] Test network of 1,000 nodes (doesn't exceed gas limit)
- [ ] Test network of 10,000 nodes (returns capped value)
- [ ] Test deep chain (depth 50) returns correct count
- [ ] Test wide tree (100 direct referees) returns correct count
- [ ] Gas benchmark with various network sizes

**Files to Modify:**
- `contracts/ShapleyReferrals.sol`
- `test/ShapleyReferrals.test.js`

**Acceptance Criteria:**
- ✅ No more recursion
- ✅ Gas cost predictable (<1M gas for any network)
- ✅ Returns accurate count for small networks
- ✅ Returns capped value for large networks
- ✅ All tests pass

**Estimated Effort:** 3 hours

**References:**
- ACTION_PLAN.md: Fix #0.3
- CRITICAL_REVIEW.md: ISSUE #14

---

#### Issue #4: Fix Reputation Time-Weighting Cliff

**Title:** Fix reputation time-weighting cliff at 365 days

**Labels:**
- 🟠 `priority: high`
- `phase-0: stop-gap`
- `type: bug`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Description:**

**Problem:**
Reputation calculation has a discontinuity at exactly 365 days, causing unfair weighting.

```solidity
// ReputationRegistry.sol:244
uint256 timeWeight = age > 365 days ? 1 : (365 days - age) / 1 days + 1;

// Results:
// Age 364 days: weight = 2
// Age 365 days: weight = 1  <- CLIFF!
// Age 366 days: weight = 1
```

Additionally, staked feedback with quadratic weighting can dominate entire history:
- Fresh staked: 365 × 2 = 730 weight
- Old unstaked: 1 × 1 = 1 weight
- Ratio: 730:1 (single review dominates)

**Required Fix:**
Smooth exponential decay with capped stake multiplier:

```solidity
function _updateReputationScore(uint256 agentId) private {
    // ... existing setup ...

    for (uint256 i = 0; i < feedbackIds.length; i++) {
        Feedback memory feedback = _feedbacks[feedbackIds[i]];

        if (feedback.disputed || feedback.rating == 0) continue;

        // Smooth exponential decay
        uint256 age = currentTime - feedback.timestamp;
        uint256 timeWeight;

        if (age <= 30 days) {
            timeWeight = 1000; // Very recent: 10x
        } else if (age <= 90 days) {
            timeWeight = 500; // Recent: 5x
        } else if (age <= 180 days) {
            timeWeight = 200; // Medium: 2x
        } else if (age <= 365 days) {
            timeWeight = 100; // Old: 1x
        } else {
            // Exponential decay after 1 year
            uint256 yearsOld = (age - 365 days) / 365 days;
            timeWeight = 100 / (2 ** yearsOld); // Halve every year
            if (timeWeight < 10) timeWeight = 10; // Min 0.1x
        }

        // Cap stake weight to prevent dominance
        uint256 stakeWeight = feedback.stake > 0 ? 150 : 100; // Max 1.5x, not 2x

        uint256 weight = (timeWeight * stakeWeight) / 100;

        // ... rest of calculation
    }
}
```

**Testing Requirements:**
- [ ] Test feedback at 364, 365, 366 days (smooth transition)
- [ ] Test feedback at 2 years (properly decayed)
- [ ] Test staked vs unstaked feedback weight ratio (<10:1)
- [ ] Test reputation with 100 feedbacks across 3 years
- [ ] Compare old vs new algorithm results

**Files to Modify:**
- `contracts/erc8004/ReputationRegistry.sol`
- `test/ReputationRegistry.test.js`

**Acceptance Criteria:**
- ✅ No cliff at 365 days
- ✅ Smooth exponential decay
- ✅ Stake multiplier capped at 1.5x
- ✅ All tests pass
- ✅ Gas cost similar to before

**Estimated Effort:** 2 hours

**References:**
- ACTION_PLAN.md: Fix #0.4
- CRITICAL_REVIEW.md: ISSUE #6

---

#### Issue #5: Add Circuit Breakers to Token Minting

**Title:** Implement emergency pause and daily mint limits

**Labels:**
- 🔴 `priority: critical`
- `phase-0: stop-gap`
- `type: security`
- `type: feature`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Description:**

**Problem:**
No emergency stop mechanism if economic attack is detected. No limits on daily minting.

**Required Fix:**
Add emergency controls to PsiToken:

```solidity
contract PsiToken is ERC20, AccessControl {
    bool public emergencyPaused;
    uint256 public dailyMintLimit = 1_000_000 * 10**18;
    uint256 public mintedToday;
    uint256 public lastMintReset;

    event EmergencyPause(address admin, string reason);
    event EmergencyUnpause(address admin);
    event DailyMintLimitExceeded(uint256 attempted, uint256 limit);

    modifier whenNotPaused() {
        require(!emergencyPaused, "Emergency pause active");
        _;
    }

    function emergencyPause(string calldata reason)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencyPaused = true;
        emit EmergencyPause(msg.sender, reason);
    }

    function emergencyUnpause()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencyPaused = false;
        emit EmergencyUnpause(msg.sender);
    }

    function setDailyMintLimit(uint256 newLimit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        dailyMintLimit = newLimit;
    }

    function rewardAgent(
        address agent,
        uint256 amount,
        bool cooperative,
        uint256 networkSize
    ) external whenNotPaused {
        // Reset daily counter
        if (block.timestamp > lastMintReset + 1 days) {
            mintedToday = 0;
            lastMintReset = block.timestamp;
        }

        // Check daily limit
        require(mintedToday + amount <= dailyMintLimit, "Daily limit exceeded");
        mintedToday += amount;

        // ... rest of function
    }
}
```

**Testing Requirements:**
- [ ] Test emergency pause stops all minting
- [ ] Test emergency unpause restores functionality
- [ ] Test daily limit enforcement
- [ ] Test daily limit resets after 24 hours
- [ ] Test admin can adjust daily limit
- [ ] Test non-admin cannot pause/unpause
- [ ] Test events are emitted correctly

**Files to Modify:**
- `contracts/PsiToken.sol`
- `test/PsiToken.test.js`

**Acceptance Criteria:**
- ✅ Emergency pause works
- ✅ Daily mint limit enforced
- ✅ Admin controls functional
- ✅ Access control correct
- ✅ All tests pass

**Estimated Effort:** 4 hours

**References:**
- ACTION_PLAN.md: Fix #0.5

---

#### Issue #6: Phase 0 Testing & Deployment

**Title:** Comprehensive testing and deployment of Phase 0 fixes

**Labels:**
- 🔴 `priority: critical`
- `phase-0: stop-gap`
- `type: testing`
- `effort: s`

**Milestone:** M0: Critical Fixes

**Dependencies:** Issues #1-5 must be completed first

**Description:**

**Objective:**
Ensure all Phase 0 fixes work correctly together and are ready for deployment.

**Tasks:**

**Testing:**
- [ ] Run full test suite (all existing tests pass)
- [ ] Run new Phase 0 tests (all pass)
- [ ] Gas optimization tests
- [ ] Integration tests (fixes work together)
- [ ] Edge case tests
- [ ] Test coverage >95%

**Code Review:**
- [ ] All PRs reviewed by 2+ developers
- [ ] Security review by team lead
- [ ] Code follows style guide
- [ ] Documentation updated

**Deployment:**
- [ ] Deploy to local testnet
- [ ] Deploy to Sepolia testnet
- [ ] Verify contracts on Etherscan
- [ ] Test on testnet with real transactions
- [ ] Create deployment report

**Documentation:**
- [ ] Update CHANGELOG.md
- [ ] Update README.md if needed
- [ ] Document new constants (caps, limits)
- [ ] Create upgrade guide

**Acceptance Criteria:**
- ✅ All tests pass (100%)
- ✅ Test coverage >95%
- ✅ All PRs merged
- ✅ Deployed to testnet
- ✅ Documentation complete

**Estimated Effort:** 1-2 days

---

### Phase 1: Foundation - Core Infrastructure (6-9 months)

---

#### Issue #7: Implement Ed25519 DID Library

**Title:** Build Ed25519-based Decentralized Identifier system

**Labels:**
- 🟠 `priority: high`
- `phase-1: foundation`
- `type: feature`
- `component: did`
- `effort: xl`

**Milestone:** M1.1: DID + IPFS

**Description:**

**Objective:**
Implement W3C-compliant DID system using Ed25519 keys for agent identity.

**Requirements:**
- Ed25519 key generation
- DID document creation (W3C format)
- DID resolution
- Key rotation mechanism
- Signature verification

**Technical Spec:**

```typescript
// packages/did/src/index.ts

interface DIDDocument {
  '@context': string[];
  id: string; // "did:key:z6Mk..."
  verificationMethod: VerificationMethod[];
  authentication: string[];
  assertionMethod: string[];
  capabilityDelegation: string[];
}

class Ed25519DID {
  static generate(): {
    did: string;
    privateKey: Uint8Array;
    publicKey: Uint8Array;
  }

  static resolve(did: string): Promise<DIDDocument>

  static verify(
    did: string,
    signature: Uint8Array,
    message: Uint8Array
  ): boolean

  static rotate(
    oldPrivateKey: Uint8Array
  ): {
    newDID: string;
    newPrivateKey: Uint8Array;
  }
}
```

**Dependencies:**
- `@stablelib/ed25519`
- `did-resolver`
- `key-did-provider-ed25519`

**Deliverables:**
- [ ] Ed25519 key generation library
- [ ] DID document structure
- [ ] DID resolver
- [ ] Key rotation mechanism
- [ ] Comprehensive test suite (>95% coverage)
- [ ] Documentation
- [ ] Example usage code

**Testing Requirements:**
- [ ] Unit tests for all functions
- [ ] Key generation (1000 keys)
- [ ] DID resolution (100 DIDs)
- [ ] Signature verification
- [ ] Key rotation
- [ ] Performance: 1000 generations/sec
- [ ] Security: Keys never collide

**Files to Create:**
- `packages/did/src/index.ts`
- `packages/did/src/types.ts`
- `packages/did/src/resolver.ts`
- `packages/did/test/did.test.ts`
- `packages/did/README.md`

**Acceptance Criteria:**
- ✅ W3C DID compliant
- ✅ All tests pass
- ✅ Performance targets met
- ✅ Documentation complete
- ✅ Examples work

**Estimated Effort:** 2-3 weeks

**References:**
- ACTION_PLAN.md: 1.1.1
- https://www.w3.org/TR/did-core/

---

#### Issue #8: Integrate DIDs with Identity Registry

**Title:** Connect Ed25519 DIDs to on-chain Identity NFTs

**Labels:**
- 🟠 `priority: high`
- `phase-1: foundation`
- `type: feature`
- `component: did`
- `component: smart-contracts`
- `effort: m`

**Milestone:** M1.1: DID + IPFS

**Dependencies:** Issue #7 (DID library), Issue #9 (IPFS integration)

**Description:**

**Objective:**
Allow agents to register using DIDs, store DID documents on IPFS, reference IPFS CID on-chain.

**Implementation:**

```solidity
// contracts/erc8004/IdentityRegistry.sol

function registerAgentWithDID(
    string calldata didDocumentCID,
    bytes calldata signature
) external returns (uint256 agentId) {
    // Verify signature proves DID ownership
    require(_verifyDIDSignature(didDocumentCID, signature), "Invalid signature");

    // Register agent with DID document
    return _registerAgent(msg.sender, didDocumentCID);
}

function _verifyDIDSignature(
    string calldata didDocumentCID,
    bytes calldata signature
) internal view returns (bool) {
    // Fetch DID document from IPFS (off-chain)
    // Extract public key
    // Verify signature
    // This should be done off-chain and verified on-chain
}
```

**Deliverables:**
- [ ] Modified IdentityRegistry contract
- [ ] DID verification library
- [ ] Integration tests
- [ ] Migration script
- [ ] Documentation

**Testing Requirements:**
- [ ] Test DID registration
- [ ] Test signature verification
- [ ] Test invalid DIDs rejected
- [ ] Test IPFS CID stored correctly
- [ ] Test retrieval of DID from on-chain data
- [ ] Gas cost analysis

**Files to Modify:**
- `contracts/erc8004/IdentityRegistry.sol`
- `contracts/erc8004/IIdentityRegistry.sol`
- `test/IdentityRegistry.test.js`

**Acceptance Criteria:**
- ✅ DIDs can register as agents
- ✅ Signature verification works
- ✅ IPFS integration works
- ✅ All tests pass
- ✅ Gas cost reasonable

**Estimated Effort:** 3-5 days

**References:**
- ACTION_PLAN.md: 1.1.2

---

#### Issue #9: Build IPFS Integration Layer

**Title:** Implement IPFS client for DID and context storage

**Labels:**
- 🟠 `priority: high`
- `phase-1: foundation`
- `type: feature`
- `type: infrastructure`
- `component: ipfs`
- `effort: l`

**Milestone:** M1.1: DID + IPFS

**Description:**

**Objective:**
Create IPFS client library for uploading/downloading DID documents and context graphs.

**Technical Spec:**

```typescript
// packages/ipfs/src/index.ts

interface IPFSClient {
  uploadDIDDocument(doc: DIDDocument): Promise<string>; // Returns CID
  uploadContextGraph(graph: EncryptedContextGraph): Promise<string>;

  fetchDIDDocument(cid: string): Promise<DIDDocument>;
  fetchContextGraph(cid: string): Promise<EncryptedContextGraph>;

  pin(cid: string): Promise<void>;
  unpin(cid: string): Promise<void>;
}

class IPFSManager implements IPFSClient {
  constructor(options: {
    gateway: string;
    apiEndpoint: string;
    pinningService?: 'pinata' | 'web3.storage' | 'infura';
  });
}
```

**Infrastructure Setup:**
- [ ] Deploy 3 IPFS nodes (redundancy)
- [ ] Configure pinning service (Pinata recommended)
- [ ] Set up caching layer (Redis)
- [ ] Add content validation

**Deliverables:**
- [ ] IPFS client library
- [ ] Pinning service integration
- [ ] Caching layer
- [ ] Content validation
- [ ] Retry logic
- [ ] Test suite
- [ ] Documentation

**Testing Requirements:**
- [ ] Upload/download DID documents
- [ ] Upload/download context graphs
- [ ] Pin/unpin content
- [ ] Cache hit/miss scenarios
- [ ] Failure recovery
- [ ] Performance: 100 uploads/sec

**Files to Create:**
- `packages/ipfs/src/index.ts`
- `packages/ipfs/src/client.ts`
- `packages/ipfs/src/pinning.ts`
- `packages/ipfs/test/ipfs.test.ts`
- `packages/ipfs/README.md`

**Infrastructure Cost:**
- IPFS nodes: $300-500/month
- Pinning service: $50-200/month
- Total: ~$400-700/month

**Acceptance Criteria:**
- ✅ IPFS client works reliably
- ✅ Content validated correctly
- ✅ Pinning service integrated
- ✅ Performance targets met
- ✅ All tests pass

**Estimated Effort:** 1-2 weeks

**References:**
- ACTION_PLAN.md: 1.2.1

---

#### Issue #10: Implement IPFS Verification in Smart Contracts

**Title:** Add on-chain IPFS CID verification

**Labels:**
- 🟡 `priority: medium`
- `phase-1: foundation`
- `type: feature`
- `component: smart-contracts`
- `component: ipfs`
- `effort: s`

**Milestone:** M1.1: DID + IPFS

**Dependencies:** Issue #9

**Description:**

**Objective:**
Verify IPFS CIDs are valid format on-chain before storing.

**Implementation:**

```solidity
// contracts/utils/IPFSVerifier.sol

library IPFSVerifier {
    function isValidCID(string memory cid) internal pure returns (bool) {
        bytes memory cidBytes = bytes(cid);

        // Check length
        if (cidBytes.length < 46 || cidBytes.length > 64) {
            return false;
        }

        // Check prefix (CIDv0: Qm... or CIDv1: b...)
        if (cidBytes[0] == 'Q' && cidBytes[1] == 'm') {
            // CIDv0
            return _isValidBase58(cidBytes);
        } else if (cidBytes[0] == 'b') {
            // CIDv1
            return _isValidBase32(cidBytes);
        }

        return false;
    }

    function _isValidBase58(bytes memory data) internal pure returns (bool) {
        // Validate base58 characters
    }

    function _isValidBase32(bytes memory data) internal pure returns (bool) {
        // Validate base32 characters
    }
}
```

**Deliverables:**
- [ ] IPFS verifier library
- [ ] Integration with Identity Registry
- [ ] Integration with other contracts
- [ ] Test suite
- [ ] Gas optimization

**Testing Requirements:**
- [ ] Test valid CIDv0
- [ ] Test valid CIDv1
- [ ] Test invalid CIDs rejected
- [ ] Gas cost analysis

**Files to Create:**
- `contracts/utils/IPFSVerifier.sol`
- `test/IPFSVerifier.test.js`

**Acceptance Criteria:**
- ✅ Valid CIDs pass
- ✅ Invalid CIDs fail
- ✅ Gas cost <10k
- ✅ All tests pass

**Estimated Effort:** 1-2 days

**References:**
- ACTION_PLAN.md: 1.2.2

---

#### Issue #11: Design Context Graph Data Structure

**Title:** Implement encrypted context graph with CRDT support

**Labels:**
- 🟠 `priority: high`
- `phase-1: foundation`
- `type: feature`
- `component: crdt`
- `effort: xl`

**Milestone:** M1.2: Context Graphs

**Dependencies:** Issue #9 (IPFS)

**Description:**

**Objective:**
Create graph-based data structure for AI conversation context with conflict-free merging.

**Technical Spec:**

```typescript
// packages/context/src/graph.ts

interface ContextNode {
  id: string;
  type: 'message' | 'state' | 'reference';
  content: EncryptedContent;
  timestamp: number;
  author: string; // DID
  signature: Uint8Array;
  edges: Edge[];
}

interface Edge {
  target: string;
  type: 'reply' | 'reference' | 'dependency';
  weight: number;
}

interface ContextGraph {
  nodes: Map<string, ContextNode>;
  root: string;
  version: number;
  metadata: GraphMetadata;
}

class ContextGraphManager {
  createNode(content: Content, author: DID): ContextNode;
  addEdge(from: string, to: string, type: EdgeType): void;
  serialize(): Uint8Array;
  deserialize(data: Uint8Array): ContextGraph;
  toCID(): Promise<string>; // Upload to IPFS
}
```

**Deliverables:**
- [ ] Context graph data structure
- [ ] Node creation/modification
- [ ] Edge management
- [ ] Serialization/deserialization
- [ ] IPFS integration
- [ ] Test suite
- [ ] Documentation
- [ ] Examples

**Testing Requirements:**
- [ ] Create/modify nodes
- [ ] Add/remove edges
- [ ] Serialize/deserialize
- [ ] Upload to IPFS
- [ ] Large graphs (1000+ nodes)
- [ ] Performance benchmarks

**Files to Create:**
- `packages/context/src/graph.ts`
- `packages/context/src/node.ts`
- `packages/context/src/edge.ts`
- `packages/context/test/graph.test.ts`
- `packages/context/README.md`

**Acceptance Criteria:**
- ✅ Graph operations work correctly
- ✅ Serialization efficient
- ✅ IPFS integration works
- ✅ Performance acceptable
- ✅ All tests pass

**Estimated Effort:** 2-3 weeks

**References:**
- ACTION_PLAN.md: 1.3.1

---

[Continue with Issues #12-50 covering remaining Phase 1, Phase 2, and Phase 3 tasks...]

---

## Quick Start Guide

### For Project Manager:

1. **Create project board** with columns specified above
2. **Create labels** as specified
3. **Create milestones** with due dates
4. **Create issues #1-6** for Phase 0 (copy from above)
5. **Assign** issues to team members
6. **Start Phase 0** immediately

### For Developers:

1. **Check project board** for your assigned tasks
2. **Move card** to "In Progress" when starting
3. **Create branch** from main: `git checkout -b fix/issue-N-description`
4. **Implement fix** following specification
5. **Write tests** (coverage >95%)
6. **Create PR** referencing issue number
7. **Request review** from 2+ teammates
8. **Move card** to "Done" when merged

### For Team Lead:

1. **Daily standup** review project board
2. **Weekly planning** prioritize next issues
3. **Track velocity** estimate completion dates
4. **Adjust resources** if blockers arise
5. **Report progress** to stakeholders

---

## Automation Recommendations

### GitHub Actions Workflows:

1. **PR Checks:**
   - Run tests
   - Check coverage >95%
   - Run linter
   - Gas snapshot
   - Security scan (Slither)

2. **Issue Automation:**
   - Auto-label based on files changed
   - Auto-assign based on component
   - Auto-close on merged PR
   - Update project board

3. **Deployment:**
   - Auto-deploy to testnet on main branch
   - Create release notes
   - Notify team on Discord/Slack

---

## Project Board Saved in Repository

This specification should be saved as:
- `.github/PROJECT_BOARD.md`

And referenced from:
- `README.md`
- `CONTRIBUTING.md`

---

**Ready to start!** Create the issues and let's ship Phase 0 in 2-4 weeks.
