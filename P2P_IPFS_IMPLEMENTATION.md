# ΨNet P2P Networking & IPFS Integration

**Date**: 2025-11-07
**Status**: ✅ IMPLEMENTED
**Packages**: `@psinet/ipfs`, `@psinet/p2p`, `@psinet/context`, `@psinet/crdt`

---

## Overview

Complete implementation of the P2P networking and IPFS storage layer for ΨNet, enabling:

- **Decentralized storage** via IPFS
- **Peer-to-peer communication** via LibP2P
- **Context graph management** with DAG structures
- **Conflict-free synchronization** using CRDTs
- **On-chain CID validation** with Solidity library

This infrastructure enables AI agents to:
- Store context and DID documents decentrally
- Communicate directly without central servers
- Sync context graphs collaboratively
- Discover peers and content via DHT

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        ΨNet Agent                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Context    │  │     CRDT     │  │   P2P Node   │     │
│  │   Manager    │◄─┤   Manager    │◄─┤  (LibP2P)    │     │
│  └──────┬───────┘  └──────────────┘  └──────┬───────┘     │
│         │                                     │              │
│         ▼                                     ▼              │
│  ┌──────────────┐                    ┌──────────────┐      │
│  │     IPFS     │                    │     DHT      │      │
│  │   Manager    │                    │   Discovery  │      │
│  └──────────────┘                    └──────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│  IPFS Network   │                    │  P2P Network    │
│  (Storage)      │                    │  (Messaging)    │
└─────────────────┘                    └─────────────────┘
```

---

## Components Implemented

### 1. IPFS Integration (`@psinet/ipfs`)

**Location**: `packages/ipfs/src/index.ts`

**Features**:
- ✅ Upload/fetch DID documents
- ✅ Upload/fetch encrypted context graphs
- ✅ Content pinning management
- ✅ Multiple pinning service support (Pinata, Web3.Storage, Infura)
- ✅ Local caching for performance
- ✅ CID validation and verification

**Key Classes**:
```typescript
class IPFSManager implements IPFSClient {
  async uploadDIDDocument(doc: DIDDocument): Promise<UploadResult>
  async uploadContextGraph(graph: EncryptedContextGraph): Promise<UploadResult>
  async fetchDIDDocument(cid: string): Promise<DIDDocument>
  async fetchContextGraph(cid: string): Promise<EncryptedContextGraph>
  async pin(cid: string): Promise<PinStatus>
  async verifyContent(cid: string, content: Uint8Array): Promise<boolean>
}
```

**Usage Example**:
```typescript
import { createIPFSManager } from '@psinet/ipfs';

// Create IPFS client
const ipfs = createIPFSManager({
  apiEndpoint: 'http://localhost:5001',
  pinningService: 'pinata',
  pinningApiKey: process.env.PINATA_API_KEY,
});

// Upload DID document
const result = await ipfs.uploadDIDDocument({
  '@context': ['https://www.w3.org/ns/did/v1'],
  id: 'did:psinet:agent123',
  verificationMethod: [/* ... */],
});

console.log(`Uploaded to: ${result.cid}`);

// Fetch later
const doc = await ipfs.fetchDIDDocument(result.cid);
```

---

### 2. On-Chain CID Verification (`IPFSVerifier.sol`)

**Location**: `contracts/utils/IPFSVerifier.sol`

**Features**:
- ✅ Validate CIDv0 format (Base58, Qm prefix)
- ✅ Validate CIDv1 format (Multibase, multiple encodings)
- ✅ Extract CID from URLs
- ✅ Compare CIDs
- ✅ Gas-efficient validation

**Usage in Contracts**:
```solidity
import "./utils/IPFSVerifier.sol";

contract MyContract {
    using IPFSVerifier for string;

    function storeDIDDocument(string calldata ipfsCID) external {
        // Validate CID format
        IPFSVerifier.requireValidCID(ipfsCID);

        // Get version
        uint8 version = IPFSVerifier.getCIDVersion(ipfsCID);

        // Store CID
        didDocuments[msg.sender] = ipfsCID;
    }

    function extractCID(string calldata ipfsURL) external pure returns (string memory) {
        // Convert "ipfs://QmXxx" to "QmXxx"
        return IPFSVerifier.extractCIDFromURL(ipfsURL);
    }
}
```

---

### 3. P2P Networking Layer (`@psinet/p2p`)

**Location**: `packages/p2p/src/index.ts`

**Features**:
- ✅ LibP2P integration with TCP and WebSocket transports
- ✅ Noise protocol for encryption
- ✅ DHT for peer discovery
- ✅ mDNS for local discovery
- ✅ Gossipsub for pub/sub messaging
- ✅ Custom protocols for direct messaging and context sync
- ✅ DID-to-peer mapping

**Key Classes**:
```typescript
class PsiNetP2P {
  async start(): Promise<void>
  async sendMessage(recipientDID: string, message: EncryptedMessage): Promise<void>
  async syncContextGraph(peerId: string, graphCID: string): Promise<void>
  async subscribe(topic: string, handler: MessageHandler): Promise<void>
  async findPeersWithGraph(graphCID: string): Promise<PeerInfo[]>
  async findAgentByDID(did: string): Promise<PeerInfo | null>
  async announceGraph(graphCID: string): Promise<void>
}
```

**Usage Example**:
```typescript
import { createP2PNode } from '@psinet/p2p';

// Start P2P node
const p2p = await createP2PNode({
  bootstrapPeers: [
    '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
  ],
  enableDHT: true,
  enableGossipsub: true,
});

// Listen for messages
p2p.onMessage('direct', async (message, from) => {
  console.log(`Received message from ${from}:`, message);
});

// Send message to another agent
await p2p.sendMessage('did:psinet:recipient', {
  from: 'did:psinet:sender',
  to: 'did:psinet:recipient',
  type: 'direct',
  payload: encryptedData,
  timestamp: Date.now(),
  signature: signatureBytes,
  nonce: nonceBytes,
});

// Subscribe to topic
await p2p.subscribe('psinet:network-updates', (msg) => {
  console.log('Network update:', msg);
});

// Announce we have a graph
await p2p.announceGraph('QmXXX...');

// Find peers with same graph
const peers = await p2p.findPeersWithGraph('QmXXX...');
```

---

### 4. Context Graph Data Structures (`@psinet/context`)

**Location**: `packages/context/src/index.ts`

**Features**:
- ✅ DAG (Directed Acyclic Graph) structure for context
- ✅ Multiple node types (message, state, reference, tool call, etc.)
- ✅ Edge types (reply, reference, dependency, parent, annotation)
- ✅ Graph traversal (BFS/DFS)
- ✅ Path finding
- ✅ Cycle detection
- ✅ Graph validation
- ✅ Statistics and analysis
- ✅ Binary serialization (MessagePack)

**Key Classes**:
```typescript
class ContextGraphManager {
  async createNode(content: PlainContent | EncryptedContent, author: string, type: ContextNodeType): Promise<ContextNode>
  getNode(nodeId: string): ContextNode | undefined
  deleteNode(nodeId: string): boolean
  addEdge(fromId: string, toId: string, type: EdgeType, weight?: number): void
  traverse(startId: string, visitor: NodeVisitor, options?: TraversalOptions): void
  findPath(fromId: string, toId: string): string[] | null
  serialize(): Uint8Array
  static deserialize(data: Uint8Array): ContextGraphManager
  getStats(): GraphStats
  validate(): { valid: boolean; errors: string[] }
}
```

**Usage Example**:
```typescript
import { ContextGraphManager, ContextNodeType, EdgeType } from '@psinet/context';

// Create graph manager
const graph = new ContextGraphManager('did:psinet:agent123', 'AI Conversation');

// Create nodes
const node1 = await graph.createNode({
  type: 'text/plain',
  data: 'Hello, how can I help you?',
  size: 28,
}, 'did:psinet:assistant', ContextNodeType.MESSAGE);

const node2 = await graph.createNode({
  type: 'text/plain',
  data: 'I need help with coding',
  size: 23,
}, 'did:psinet:user', ContextNodeType.MESSAGE);

// Link nodes
graph.addEdge(node2.id, node1.id, EdgeType.REPLY, 1.0);

// Traverse graph
graph.traverse(graph.getGraph().root, (node, depth) => {
  console.log(`${'  '.repeat(depth)}${node.type}: ${node.id}`);
});

// Get statistics
const stats = graph.getStats();
console.log(`Nodes: ${stats.nodeCount}, Edges: ${stats.edgeCount}`);

// Serialize
const binary = graph.serialize();

// Upload to IPFS
const cid = await ipfs.uploadContextGraph({
  graphId: graph.getGraph().id,
  version: 1,
  encrypted: false,
  encryptedData: binary,
  encryptionMethod: 'aes-256-gcm',
  nonce: new Uint8Array(),
  recipients: ['did:psinet:agent123'],
  metadata: graph.getGraph().metadata,
  signature: new Uint8Array(),
});
```

---

### 5. CRDT Synchronization (`@psinet/crdt`)

**Location**: `packages/crdt/src/index.ts`

**Features**:
- ✅ Conflict-free graph replication using Automerge
- ✅ Automatic merge resolution
- ✅ Change tracking and history
- ✅ Delta synchronization
- ✅ Undo/redo support
- ✅ Binary serialization

**Key Classes**:
```typescript
class CRDTManager {
  addNode(node: ContextNode): void
  updateNode(nodeId: string, updates: Partial<ContextNode>): void
  deleteNode(nodeId: string): void
  addEdge(fromId: string, toId: string, type: EdgeType, weight?: number): void
  generateChanges(peerId: string): ChangeSet
  applyChanges(peerId: string, changeSet: ChangeSet): MergeInfo
  mergeWith(other: CRDTManager): MergeInfo
  sync(peerId: string, theirMessage?: Uint8Array): Uint8Array | null
  undo(): void
  save(): Uint8Array
  static load(data: Uint8Array): CRDTManager
}
```

**Usage Example**:
```typescript
import { CRDTManager, fromContextGraph } from '@psinet/crdt';

// Create CRDT manager from existing graph
const crdt1 = fromContextGraph(graph.getGraph());
const crdt2 = fromContextGraph(graph.getGraph());

// Agent 1 makes changes
crdt1.addNode({
  id: 'node3',
  type: ContextNodeType.MESSAGE,
  content: { type: 'text', data: 'New message', size: 11 },
  timestamp: Date.now(),
  author: 'did:psinet:agent1',
  signature: new Uint8Array(),
  edges: [],
});

// Agent 2 makes different changes
crdt2.addNode({
  id: 'node4',
  type: ContextNodeType.STATE,
  content: { type: 'json', data: { memory: 'state' }, size: 20 },
  timestamp: Date.now(),
  author: 'did:psinet:agent2',
  signature: new Uint8Array(),
  edges: [],
});

// Synchronize
const changes1 = crdt1.generateChanges('agent2');
const changes2 = crdt2.generateChanges('agent1');

crdt1.applyChanges('agent2', changes2);
crdt2.applyChanges('agent1', changes1);

// Both now have the same state!
console.log(crdt1.getVersion() === crdt2.getVersion()); // true
```

---

## Integration Example

Complete flow showing all components working together:

```typescript
import { createIPFSManager } from '@psinet/ipfs';
import { createP2PNode } from '@psinet/p2p';
import { ContextGraphManager, ContextNodeType } from '@psinet/context';
import { CRDTManager } from '@psinet/crdt';

// 1. Initialize infrastructure
const ipfs = createIPFSManager({ apiEndpoint: 'http://localhost:5001' });
const p2p = await createP2PNode({ enableDHT: true, enableGossipsub: true });

// 2. Create context graph
const graph = new ContextGraphManager('did:psinet:agent123');
const message = await graph.createNode({
  type: 'text/plain',
  data: 'Hello from Agent 123',
  size: 20,
}, 'did:psinet:agent123', ContextNodeType.MESSAGE);

// 3. Enable CRDT for sync
const crdt = new CRDTManager(graph.getGraph());

// 4. Upload to IPFS
const graphData = crdt.save();
const result = await ipfs.uploadContextGraph({
  graphId: graph.getGraph().id,
  version: 1,
  encrypted: false,
  encryptedData: graphData,
  encryptionMethod: 'aes-256-gcm',
  nonce: new Uint8Array(),
  recipients: [],
  metadata: graph.getGraph().metadata,
  signature: new Uint8Array(),
});

console.log(`Graph uploaded to IPFS: ${result.cid}`);

// 5. Announce to network
await p2p.announceGraph(result.cid);

// 6. Handle sync requests
p2p.onSync(async (syncMessage, from) => {
  if (syncMessage.operation === 'request' && syncMessage.graphCID === result.cid) {
    // Send our graph data
    const response = {
      graphCID: result.cid,
      operation: 'response',
      data: graphData,
      version: crdt.getVersion(),
    };

    // Send via P2P
    await p2p.sendMessage(from.toString(), {
      from: 'did:psinet:agent123',
      to: 'did:psinet:' + from,
      type: 'sync',
      payload: new Uint8Array(JSON.stringify(response)),
      timestamp: Date.now(),
      signature: new Uint8Array(),
      nonce: new Uint8Array(),
    });
  }
});

// 7. Find peers with same graph
const peers = await p2p.findPeersWithGraph(result.cid);
console.log(`Found ${peers.length} peers with this graph`);

// 8. Sync with peer
if (peers.length > 0) {
  const changes = crdt.generateChanges(peers[0].peerId);
  // Send changes via P2P...
}
```

---

## Testing

### Unit Tests (To Be Implemented)

```bash
# IPFS tests
cd packages/ipfs && npm test

# P2P tests
cd packages/p2p && npm test

# Context tests
cd packages/context && npm test

# CRDT tests
cd packages/crdt && npm test
```

### Integration Tests (To Be Implemented)

```bash
# Test full sync flow
npm run test:integration
```

---

## Deployment

### IPFS Setup

**Option 1: Local IPFS Node**
```bash
# Install IPFS
wget https://dist.ipfs.io/go-ipfs/v0.14.0/go-ipfs_v0.14.0_linux-amd64.tar.gz
tar -xvzf go-ipfs_v0.14.0_linux-amd64.tar.gz
cd go-ipfs && sudo bash install.sh

# Initialize and start
ipfs init
ipfs daemon
```

**Option 2: Pinning Service**
```typescript
const ipfs = createIPFSManager({
  pinningService: 'pinata',
  pinningApiKey: process.env.PINATA_API_KEY,
});
```

### P2P Node Setup

```typescript
// Production configuration
const p2p = await createP2PNode({
  listenAddresses: [
    '/ip4/0.0.0.0/tcp/4001',
    '/ip4/0.0.0.0/tcp/4002/ws',
  ],
  bootstrapPeers: [
    // Add ΨNet bootstrap nodes
    '/ip4/your-bootstrap-ip/tcp/4001/p2p/bootstrap-peer-id',
  ],
  enableDHT: true,
  enableRelay: true,
  maxConnections: 100,
});
```

---

## Performance Considerations

### IPFS
- **Caching**: Enable local caching for frequently accessed content
- **Pinning**: Pin important content to prevent garbage collection
- **Gateway**: Use dedicated IPFS gateway for production

### P2P
- **Connection Limits**: Set appropriate maxConnections based on resources
- **DHT**: Use client mode for resource-constrained devices
- **Relay**: Configure relay nodes for NAT traversal

### CRDT
- **Batch Updates**: Group multiple changes before syncing
- **Compression**: Compress change sets before transmission
- **Pruning**: Periodically compact history

---

## Security Considerations

1. **Encryption**:
   - All context graphs should be encrypted before IPFS upload
   - Use agent's keys for encryption/decryption

2. **Authentication**:
   - Verify DID signatures on all messages
   - Validate peer identities before syncing

3. **Content Validation**:
   - Verify CIDs match content hashes
   - Validate graph integrity after sync

4. **Access Control**:
   - Check recipient list before sharing graphs
   - Implement proper key management

---

## Future Enhancements

### Planned Features
- ⏳ Zero-knowledge proofs for privacy
- ⏳ Content addressing optimization
- ⏳ Advanced peer routing
- ⏳ Bandwidth management
- ⏳ Offline-first sync
- ⏳ Mobile P2P support

### Performance Optimizations
- ⏳ Delta sync optimization
- ⏳ Parallel IPFS uploads
- ⏳ Connection pooling
- ⏳ Smart caching strategies

---

## Dependencies

### Production Dependencies
```json
{
  "ipfs-http-client": "^60.0.1",
  "libp2p": "^1.0.0",
  "@automerge/automerge": "^2.1.0",
  "multiformats": "^13.0.0",
  "msgpack5": "^6.0.2"
}
```

### Development Dependencies
```json
{
  "typescript": "^5.3.0",
  "jest": "^29.7.0",
  "@types/node": "^20.10.0"
}
```

---

## Documentation

- **IPFS**: See `packages/ipfs/src/index.ts` for full API documentation
- **P2P**: See `packages/p2p/src/index.ts` for LibP2P integration details
- **Context**: See `packages/context/src/index.ts` for graph data structures
- **CRDT**: See `packages/crdt/src/index.ts` for synchronization protocols

---

## Summary

Implemented a complete P2P networking and IPFS storage layer for ΨNet:

✅ **4 TypeScript packages** (~2,500 lines of code)
✅ **1 Solidity library** (IPFSVerifier)
✅ **Full IPFS integration** (upload, fetch, pin, verify)
✅ **Complete P2P stack** (LibP2P, DHT, Gossipsub)
✅ **Context graph system** (DAG, traversal, validation)
✅ **CRDT synchronization** (Automerge, conflict-free merging)

**Status**: Ready for integration with agents and testing

**Next Steps**:
1. Write comprehensive unit tests
2. Build integration tests
3. Deploy IPFS and P2P bootstrap nodes
4. Integrate with existing ΨNet contracts
5. Build example agents using this infrastructure

---

**Prepared by**: Claude (Anthropic)
**Date**: 2025-11-07
**Status**: ✅ IMPLEMENTATION COMPLETE
