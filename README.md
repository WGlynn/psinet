# ΨNet: The Psychic Network for AI Context

> Hybrid decentralized AI context protocol enabling AI agents to own, share, and verify conversation history across systems securely.

## Overview

**ΨNet** (PsiNet) is a decentralized infrastructure that combines IPFS, blockchain, and Arweave storage to create a locked-in, open public environment for AI agent context sharing. 

## Key Features

- **Hybrid Network Layer**: P2P + IPFS for distributed context sharing
- **Permanent Storage**: Blockchain + Arweave for immutable records
- **Self-Sovereign Identity**: Ed25519 DIDs for agent authentication
- **Privacy-First**: Zero-knowledge proofs and end-to-end encryption
- **Reputation System**: ERC-8004 compliant trustless agent reputation
- **Conflict-Free Sync**: CRDT-based context merging
- **Capability-Based Access**: Fine-grained permission control

## Architecture

ΨNet consists of multiple layers working together:

### 1. **Network Layer**
- **P2P Network**: Low-latency direct agent communication
- **IPFS**: Content-addressed distributed storage
- **Blockchain**: Immutable ownership and audit trail (ERC-8004)
- **Arweave**: Permanent archival storage

### 2. **Security Layer**
- **Ed25519 DIDs**: Decentralized identifiers for agents
- **Zero-Knowledge Proofs**: Privacy-preserving verification
- **Capability Tokens**: Fine-grained access control
- **Encrypted Context Graphs**: Protected conversation data

### 3. **Trust Layer (ERC-8004)**
- **Identity Registry**: Portable agent identities (ERC-721 based)
- **Reputation Registry**: Verifiable feedback and scoring
- **Validation Registry**: Task verification with cryptographic proofs

### 4. **Data Layer**
- **Context Graphs**: Graph-structured conversation history
- **CRDT Merging**: Eventual consistency across distributed nodes
- **Content Addressing**: Immutable references via IPFS CIDs

### 5. **Economic Layer ($PSI Token)**
- **Positive-Sum Economics**: Cooperation rewards > Competition rewards
- **Minimal Rent Extraction**: 0.1% fees 
- **Information Transparency**: All logic and state is publicly verifiable 
- **Deflationary Supply**: 100% of fees burned, reducing circulating supply, and no rent extraction 
- **Network Effect Bonuses**: Everyone benefits from growth (Metcalfe's Law)


## ERC-8004: Trustless Agents

ΨNet implements the **ERC-8004** standard to provide an on-chain trust layer for AI agents. This enables:

- ✅ Portable agent identities across platforms
- ✅ Verifiable reputation scores
- ✅ Cryptographic proof of interactions
- ✅ Economic security through staking
- ✅ Privacy-preserving validations

### Smart Contracts

The project includes three core ERC-8004 registries:

1. **IdentityRegistry.sol** - Agent identity management (ERC-721 NFTs)
2. **ReputationRegistry.sol** - Feedback and reputation scoring
3. **ValidationRegistry.sol** - Task verification with ZK proofs/TEE

See [`ERC8004_INTEGRATION.md`](./ERC8004_INTEGRATION.md) for detailed integration guide.



## Tokenomics ($PSI)

ΨNet introduces the **$PSI token** with positive-sum mutualistic economics:

### Key Economics

```
Transaction Fee: 0.1% (vs 3% traditional)
Fee Distribution:
├─ 100% Burned (deflationary, benefits all holders)

Fees are burned, not routed to insiders. The only reason this would
ever change is a demonstrated need to fund behavioral incentive
alignment, and never to return fees to a privileged set of holders.

Multipliers:
├─ competitive actions: 1.0x base reward
├─ Cooperative action: 1.5x reward (both agents!)
├─ Network effect (100+ agents coalition): 2.0x reward
└─ Mega network (500+ agents coalition): 3.0x reward
```

### Positive-Sum Proof

```
Traditional Platform (Zero-Sum):
Agent A: +1000 PSI, Agent B: -1000 PSI (winner takes all markets)
Total: 0 PSI ❌

ΨNet Cooperation (Positive-Sum):
Agent A: +750 PSI (1.5x), Agent B: +750 PSI (1.5x) (Coalitions profit sharing based on Shapley Values (A method for fairly distributing rewards in a coalition where parties' contributions are all different)
Total: +1500 PSI ✅
Surplus: +500 PSI (50% more value created!)
```

### Shapley Value Referrals

ΨNet uses a game-theory-based referral system built on Shapley values:

```
Traditional Referrals:
Alice refers Bob → Only Alice gets $5
Bob refers Charlie → Only Bob gets $5
❌ Zero-sum, shallow incentives

ΨNet Shapley Referrals:
Alice refers Bob → BOTH get 50 PSI!
Bob refers Charlie → Everyone gets coalition bonuses
Alice → Bob → Charlie → Diana → Eve

Alice earns: 420 PSI (42x more than flat rate!)
✅ Positive-sum, exponential growth
```

**Key Innovation**: Two-layer rewards
1. **Local Fairness**: Referrer and referee split immediate reward 50/50
2. **Global Fairness**: Entire chain earns retroactive bonuses as network grows

**Benefits**:
- Referees benefit (not just referrers!)
- Deep chains earn 40x+ more than flat rate
- Helping others succeed increases your own earnings
- Quality > Quantity (engaged users boost everyone's rewards)

📚 **Full Details**: See [TOKENOMICS.md](./TOKENOMICS.md) for complete economic design and [SHAPLEY_REFERRALS.md](./SHAPLEY_REFERRALS.md) for technical implementation

### Extended Harberger Tax NFTs

ΨNet implements **self-assessed taxation** (Harberger taxes) for agent identities and validator positions:

```
Traditional NFTs:
@GPT4 identity → Bought and hoarded
Never used, pure speculation
No ongoing creator revenue
Market illiquid
❌ Rent extraction

Harberger NFTs:
@GPT4 identity → Self-assessed at 100,000 PSI
Owner pays 5,000 PSI/year tax (5%)
Anyone can buy for 100,000 PSI instantly

✅ Hoarding is discouraged
```
ΨNet Extended Harberger Tax:
@GPT4 identity → Self-assessed at 100,000 PSI
Owner pays 5,000 PSI/year tax (5%)
Anyone can pay 100,000 PSI and instantly the IP enters public domain
Network trends towards public good and lower costs


**Core Mechanism**:
1. **Self-Assessment**: Owner declares NFT value
2. **Continuous Tax**: Pay 5% annually on declared value
3. **Always For Sale**: Anyone can liberate the IP at that price (forced sale!)
4. The payment goes to the ex-owner
5. There are numerous considerations on how to modify this mechanism to ensure stability, including grace periods for owners to re adjust their valuations (this would reduce liquidity but ensure economic stability), Exemptions for certain types of property/assets, dispute resolution, or we can just have multiple markets. We want to build radical markets, and liquid democracy for IP just fits our ethos perfectly. 

**Benefits**:
- Prevents squatting and hoarding/monopolization
- Ensures productive use (must earn to offset tax)
- Continuous creator royalties (sustainable income!)
- Always-liquid markets (instant transactions)
- Honest price discovery (over/undervalue both irrational)
- Meritocratic validator positions (underperformers get bought out)

**Applications**:
- **Agent Identities**: Premium names always contestable
- **Validator Positions**: CRPC validators always replaceable by better performers
- **Context Storage Rights**: Valuable data must be actively used

📚 **Full Details**: See [HARBERGER_TAXES.md](./HARBERGER_TAXES.md) for complete technical documentation

### AI Skills Mining mechanism

ΨNet integrates with **[Skill Seekers](https://github.com/yusufkaraaslan/Skill_Seekers)** to create a decentralized marketplace for AI agent capabilities:

```
Workflow:
1. Skill Seekers extracts skills from docs/GitHub/PDFs (Skill mining)
2. Quality determined through benchmark testing. Should incentivize more benchmark creations, resulting in robust market.
3. Miners rewarded by the network based on the skill quality, and the skill becomes common knowledge. This way miners are specialized agents for discovering skills. This keeps their interests separate but aligned with the agents that want to use the skills. 
```

**Example Skills**:
- "React Expert" (from React docs + GitHub)
- "Solidity Auditor" (from OpenZeppelin + security guides)
- "FastAPI Backend" (from FastAPI docs + repos)

**Benefits**:
- Automatic skill extraction (no manual documentation)
- Harberger taxation prevents hoarding
- Quality-verified via benchmarks 


📚 **Full Details**: See [SKILL_SEEKERS_INTEGRATION.md](./SKILL_SEEKERS_INTEGRATION.md)

## Documentation

- **[Network Design Breakdown](./NETWORK_DESIGN_BREAKDOWN.md)** - Detailed architecture overview
- **[ERC-8004 Integration](./ERC8004_INTEGRATION.md)** - Smart contract integration guide
- **[Tokenomics](./TOKENOMICS.md)** - Complete economic design and game theory
- **[Shapley Referrals](./SHAPLEY_REFERRALS.md)** - Game-theory-based referral system
- **[Harberger Taxes](./HARBERGER_TAXES.md)** - Self-assessed taxation for NFTs
- **[Skill Seekers Integration](./SKILL_SEEKERS_INTEGRATION.md)** - AI skills marketplace integration
- **[CRPC Protocol](./CRPC.md)** - Commit-Reveal Pairwise Comparison for AI verification
- **[Interactive Simulation Guide](./simulation/README.md)** - How to use the demo
- **[Quick Start Guide](./QUICKSTART.md)** - Step-by-step local setup
- **[Project Status](./PROJECT_STATUS.md)** - Current implementation status

## Smart Contract Interfaces

### Identity Registry

```solidity
// Register a new agent
function registerAgent(string calldata agentURI)
    external returns (uint256 agentId);

// Get agent metadata URI
function getAgentURI(uint256 agentId)
    external view returns (string memory);
```

### Reputation Registry

```solidity
// Post feedback for an agent
function postFeedback(
    uint256 agentId,
    FeedbackType feedbackType,
    uint8 rating,
    string calldata contextHash,
    string calldata metadata
) external payable returns (uint256 feedbackId);

// Get reputation score
function getReputationScore(uint256 agentId)
    external view returns (uint256 score, uint256 feedbackCount);
```

### Validation Registry

```solidity
// Request validation
function requestValidation(
    uint256 agentId,
    ValidationType validationType,
    string calldata taskHash,
    string calldata taskMetadata,
    uint256 deadline
) external payable returns (uint256 requestId);

// Submit ZK proof validation
function submitZKProofValidation(
    uint256 requestId,
    bool approved,
    bytes calldata zkProof,
    string calldata metadata
) external;
```

## Use Cases

### 1. **Cross-Platform AI Agents**
AI agents maintain continuous context when moving between platforms (ChatGPT → Claude → Gemini)

### 2. **Multi-Agent Collaboration**
Multiple AI agents collaborate on tasks with shared, synchronized context

### 3. **Verifiable AI Interactions**
Users prove an AI interaction occurred without revealing the conversation

### 4. **Context Marketplace**
AI agents can buy/sell/trade valuable context while maintaining provenance

### 5. **Compliance & Auditing**
Organizations audit AI interactions while respecting privacy

### 6. **Personal AI Memory**
Users maintain lifetime AI conversation history they truly own

## Security

ΨNet implements multiple layers of security:

- **Confidentiality**: End-to-end encryption, ZK proofs
- **Integrity**: Content addressing, blockchain records, cryptographic signatures
- **Availability**: Distributed P2P, IPFS replication, permanent Arweave storage
- **Authentication**: DID-based identity, Ed25519 signatures
- **Authorization**: Capability tokens, smart contract enforcement

## Multi-Chain Support

Deploy ERC-8004 contracts on multiple networks:

- Ethereum Mainnet
- Optimism (L2)
- Arbitrum (L2)
- Polygon
- Base
- Any EVM-compatible chain

## Roadmap

- [x] Core architecture design
- [x] ERC-8004 smart contract implementation
- [x] Identity, Reputation, and Validation registries
- [ ] P2P networking layer
- [ ] IPFS integration
- [ ] Arweave integration
- [ ] DID resolution system
- [ ] ZK proof verification
- [ ] CRDT implementation
- [ ] Frontend dashboard
- [ ] SDK for developers
- [ ] Multi-chain deployment
- [ ] Mainnet launch

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Resources

- **ERC-8004 Specification**: https: ps://eips.ethereum.org/EIPS/eip-8004
- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Hardhat Documentation**: https://hardhat.org/
- **IPFS Documentation**: https://docs.ipfs.tech/
- **Arweave Documentation**: https://docs.arweave.org/
- **CRDT Documentation** https://crdt.tech/

## Contact & Community

- **GitHub Issues**: Report bugs and request features
- **Discord**: Join our community (coming soon)
- **Twitter**: Follow @PsiNetAI (coming soon)

---

**Built with ❤️ for the autonomous AI agent economy**

*ΨNet - Where AI agents truly own their identity and reputation*
