// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MultisigWalletAdvanced} from "../src/MultisigWalletAdvanced.sol";

contract MultisigHandler is Test {
    MultisigWalletAdvanced public wallet;
    address[] internal _owners;
    address[] internal _nonOwners;
    uint256 internal constant NUM_OWNERS = 3;
    uint256 internal constant NUM_NON_OWNERS = 3;

    constructor(MultisigWalletAdvanced _wallet) {
        wallet = _wallet;

        // Setup owners (using deterministic addresses for reproducibility)
        for(uint256 i = 1; i <= NUM_OWNERS; i++) {
            _owners.push(vm.addr(i));
        }

        // Setup non-owners
        for(uint256 i = 100; i < 100 + NUM_NON_OWNERS; i++) {
            _nonOwners.push(vm.addr(i));
        }

        // Fund the wallet
        vm.deal(address(wallet), 100 ether);
    }

    function generateSignatures(
        address recipient,
        uint256 amount,
        uint256 numSigners
    ) internal view returns (bytes[] memory) {
        require(numSigners <= NUM_OWNERS, "Too many signers requested");

        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        bytes[] memory signatures = new bytes[](numSigners);
        for(uint256 i = 0; i < numSigners; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(i + 1, ethSignedHash); // Use owner private keys
            signatures[i] = abi.encodePacked(r, s, v);
        }

        return signatures;
    }

    function generateNonOwnerSignatures(
        address recipient,
        uint256 amount,
        uint256 numSigners
    ) internal view returns (bytes[] memory) {
        require(numSigners <= NUM_NON_OWNERS, "Too many signers requested");

        bytes32 txHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));

        bytes[] memory signatures = new bytes[](numSigners);
        for(uint256 i = 0; i < numSigners; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(i + 100, ethSignedHash); // Use non-owner private keys
            signatures[i] = abi.encodePacked(r, s, v);
        }

        return signatures;
    }

    function triggerValidTransaction(uint256 amount) external {
        // Bound amount to wallet balance
        amount = bound(amount, 0, address(wallet).balance);
        if (amount == 0) return;

        address recipient = vm.addr(999);
        bytes[] memory signatures = generateSignatures(recipient, amount, wallet.quorum());

        wallet.triggerTransaction(recipient, amount, signatures);
    }

    function triggerInvalidTransaction(uint256 amount) external {
        // Try to spend more than wallet balance
        amount = bound(amount, address(wallet).balance + 1, type(uint256).max);
        
        address recipient = vm.addr(999);
        bytes[] memory signatures = generateSignatures(recipient, amount, wallet.quorum());

        try wallet.triggerTransaction(recipient, amount, signatures) {
            revert("Transaction should have failed");
        } catch {}
    }

    function triggerTransactionWithInsufficientSignatures(uint256 amount) external {
        amount = bound(amount, 0, address(wallet).balance);
        if (amount == 0) return;

        address recipient = vm.addr(999);
        bytes[] memory signatures = generateSignatures(recipient, amount, wallet.quorum() - 1);

        try wallet.triggerTransaction(recipient, amount, signatures) {
            revert("Transaction should have failed");
        } catch {}
    }

    function triggerTransactionWithNonOwnerSignatures(uint256 amount) external {
        amount = bound(amount, 0, address(wallet).balance);
        if (amount == 0) return;

        address recipient = vm.addr(999);
        bytes[] memory signatures = generateNonOwnerSignatures(recipient, amount, wallet.quorum());

        try wallet.triggerTransaction(recipient, amount, signatures) {
            revert("Transaction should have failed");
        } catch {}
    }

    receive() external payable {}
}

contract MultisigWalletAdvancedInvariantTest is StdInvariant, Test {
    MultisigWalletAdvanced public wallet;
    MultisigHandler public handler;
    address[] internal _owners;

    function setUp() public {
        // Setup owners
        for(uint256 i = 1; i <= 3; i++) {
            _owners.push(vm.addr(i));
        }

        // Deploy wallet with quorum of 2
        wallet = new MultisigWalletAdvanced(_owners, 2);
        
        // Setup handler
        handler = new MultisigHandler(wallet);

        // Target handler for invariant testing
        targetContract(address(handler));

        // Fund wallet
        vm.deal(address(wallet), 100 ether);
    }

    function invariant_balanceIsNeverNegative() public {
        assertGe(address(wallet).balance, 0);
    }

    function invariant_quorumNeverExceedsOwners() public {
        assertLe(wallet.quorum(), _owners.length);
    }

    function invariant_quorumIsNeverZero() public {
        assertGt(wallet.quorum(), 0);
    }

    function invariant_ownerCountNeverChanges() public {
        assertEq(_owners.length, 3);
        for(uint256 i = 0; i < _owners.length; i++) {
            assertEq(wallet.owners(i), _owners[i]);
        }
    }
}
