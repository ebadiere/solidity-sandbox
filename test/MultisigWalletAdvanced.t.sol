// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MultisigWalletAdvanced} from "../src/MultisigWalletAdvanced.sol";

contract MultisigWalletAdvancedTest is Test {
    MultisigWalletAdvanced public wallet;
    address[] public owners;
    uint256 public constant QUORUM = 2;
    
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    
    function setUp() public {
        // Create owner addresses
        owner1 = vm.addr(1); // Use vm.addr to get the address for private key 1
        owner2 = vm.addr(2); // Use vm.addr to get the address for private key 2
        owner3 = vm.addr(3); // Use vm.addr to get the address for private key 3
        nonOwner = vm.addr(999); // Use vm.addr to get the address for private key 999
        
        // Fund owners
        vm.deal(owner1, 100 ether);
        vm.deal(owner2, 100 ether);
        vm.deal(owner3, 100 ether);
        
        // Setup owners array
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);
        
        // Deploy wallet
        wallet = new MultisigWalletAdvanced(owners, QUORUM);
        
        // Fund wallet
        vm.deal(address(wallet), 10 ether);
    }
    
    function testConstructorSuccess() public {
        assertEq(wallet.owners(0), owner1);
        assertEq(wallet.owners(1), owner2);
        assertEq(wallet.owners(2), owner3);
        assertEq(wallet.quorum(), QUORUM);
    }
    
    function testConstructorFailQuorumTooHigh() public {
        uint256 tooHighQuorum = owners.length + 1;
        vm.expectRevert(MultisigWalletAdvanced.quorumCannotExceedOwners.selector);
        new MultisigWalletAdvanced(owners, tooHighQuorum);
    }
    
    function testTriggerTransactionSuccess() public {
        address recipient = vm.addr(4); // Use vm.addr to get the address for private key 4
        uint256 amount = 1 ether;
        
        // Create transaction hash
        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        
        // Generate signatures from owner1 and owner2
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, ethSignedHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(2, ethSignedHash);
        
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1);
        signatures[1] = abi.encodePacked(r2, s2, v2);
        
        uint256 recipientBalanceBefore = recipient.balance;
        
        // Execute transaction
        wallet.triggerTransaction(recipient, amount, signatures);
        
        assertEq(recipient.balance, recipientBalanceBefore + amount);
    }
    
    function testTriggerTransactionFailInsufficientSignatures() public {
        address recipient = vm.addr(4); // Use vm.addr to get the address for private key 4
        uint256 amount = 1 ether;
        
        bytes[] memory signatures = new bytes[](1);
        
        // Create transaction hash and get one valid signature
        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethSignedHash);
        signatures[0] = abi.encodePacked(r, s, v);
        
        vm.expectRevert(MultisigWalletAdvanced.signatureQuorumNotMet.selector);
        wallet.triggerTransaction(recipient, amount, signatures);
    }
    
    function testTriggerTransactionFailDuplicateSignature() public {
        address recipient = vm.addr(4); // Use vm.addr to get the address for private key 4
        uint256 amount = 1 ether;
        
        // Create transaction hash
        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        
        // Generate signature from owner1 twice
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, ethSignedHash);
        
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1);
        signatures[1] = abi.encodePacked(r1, s1, v1); // Same signature
        
        vm.expectRevert(MultisigWalletAdvanced.duplicateSignature.selector);
        wallet.triggerTransaction(recipient, amount, signatures);
    }
    
    function testTriggerTransactionFailNonOwnerSignature() public {
        address recipient = vm.addr(4); // Use vm.addr to get the address for private key 4
        uint256 amount = 1 ether;
        
        // Create transaction hash
        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
        
        // Generate signatures from owner1 and non-owner
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(1, ethSignedHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(999, ethSignedHash); // non-owner private key
        
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = abi.encodePacked(r1, s1, v1);
        signatures[1] = abi.encodePacked(r2, s2, v2);
        
        vm.expectRevert(MultisigWalletAdvanced.notAnOwner.selector);
        wallet.triggerTransaction(recipient, amount, signatures);
    }
}
