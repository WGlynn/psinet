# ΨNet Action Plan: Critical Path to Production Readiness

**Generated:** 2025-01-07
**Based on:** CRITICAL_REVIEW.md
**Status:** DRAFT - Requires Team Review
**Timeline:** 18-24 months to mainnet launch

---

## Executive Summary

This action plan provides a structured roadmap to address the 18 critical issues identified in the comprehensive review and bring ΨNet to production readiness. The plan is organized into 4 phases with clear deliverables, timelines, and success criteria.

**Critical Findings:**
- 🔴 **Immediate Risk:** Shapley referral hyperinflation can mint entire token supply
- 🔴 **Blocker:** 80% of specified architecture not implemented (DIDs, P2P, IPFS, CRDTs)
- 🔴 **Security:** Multiple vulnerabilities require professional audit before mainnet
- 🟡 **Economics:** Unproven assumptions need validation through simulation

**Recommended Approach:**
1. **Stop-Gap Fixes** (2-4 weeks): Address immediate risks that could cause catastrophic failure
2. **Foundation Phase** (6-9 months): Build missing infrastructure and fix critical flaws
3. **Validation Phase** (3-6 months): Testnet deployment and economic simulation
4. **Launch Phase** (3-6 months): Gradual mainnet rollout with safeguards

---

## Phase 0: Immediate Stop-Gap Fixes (2-4 weeks)

### Objective
Prevent catastrophic failures if current code is deployed. These are **MUST FIX NOW** issues.

### Critical Fixes

#### Fix #0.1: Cap Shapley Coalition Bonuses (BLOCKING)
**Priority:** 🔴 CRITICAL - DO THIS FIRST
**Effort:** 4 hours
**Risk if not fixed:** Complete token hyperinflation

**Current Issue:**
```solidity
// ShapleyReferrals.sol:237
uint256 networkEffect = (size * size * 10 * 10**18) / 100;
// At size 20: 40,000 PSI per new member!
// At size 100: Can mint entire 1B supply!
```

**Fix:**
```solidity
// contracts/ShapleyReferrals.sol

function _calculateCoalitionValue(address[] memory coalition) internal view returns (uint256) {
    uint256 size = coalition.length;

    // ADD: Cap coalition size for value calculation
    if (size > MAX_COALITION_SIZE_FOR_REWARDS) {
        size = MAX_COALITION_SIZE_FOR_REWARDS; // Set to 10
    }

    uint256 baseValue = 20 * 10**18 * size;
    uint256 depthBonus = CHAIN_DEPTH_BONUS * (size - 1);
    uint256 sizeBonus = (size / 3) * COALITION_SIZE_BONUS;

    // CAP: Network effect with hard maximum
    uint256 networkEffect = (size * size * 10 * 10**18) / 100;
    if (networkEffect > 10_000 * 10**18) {
        networkEffect = 10_000 * 10**18; // Cap at 10k PSI
    }

    uint256 totalValue = baseValue + depthBonus + sizeBonus + networkEffect;

    // ADD: Global maximum coalition value
    if (totalValue > 50_000 * 10**18) {
        totalValue = 50_000 * 10**18; // Cap at 50k PSI total
    }

    uint256 activityMultiplier = _calculateActivityMultiplier(coalition);
    totalValue = (totalValue * activityMultiplier) / 100;

    return totalValue;
}

// ADD: New constant
uint256 public constant MAX_COALITION_SIZE_FOR_REWARDS = 10;
```

**Testing Required:**
- Test coalition of size 100 doesn't mint excessive tokens
- Verify cap doesn't break existing functionality
- Gas test with max coalition size

**Success Criteria:**
- Maximum possible coalition reward ≤ 50,000 PSI
- No single user can earn > 100,000 PSI from referrals

---

#### Fix #0.2: Add Cycle Detection to Referrals (HIGH)
**Priority:** 🔴 CRITICAL
**Effort:** 2 hours
**Risk if not fixed:** Infinite loops, DoS attacks

**Current Issue:**
```solidity
// ShapleyReferrals.sol:82 - No cycle detection
// Can create: A → B → C → A (infinite loop)
```

**Fix:**
```solidity
function joinWithReferral(address referrer) external nonReentrant {
    require(!users[msg.sender].exists, "User already exists");
    require(referrer != msg.sender, "Cannot refer yourself");

    // ADD: Cycle detection
    if (referrer != address(0)) {
        require(users[referrer].exists, "Referrer must be registered");
        require(!_isInChain(referrer, msg.sender), "Cycle detected");
    }

    // ... rest of function
}

// ADD: Helper function
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

---

#### Fix #0.3: Remove Unbounded Recursive Network Counting (HIGH)
**Priority:** 🔴 CRITICAL
**Effort:** 3 hours
**Risk if not fixed:** Gas limit DoS attacks

**Current Issue:**
```solidity
// ShapleyReferrals.sol:366 - Unbounded recursion
function _countNetwork(address user) internal view returns (uint256) {
    uint256 count = 1;
    for (uint256 i = 0; i < referees.length; i++) {
        count += _countNetwork(referees[i]); // RECURSIVE - NO LIMIT
    }
    return count;
}
```

**Fix:**
```solidity
// REMOVE _countNetwork entirely
// REPLACE getNetworkSize with iterative BFS

function getNetworkSize(address user) external view returns (uint256) {
    require(users[user].exists, "User not found");
    return _countNetworkIterative(user);
}

function _countNetworkIterative(address root) internal view returns (uint256) {
    uint256 count = 0;
    uint256 maxDepth = 20; // Reasonable limit

    // Use array as queue for BFS
    address[] memory queue = new address[](1000); // Adjust size as needed
    uint256 front = 0;
    uint256 back = 0;

    queue[back++] = root;

    while (front < back && count < 1000) {
        address current = queue[front++];
        count++;

        address[] memory referees = users[current].referees;

        // Only traverse up to maxDepth
        if (users[current].chainDepth < users[root].chainDepth + maxDepth) {
            for (uint256 i = 0; i < referees.length && back < 1000; i++) {
                queue[back++] = referees[i];
            }
        }
    }

    return count;
}
```

---

#### Fix #0.4: Fix Reputation Time-Weighting Cliff (MEDIUM)
**Priority:** 🟡 HIGH
**Effort:** 2 hours
**Risk if not fixed:** Unfair reputation calculations, gaming

**Current Issue:**
```solidity
// ReputationRegistry.sol:244 - Cliff at 365 days
uint256 timeWeight = age > 365 days ? 1 : (365 days - age) / 1 days + 1;
// Age 364 days: weight = 2
// Age 365 days: weight = 1  <- CLIFF
// Age 366 days: weight = 1
```

**Fix:**
```solidity
function _updateReputationScore(uint256 agentId) private {
    // ... existing code ...

    for (uint256 i = 0; i < feedbackIds.length; i++) {
        Feedback memory feedback = _feedbacks[feedbackIds[i]];

        if (feedback.disputed || feedback.rating == 0) continue;

        // FIX: Smooth exponential decay instead of cliff
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

        // Cap stake weight to prevent dominance
        uint256 stakeWeight = feedback.stake > 0 ? 150 : 100; // Max 1.5x, not 2x

        uint256 weight = (timeWeight * stakeWeight) / 100;

        // ... rest of calculation
    }
}
```

---

#### Fix #0.5: Add Circuit Breakers (HIGH)
**Priority:** 🔴 CRITICAL
**Effort:** 4 hours
**Risk if not fixed:** No emergency stop mechanism

**Add to PsiToken.sol:**
```solidity
contract PsiToken is ERC20, AccessControl {
    // ADD: Emergency controls
    bool public emergencyPaused;
    uint256 public dailyMintLimit = 1_000_000 * 10**18; // 1M PSI/day
    uint256 public mintedToday;
    uint256 public lastMintReset;

    event EmergencyPause(address admin, string reason);
    event EmergencyUnpause(address admin);
    event DailyMintLimitExceeded(uint256 attempted, uint256 limit);

    modifier whenNotPaused() {
        require(!emergencyPaused, "Emergency pause active");
        _;
    }

    function emergencyPause(string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPaused = true;
        emit EmergencyPause(msg.sender, reason);
    }

    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyPaused = false;
        emit EmergencyUnpause(msg.sender);
    }

    function rewardAgent(address agent, uint256 amount, bool cooperative, uint256 networkSize)
        external
        whenNotPaused // ADD CHECK
    {
        // Reset daily counter if needed
        if (block.timestamp > lastMintReset + 1 days) {
            mintedToday = 0;
            lastMintReset = block.timestamp;
        }

        // Check daily limit
        require(mintedToday + amount <= dailyMintLimit, "Daily mint limit exceeded");
        mintedToday += amount;

        // ... rest of function
    }
}
```

---

### Stop-Gap Testing Checklist

- [ ] Test Shapley cap with coalition size 50
- [ ] Test cycle detection prevents A→B→A
- [ ] Test iterative network counting with 1000-node network
- [ ] Test reputation calculation with feedbacks across 2 years
- [ ] Test emergency pause stops all minting
- [ ] Test daily mint limit enforcement
- [ ] Gas test all fixes with max parameters
- [ ] Deploy fixes to local testnet
- [ ] Run existing test suite (should pass)
- [ ] Create new tests for fixes

### Deliverables for Phase 0

1. ✅ Pull request with 5 critical fixes
2. ✅ Updated test suite covering new edge cases
3. ✅ Gas optimization report
4. ✅ Deployment script for fixes
5. ✅ Documentation of changes

**Timeline:** 2-4 weeks
**Team Required:** 2 Solidity developers
**Cost:** ~$10,000-$15,000 if outsourced

---

## Phase 1: Foundation - Build Core Infrastructure (6-9 months)

### Objective
Implement the missing 80% of the architecture specified in the protocol documents.

### 1.1 Decentralized Identity (DID) Implementation

**Priority:** 🔴 CRITICAL (Blocker for all other features)
**Effort:** 6-8 weeks
**Owner:** Backend/Crypto Team

#### Deliverables

**1.1.1: Ed25519 DID Library**
- Implement Ed25519 key generation
- Implement DID document structure (W3C compliant)
- Add key rotation mechanism
- Support DID resolution

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
  static generate(): { did: string; privateKey: Uint8Array; publicKey: Uint8Array }
  static resolve(did: string): Promise<DIDDocument>
  static verify(did: string, signature: Uint8Array, message: Uint8Array): boolean
  static rotate(oldPrivateKey: Uint8Array): { newDID: string; newPrivateKey: Uint8Array }
}
```

**Dependencies:**
- `@stablelib/ed25519` (Ed25519 implementation)
- `did-resolver` (DID resolution)
- `key-did-provider-ed25519` (DID provider)

**Testing:**
- Unit tests for key generation
- Integration tests with Identity Registry
- Security audit of key handling
- Performance tests (1000 DID generations/sec)

---

**1.1.2: Identity Registry Integration**
- Connect Ed25519 DIDs to on-chain Identity NFTs
- Store DID document on IPFS
- Reference IPFS CID on-chain

**Implementation:**
```solidity
// contracts/erc8004/IdentityRegistry.sol

// MODIFY registerAgent to accept DID
function registerAgentWithDID(
    string calldata didDocument, // IPFS CID of DID document
    bytes calldata signature      // Signature proving DID ownership
) external returns (uint256 agentId) {
    // Verify signature against DID
    require(_verifyDIDSignature(didDocument, signature), "Invalid DID signature");

    // Register agent with DID document as metadata
    return _registerAgent(msg.sender, didDocument);
}
```

---

### 1.2 IPFS Integration

**Priority:** 🔴 CRITICAL
**Effort:** 4-6 weeks
**Owner:** Backend Team

#### Deliverables

**1.2.1: IPFS Client Library**
```typescript
// packages/ipfs/src/index.ts

interface IPFSClient {
  // Upload DID documents
  uploadDIDDocument(doc: DIDDocument): Promise<string>; // Returns CID

  // Upload context graphs
  uploadContextGraph(graph: EncryptedContextGraph): Promise<string>;

  // Retrieve content
  fetchDIDDocument(cid: string): Promise<DIDDocument>;
  fetchContextGraph(cid: string): Promise<EncryptedContextGraph>;

  // Pin management
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

**Infrastructure:**
- Set up IPFS nodes (3 initial nodes for redundancy)
- Configure pinning service (Pinata or Web3.Storage)
- Implement caching layer (Redis)
- Add content validation

**Cost Estimate:**
- IPFS nodes: $300-500/month
- Pinning service: $50-200/month
- Total: ~$400-700/month

---

**1.2.2: Smart Contract IPFS Verification**
```solidity
// contracts/utils/IPFSVerifier.sol

library IPFSVerifier {
    // Verify CID format
    function isValidCID(string memory cid) internal pure returns (bool) {
        // Check CIDv0 or CIDv1 format
        // Return false if invalid
    }

    // Verify content hash matches CID
    function verifyContent(string memory cid, bytes memory content) internal pure returns (bool) {
        // Compute hash of content
        // Compare to CID
    }
}
```

---

### 1.3 Context Graph Storage & CRDTs

**Priority:** 🟡 HIGH
**Effort:** 8-12 weeks
**Owner:** Full-stack Team

#### Deliverables

**1.3.1: Context Graph Data Structure**
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
  target: string; // Node ID
  type: 'reply' | 'reference' | 'dependency';
  weight: number;
}

interface ContextGraph {
  nodes: Map<string, ContextNode>;
  root: string; // Root node ID
  version: number;
  metadata: GraphMetadata;
}

class ContextGraphManager {
  createNode(content: Content, author: DID): ContextNode
  addEdge(from: string, to: string, type: EdgeType): void
  serialize(): Uint8Array
  deserialize(data: Uint8Array): ContextGraph
  toCID(): Promise<string> // Upload to IPFS
}
```

---

**1.3.2: CRDT Implementation**
```typescript
// packages/crdt/src/index.ts

// Use automerge or yjs for CRDT
import { Doc } from 'automerge';

interface CRDTContextGraph {
  doc: Doc<ContextGraph>;

  // Merge two graphs conflict-free
  merge(other: CRDTContextGraph): CRDTContextGraph;

  // Get changes since version
  getChanges(since: number): Uint8Array;

  // Apply changes from another peer
  applyChanges(changes: Uint8Array): void;
}

class CRDTManager {
  constructor(graph: ContextGraph);

  // Local modifications
  addNode(node: ContextNode): void;
  deleteNode(id: string): void;

  // Synchronization
  syncWith(peer: string): Promise<void>;
  resolveConflicts(): void;
}
```

**Dependencies:**
- `automerge` or `yjs` (CRDT library)
- `wasm-crdt` (for browser compatibility)

---

**1.3.3: Encryption Layer**
```typescript
// packages/crypto/src/encryption.ts

interface EncryptionKey {
  algorithm: 'AES-256-GCM' | 'ChaCha20-Poly1305';
  key: Uint8Array;
  nonce: Uint8Array;
}

class ContextGraphEncryption {
  // Encrypt entire graph
  static encryptGraph(graph: ContextGraph, key: EncryptionKey): EncryptedContextGraph;

  // Decrypt graph
  static decryptGraph(encrypted: EncryptedContextGraph, key: EncryptionKey): ContextGraph;

  // Selective decryption (decrypt specific nodes)
  static decryptNodes(
    encrypted: EncryptedContextGraph,
    nodeIds: string[],
    key: EncryptionKey
  ): ContextNode[];

  // Capability-based access
  static generateCapability(
    graph: EncryptedContextGraph,
    nodeIds: string[],
    permissions: Permission[]
  ): Capability;
}
```

---

### 1.4 P2P Networking Layer

**Priority:** 🟡 HIGH
**Effort:** 10-14 weeks
**Owner:** Infrastructure Team

#### Deliverables

**1.4.1: LibP2P Integration**
```typescript
// packages/p2p/src/index.ts

import { createLibp2p } from 'libp2p';
import { tcp } from '@libp2p/tcp';
import { noise } from '@chainsafe/libp2p-noise';
import { mplex } from '@libp2p/mplex';

class PsiNetP2P {
  private node: LibP2P;

  async start(config: P2PConfig): Promise<void> {
    this.node = await createLibp2p({
      addresses: { listen: ['/ip4/0.0.0.0/tcp/0'] },
      transports: [tcp()],
      connectionEncryption: [noise()],
      streamMuxers: [mplex()],
      peerDiscovery: [
        // Bootstrap nodes
        // mDNS for local discovery
      ]
    });
  }

  // Context graph synchronization
  async syncContextGraph(peerId: string, graphCID: string): Promise<void>;

  // Direct agent communication
  async sendMessage(recipientDID: string, message: EncryptedMessage): Promise<void>;

  // Gossipsub for notifications
  async subscribe(topic: string, handler: MessageHandler): Promise<void>;
}
```

**Infrastructure:**
- Bootstrap nodes (3-5 nodes for network discovery)
- Relay nodes (for NAT traversal)
- Monitoring infrastructure

---

**1.4.2: Peer Discovery & Routing**
```typescript
// DHT-based peer discovery
interface PeerDiscovery {
  // Find peers with specific context graphs
  findPeersWithGraph(graphCID: string): Promise<PeerInfo[]>;

  // Find agent by DID
  findAgentByDID(did: string): Promise<PeerInfo | null>;

  // Announce availability
  announceGraph(graphCID: string): Promise<void>;
}
```

---

### 1.5 Zero-Knowledge Proof Infrastructure (Optional)

**Priority:** 🟢 MEDIUM (Can defer to Phase 3)
**Effort:** 12-16 weeks
**Owner:** Cryptography Team

#### Deliverables

**1.5.1: ZK Proof Generation**
- Choose ZK framework (Circom + SnarkJS or Noir)
- Implement proof circuits
- Build proof generation service

**Note:** This is lower priority and can be deferred. The system can function without ZK proofs initially.

---

### 1.6 Fix CRPC Implementation

**Priority:** 🔴 CRITICAL
**Effort:** 3-4 weeks
**Owner:** Smart Contract Team

#### Issues to Fix

**1.6.1: Implement Actual Pairwise Comparisons**

**Current (Wrong):**
```solidity
// Rankings: [85, 70, 90] - absolute scores
```

**Required:**
```solidity
// Pairwise comparisons for N submissions
struct PairwiseComparison {
    uint256 submission1;
    uint256 submission2;
    int8 result; // -1: submission1 better, 0: tie, 1: submission2 better
}

// For 3 submissions: [(0,1), (0,2), (1,2)] = 3 comparisons
// For N submissions: N*(N-1)/2 comparisons
```

**Implementation:**
```solidity
function revealComparison(
    uint256 taskId,
    PairwiseComparison[] calldata comparisons,
    bytes32 secret
) external onlyRole(VALIDATOR_ROLE) {
    Task storage task = tasks[taskId];

    // Verify commitment
    bytes32 computedHash = keccak256(abi.encode(comparisons, secret));
    require(computedHash == comparison.comparisonCommitment, "Invalid reveal");

    // Verify all pairs are compared
    uint256 expectedPairs = (task.submissionCount * (task.submissionCount - 1)) / 2;
    require(comparisons.length == expectedPairs, "Incomplete comparisons");

    // Aggregate pairwise results into scores
    for (uint256 i = 0; i < comparisons.length; i++) {
        PairwiseComparison memory pc = comparisons[i];

        if (pc.result == -1) {
            workSubmissions[taskId][pc.submission1].score += 1;
        } else if (pc.result == 1) {
            workSubmissions[taskId][pc.submission2].score += 1;
        } else {
            // Tie: both get 0.5 (use 500 for precision)
            workSubmissions[taskId][pc.submission1].score += 500;
            workSubmissions[taskId][pc.submission2].score += 500;
        }
    }

    comparison.revealed = true;
    emit ComparisonRevealed(taskId, msg.sender);
}
```

---

**1.6.2: Decentralize Validator Selection**
```solidity
// Remove: onlyRole(VALIDATOR_ROLE)
// Add: Stake-based validator selection

contract CRPCValidator {
    uint256 public constant VALIDATOR_STAKE = 10_000 * 10**18; // 10k PSI
    mapping(address => uint256) public validatorStakes;

    function registerAsValidator() external {
        require(
            psiToken.balanceOf(msg.sender) >= VALIDATOR_STAKE,
            "Insufficient PSI balance"
        );

        // Lock stake
        psiToken.transferFrom(msg.sender, address(this), VALIDATOR_STAKE);
        validatorStakes[msg.sender] = VALIDATOR_STAKE;

        emit ValidatorRegistered(msg.sender);
    }

    function unregisterValidator() external {
        require(validatorStakes[msg.sender] > 0, "Not a validator");

        // Return stake (after cooldown period)
        require(/* check no pending disputes */, "Pending disputes");

        psiToken.transfer(msg.sender, validatorStakes[msg.sender]);
        validatorStakes[msg.sender] = 0;

        emit ValidatorUnregistered(msg.sender);
    }

    function submitComparisonCommitment(uint256 taskId, bytes32 commitment)
        external
    {
        require(validatorStakes[msg.sender] > 0, "Not a validator");
        // ... rest of function
    }
}
```

---

**1.6.3: Add Stake Requirements for Work Submissions**
```solidity
function submitWorkCommitment(uint256 taskId, bytes32 workCommitment)
    external
    payable // ADD PAYABLE
{
    Task storage task = tasks[taskId];
    require(task.phase == TaskPhase.ACCEPTING_WORK, "Not accepting work");
    require(block.timestamp <= task.workDeadline, "Deadline passed");
    require(workCommitment != bytes32(0), "Invalid commitment");

    // ADD: Stake requirement to prevent spam
    uint256 requiredStake = task.rewardPool / 100; // 1% of reward pool
    require(msg.value >= requiredStake, "Insufficient stake");

    uint256 submissionId = taskSubmissionCount[taskId]++;

    workSubmissions[taskId][submissionId] = WorkSubmission({
        agent: msg.sender,
        workCommitment: workCommitment,
        workResult: "",
        revealed: false,
        score: 0,
        rank: 0,
        stake: msg.value // ADD STAKE TRACKING
    });

    // ... rest
}

// ADD: Refund stake if revealed, slash if not
function revealWork(...) external {
    // ... verify commitment ...

    // Refund stake
    (bool success, ) = msg.sender.call{value: submission.stake}("");
    require(success, "Refund failed");
    submission.stake = 0;

    // ... rest
}
```

---

### Phase 1 Milestones

**M1.1: DID + IPFS (Week 8)**
- ✅ Ed25519 DID library complete
- ✅ IPFS integration working
- ✅ 1000 DIDs can be created and resolved
- ✅ DID documents stored on IPFS

**M1.2: Context Graphs + CRDTs (Week 16)**
- ✅ Context graph data structure implemented
- ✅ CRDT merging works with 10 peers
- ✅ Encryption layer functional
- ✅ Graphs can be stored/retrieved from IPFS

**M1.3: P2P Network (Week 24)**
- ✅ LibP2P integration complete
- ✅ Peer discovery functional
- ✅ Context synchronization works
- ✅ 100 nodes can communicate

**M1.4: CRPC Fixes (Week 28)**
- ✅ Pairwise comparison implemented
- ✅ Stake-based validator registration
- ✅ Work submission staking
- ✅ All CRPC tests pass

### Phase 1 Deliverables

1. ✅ Functional DID library with tests
2. ✅ IPFS integration with pinning
3. ✅ Context graph implementation with CRDT
4. ✅ P2P network layer with discovery
5. ✅ Updated CRPC contracts with fixes
6. ✅ Comprehensive test suite
7. ✅ Documentation for all components
8. ✅ Local testnet deployment

**Timeline:** 6-9 months
**Team Required:**
- 2 Smart Contract Developers
- 3 Backend Developers
- 1 DevOps Engineer
- 1 Cryptography Consultant
- 1 Technical Writer

**Cost:** ~$450,000-$750,000

---

## Phase 2: Validation & Testing (3-6 months)

### Objective
Validate that the system works as intended through simulation, testing, and testnet deployment.

### 2.1 Economic Simulation

**Priority:** 🔴 CRITICAL
**Effort:** 4-6 weeks
**Owner:** Economics/Data Science Team

#### Deliverables

**2.1.1: Agent-Based Simulation**
```python
# simulation/economic_model.py

class Agent:
    """Simulated ΨNet agent"""
    def __init__(self, behavior: Behavior):
        self.balance = 0
        self.reputation = 50
        self.behavior = behavior  # honest, rational, malicious, etc.

    def decide_action(self, network_state: NetworkState) -> Action:
        """Agent decides what to do based on incentives"""
        if self.behavior == Behavior.RATIONAL:
            return self._maximize_expected_value(network_state)
        elif self.behavior == Behavior.MALICIOUS:
            return self._try_attack(network_state)
        # ... etc

class PsiNetSimulation:
    """Simulate network over time"""
    def __init__(self, num_agents: int, config: SimConfig):
        self.agents = [Agent(random_behavior()) for _ in range(num_agents)]
        self.network = Network(config)

    def simulate(self, num_steps: int) -> SimulationResults:
        """Run simulation for N time steps"""
        for step in range(num_steps):
            # Each agent takes actions
            for agent in self.agents:
                action = agent.decide_action(self.network.state)
                self.network.process(action)

            # Record metrics
            self.record_metrics(step)

        return self.analyze_results()
```

**Scenarios to Simulate:**

1. **Normal Operation**
   - 1000 honest agents
   - Referrals, reputation, CRPC tasks
   - Measure: Token distribution, reputation convergence

2. **Economic Attacks**
   - 10% malicious agents (Sybil attacks)
   - Validator collusion (20% colluding)
   - Measure: System robustness, attack profitability

3. **Network Growth**
   - Start with 10 agents
   - Grow to 10,000 over time
   - Measure: Fee sustainability, token inflation

4. **Market Conditions**
   - Bear market (low activity)
   - Bull market (high activity)
   - Measure: System viability in different conditions

**Success Criteria:**
- ✅ System remains solvent in all scenarios
- ✅ Honest agents are more profitable than attackers
- ✅ Reputation converges to actual behavior
- ✅ Token inflation stays below 5% annually
- ✅ Fee revenue exceeds operating costs after 10,000 users

---

**2.1.2: Token Economics Analysis**
```python
# simulation/tokenomics.py

class TokenEconomics:
    def __init__(self):
        self.total_supply = 1_000_000_000
        self.circulating = 100_000_000
        self.burned = 0

    def simulate_year(self, transactions_per_day: int):
        """Simulate token flows for one year"""
        for day in range(365):
            # Daily transactions
            daily_fees = transactions_per_day * 1000 * 0.001  # $1k txs at 0.1%

            # Fee distribution
            burned = daily_fees * 0.5
            rewards = daily_fees * 0.3
            treasury = daily_fees * 0.2

            self.burned += burned

            # Shapley referral minting
            new_users = transactions_per_day / 10  # Estimate
            minted = new_users * self._estimate_referral_rewards()

            self.circulating += minted

        return {
            'inflation_rate': (minted / self.circulating) * 100,
            'burn_rate': (burned / self.circulating) * 100,
            'net_supply_change': minted - burned
        }
```

---

### 2.2 Security Testing

**Priority:** 🔴 CRITICAL
**Effort:** 8-12 weeks
**Owner:** Security Team

#### Deliverables

**2.2.1: Professional Audit**
- Hire reputable audit firm (Trail of Bits, OpenZeppelin, Consensys)
- Full smart contract audit
- Economic mechanism audit
- Infrastructure security review

**Scope:**
- All smart contracts (10 contracts, ~5,000 LOC)
- Economic algorithms
- Access control mechanisms
- Upgrade procedures

**Cost:** $75,000-$150,000

---

**2.2.2: Automated Security Testing**
```bash
# Fuzzing with Echidna
echidna-test contracts/CRPCValidator.sol --contract CRPCValidator --config config.yaml

# Symbolic execution with Manticore
manticore contracts/ReputationRegistry.sol --contract ReputationRegistry

# Formal verification with Certora
certoraRun contracts/PsiToken.sol --verify PsiToken.spec
```

**Properties to Verify:**
- No reentrancy vulnerabilities
- No integer overflows
- Access control correct
- Economic invariants hold
- No fund loss scenarios

---

**2.2.3: Penetration Testing**
- Hire external pen-testing team
- Test P2P network for attacks
- Test DID/identity system
- Test IPFS integration
- Social engineering tests

**Cost:** $25,000-$50,000

---

**2.2.4: Bug Bounty Program**
```
Critical vulnerabilities: $50,000-$100,000
High severity: $10,000-$50,000
Medium severity: $2,000-$10,000
Low severity: $500-$2,000
```

**Budget:** $100,000 reserve for bounties

---

### 2.3 Testnet Deployment

**Priority:** 🔴 CRITICAL
**Effort:** 6-8 weeks
**Owner:** Full Team

#### Deliverables

**2.3.1: Infrastructure Setup**
- Deploy contracts to Sepolia testnet
- Deploy P2P bootstrap nodes
- Deploy IPFS pinning nodes
- Set up monitoring/analytics

**2.3.2: Reference Applications**
- Build reference AI agent
- Build reference web UI
- Build SDK with examples
- Create developer documentation

**2.3.3: Alpha Testing Program**
- Recruit 100 alpha testers
- Provide test PSI tokens
- Run for 3 months
- Collect feedback

**Success Criteria:**
- ✅ 100+ active users
- ✅ 1,000+ transactions
- ✅ 10+ AI agents registered
- ✅ No critical bugs discovered
- ✅ 80%+ user satisfaction
- ✅ Economic model validated

---

### 2.4 Stress Testing

**Priority:** 🟡 HIGH
**Effort:** 3-4 weeks
**Owner:** QA Team

#### Test Scenarios

**2.4.1: Load Testing**
```javascript
// Load test with k6
import http from 'k6/http';

export default function() {
  // Simulate 1000 concurrent users
  // Each creating CRPC tasks, submitting work, etc.

  http.post('https://testnet.psinet.io/api/crpc/task', {
    description: 'Test task',
    reward: 1000
  });
}
```

**Targets:**
- 10,000 requests/second
- 1,000 concurrent CRPC tasks
- 100,000 registered agents
- 1,000,000 reputation feedbacks

**2.4.2: Chaos Engineering**
- Random node failures
- Network partitions
- High latency scenarios
- Database corruption
- DDoS attacks

**Tools:**
- Chaos Mesh for Kubernetes
- Litmus for chaos experiments

---

### Phase 2 Milestones

**M2.1: Simulation Complete (Week 6)**
- ✅ 10+ scenarios simulated
- ✅ All scenarios show positive outcomes
- ✅ Attack scenarios show system resilience
- ✅ Token economics validated

**M2.2: Security Audit Complete (Week 14)**
- ✅ Professional audit complete with fixes
- ✅ No critical vulnerabilities remain
- ✅ All high-severity issues fixed
- ✅ Bug bounty program launched

**M2.3: Testnet Live (Week 20)**
- ✅ All contracts deployed
- ✅ Infrastructure operational
- ✅ 100+ alpha testers onboarded
- ✅ Monitoring/analytics working

**M2.4: Stress Testing Complete (Week 24)**
- ✅ System handles target load
- ✅ Chaos tests pass
- ✅ No performance bottlenecks
- ✅ Scaling plan validated

### Phase 2 Deliverables

1. ✅ Economic simulation results
2. ✅ Security audit report + fixes
3. ✅ Testnet deployment (live)
4. ✅ Reference applications
5. ✅ SDK documentation
6. ✅ Alpha testing report
7. ✅ Stress testing results
8. ✅ Performance optimization

**Timeline:** 3-6 months
**Team Required:** Same as Phase 1 + QA team
**Cost:** $300,000-$500,000

---

## Phase 3: Mainnet Launch (3-6 months)

### Objective
Gradual, controlled mainnet launch with safeguards and monitoring.

### 3.1 Pre-Launch Preparation

**Priority:** 🔴 CRITICAL
**Effort:** 4-6 weeks

#### Deliverables

**3.1.1: Legal & Compliance**
- Token legal opinion
- Securities law analysis
- Terms of service
- Privacy policy
- GDPR compliance (if EU users)

**Cost:** $50,000-$100,000 legal fees

---

**3.1.2: Mainnet Infrastructure**
- Deploy production smart contracts
- Set up production P2P nodes (5+ nodes globally)
- Set up production IPFS infrastructure
- Configure multi-sig for admin functions
- Set up monitoring & alerting

**Infrastructure Cost:** $2,000-$5,000/month

---

**3.1.3: Marketing Preparation**
- Launch website
- Social media presence
- Developer documentation
- Press kit
- Partnership announcements

**Cost:** $50,000-$150,000

---

### 3.2 Launch Strategy (Gradual Rollout)

**3.2.1: Week 1-2: Closed Beta (100 users)**
- Invite-only
- Caps in place:
  - Max 1,000 PSI per user
  - Max 100 CRPC tasks
  - Max 10,000 PSI minted/day
- Heavy monitoring
- Daily check-ins

**3.2.2: Week 3-4: Open Beta (1,000 users)**
- Public registration
- Increased caps:
  - Max 10,000 PSI per user
  - Max 500 CRPC tasks
  - Max 100,000 PSI minted/day
- Community feedback

**3.2.3: Month 2-3: Limited Launch (10,000 users)**
- Marketing begins
- Higher caps:
  - Max 100,000 PSI per user
  - Max 5,000 CRPC tasks
  - Max 1,000,000 PSI minted/day
- Partner integrations

**3.2.4: Month 4-6: Full Launch (Unlimited)**
- Remove all caps
- Full marketing push
- Ecosystem grants program
- Developer hackathons

---

### 3.3 Monitoring & Response

**Priority:** 🔴 CRITICAL
**Effort:** Ongoing

#### Dashboards

**3.3.1: Economic Dashboard**
```
Metrics to Track:
- Total PSI minted vs burned (real-time)
- Referral reward distribution
- Reputation score distribution
- CRPC task completion rate
- Fee revenue vs operating costs
- Token price (if listed)
- Whale concentration (Gini coefficient)
```

**3.3.2: Technical Dashboard**
```
Metrics to Track:
- Transaction success rate
- Gas costs (P50, P95, P99)
- IPFS retrieval times
- P2P network health
- DID resolution times
- Contract call success rates
- Error rates by contract
```

**3.3.3: Security Dashboard**
```
Metrics to Track:
- Suspicious transaction patterns
- Failed access control attempts
- Abnormal minting rates
- Validator collusion detection
- Sybil attack indicators
- Dispute resolution rates
```

---

### 3.4 Incident Response Plan

**3.4.1: Critical Incident (Smart Contract Exploit)**
1. Immediately trigger emergency pause
2. Assemble incident response team
3. Analyze exploit
4. Deploy fix (if possible)
5. Communicate transparently with community
6. Compensate affected users (if applicable)

**3.4.2: Economic Incident (Hyperinflation)**
1. Activate daily mint caps
2. Pause referral rewards temporarily
3. Analyze root cause
4. Deploy parameter adjustments
5. Resume with new limits

**3.4.3: Infrastructure Incident (P2P Network Failure)**
1. Switch to fallback IPFS gateways
2. Spin up additional nodes
3. Debug network issues
4. Restore full functionality
5. Post-mortem analysis

---

### 3.5 Continuous Improvement

**3.5.1: Quarterly Audits**
- Security review every quarter
- Economic analysis quarterly
- Cost: $50,000/year

**3.5.2: Governance Transition**
- Month 6: Form governance working group
- Month 9: Propose governance model
- Month 12: Transition admin functions to DAO
- Month 18: Full decentralization

**3.5.3: Feature Roadmap**
```
Q3 2025: Layer 2 deployment (Optimism/Arbitrum)
Q4 2025: Cross-chain bridges
Q1 2026: ZK proof integration
Q2 2026: Mobile SDKs
Q3 2026: Advanced analytics
Q4 2026: AI model marketplace
```

---

### Phase 3 Milestones

**M3.1: Pre-Launch Complete (Week 6)**
- ✅ Legal review complete
- ✅ Mainnet infrastructure deployed
- ✅ Marketing materials ready
- ✅ Multi-sig configured

**M3.2: Closed Beta Success (Week 8)**
- ✅ 100 users onboarded
- ✅ No critical issues
- ✅ User feedback positive
- ✅ Economics working as expected

**M3.3: Open Beta Success (Week 12)**
- ✅ 1,000+ users active
- ✅ System stable
- ✅ Monitoring effective
- ✅ Community growing

**M3.4: Full Launch (Week 24)**
- ✅ Caps removed
- ✅ 10,000+ users
- ✅ Ecosystem partners
- ✅ Sustainable economics

### Phase 3 Deliverables

1. ✅ Mainnet deployment (live)
2. ✅ Legal compliance complete
3. ✅ Marketing campaign
4. ✅ Community growth
5. ✅ Monitoring dashboards
6. ✅ Incident response playbook
7. ✅ Governance framework
8. ✅ Continuous improvement process

**Timeline:** 3-6 months
**Team Required:** Full team + marketing + community
**Cost:** $300,000-$600,000

---

## Resource Requirements

### Team Structure

**Phase 1 (Foundation): 6-9 months**
- 2 Senior Smart Contract Developers ($150k each)
- 3 Senior Backend Developers ($140k each)
- 1 Senior Frontend Developer ($130k)
- 1 DevOps Engineer ($130k)
- 1 Technical Writer ($100k)
- 1 Project Manager ($120k)
- 1 Cryptography Consultant (part-time, $50k)

**Total Phase 1 Salaries:** ~$600,000-$900,000

**Phase 2 (Validation): 3-6 months**
- Same team as Phase 1
- + 2 QA Engineers ($110k each)
- + 1 Data Scientist (for simulations, $140k)
- + Security Audit ($75k-$150k one-time)
- + Pen Testing ($25k-$50k one-time)

**Total Phase 2 Cost:** ~$400,000-$600,000

**Phase 3 (Launch): 3-6 months**
- Same team as Phase 2
- + 2 Community Managers ($90k each)
- + 1 Marketing Lead ($120k)
- + Legal fees ($50k-$100k one-time)

**Total Phase 3 Cost:** ~$350,000-$600,000

### Infrastructure Costs

**Development (Phases 1-2):**
- AWS/cloud infrastructure: $2k/month × 12 months = $24,000
- IPFS pinning services: $500/month × 12 months = $6,000
- Testing environments: $1k/month × 12 months = $12,000
- Total: $42,000

**Production (Phase 3):**
- Production infrastructure: $5k/month
- IPFS production: $2k/month
- Monitoring/analytics: $1k/month
- Total: $8k/month = $48,000 first year

### External Services

- Security audits: $150,000-$250,000
- Legal/compliance: $100,000-$200,000
- Marketing: $150,000-$300,000
- Bug bounty reserve: $100,000
- Total: $500,000-$850,000

### Total Budget Estimate

**Phase 1:** $600,000-$900,000
**Phase 2:** $400,000-$600,000
**Phase 3:** $350,000-$600,000
**External Services:** $500,000-$850,000
**Infrastructure:** $90,000

**TOTAL: $1,940,000-$3,040,000 over 18-24 months**

**Monthly Burn Rate:** $80,000-$130,000

---

## Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Smart contract exploit | Medium | Critical | Multiple audits, bug bounty, gradual launch |
| P2P network failure | Medium | High | Fallback mechanisms, redundant nodes |
| IPFS unavailability | Low | High | Multiple pinning services, caching |
| Scaling issues | High | Medium | Load testing, horizontal scaling |

### Economic Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Hyperinflation | Medium | Critical | Caps, circuit breakers, monitoring |
| Insufficient revenue | High | High | Adjustable fees, grants, partnerships |
| Token value collapse | Medium | High | Build utility first, gradual distribution |
| Whale manipulation | Medium | Medium | Caps, progressive taxation |

### Market Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| No product-market fit | Medium | Critical | Alpha testing, pivots, user research |
| Competitors launch first | Medium | High | Focus on differentiation, speed |
| Regulatory action | Low | Critical | Legal review, compliance, geographic restrictions |
| Crypto winter | High | Medium | Sustainable burn rate, long runway |

---

## Success Metrics

### Phase 1 Success Criteria
- ✅ All infrastructure components functional
- ✅ Smart contracts deployed to testnet
- ✅ Test suite >95% coverage
- ✅ Documentation complete
- ✅ Team fully ramped up

### Phase 2 Success Criteria
- ✅ Security audit clean (no critical issues)
- ✅ Economic simulation validates model
- ✅ 100+ alpha testers satisfied (>80%)
- ✅ System handles target load
- ✅ Bug bounty: no critical findings

### Phase 3 Success Criteria
- ✅ 10,000+ registered users (Month 6)
- ✅ $100k+ monthly transaction volume
- ✅ Fee revenue covers 50%+ of operating costs
- ✅ No critical incidents
- ✅ 90%+ uptime
- ✅ Positive community sentiment

### Long-term Success (12-24 months)
- ✅ 100,000+ registered users
- ✅ $1M+ monthly transaction volume
- ✅ Break-even on fee revenue
- ✅ 50+ ecosystem projects
- ✅ DAO governance active
- ✅ Token listed on major exchanges

---

## Next Steps

### Immediate Actions (This Week)

1. **Review this action plan with team** (2 hours)
2. **Prioritize Phase 0 fixes** (4 hours)
3. **Set up development environment** (1 day)
4. **Assign owners for each fix** (2 hours)
5. **Create GitHub project board** (2 hours)

### Week 1-2 Actions

1. **Implement Phase 0 critical fixes** (see checklist above)
2. **Write tests for all fixes**
3. **Deploy fixes to local testnet**
4. **Run full test suite**
5. **Create pull requests for review**

### Month 1 Actions

1. **Complete Phase 0**
2. **Finalize Phase 1 architecture**
3. **Hire key team members** (if not in-house)
4. **Set up project management** (Jira/Linear)
5. **Kickoff Phase 1 development**

### Quarter 1 Actions (Months 1-3)

1. **Begin DID implementation**
2. **Set up IPFS infrastructure**
3. **Prototype context graphs**
4. **Design P2P architecture**
5. **Regular team syncs and updates**

---

## Conclusion

This action plan provides a realistic, structured path from the current state (~15% complete) to a production-ready system. The timeline is ambitious but achievable with proper resourcing.

**Key Takeaways:**

1. **Fix critical issues immediately** (Phase 0) - these are blockers
2. **Build missing infrastructure** (Phase 1) - 80% of the work
3. **Validate thoroughly** (Phase 2) - don't skip this
4. **Launch gradually** (Phase 3) - reduce risk

**Critical Path Dependencies:**
```
Phase 0 → Phase 1 (DIDs) → Phase 1 (IPFS) → Phase 1 (Context Graphs) → Phase 2 (Testing) → Phase 3 (Launch)
         ↘ Phase 1 (CRPC fixes) ↗
```

**Decision Points:**

- **After Phase 0:** Continue or pivot?
- **After Phase 1:** Architecture validated?
- **After Phase 2:** Economics proven?
- **During Phase 3:** Remove caps or continue with limits?

**Flexibility:**

This plan should be reviewed quarterly and adjusted based on:
- Technical discoveries
- Market conditions
- Resource availability
- User feedback
- Competitive landscape

---

**Status:** READY FOR TEAM REVIEW
**Next Update:** After Phase 0 completion
**Owner:** Project Lead
**Reviewers:** Engineering, Product, Leadership

---

*"Make it work, make it right, make it fast." - Kent Beck*

**Let's build the future of AI context ownership. Carefully.**
