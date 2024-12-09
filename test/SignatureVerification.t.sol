// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SignatureVerification} from "../src/SignatureVerification.sol";

contract SignatureVerificationTest is Test {
    SignatureVerification public verifier;
    uint256 internal signerPrivateKey;
    address internal signer;
    
    function setUp() public {
        verifier = new SignatureVerification();
        
        // Create a consistent private key for testing
        signerPrivateKey = 0xA11CE;
        signer = vm.addr(signerPrivateKey);
    }

    function testValidSignature() public {
        // Create a test message
        bytes memory message = abi.encodePacked("Hello, World!");
        
        // Hash the message
        bytes32 messageHash = keccak256(message);
        
        // Create ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        
        // Sign the message using the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        
        // Concatenate signature components
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verify the signature
        bool isValid = verifier.verifySignature(message, signature, signer);
        assertTrue(isValid, "Signature should be valid");
    }

    function testInvalidSigner() public {
        // Create a test message
        bytes memory message = abi.encodePacked("Hello, World!");
        
        // Hash the message
        bytes32 messageHash = keccak256(message);
        
        // Create ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        
        // Sign the message using the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        
        // Concatenate signature components
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Try to verify with wrong address
        address wrongAddress = address(0x1234);
        bool isValid = verifier.verifySignature(message, signature, wrongAddress);
        assertFalse(isValid, "Signature should be invalid for wrong address");
    }

    function testInvalidSignatureLength() public {
        bytes memory message = abi.encodePacked("Hello, World!");
        bytes memory invalidSignature = abi.encodePacked("invalid");
        
        vm.expectRevert("Invalid signature length");
        verifier.verifySignature(message, invalidSignature, signer);
    }

    function testModifiedMessage() public {
        // Sign original message
        bytes memory originalMessage = abi.encodePacked("Hello, World!");
        bytes32 messageHash = keccak256(originalMessage);
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Try to verify with modified message
        bytes memory modifiedMessage = abi.encodePacked("Hello, Modified World!");
        bool isValid = verifier.verifySignature(modifiedMessage, signature, signer);
        assertFalse(isValid, "Signature should be invalid for modified message");
    }
}
