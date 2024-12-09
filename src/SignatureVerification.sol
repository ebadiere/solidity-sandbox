// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SignatureVerification {
    /**
     * @dev Verifies if a message was signed by the specified address
     * @param _message The original message that was signed
     * @param _signature The signature (65 bytes = r + s + v)
     * @param _signer The expected signer address
     * @return bool indicating if the signature is valid
     */
    function verifySignature(
        bytes memory _message,
        bytes memory _signature,
        address _signer
    ) public pure returns (bool) {
        require(_signature.length == 65, "Invalid signature length");
        
        // Create message hash
        bytes32 messageHash = keccak256(_message);
        
        // Create ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Extract signature components
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        
        // If v is 0 or 1, convert it to 27 or 28
        if (v < 27) {
            v += 27;
        }
        
        // Verify v is either 27 or 28
        require(v == 27 || v == 28, "Invalid signature v value");

        // Recover signer address
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);
        
        // Ensure recovered address is not 0x0
        require(recoveredSigner != address(0), "Invalid signature");
        
        return recoveredSigner == _signer;
    }
}