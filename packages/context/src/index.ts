/**
 * @module @psinet/context
 * @description Context graph data structures for ΨNet
 *
 * Represents AI agent context as a directed acyclic graph (DAG) where:
 * - Nodes represent messages, state snapshots, or references
 * - Edges represent relationships (replies, dependencies, references)
 * - Graphs are content-addressed and stored on IPFS
 * - Supports encryption, compression, and CRDT-based synchronization
 */

import { fromString, toString } from 'uint8arrays';
import { sha256 } from 'multiformats/hashes/sha2';
import * as msgpack from 'msgpack5';

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * Context node types
 */
export enum ContextNodeType {
  /** User or agent message */
  MESSAGE = 'message',

  /** State snapshot (memory, variables, etc.) */
  STATE = 'state',

  /** Reference to external resource */
  REFERENCE = 'reference',

  /** Tool/function call */
  TOOL_CALL = 'tool_call',

  /** Tool/function result */
  TOOL_RESULT = 'tool_result',

  /** Metadata/annotation */
  METADATA = 'metadata',
}

/**
 * Edge types connecting nodes
 */
export enum EdgeType {
  /** Reply relationship (message → message) */
  REPLY = 'reply',

  /** Reference relationship */
  REFERENCE = 'reference',

  /** Dependency (must be processed before) */
  DEPENDENCY = 'dependency',

  /** Parent-child relationship */
  PARENT = 'parent',

  /** Annotation/metadata link */
  ANNOTATION = 'annotation',
}

/**
 * Encrypted content wrapper
 */
export interface EncryptedContent {
  /** Encryption algorithm used */
  algorithm: 'aes-256-gcm' | 'xchacha20-poly1305';

  /** Encrypted data */
  ciphertext: Uint8Array;

  /** Nonce/IV */
  nonce: Uint8Array;

  /** Authentication tag (if applicable) */
  tag?: Uint8Array;

  /** Key identifier (for key agreement) */
  keyId?: string;
}

/**
 * Plain content (before encryption)
 */
export interface PlainContent {
  /** Content type */
  type: string;

  /** Content data */
  data: any;

  /** MIME type (if applicable) */
  mimeType?: string;

  /** Original size (bytes) */
  size: number;
}

/**
 * Edge connecting two nodes
 */
export interface Edge {
  /** Target node ID */
  target: string;

  /** Edge type */
  type: EdgeType;

  /** Edge weight (importance, priority) */
  weight: number;

  /** Edge metadata */
  metadata?: Record<string, any>;
}

/**
 * Context graph node
 */
export interface ContextNode {
  /** Unique node ID (content hash) */
  id: string;

  /** Node type */
  type: ContextNodeType;

  /** Encrypted or plain content */
  content: EncryptedContent | PlainContent;

  /** Creation timestamp */
  timestamp: number;

  /** Author DID */
  author: string;

  /** Digital signature */
  signature: Uint8Array;

  /** Outgoing edges */
  edges: Edge[];

  /** Node metadata */
  metadata?: Record<string, any>;

  /** Compression ratio (if compressed) */
  compressionRatio?: number;
}

/**
 * Graph metadata
 */
export interface GraphMetadata {
  /** Graph creation time */
  created: number;

  /** Last update time */
  updated: number;

  /** Author DID */
  author: string;

  /** Graph description */
  description?: string;

  /** Total size in bytes */
  size: number;

  /** Number of nodes */
  nodeCount: number;

  /** Number of edges */
  edgeCount: number;

  /** Compression ratio */
  compressionRatio?: number;

  /** Tags for categorization */
  tags?: string[];

  /** Custom metadata */
  custom?: Record<string, any>;
}

/**
 * Context graph structure
 */
export interface ContextGraph {
  /** Graph ID (hash of content) */
  id: string;

  /** Graph version number */
  version: number;

  /** Root node ID (entry point) */
  root: string;

  /** All nodes in the graph */
  nodes: Map<string, ContextNode>;

  /** Graph metadata */
  metadata: GraphMetadata;

  /** Graph signature (by author) */
  signature?: Uint8Array;
}

/**
 * Graph traversal options
 */
export interface TraversalOptions {
  /** Maximum depth to traverse */
  maxDepth?: number;

  /** Filter function for nodes */
  filter?: (node: ContextNode) => boolean;

  /** Sort edges before traversal */
  sortEdges?: (a: Edge, b: Edge) => number;

  /** Visit nodes in order */
  order?: 'bfs' | 'dfs';
}

/**
 * Graph statistics
 */
export interface GraphStats {
  /** Total nodes */
  nodeCount: number;

  /** Total edges */
  edgeCount: number;

  /** Nodes by type */
  nodesByType: Record<string, number>;

  /** Edges by type */
  edgesByType: Record<string, number>;

  /** Average edges per node */
  avgEdgesPerNode: number;

  /** Max depth from root */
  maxDepth: number;

  /** Total size in bytes */
  totalSize: number;

  /** Compression ratio */
  compressionRatio?: number;
}

// ============================================================================
// Context Graph Manager
// ============================================================================

/**
 * Manager for creating and manipulating context graphs
 */
export class ContextGraphManager {
  private graph: ContextGraph;
  private msgpackCodec = msgpack();

  constructor(authorDID: string, description?: string) {
    // Initialize empty graph
    this.graph = {
      id: '',
      version: 1,
      root: '',
      nodes: new Map(),
      metadata: {
        created: Date.now(),
        updated: Date.now(),
        author: authorDID,
        description,
        size: 0,
        nodeCount: 0,
        edgeCount: 0,
      },
    };
  }

  // --------------------------------------------------------------------------
  // Node Operations
  // --------------------------------------------------------------------------

  /**
   * Create a new node
   * @param content Node content
   * @param author Author DID
   * @param type Node type
   * @returns Created node
   */
  async createNode(
    content: PlainContent | EncryptedContent,
    author: string,
    type: ContextNodeType = ContextNodeType.MESSAGE
  ): Promise<ContextNode> {
    // Generate node ID from content hash
    const contentHash = await this.hashContent(content);

    const node: ContextNode = {
      id: contentHash,
      type,
      content,
      timestamp: Date.now(),
      author,
      signature: new Uint8Array(), // Would be signed with author's key
      edges: [],
      metadata: {},
    };

    // Add to graph
    this.graph.nodes.set(node.id, node);

    // Set as root if first node
    if (this.graph.nodes.size === 1) {
      this.graph.root = node.id;
    }

    // Update metadata
    this.updateMetadata();

    return node;
  }

  /**
   * Get node by ID
   */
  getNode(nodeId: string): ContextNode | undefined {
    return this.graph.nodes.get(nodeId);
  }

  /**
   * Delete node
   */
  deleteNode(nodeId: string): boolean {
    const deleted = this.graph.nodes.delete(nodeId);

    if (deleted) {
      // Remove edges pointing to this node
      for (const node of this.graph.nodes.values()) {
        node.edges = node.edges.filter((edge) => edge.target !== nodeId);
      }

      // Update root if deleted
      if (this.graph.root === nodeId) {
        this.graph.root = this.graph.nodes.keys().next().value || '';
      }

      this.updateMetadata();
    }

    return deleted;
  }

  /**
   * Get all nodes of a specific type
   */
  getNodesByType(type: ContextNodeType): ContextNode[] {
    return Array.from(this.graph.nodes.values()).filter((node) => node.type === type);
  }

  // --------------------------------------------------------------------------
  // Edge Operations
  // --------------------------------------------------------------------------

  /**
   * Add edge between nodes
   * @param fromId Source node ID
   * @param toId Target node ID
   * @param type Edge type
   * @param weight Edge weight (default: 1.0)
   */
  addEdge(fromId: string, toId: string, type: EdgeType, weight: number = 1.0): void {
    const fromNode = this.graph.nodes.get(fromId);
    const toNode = this.graph.nodes.get(toId);

    if (!fromNode || !toNode) {
      throw new Error('Both nodes must exist to create edge');
    }

    // Check for existing edge
    const existingEdge = fromNode.edges.find(
      (e) => e.target === toId && e.type === type
    );

    if (existingEdge) {
      // Update weight
      existingEdge.weight = weight;
    } else {
      // Add new edge
      fromNode.edges.push({
        target: toId,
        type,
        weight,
      });
    }

    this.updateMetadata();
  }

  /**
   * Remove edge between nodes
   */
  removeEdge(fromId: string, toId: string, type?: EdgeType): boolean {
    const fromNode = this.graph.nodes.get(fromId);
    if (!fromNode) return false;

    const originalLength = fromNode.edges.length;

    fromNode.edges = fromNode.edges.filter((edge) => {
      if (edge.target !== toId) return true;
      if (type && edge.type !== type) return true;
      return false;
    });

    const removed = fromNode.edges.length < originalLength;

    if (removed) {
      this.updateMetadata();
    }

    return removed;
  }

  /**
   * Get all edges from a node
   */
  getEdges(fromId: string, type?: EdgeType): Edge[] {
    const node = this.graph.nodes.get(fromId);
    if (!node) return [];

    if (type) {
      return node.edges.filter((e) => e.type === type);
    }

    return node.edges;
  }

  /**
   * Get incoming edges to a node
   */
  getIncomingEdges(toId: string, type?: EdgeType): Array<{ from: string; edge: Edge }> {
    const incoming: Array<{ from: string; edge: Edge }> = [];

    for (const [nodeId, node] of this.graph.nodes) {
      for (const edge of node.edges) {
        if (edge.target === toId) {
          if (!type || edge.type === type) {
            incoming.push({ from: nodeId, edge });
          }
        }
      }
    }

    return incoming;
  }

  // --------------------------------------------------------------------------
  // Graph Traversal
  // --------------------------------------------------------------------------

  /**
   * Traverse graph starting from a node
   * @param startId Starting node ID
   * @param visitor Visitor function called for each node
   * @param options Traversal options
   */
  traverse(
    startId: string,
    visitor: (node: ContextNode, depth: number) => void | boolean,
    options: TraversalOptions = {}
  ): void {
    const {
      maxDepth = Infinity,
      filter,
      sortEdges,
      order = 'bfs',
    } = options;

    const visited = new Set<string>();
    const queue: Array<{ id: string; depth: number }> = [{ id: startId, depth: 0 }];

    while (queue.length > 0) {
      const { id, depth } = order === 'bfs' ? queue.shift()! : queue.pop()!;

      if (visited.has(id) || depth > maxDepth) {
        continue;
      }

      const node = this.graph.nodes.get(id);
      if (!node) continue;

      if (filter && !filter(node)) {
        continue;
      }

      visited.add(id);

      // Visit node
      const shouldContinue = visitor(node, depth);
      if (shouldContinue === false) {
        break;
      }

      // Add children to queue
      let edges = [...node.edges];
      if (sortEdges) {
        edges.sort(sortEdges);
      }

      for (const edge of edges) {
        if (!visited.has(edge.target)) {
          queue.push({ id: edge.target, depth: depth + 1 });
        }
      }
    }
  }

  /**
   * Find shortest path between two nodes
   */
  findPath(fromId: string, toId: string): string[] | null {
    const queue: Array<{ id: string; path: string[] }> = [{ id: fromId, path: [fromId] }];
    const visited = new Set<string>();

    while (queue.length > 0) {
      const { id, path } = queue.shift()!;

      if (id === toId) {
        return path;
      }

      if (visited.has(id)) {
        continue;
      }

      visited.add(id);

      const node = this.graph.nodes.get(id);
      if (!node) continue;

      for (const edge of node.edges) {
        if (!visited.has(edge.target)) {
          queue.push({
            id: edge.target,
            path: [...path, edge.target],
          });
        }
      }
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  /**
   * Serialize graph to binary format (MessagePack)
   */
  serialize(): Uint8Array {
    const serializable = {
      id: this.graph.id,
      version: this.graph.version,
      root: this.graph.root,
      nodes: Array.from(this.graph.nodes.entries()).map(([id, node]) => ({
        ...node,
        content: this.serializeContent(node.content),
        signature: Array.from(node.signature),
      })),
      metadata: this.graph.metadata,
      signature: this.graph.signature ? Array.from(this.graph.signature) : undefined,
    };

    return this.msgpackCodec.encode(serializable);
  }

  /**
   * Deserialize graph from binary format
   */
  static deserialize(data: Uint8Array): ContextGraphManager {
    const msgpackCodec = msgpack();
    const parsed = msgpackCodec.decode(data);

    // Create new manager
    const manager = new ContextGraphManager(parsed.metadata.author);

    // Restore graph
    manager.graph = {
      id: parsed.id,
      version: parsed.version,
      root: parsed.root,
      nodes: new Map(
        parsed.nodes.map((node: any) => [
          node.id,
          {
            ...node,
            content: manager.deserializeContent(node.content),
            signature: new Uint8Array(node.signature),
          },
        ])
      ),
      metadata: parsed.metadata,
      signature: parsed.signature ? new Uint8Array(parsed.signature) : undefined,
    };

    return manager;
  }

  /**
   * Convert to IPFS-storable format
   */
  async toCID(): Promise<string> {
    // This would integrate with @psinet/ipfs
    // For now, return a placeholder
    const data = this.serialize();
    const hash = await sha256.digest(data);
    return hash.toString();
  }

  // --------------------------------------------------------------------------
  // Statistics & Analysis
  // --------------------------------------------------------------------------

  /**
   * Get graph statistics
   */
  getStats(): GraphStats {
    const nodesByType: Record<string, number> = {};
    const edgesByType: Record<string, number> = {};
    let totalEdges = 0;
    let maxDepth = 0;
    let totalSize = 0;

    for (const node of this.graph.nodes.values()) {
      // Count nodes by type
      nodesByType[node.type] = (nodesByType[node.type] || 0) + 1;

      // Count edges by type
      for (const edge of node.edges) {
        edgesByType[edge.type] = (edgesByType[edge.type] || 0) + 1;
        totalEdges++;
      }

      // Estimate size
      totalSize += JSON.stringify(node).length;
    }

    // Calculate max depth
    if (this.graph.root) {
      this.traverse(
        this.graph.root,
        (node, depth) => {
          maxDepth = Math.max(maxDepth, depth);
        },
        { order: 'dfs' }
      );
    }

    return {
      nodeCount: this.graph.nodes.size,
      edgeCount: totalEdges,
      nodesByType,
      edgesByType,
      avgEdgesPerNode: totalEdges / this.graph.nodes.size || 0,
      maxDepth,
      totalSize,
      compressionRatio: this.graph.metadata.compressionRatio,
    };
  }

  /**
   * Validate graph integrity
   */
  validate(): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Check root exists
    if (!this.graph.root || !this.graph.nodes.has(this.graph.root)) {
      errors.push('Root node does not exist');
    }

    // Check all edges point to existing nodes
    for (const [nodeId, node] of this.graph.nodes) {
      for (const edge of node.edges) {
        if (!this.graph.nodes.has(edge.target)) {
          errors.push(`Edge from ${nodeId} points to non-existent node ${edge.target}`);
        }
      }
    }

    // Check for cycles (graphs should be acyclic)
    const hasCycle = this.detectCycles();
    if (hasCycle) {
      errors.push('Graph contains cycles');
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }

  // --------------------------------------------------------------------------
  // Private Helpers
  // --------------------------------------------------------------------------

  private async hashContent(content: PlainContent | EncryptedContent): Promise<string> {
    const data = this.serializeContent(content);
    const hash = await sha256.digest(data);
    return hash.toString();
  }

  private serializeContent(content: PlainContent | EncryptedContent): Uint8Array {
    if ('ciphertext' in content) {
      // Encrypted content
      return this.msgpackCodec.encode({
        ...content,
        ciphertext: Array.from(content.ciphertext),
        nonce: Array.from(content.nonce),
        tag: content.tag ? Array.from(content.tag) : undefined,
      });
    } else {
      // Plain content
      return this.msgpackCodec.encode(content);
    }
  }

  private deserializeContent(data: any): PlainContent | EncryptedContent {
    if (data.ciphertext) {
      return {
        ...data,
        ciphertext: new Uint8Array(data.ciphertext),
        nonce: new Uint8Array(data.nonce),
        tag: data.tag ? new Uint8Array(data.tag) : undefined,
      };
    } else {
      return data;
    }
  }

  private updateMetadata(): void {
    let edgeCount = 0;
    for (const node of this.graph.nodes.values()) {
      edgeCount += node.edges.length;
    }

    this.graph.metadata.updated = Date.now();
    this.graph.metadata.nodeCount = this.graph.nodes.size;
    this.graph.metadata.edgeCount = edgeCount;
    this.graph.metadata.size = this.serialize().length;
  }

  private detectCycles(): boolean {
    const visited = new Set<string>();
    const recursionStack = new Set<string>();

    const hasCycleDFS = (nodeId: string): boolean => {
      visited.add(nodeId);
      recursionStack.add(nodeId);

      const node = this.graph.nodes.get(nodeId);
      if (!node) return false;

      for (const edge of node.edges) {
        if (!visited.has(edge.target)) {
          if (hasCycleDFS(edge.target)) {
            return true;
          }
        } else if (recursionStack.has(edge.target)) {
          return true;
        }
      }

      recursionStack.delete(nodeId);
      return false;
    };

    for (const nodeId of this.graph.nodes.keys()) {
      if (!visited.has(nodeId)) {
        if (hasCycleDFS(nodeId)) {
          return true;
        }
      }
    }

    return false;
  }

  /**
   * Get raw graph object
   */
  getGraph(): ContextGraph {
    return this.graph;
  }

  /**
   * Set root node
   */
  setRoot(nodeId: string): void {
    if (!this.graph.nodes.has(nodeId)) {
      throw new Error('Node does not exist');
    }
    this.graph.root = nodeId;
  }
}

// ============================================================================
// Exports
// ============================================================================

export default ContextGraphManager;
