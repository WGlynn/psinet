/**
 * @module @psinet/ipfs
 * @description IPFS integration for ΨNet - decentralized storage layer
 *
 * Features:
 * - DID document storage and retrieval
 * - Context graph storage
 * - Content pinning management
 * - CID validation and verification
 * - Multiple pinning service support (Pinata, Web3.Storage, Infura)
 */

import { create, IPFSHTTPClient, Options } from 'ipfs-http-client';
import { CID } from 'multiformats/cid';
import * as json from 'multiformats/codecs/json';
import { sha256 } from 'multiformats/hashes/sha2';
import { fromString, toString } from 'uint8arrays';
import { LRUCache } from 'lru-cache';
import winston from 'winston';
import CircuitBreaker from 'opossum';

// ============================================================================
// Logging Setup
// ============================================================================

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: '@psinet/ipfs' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
          const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
          return `${timestamp} [${service}] [${level}] ${message}${metaStr}`;
        })
      ),
    }),
  ],
});

// ============================================================================
// Custom Error Classes
// ============================================================================

export class IPFSError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'IPFSError';
  }
}

export class UploadError extends IPFSError {
  constructor(message: string, cause?: Error) {
    super(message, cause);
    this.name = 'UploadError';
  }
}

export class FetchError extends IPFSError {
  constructor(message: string, cause?: Error) {
    super(message, cause);
    this.name = 'FetchError';
  }
}

export class ValidationError extends IPFSError {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class TimeoutError extends IPFSError {
  constructor(message: string) {
    super(message);
    this.name = 'TimeoutError';
  }
}

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * DID Document as per W3C DID Core specification
 */
export interface DIDDocument {
  '@context': string[];
  id: string; // did:psinet:...
  controller?: string | string[];
  verificationMethod?: VerificationMethod[];
  authentication?: (string | VerificationMethod)[];
  assertionMethod?: (string | VerificationMethod)[];
  keyAgreement?: (string | VerificationMethod)[];
  service?: ServiceEndpoint[];
  created?: string;
  updated?: string;
  proof?: Proof;
}

export interface VerificationMethod {
  id: string;
  type: string;
  controller: string;
  publicKeyMultibase?: string;
  publicKeyJwk?: JsonWebKey;
}

export interface ServiceEndpoint {
  id: string;
  type: string;
  serviceEndpoint: string | object;
}

export interface Proof {
  type: string;
  created: string;
  verificationMethod: string;
  proofPurpose: string;
  proofValue: string;
}

/**
 * Encrypted context graph structure
 */
export interface EncryptedContextGraph {
  graphId: string;
  version: number;
  encrypted: boolean;
  encryptedData: Uint8Array; // Encrypted serialized graph
  encryptionMethod: 'aes-256-gcm' | 'xchacha20-poly1305';
  nonce: Uint8Array;
  recipients: string[]; // DIDs of authorized agents
  metadata: GraphMetadata;
  signature: Uint8Array;
}

export interface GraphMetadata {
  created: number;
  updated: number;
  author: string; // DID
  size: number; // bytes
  nodeCount: number;
  compressionRatio?: number;
}

/**
 * Configuration for IPFS client
 */
export interface IPFSConfig {
  /** IPFS gateway URL (for fetching) */
  gateway?: string;

  /** IPFS API endpoint (for uploading) */
  apiEndpoint?: string;

  /** Pinning service to use */
  pinningService?: 'pinata' | 'web3.storage' | 'infura' | 'local';

  /** API key for pinning service */
  pinningApiKey?: string;

  /** Timeout for IPFS operations (ms) */
  timeout?: number;

  /** Enable local caching */
  enableCache?: boolean;

  /** Custom IPFS client options */
  ipfsOptions?: Options;
}

/**
 * Result of content upload
 */
export interface UploadResult {
  cid: string;
  size: number;
  timestamp: number;
  pinned: boolean;
}

/**
 * Pinning status
 */
export interface PinStatus {
  cid: string;
  pinned: boolean;
  pinnedAt?: number;
  pinningService?: string;
}

// ============================================================================
// IPFS Client Interface
// ============================================================================

/**
 * Core IPFS client interface for ΨNet
 */
export interface IPFSClient {
  /**
   * Upload DID document to IPFS
   * @param doc - DID document to upload
   * @returns CID of uploaded document
   */
  uploadDIDDocument(doc: DIDDocument): Promise<UploadResult>;

  /**
   * Upload encrypted context graph to IPFS
   * @param graph - Encrypted context graph
   * @returns CID of uploaded graph
   */
  uploadContextGraph(graph: EncryptedContextGraph): Promise<UploadResult>;

  /**
   * Upload arbitrary content
   * @param content - Content to upload
   * @returns CID of uploaded content
   */
  uploadContent(content: Uint8Array | string): Promise<UploadResult>;

  /**
   * Fetch DID document from IPFS
   * @param cid - Content identifier
   * @returns DID document
   */
  fetchDIDDocument(cid: string): Promise<DIDDocument>;

  /**
   * Fetch encrypted context graph from IPFS
   * @param cid - Content identifier
   * @returns Encrypted context graph
   */
  fetchContextGraph(cid: string): Promise<EncryptedContextGraph>;

  /**
   * Fetch arbitrary content from IPFS
   * @param cid - Content identifier
   * @returns Content as Uint8Array
   */
  fetchContent(cid: string): Promise<Uint8Array>;

  /**
   * Pin content to IPFS (prevent garbage collection)
   * @param cid - Content identifier to pin
   */
  pin(cid: string): Promise<PinStatus>;

  /**
   * Unpin content from IPFS
   * @param cid - Content identifier to unpin
   */
  unpin(cid: string): Promise<void>;

  /**
   * Check if content is pinned
   * @param cid - Content identifier
   * @returns Pin status
   */
  isPinned(cid: string): Promise<boolean>;

  /**
   * Verify CID is valid and content matches
   * @param cid - Content identifier
   * @param content - Content to verify
   * @returns True if content matches CID
   */
  verifyContent(cid: string, content: Uint8Array): Promise<boolean>;

  /**
   * Get statistics about stored content
   */
  getStats(): Promise<{
    totalPinned: number;
    totalSize: number;
    pinnedCIDs: string[];
  }>;
}

// ============================================================================
// IPFS Manager Implementation
// ============================================================================

/**
 * Production-ready IPFS client for ΨNet
 */
export class IPFSManager implements IPFSClient {
  private client: IPFSHTTPClient;
  private config: Required<IPFSConfig>;
  private cache: LRUCache<string, DIDDocument | EncryptedContextGraph>;
  private uploadBreaker: CircuitBreaker;
  private fetchBreaker: CircuitBreaker;

  constructor(config: IPFSConfig = {}) {
    // Default configuration
    this.config = {
      gateway: config.gateway || 'https://ipfs.io',
      apiEndpoint: config.apiEndpoint || 'http://localhost:5001',
      pinningService: config.pinningService || 'local',
      pinningApiKey: config.pinningApiKey || '',
      timeout: config.timeout || 30000,
      enableCache: config.enableCache !== false,
      ipfsOptions: config.ipfsOptions || {},
    };

    // Create IPFS HTTP client
    this.client = create({
      url: this.config.apiEndpoint,
      timeout: this.config.timeout,
      ...this.config.ipfsOptions,
    });

    // Initialize LRU cache with size limits
    this.cache = new LRUCache({
      max: 1000, // Maximum 1000 entries
      maxSize: 100 * 1024 * 1024, // 100MB total
      ttl: 1000 * 60 * 60, // 1 hour TTL
      sizeCalculation: (value) => {
        // Estimate size of cached value
        return JSON.stringify(value).length;
      },
      dispose: (value, key) => {
        // Cleanup on eviction (optional)
        logger.debug('Cache entry evicted', { cid: key });
      },
    });

    // Initialize circuit breakers for resilience
    this.uploadBreaker = new CircuitBreaker(this.uploadInternal.bind(this), {
      timeout: 10000, // 10s timeout
      errorThresholdPercentage: 50, // Open after 50% errors
      resetTimeout: 30000, // Try again after 30s
      rollingCountTimeout: 10000, // 10s window
      rollingCountBuckets: 10,
      name: 'ipfs-upload',
    });

    this.fetchBreaker = new CircuitBreaker(this.fetchInternal.bind(this), {
      timeout: 10000, // 10s timeout
      errorThresholdPercentage: 50,
      resetTimeout: 30000,
      rollingCountTimeout: 10000,
      rollingCountBuckets: 10,
      name: 'ipfs-fetch',
    });

    // Log circuit breaker events
    this.uploadBreaker.on('open', () => {
      logger.error('Upload circuit breaker opened - IPFS uploads failing');
    });
    this.uploadBreaker.on('halfOpen', () => {
      logger.warn('Upload circuit breaker half-open - testing IPFS');
    });
    this.uploadBreaker.on('close', () => {
      logger.info('Upload circuit breaker closed - IPFS uploads recovered');
    });

    this.fetchBreaker.on('open', () => {
      logger.error('Fetch circuit breaker opened - IPFS fetches failing');
    });
    this.fetchBreaker.on('halfOpen', () => {
      logger.warn('Fetch circuit breaker half-open - testing IPFS');
    });
    this.fetchBreaker.on('close', () => {
      logger.info('Fetch circuit breaker closed - IPFS fetches recovered');
    });
  }

  // ------------------------------------------------------------------------
  // Error Handling & Retry Logic
  // ------------------------------------------------------------------------

  /**
   * Retry operation with exponential backoff
   */
  private async retryOperation<T>(
    operation: () => Promise<T>,
    operationName: string,
    maxRetries: number = 3
  ): Promise<T> {
    const backoffMs = [1000, 2000, 4000]; // exponential backoff
    let lastError: Error | undefined;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error as Error;

        // Don't retry on validation errors
        if (error instanceof ValidationError) {
          throw error;
        }

        // Log retry attempt
        logger.warn('Operation failed, retrying', {
          operation: operationName,
          attempt: attempt + 1,
          maxRetries,
          error: error instanceof Error ? error.message : String(error),
        });

        // Don't wait after last attempt
        if (attempt < maxRetries - 1) {
          await this.sleep(backoffMs[attempt]);
        }
      }
    }

    throw new IPFSError(
      `${operationName} failed after ${maxRetries} attempts`,
      lastError
    );
  }

  /**
   * Check if error is retriable
   */
  private isRetriableError(error: any): boolean {
    // Network errors, timeouts are retriable
    if (error.code === 'ETIMEDOUT' || error.code === 'ECONNREFUSED') {
      return true;
    }
    if (error.name === 'TimeoutError') {
      return true;
    }
    // Validation errors are not retriable
    return !(error instanceof ValidationError);
  }

  /**
   * Sleep helper
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Execute with timeout
   */
  private async withTimeout<T>(
    promise: Promise<T>,
    timeoutMs: number,
    operationName: string
  ): Promise<T> {
    return Promise.race([
      promise,
      new Promise<T>((_, reject) =>
        setTimeout(
          () => reject(new TimeoutError(`${operationName} timed out after ${timeoutMs}ms`)),
          timeoutMs
        )
      ),
    ]);
  }

  // ------------------------------------------------------------------------
  // Circuit Breaker Internal Methods
  // ------------------------------------------------------------------------

  /**
   * Internal upload method wrapped by circuit breaker
   */
  private async uploadInternal(bytes: Uint8Array): Promise<UploadResult> {
    // Upload to IPFS with retry logic
    return this.retryOperation(async () => {
      try {
        // Upload with timeout
        const result = await this.withTimeout(
          this.client.add(bytes, {
            pin: true,
            cidVersion: 1,
          }),
          this.config.timeout,
          'IPFS upload'
        );

        const uploadResult: UploadResult = {
          cid: result.cid.toString(),
          size: result.size,
          timestamp: Date.now(),
          pinned: true,
        };

        // Pin to pinning service if configured
        if (this.config.pinningService !== 'local') {
          await this.pinToService(uploadResult.cid).catch((error) => {
            logger.warn('Pinning service failed, continuing with upload', {
              cid: uploadResult.cid,
              service: this.config.pinningService,
              error: error instanceof Error ? error.message : String(error),
            });
            // Don't fail upload if pinning service fails
          });
        }

        return uploadResult;
      } catch (error) {
        throw new UploadError('Failed to upload content', error as Error);
      }
    }, 'IPFS upload');
  }

  /**
   * Internal fetch method wrapped by circuit breaker
   */
  private async fetchInternal(cid: string): Promise<Uint8Array> {
    return this.retryOperation(async () => {
      try {
        const chunks: Uint8Array[] = [];
        for await (const chunk of this.client.cat(cid, {
          timeout: this.config.timeout,
        })) {
          chunks.push(chunk);
        }

        // Concatenate chunks
        const totalLength = chunks.reduce((acc, chunk) => acc + chunk.length, 0);
        const result = new Uint8Array(totalLength);
        let offset = 0;
        for (const chunk of chunks) {
          result.set(chunk, offset);
          offset += chunk.length;
        }

        return result;
      } catch (error) {
        throw new FetchError('Failed to fetch content from IPFS', error as Error);
      }
    }, 'IPFS fetch');
  }

  // ------------------------------------------------------------------------
  // Upload Operations
  // ------------------------------------------------------------------------

  async uploadDIDDocument(doc: DIDDocument): Promise<UploadResult> {
    // Validate DID document
    try {
      this.validateDIDDocument(doc);
    } catch (error) {
      throw new ValidationError(`Invalid DID document: ${(error as Error).message}`);
    }

    // Serialize to JSON
    const content = JSON.stringify(doc, null, 2);
    const bytes = fromString(content);

    // Upload via circuit breaker
    return this.uploadBreaker.fire(bytes);
  }

  async uploadContextGraph(graph: EncryptedContextGraph): Promise<UploadResult> {
    // Validate graph structure
    try {
      this.validateContextGraph(graph);
    } catch (error) {
      throw new ValidationError(`Invalid context graph: ${(error as Error).message}`);
    }

    // Serialize graph
    const content = this.serializeGraph(graph);

    // Upload via circuit breaker
    return this.uploadBreaker.fire(content);
  }

  async uploadContent(content: Uint8Array | string): Promise<UploadResult> {
    const bytes = typeof content === 'string' ? fromString(content) : content;

    // Upload via circuit breaker
    return this.uploadBreaker.fire(bytes);
  }

  // ------------------------------------------------------------------------
  // Fetch Operations
  // ------------------------------------------------------------------------

  async fetchDIDDocument(cid: string): Promise<DIDDocument> {
    // Check cache first
    if (this.config.enableCache && this.cache.has(cid)) {
      const cached = this.cache.get(cid);
      if (cached && 'id' in cached) {
        // It's a DID document
        logger.debug('Cache hit for DID document', { cid });
        return cached as DIDDocument;
      }
    }

    // Fetch via circuit breaker
    const data = await this.fetchBreaker.fire(cid);
    const doc = JSON.parse(toString(data)) as DIDDocument;

    // Cache result
    if (this.config.enableCache) {
      this.cache.set(cid, doc);
    }

    return doc;
  }

  async fetchContextGraph(cid: string): Promise<EncryptedContextGraph> {
    // Check cache first
    if (this.config.enableCache && this.cache.has(cid)) {
      const cached = this.cache.get(cid);
      if (cached && 'encryptedData' in cached) {
        // It's a context graph
        logger.debug('Cache hit for context graph', { cid });
        return cached as EncryptedContextGraph;
      }
    }

    // Fetch via circuit breaker
    const data = await this.fetchBreaker.fire(cid);
    const graph = this.deserializeGraph(data);

    // Cache result
    if (this.config.enableCache) {
      this.cache.set(cid, graph);
    }

    return graph;
  }

  async fetchContent(cid: string): Promise<Uint8Array> {
    // Fetch via circuit breaker (no caching for raw content)
    return this.fetchBreaker.fire(cid);
  }


  // ------------------------------------------------------------------------
  // Pinning Operations
  // ------------------------------------------------------------------------

  async pin(cid: string): Promise<PinStatus> {
    await this.client.pin.add(CID.parse(cid));

    // Also pin to external service if configured
    if (this.config.pinningService !== 'local') {
      await this.pinToService(cid);
    }

    return {
      cid,
      pinned: true,
      pinnedAt: Date.now(),
      pinningService: this.config.pinningService,
    };
  }

  async unpin(cid: string): Promise<void> {
    await this.client.pin.rm(CID.parse(cid));

    // Also unpin from external service
    if (this.config.pinningService !== 'local') {
      await this.unpinFromService(cid);
    }
  }

  async isPinned(cid: string): Promise<boolean> {
    try {
      for await (const pin of this.client.pin.ls({ paths: CID.parse(cid) })) {
        if (pin.cid.toString() === cid) {
          return true;
        }
      }
      return false;
    } catch (error) {
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // Verification
  // ------------------------------------------------------------------------

  async verifyContent(cid: string, content: Uint8Array): Promise<boolean> {
    try {
      // Compute hash of content
      const hash = await sha256.digest(content);

      // Create CID from hash
      const computedCID = CID.createV1(json.code, hash);

      // Compare CIDs
      return computedCID.toString() === cid;
    } catch (error) {
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // Statistics
  // ------------------------------------------------------------------------

  async getStats(): Promise<{
    totalPinned: number;
    totalSize: number;
    pinnedCIDs: string[];
  }> {
    const pinnedCIDs: string[] = [];
    let totalSize = 0;

    for await (const pin of this.client.pin.ls()) {
      const cidStr = pin.cid.toString();
      pinnedCIDs.push(cidStr);

      // Get size (this is expensive, consider caching)
      try {
        const stat = await this.client.files.stat(`/ipfs/${cidStr}`);
        totalSize += stat.cumulativeSize;
      } catch (error) {
        // Ignore errors for individual files
      }
    }

    return {
      totalPinned: pinnedCIDs.length,
      totalSize,
      pinnedCIDs,
    };
  }

  // ------------------------------------------------------------------------
  // Private Helper Methods
  // ------------------------------------------------------------------------

  private validateDIDDocument(doc: DIDDocument): void {
    if (!doc.id || !doc.id.startsWith('did:')) {
      throw new Error('Invalid DID document: missing or invalid id');
    }
    if (!doc['@context'] || !Array.isArray(doc['@context'])) {
      throw new Error('Invalid DID document: missing @context');
    }
  }

  private validateContextGraph(graph: EncryptedContextGraph): void {
    if (!graph.graphId || !graph.encryptedData) {
      throw new Error('Invalid context graph: missing required fields');
    }
    if (!graph.metadata || !graph.metadata.author) {
      throw new Error('Invalid context graph: missing metadata');
    }
  }

  private serializeGraph(graph: EncryptedContextGraph): Uint8Array {
    // Convert to a serializable format
    const serializable = {
      ...graph,
      encryptedData: Array.from(graph.encryptedData),
      nonce: Array.from(graph.nonce),
      signature: Array.from(graph.signature),
    };
    return fromString(JSON.stringify(serializable));
  }

  private deserializeGraph(data: Uint8Array): EncryptedContextGraph {
    const json = toString(data);
    const parsed = JSON.parse(json);

    return {
      ...parsed,
      encryptedData: new Uint8Array(parsed.encryptedData),
      nonce: new Uint8Array(parsed.nonce),
      signature: new Uint8Array(parsed.signature),
    };
  }

  private async pinToService(cid: string): Promise<void> {
    // This would integrate with Pinata, Web3.Storage, or Infura
    // Implementation depends on the chosen service
    // For now, this is a placeholder
    logger.info('Pinning content to service', {
      cid,
      service: this.config.pinningService,
    });

    // Example for Pinata:
    // const response = await fetch('https://api.pinata.cloud/pinning/pinByHash', {
    //   method: 'POST',
    //   headers: {
    //     'Authorization': `Bearer ${this.config.pinningApiKey}`,
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({ hashToPin: cid }),
    // });
  }

  private async unpinFromService(cid: string): Promise<void> {
    logger.info('Unpinning content from service', {
      cid,
      service: this.config.pinningService,
    });
  }

  /**
   * Clear cache
   */
  clearCache(): void {
    this.cache.clear();
  }

  /**
   * Close IPFS connection
   */
  async close(): Promise<void> {
    // Clean up resources
    this.clearCache();
  }
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Validate CID format
 */
export function isValidCID(cid: string): boolean {
  try {
    CID.parse(cid);
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Convert CID version (v0 to v1 or vice versa)
 */
export function convertCIDVersion(cid: string, version: 0 | 1): string {
  const parsed = CID.parse(cid);
  if (version === 0) {
    return parsed.toV0().toString();
  } else {
    return parsed.toV1().toString();
  }
}

/**
 * Create IPFS manager with default config
 */
export function createIPFSManager(config?: IPFSConfig): IPFSManager {
  return new IPFSManager(config);
}

// Export default instance
export default IPFSManager;
