/**
 * @module @psinet/p2p/crypto
 * @description Cryptographic utilities for ΨNet P2P - message signing and verification
 *
 * Features:
 * - Ed25519 signature generation and verification
 * - DID document key resolution
 * - Message signing with DID authentication
 * - Signature verification with DID ownership checks
 */

import * as ed25519 from '@noble/ed25519';
import { sha512 } from '@noble/hashes/sha512';
import { toString, fromString } from 'uint8arrays';

// Set the hash function for ed25519 (required by @noble/ed25519)
ed25519.etc.sha512Sync = (...m) => sha512(ed25519.etc.concatBytes(...m));

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * DID Document simplified for key resolution
 */
export interface DIDDocument {
  id: string; // did:psinet:...
  verificationMethod?: VerificationMethod[];
  authentication?: (string | VerificationMethod)[];
  assertionMethod?: (string | VerificationMethod)[];
}

export interface VerificationMethod {
  id: string;
  type: string;
  controller: string;
  publicKeyMultibase?: string;
  publicKeyHex?: string;
}

/**
 * Signed message envelope
 */
export interface SignedMessage<T = any> {
  /** The actual message payload */
  payload: T;
  /** Sender's DID */
  from: string;
  /** Timestamp (Unix milliseconds) */
  timestamp: number;
  /** Nonce for replay protection */
  nonce: string;
  /** Signature (hex encoded) */
  signature: string;
  /** Verification method ID used for signing */
  verificationMethod: string;
}

/**
 * Key pair for signing
 */
export interface KeyPair {
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}

// ============================================================================
// Key Management
// ============================================================================

/**
 * Generate a new Ed25519 key pair
 */
export async function generateKeyPair(): Promise<KeyPair> {
  const privateKey = ed25519.utils.randomPrivateKey();
  const publicKey = await ed25519.getPublicKey(privateKey);

  return {
    publicKey,
    privateKey,
  };
}

/**
 * Convert public key to multibase format (base58btc)
 */
export function publicKeyToMultibase(publicKey: Uint8Array): string {
  // Ed25519 public key multicodec prefix (0xed01)
  const prefix = new Uint8Array([0xed, 0x01]);
  const prefixed = new Uint8Array(prefix.length + publicKey.length);
  prefixed.set(prefix);
  prefixed.set(publicKey, prefix.length);

  // Base58btc encoding (multibase prefix 'z')
  return 'z' + base58Encode(prefixed);
}

/**
 * Parse multibase public key to raw bytes
 */
export function multibaseToPublicKey(multibase: string): Uint8Array {
  if (!multibase.startsWith('z')) {
    throw new Error('Invalid multibase format - expected base58btc (z prefix)');
  }

  const decoded = base58Decode(multibase.slice(1));

  // Verify and remove Ed25519 multicodec prefix
  if (decoded[0] !== 0xed || decoded[1] !== 0x01) {
    throw new Error('Invalid Ed25519 multicodec prefix');
  }

  return decoded.slice(2);
}

/**
 * Convert public key to hex string
 */
export function publicKeyToHex(publicKey: Uint8Array): string {
  return Buffer.from(publicKey).toString('hex');
}

/**
 * Parse hex public key to raw bytes
 */
export function hexToPublicKey(hex: string): Uint8Array {
  return fromString(hex, 'base16');
}

// ============================================================================
// Message Signing & Verification
// ============================================================================

/**
 * Sign a message with a private key
 * @param message The message payload to sign
 * @param privateKey The Ed25519 private key
 * @param did The signer's DID
 * @param verificationMethodId The verification method ID used for signing
 */
export async function signMessage<T>(
  message: T,
  privateKey: Uint8Array,
  did: string,
  verificationMethodId: string
): Promise<SignedMessage<T>> {
  // Create the message envelope
  const envelope: Omit<SignedMessage<T>, 'signature'> = {
    payload: message,
    from: did,
    timestamp: Date.now(),
    nonce: generateNonce(),
    verificationMethod: verificationMethodId,
  };

  // Serialize for signing (canonical JSON)
  const messageBytes = fromString(canonicalJSON(envelope), 'utf8');

  // Sign the message
  const signature = await ed25519.sign(messageBytes, privateKey);

  return {
    ...envelope,
    signature: Buffer.from(signature).toString('hex'),
  };
}

/**
 * Verify a signed message
 * @param signedMessage The signed message to verify
 * @param didDocument The DID document to resolve the public key
 * @param options Verification options
 */
export async function verifyMessage<T>(
  signedMessage: SignedMessage<T>,
  didDocument: DIDDocument,
  options: {
    maxAge?: number; // Max age in milliseconds (default: 5 minutes)
    checkNonce?: (nonce: string, did: string) => Promise<boolean>;
  } = {}
): Promise<boolean> {
  const { maxAge = 5 * 60 * 1000, checkNonce } = options;

  try {
    // 1. Verify DID matches
    if (signedMessage.from !== didDocument.id) {
      logger.warn('DID mismatch in signature verification', {
        expected: didDocument.id,
        actual: signedMessage.from,
      });
      return false;
    }

    // 2. Verify timestamp (prevent replay attacks)
    const age = Date.now() - signedMessage.timestamp;
    if (age > maxAge) {
      logger.warn('Message timestamp too old', {
        age,
        maxAge,
        timestamp: signedMessage.timestamp,
      });
      return false;
    }

    if (age < -60000) {
      // More than 1 minute in the future
      logger.warn('Message timestamp in the future', {
        age,
        timestamp: signedMessage.timestamp,
      });
      return false;
    }

    // 3. Verify nonce (if checker provided)
    if (checkNonce) {
      const nonceValid = await checkNonce(signedMessage.nonce, signedMessage.from);
      if (!nonceValid) {
        logger.warn('Nonce already used (replay attack detected)', {
          nonce: signedMessage.nonce,
          from: signedMessage.from,
        });
        return false;
      }
    }

    // 4. Resolve public key from DID document
    const publicKey = resolveVerificationKey(didDocument, signedMessage.verificationMethod);
    if (!publicKey) {
      logger.warn('Verification method not found in DID document', {
        verificationMethod: signedMessage.verificationMethod,
        did: didDocument.id,
      });
      return false;
    }

    // 5. Verify signature
    const { signature, ...messageWithoutSig } = signedMessage;
    const messageBytes = fromString(canonicalJSON(messageWithoutSig), 'utf8');
    const signatureBytes = fromString(signature, 'base16');

    const valid = await ed25519.verify(signatureBytes, messageBytes, publicKey);

    if (!valid) {
      logger.warn('Signature verification failed', {
        from: signedMessage.from,
        verificationMethod: signedMessage.verificationMethod,
      });
    }

    return valid;
  } catch (error) {
    logger.error('Error during signature verification', {
      error: error instanceof Error ? error.message : String(error),
      from: signedMessage.from,
    });
    return false;
  }
}

/**
 * Resolve a verification key from a DID document
 */
export function resolveVerificationKey(
  didDocument: DIDDocument,
  verificationMethodId: string
): Uint8Array | null {
  // Find the verification method
  let method: VerificationMethod | undefined;

  // Check verificationMethod array
  if (didDocument.verificationMethod) {
    method = didDocument.verificationMethod.find((vm) => vm.id === verificationMethodId);
  }

  // Check authentication array
  if (!method && didDocument.authentication) {
    for (const auth of didDocument.authentication) {
      if (typeof auth === 'object' && auth.id === verificationMethodId) {
        method = auth;
        break;
      }
    }
  }

  // Check assertionMethod array
  if (!method && didDocument.assertionMethod) {
    for (const assertion of didDocument.assertionMethod) {
      if (typeof assertion === 'object' && assertion.id === verificationMethodId) {
        method = assertion;
        break;
      }
    }
  }

  if (!method) {
    return null;
  }

  // Extract public key based on format
  if (method.publicKeyMultibase) {
    return multibaseToPublicKey(method.publicKeyMultibase);
  }

  if (method.publicKeyHex) {
    return hexToPublicKey(method.publicKeyHex);
  }

  return null;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Generate a random nonce for replay protection
 */
export function generateNonce(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Buffer.from(bytes).toString('hex');
}

/**
 * Canonical JSON serialization (for consistent signing)
 */
function canonicalJSON(obj: any): string {
  return JSON.stringify(obj, Object.keys(obj).sort());
}

/**
 * Simple Base58 encoding (Bitcoin alphabet)
 */
function base58Encode(bytes: Uint8Array): string {
  const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const base = BigInt(ALPHABET.length);

  let num = BigInt('0x' + Buffer.from(bytes).toString('hex'));
  let encoded = '';

  while (num > 0n) {
    const remainder = Number(num % base);
    encoded = ALPHABET[remainder] + encoded;
    num = num / base;
  }

  // Add leading '1's for leading zero bytes
  for (let i = 0; i < bytes.length && bytes[i] === 0; i++) {
    encoded = '1' + encoded;
  }

  return encoded;
}

/**
 * Simple Base58 decoding
 */
function base58Decode(str: string): Uint8Array {
  const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  const base = BigInt(ALPHABET.length);

  let num = 0n;
  for (const char of str) {
    const digit = ALPHABET.indexOf(char);
    if (digit === -1) {
      throw new Error(`Invalid base58 character: ${char}`);
    }
    num = num * base + BigInt(digit);
  }

  const hex = num.toString(16);
  const bytes = Buffer.from(hex.length % 2 ? '0' + hex : hex, 'hex');

  // Count leading '1's and add zero bytes
  let leadingZeros = 0;
  for (const char of str) {
    if (char === '1') leadingZeros++;
    else break;
  }

  if (leadingZeros === 0) {
    return new Uint8Array(bytes);
  }

  const result = new Uint8Array(leadingZeros + bytes.length);
  result.set(bytes, leadingZeros);
  return result;
}

// ============================================================================
// Logger (minimal for crypto module)
// ============================================================================

const logger = {
  warn: (msg: string, meta?: any) => console.warn(`[crypto] ${msg}`, meta || ''),
  error: (msg: string, meta?: any) => console.error(`[crypto] ${msg}`, meta || ''),
};
