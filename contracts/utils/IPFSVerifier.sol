// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPFSVerifier
 * @dev Library for validating IPFS CIDs (Content Identifiers) on-chain
 *
 * Supports both CIDv0 and CIDv1 formats:
 * - CIDv0: Base58-encoded SHA-256 hash (46 characters, starts with "Qm")
 * - CIDv1: Multibase-encoded with codec and hash (variable length)
 *
 * Used by ΨNet contracts to validate IPFS references for:
 * - DID documents
 * - Context graphs
 * - Skill packages
 * - Metadata
 *
 * @author ΨNet Team
 */
library IPFSVerifier {
    // ========================================================================
    // Constants
    // ========================================================================

    /// @dev CIDv0 prefix (always "Qm" in Base58)
    bytes2 private constant CIDv0_PREFIX = "Qm";

    /// @dev CIDv0 length (Base58 SHA-256)
    uint256 private constant CIDv0_LENGTH = 46;

    /// @dev Minimum length for CIDv1
    uint256 private constant CIDv1_MIN_LENGTH = 32;

    /// @dev Maximum reasonable CID length (prevent DoS)
    uint256 private constant MAX_CID_LENGTH = 200;

    /// @dev Valid Base58 characters for CIDv0
    bytes private constant BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    /// @dev Valid Multibase prefixes for CIDv1
    bytes1 private constant MULTIBASE_BASE32 = "b"; // base32 lowercase
    bytes1 private constant MULTIBASE_BASE32_UPPER = "B"; // base32 uppercase
    bytes1 private constant MULTIBASE_BASE58 = "z"; // base58btc
    bytes1 private constant MULTIBASE_BASE64 = "m"; // base64

    // ========================================================================
    // Events
    // ========================================================================

    /// @dev Emitted when CID validation fails (for debugging)
    event CIDValidationFailed(string cid, string reason);

    // ========================================================================
    // Main Validation Functions
    // ========================================================================

    /**
     * @dev Check if a CID is valid (CIDv0 or CIDv1)
     * @param cid The IPFS CID string to validate
     * @return bool True if CID is valid
     */
    function isValidCID(string memory cid) internal pure returns (bool) {
        bytes memory cidBytes = bytes(cid);
        uint256 length = cidBytes.length;

        // Check length bounds
        if (length == 0 || length > MAX_CID_LENGTH) {
            return false;
        }

        // Try CIDv0 validation first (most common)
        if (length == CIDv0_LENGTH && _isValidCIDv0(cidBytes)) {
            return true;
        }

        // Try CIDv1 validation
        if (length >= CIDv1_MIN_LENGTH && _isValidCIDv1(cidBytes)) {
            return true;
        }

        return false;
    }

    /**
     * @dev Get the version of a CID (0 or 1)
     * @param cid The IPFS CID string
     * @return version CID version (0 or 1), or 255 if invalid
     */
    function getCIDVersion(string memory cid) internal pure returns (uint8) {
        bytes memory cidBytes = bytes(cid);
        uint256 length = cidBytes.length;

        if (length == 0) return 255;

        // Check for CIDv0
        if (length == CIDv0_LENGTH && cidBytes[0] == "Q" && cidBytes[1] == "m") {
            return 0;
        }

        // Check for CIDv1 (multibase prefix)
        if (length >= CIDv1_MIN_LENGTH && _isMultibasePrefix(cidBytes[0])) {
            return 1;
        }

        return 255; // Invalid
    }

    /**
     * @dev Validate and normalize a CID string
     * @param cid The IPFS CID to validate
     * @return normalized The normalized CID string
     * @return version The CID version (0 or 1)
     *
     * Requirements:
     * - CID must be valid
     * - Will revert if CID is invalid
     */
    function validateAndNormalize(string memory cid)
        internal
        pure
        returns (string memory normalized, uint8 version)
    {
        require(isValidCID(cid), "Invalid CID format");

        version = getCIDVersion(cid);
        require(version == 0 || version == 1, "Unknown CID version");

        // For now, return as-is. Could add normalization logic here
        // (e.g., convert all CIDv1 to lowercase)
        normalized = cid;
    }

    /**
     * @dev Check if CID is a specific version
     * @param cid The IPFS CID string
     * @param expectedVersion Expected version (0 or 1)
     * @return bool True if CID matches expected version
     */
    function isCIDVersion(string memory cid, uint8 expectedVersion)
        internal
        pure
        returns (bool)
    {
        require(expectedVersion == 0 || expectedVersion == 1, "Invalid version");
        return getCIDVersion(cid) == expectedVersion;
    }

    // ========================================================================
    // CIDv0 Validation
    // ========================================================================

    /**
     * @dev Validate CIDv0 format
     * CIDv0 Format:
     * - Exactly 46 characters
     * - Starts with "Qm"
     * - Base58 encoded SHA-256 hash
     *
     * @param cidBytes CID as bytes
     * @return bool True if valid CIDv0
     */
    function _isValidCIDv0(bytes memory cidBytes) private pure returns (bool) {
        // Must be exactly 46 characters
        if (cidBytes.length != CIDv0_LENGTH) {
            return false;
        }

        // Must start with "Qm"
        if (cidBytes[0] != "Q" || cidBytes[1] != "m") {
            return false;
        }

        // All characters must be valid Base58
        for (uint256 i = 0; i < cidBytes.length; i++) {
            if (!_isBase58Character(cidBytes[i])) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Check if a character is a valid Base58 character
     * @param char Character to check
     * @return bool True if valid Base58 character
     */
    function _isBase58Character(bytes1 char) private pure returns (bool) {
        // Numbers 1-9 (no 0)
        if (char >= "1" && char <= "9") return true;

        // Uppercase letters (no I, O)
        if (char >= "A" && char <= "H") return true;
        if (char >= "J" && char <= "N") return true;
        if (char >= "P" && char <= "Z") return true;

        // Lowercase letters (no l, o)
        if (char >= "a" && char <= "k") return true;
        if (char >= "m" && char <= "z") return true;

        return false;
    }

    // ========================================================================
    // CIDv1 Validation
    // ========================================================================

    /**
     * @dev Validate CIDv1 format
     * CIDv1 Format:
     * - Variable length (minimum 32 characters)
     * - Starts with multibase prefix (b, B, z, m, etc.)
     * - Encodes: <multibase><version><codec><multihash>
     *
     * @param cidBytes CID as bytes
     * @return bool True if valid CIDv1
     */
    function _isValidCIDv1(bytes memory cidBytes) private pure returns (bool) {
        uint256 length = cidBytes.length;

        // Minimum length check
        if (length < CIDv1_MIN_LENGTH) {
            return false;
        }

        // First character must be a valid multibase prefix
        if (!_isMultibasePrefix(cidBytes[0])) {
            return false;
        }

        // Validate based on multibase encoding
        bytes1 prefix = cidBytes[0];

        if (prefix == MULTIBASE_BASE32 || prefix == MULTIBASE_BASE32_UPPER) {
            return _isValidBase32(cidBytes, prefix == MULTIBASE_BASE32_UPPER);
        }

        if (prefix == MULTIBASE_BASE58) {
            // Base58 validation (similar to CIDv0 but without Qm prefix)
            for (uint256 i = 1; i < length; i++) {
                if (!_isBase58Character(cidBytes[i])) {
                    return false;
                }
            }
            return true;
        }

        if (prefix == MULTIBASE_BASE64) {
            return _isValidBase64(cidBytes);
        }

        // Other multibase formats - basic validation
        return true;
    }

    /**
     * @dev Check if byte is a valid multibase prefix
     * @param char Character to check
     * @return bool True if valid multibase prefix
     */
    function _isMultibasePrefix(bytes1 char) private pure returns (bool) {
        // Common multibase prefixes
        return (
            char == "b" || // base32 lowercase
            char == "B" || // base32 uppercase
            char == "z" || // base58btc
            char == "m" || // base64
            char == "f" || // base16 (hex) lowercase
            char == "F" || // base16 (hex) uppercase
            char == "u" || // base64url
            char == "U"    // base64url-pad
        );
    }

    /**
     * @dev Validate Base32 encoding
     * @param cidBytes CID bytes (including multibase prefix)
     * @param isUpperCase True if uppercase Base32
     * @return bool True if valid Base32
     */
    function _isValidBase32(bytes memory cidBytes, bool isUpperCase)
        private
        pure
        returns (bool)
    {
        // Skip multibase prefix
        for (uint256 i = 1; i < cidBytes.length; i++) {
            bytes1 char = cidBytes[i];

            if (isUpperCase) {
                // A-Z, 2-7
                if (!((char >= "A" && char <= "Z") || (char >= "2" && char <= "7"))) {
                    return false;
                }
            } else {
                // a-z, 2-7
                if (!((char >= "a" && char <= "z") || (char >= "2" && char <= "7"))) {
                    return false;
                }
            }
        }

        return true;
    }

    /**
     * @dev Validate Base64 encoding
     * @param cidBytes CID bytes (including multibase prefix)
     * @return bool True if valid Base64
     */
    function _isValidBase64(bytes memory cidBytes) private pure returns (bool) {
        // Skip multibase prefix
        for (uint256 i = 1; i < cidBytes.length; i++) {
            bytes1 char = cidBytes[i];

            // Valid Base64: A-Z, a-z, 0-9, +, /, =
            bool valid = (
                (char >= "A" && char <= "Z") ||
                (char >= "a" && char <= "z") ||
                (char >= "0" && char <= "9") ||
                char == "+" ||
                char == "/" ||
                char == "="
            );

            if (!valid) {
                return false;
            }
        }

        return true;
    }

    // ========================================================================
    // Helper Functions for Contracts
    // ========================================================================

    /**
     * @dev Require CID to be valid, revert otherwise
     * @param cid CID to validate
     * @param errorMessage Custom error message
     */
    function requireValidCID(string memory cid, string memory errorMessage) internal pure {
        require(isValidCID(cid), errorMessage);
    }

    /**
     * @dev Require CID to be valid (default error message)
     * @param cid CID to validate
     */
    function requireValidCID(string memory cid) internal pure {
        require(isValidCID(cid), "Invalid IPFS CID");
    }

    /**
     * @dev Check if two CIDs are equal
     * @param cid1 First CID
     * @param cid2 Second CID
     * @return bool True if CIDs are identical
     */
    function areCIDsEqual(string memory cid1, string memory cid2)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(cid1)) == keccak256(bytes(cid2));
    }

    /**
     * @dev Extract CID from a full IPFS URL
     * Examples:
     * - "ipfs://QmXxx..." → "QmXxx..."
     * - "https://ipfs.io/ipfs/QmXxx" → "QmXxx..."
     *
     * @param url IPFS URL
     * @return cid Extracted CID
     */
    function extractCIDFromURL(string memory url) internal pure returns (string memory cid) {
        bytes memory urlBytes = bytes(url);

        // Check for "ipfs://" prefix
        if (urlBytes.length > 7 &&
            urlBytes[0] == "i" &&
            urlBytes[1] == "p" &&
            urlBytes[2] == "f" &&
            urlBytes[3] == "s" &&
            urlBytes[4] == ":" &&
            urlBytes[5] == "/" &&
            urlBytes[6] == "/") {
            // Extract everything after "ipfs://"
            bytes memory cidBytes = new bytes(urlBytes.length - 7);
            for (uint256 i = 7; i < urlBytes.length; i++) {
                cidBytes[i - 7] = urlBytes[i];
            }
            return string(cidBytes);
        }

        // For HTTP URLs, find last "/" and extract CID
        // This is a simplified version - production should be more robust
        for (uint256 i = urlBytes.length - 1; i > 0; i--) {
            if (urlBytes[i] == "/") {
                bytes memory cidBytes = new bytes(urlBytes.length - i - 1);
                for (uint256 j = i + 1; j < urlBytes.length; j++) {
                    cidBytes[j - i - 1] = urlBytes[j];
                }
                return string(cidBytes);
            }
        }

        // If no prefix found, assume it's already a CID
        return url;
    }

    /**
     * @dev Get CID length
     * @param cid CID string
     * @return length Length in bytes
     */
    function getCIDLength(string memory cid) internal pure returns (uint256) {
        return bytes(cid).length;
    }
}
