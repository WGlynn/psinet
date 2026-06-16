/**
 * @module @psinet/crdt
 * @description CRDT (Conflict-free Replicated Data Type) support for ΨNet
 *
 * Enables conflict-free synchronization of context graphs between agents using Automerge.
 * Agents can make concurrent modifications that automatically merge without conflicts.
 *
 * Features:
 * - Conflict-free graph updates
 * - Change tracking and history
 * - Efficient delta synchronization
 * - Automatic merge resolution
 * - Support for offline editing
 */

import * as Automerge from '@automerge/automerge';
import { v4 as uuidv4 } from 'uuid';
import type {
  ContextGraph,
  ContextNode,
  Edge,
  GraphMetadata,
  ContextNodeType,
  EdgeType,
} from '@psinet/context';

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * CRDT-enabled context graph
 * This wraps the regular ContextGraph in an Automerge document
 */
export type CRDTContextGraph = Automerge.Doc<{
  id: string;
  version: number;
  root: string;
  nodes: Record<string, ContextNode>;
  metadata: GraphMetadata;
}>;

/**
 * Change set for synchronization
 */
export interface ChangeSet {
  /** Changes as binary data */
  changes: Uint8Array;

  /** Number of changes */
  count: number;

  /** Hash of changes */
  hash: string;
}

/**
 * Sync state for a peer
 */
export interface SyncState {
  /** Peer identifier */
  peerId: string;

  /** Last sync timestamp */
  lastSync: number;

  /** Automerge sync state */
  automergeState: Automerge.SyncState;
}

/**
 * Merge conflict information
 */
export interface MergeInfo {
  /** Whether any conflicts occurred */
  hasConflicts: boolean;

  /** Number of changes merged */
  changeCount: number;

  /** Conflicts detected (if any) */
  conflicts?: Array<{
    path: string;
    ours: any;
    theirs: any;
    resolved: any;
  }>;
}

// ============================================================================
// CRDT Manager Implementation
// ============================================================================

/**
 * Manager for CRDT-enabled context graphs
 */
export class CRDTManager {
  private doc: CRDTContextGraph;
  private syncStates: Map<string, SyncState> = new Map();
  private changeHistory: Automerge.Change[] = [];

  constructor(initialGraph?: Partial<ContextGraph>) {
    // Create initial Automerge document
    this.doc = Automerge.from({
      id: initialGraph?.id || uuidv4(),
      version: initialGraph?.version || 1,
      root: initialGraph?.root || '',
      nodes: this.convertNodesToRecord(initialGraph?.nodes),
      metadata: initialGraph?.metadata || this.createDefaultMetadata(),
    });

    // Track initial state
    this.changeHistory = Automerge.getHistory(this.doc);
  }

  // --------------------------------------------------------------------------
  // Graph Modifications
  // --------------------------------------------------------------------------

  /**
   * Add a new node to the graph
   */
  addNode(node: ContextNode): void {
    this.doc = Automerge.change(this.doc, `Add node ${node.id}`, (doc) => {
      doc.nodes[node.id] = node as any;
      doc.metadata.nodeCount = Object.keys(doc.nodes).length;
      doc.metadata.updated = Date.now();

      // Set as root if first node
      if (!doc.root) {
        doc.root = node.id;
      }
    });

    this.updateHistory();
  }

  /**
   * Update an existing node
   */
  updateNode(nodeId: string, updates: Partial<ContextNode>): void {
    this.doc = Automerge.change(this.doc, `Update node ${nodeId}`, (doc) => {
      if (doc.nodes[nodeId]) {
        Object.assign(doc.nodes[nodeId], updates);
        doc.metadata.updated = Date.now();
      }
    });

    this.updateHistory();
  }

  /**
   * Delete a node
   */
  deleteNode(nodeId: string): void {
    this.doc = Automerge.change(this.doc, `Delete node ${nodeId}`, (doc) => {
      delete doc.nodes[nodeId];

      // Remove edges pointing to this node
      for (const node of Object.values(doc.nodes)) {
        if (node.edges) {
          node.edges = node.edges.filter((edge: Edge) => edge.target !== nodeId);
        }
      }

      doc.metadata.nodeCount = Object.keys(doc.nodes).length;
      doc.metadata.updated = Date.now();

      // Update root if needed
      if (doc.root === nodeId) {
        doc.root = Object.keys(doc.nodes)[0] || '';
      }
    });

    this.updateHistory();
  }

  /**
   * Add an edge between nodes
   */
  addEdge(fromId: string, toId: string, type: EdgeType, weight: number = 1.0): void {
    this.doc = Automerge.change(this.doc, `Add edge ${fromId} -> ${toId}`, (doc) => {
      const fromNode = doc.nodes[fromId];
      const toNode = doc.nodes[toId];

      if (!fromNode || !toNode) {
        throw new Error('Both nodes must exist');
      }

      if (!fromNode.edges) {
        fromNode.edges = [];
      }

      // Check for existing edge
      const existingIndex = fromNode.edges.findIndex(
        (e: Edge) => e.target === toId && e.type === type
      );

      if (existingIndex >= 0) {
        // Update existing edge
        fromNode.edges[existingIndex].weight = weight;
      } else {
        // Add new edge
        fromNode.edges.push({ target: toId, type, weight } as any);
      }

      doc.metadata.edgeCount = this.countEdges(doc.nodes);
      doc.metadata.updated = Date.now();
    });

    this.updateHistory();
  }

  /**
   * Remove an edge
   */
  removeEdge(fromId: string, toId: string, type?: EdgeType): void {
    this.doc = Automerge.change(this.doc, `Remove edge ${fromId} -> ${toId}`, (doc) => {
      const fromNode = doc.nodes[fromId];
      if (!fromNode || !fromNode.edges) return;

      fromNode.edges = fromNode.edges.filter((edge: Edge) => {
        if (edge.target !== toId) return true;
        if (type && edge.type !== type) return true;
        return false;
      });

      doc.metadata.edgeCount = this.countEdges(doc.nodes);
      doc.metadata.updated = Date.now();
    });

    this.updateHistory();
  }

  // --------------------------------------------------------------------------
  // Synchronization
  // --------------------------------------------------------------------------

  /**
   * Generate changes since last sync with a peer
   * @param peerId Peer identifier
   * @returns Change set to send to peer
   */
  generateChanges(peerId: string): ChangeSet {
    const syncState = this.getSyncState(peerId);
    const [newSyncState, message] = Automerge.generateSyncMessage(
      this.doc,
      syncState.automergeState
    );

    // Update sync state
    syncState.automergeState = newSyncState;
    syncState.lastSync = Date.now();

    const changes = message || new Uint8Array();

    return {
      changes,
      count: this.changeHistory.length,
      hash: this.computeHash(changes),
    };
  }

  /**
   * Apply changes from a peer
   * @param peerId Peer identifier
   * @param changeSet Changes received from peer
   * @returns Merge information
   */
  applyChanges(peerId: string, changeSet: ChangeSet): MergeInfo {
    const syncState = this.getSyncState(peerId);
    const previousDoc = this.doc;

    try {
      // Apply changes using Automerge sync
      const [newDoc, newSyncState] = Automerge.receiveSyncMessage(
        this.doc,
        syncState.automergeState,
        changeSet.changes
      );

      this.doc = newDoc;
      syncState.automergeState = newSyncState;
      syncState.lastSync = Date.now();

      // Update history
      this.updateHistory();

      // Detect conflicts (simplified - Automerge handles this automatically)
      const hasConflicts = false; // Automerge merges automatically

      return {
        hasConflicts,
        changeCount: changeSet.count,
      };
    } catch (error) {
      console.error('Error applying changes:', error);
      // Rollback
      this.doc = previousDoc;
      throw error;
    }
  }

  /**
   * Merge with another CRDT graph
   * @param other Other CRDT manager
   * @returns Merge information
   */
  mergeWith(other: CRDTManager): MergeInfo {
    const previousDoc = this.doc;

    try {
      // Merge documents
      this.doc = Automerge.merge(this.doc, other.doc);

      this.updateHistory();

      return {
        hasConflicts: false, // Automerge handles conflicts automatically
        changeCount: Automerge.getChanges(previousDoc, this.doc).length,
      };
    } catch (error) {
      console.error('Error merging:', error);
      this.doc = previousDoc;
      throw error;
    }
  }

  /**
   * Synchronize with a peer using sync protocol
   * @param peerId Peer identifier
   * @param theirMessage Their sync message (if any)
   * @returns Our sync message to send back
   */
  sync(peerId: string, theirMessage?: Uint8Array): Uint8Array | null {
    const syncState = this.getSyncState(peerId);

    if (theirMessage) {
      // Receive their message and update our doc
      const [newDoc, newSyncState, ourMessage] = Automerge.receiveSyncMessage(
        this.doc,
        syncState.automergeState,
        theirMessage
      );

      this.doc = newDoc;
      syncState.automergeState = newSyncState;
      syncState.lastSync = Date.now();
      this.updateHistory();

      return ourMessage || null;
    } else {
      // Initial sync - generate our message
      const [newSyncState, ourMessage] = Automerge.generateSyncMessage(
        this.doc,
        syncState.automergeState
      );

      syncState.automergeState = newSyncState;
      return ourMessage || null;
    }
  }

  // --------------------------------------------------------------------------
  // History & Changes
  // --------------------------------------------------------------------------

  /**
   * Get change history
   */
  getHistory(): Automerge.Change[] {
    return this.changeHistory;
  }

  /**
   * Get changes since a specific version
   */
  getChangesSince(version: number): Automerge.Change[] {
    return this.changeHistory.slice(version);
  }

  /**
   * Undo last change
   */
  undo(): void {
    if (this.changeHistory.length === 0) {
      throw new Error('Nothing to undo');
    }

    // Get all changes except the last one
    const previousChanges = this.changeHistory.slice(0, -1);

    // Recreate document from history
    let newDoc = Automerge.init<any>();
    for (const change of previousChanges) {
      newDoc = Automerge.applyChanges(newDoc, [change])[0];
    }

    this.doc = newDoc;
    this.updateHistory();
  }

  /**
   * Export changes as binary
   */
  exportChanges(): Uint8Array {
    const allChanges = Automerge.getAllChanges(this.doc);
    return Automerge.encodeChange(allChanges[allChanges.length - 1]);
  }

  /**
   * Import changes from binary
   */
  importChanges(data: Uint8Array): void {
    const change = Automerge.decodeChange(data);
    const [newDoc] = Automerge.applyChanges(this.doc, [change]);
    this.doc = newDoc;
    this.updateHistory();
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  /**
   * Serialize to binary format
   */
  save(): Uint8Array {
    return Automerge.save(this.doc);
  }

  /**
   * Load from binary format
   */
  static load(data: Uint8Array): CRDTManager {
    const doc = Automerge.load<any>(data);
    const manager = new CRDTManager();
    manager.doc = doc;
    manager.updateHistory();
    return manager;
  }

  /**
   * Clone this manager
   */
  clone(): CRDTManager {
    const cloned = new CRDTManager();
    cloned.doc = Automerge.clone(this.doc);
    cloned.updateHistory();
    return cloned;
  }

  // --------------------------------------------------------------------------
  // Getters
  // --------------------------------------------------------------------------

  /**
   * Get the current document
   */
  getDoc(): CRDTContextGraph {
    return this.doc;
  }

  /**
   * Get graph as plain object
   */
  toGraph(): ContextGraph {
    const nodes = new Map<string, ContextNode>();

    for (const [id, node] of Object.entries(this.doc.nodes)) {
      nodes.set(id, node);
    }

    return {
      id: this.doc.id,
      version: this.doc.version,
      root: this.doc.root,
      nodes,
      metadata: this.doc.metadata,
    };
  }

  /**
   * Get document version
   */
  getVersion(): number {
    return this.changeHistory.length;
  }

  /**
   * Get metadata
   */
  getMetadata(): GraphMetadata {
    return this.doc.metadata;
  }

  // --------------------------------------------------------------------------
  // Private Helpers
  // --------------------------------------------------------------------------

  private getSyncState(peerId: string): SyncState {
    let state = this.syncStates.get(peerId);

    if (!state) {
      state = {
        peerId,
        lastSync: 0,
        automergeState: Automerge.initSyncState(),
      };
      this.syncStates.set(peerId, state);
    }

    return state;
  }

  private updateHistory(): void {
    this.changeHistory = Automerge.getHistory(this.doc);
  }

  private convertNodesToRecord(
    nodes?: Map<string, ContextNode>
  ): Record<string, ContextNode> {
    if (!nodes) return {};

    const record: Record<string, ContextNode> = {};
    for (const [id, node] of nodes.entries()) {
      record[id] = node;
    }
    return record;
  }

  private countEdges(nodes: Record<string, ContextNode>): number {
    let count = 0;
    for (const node of Object.values(nodes)) {
      if (node.edges) {
        count += node.edges.length;
      }
    }
    return count;
  }

  private createDefaultMetadata(): GraphMetadata {
    return {
      created: Date.now(),
      updated: Date.now(),
      author: '',
      size: 0,
      nodeCount: 0,
      edgeCount: 0,
    };
  }

  private computeHash(data: Uint8Array): string {
    // Simple hash for now - would use crypto.subtle.digest in production
    let hash = 0;
    for (let i = 0; i < data.length; i++) {
      hash = ((hash << 5) - hash + data[i]) | 0;
    }
    return hash.toString(16);
  }

  // --------------------------------------------------------------------------
  // Conflict Resolution Hooks (Advanced)
  // --------------------------------------------------------------------------

  /**
   * Register custom conflict resolver
   * (Automerge handles most conflicts automatically, but this allows custom logic)
   */
  onConflict(
    resolver: (path: string, ours: any, theirs: any) => any
  ): void {
    // This would integrate with Automerge's conflict handling
    // For now, Automerge uses last-write-wins by default
  }
}

// ============================================================================
// Utilities
// ============================================================================

/**
 * Create a CRDT manager from a regular context graph
 */
export function fromContextGraph(graph: ContextGraph): CRDTManager {
  return new CRDTManager(graph);
}

/**
 * Merge multiple CRDT managers
 */
export function mergeMultiple(managers: CRDTManager[]): CRDTManager {
  if (managers.length === 0) {
    throw new Error('At least one manager required');
  }

  if (managers.length === 1) {
    return managers[0].clone();
  }

  let result = managers[0].clone();

  for (let i = 1; i < managers.length; i++) {
    result.mergeWith(managers[i]);
  }

  return result;
}

// ============================================================================
// Exports
// ============================================================================

export default CRDTManager;
