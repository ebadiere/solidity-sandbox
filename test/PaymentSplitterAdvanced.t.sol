// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PaymentSplitterAdvanced.sol";

contract PaymentSplitterAdvancedTest is Test {
    PaymentSplitterAdvanced public splitter;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        // Fund test addresses
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(address(this), 100 ether);
    }

    function testConstructorSuccess() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory _shares = new uint256[](3);
        _shares[0] = 50;  // 50%
        _shares[1] = 30;  // 30%
        _shares[2] = 20;  // 20%

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
    }

    function testSplitPayment() public {
        // Setup splitter with 50-30-20 split
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory _shares = new uint256[](3);
        _shares[0] = 50;
        _shares[1] = 30;
        _shares[2] = 20;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);

        // Record initial balances
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;
        uint256 charlieInitial = charlie.balance;

        // Send 100 ETH to split
        uint256 amountToSplit = 100 ether;
        splitter.splitPayment{value: amountToSplit}();

        // Verify balances
        assertEq(alice.balance, aliceInitial + (amountToSplit * 50 / 100), "Alice balance incorrect");
        assertEq(bob.balance, bobInitial + (amountToSplit * 30 / 100), "Bob balance incorrect");
        assertEq(charlie.balance, charlieInitial + (amountToSplit * 20 / 100), "Charlie balance incorrect");
    }

    function testFailConstructorZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);  // zero address
        recipients[1] = bob;

        uint256[] memory _shares = new uint256[](2);
        _shares[0] = 50;
        _shares[1] = 50;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
    }

    function testFailConstructorDuplicateRecipient() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = alice;  // duplicate

        uint256[] memory _shares = new uint256[](2);
        _shares[0] = 50;
        _shares[1] = 50;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
    }

    function testFailConstructorArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory _shares = new uint256[](1);
        _shares[0] = 100;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
    }

    function testFailConstructorZeroShares() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory _shares = new uint256[](2);
        _shares[0] = 0;  // zero share
        _shares[1] = 100;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
    }

    function testFailSplitPaymentSharesNot100() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory _shares = new uint256[](2);
        _shares[0] = 50;
        _shares[1] = 40;  // total 90, not 100

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
        splitter.splitPayment{value: 1 ether}();
    }

    function testFailSplitPaymentZeroValue() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory _shares = new uint256[](2);
        _shares[0] = 50;
        _shares[1] = 50;

        splitter = new PaymentSplitterAdvanced(recipients, _shares);
        vm.expectRevert("PaymentSplitterAdvanced: zero value");
        splitter.splitPayment{value: 0}();
    }

    function testSplitPaymentValidation() public {
        // Setup splitter with invalid shares (total 90 instead of 100)
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory _shares = new uint256[](3);
        _shares[0] = 40;  // Changed to make total != 100
        _shares[1] = 30;
        _shares[2] = 20;  // Total is now 90

        splitter = new PaymentSplitterAdvanced(recipients, _shares);

        // Record initial balances
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;
        uint256 charlieInitial = charlie.balance;

        // Send ETH and expect revert due to invalid total shares
        uint256 amountToSplit = 100 ether;
        vm.expectRevert("Total shares must equal 100");
        splitter.splitPayment{value: amountToSplit}();

        // Verify balances haven't changed
        assertEq(alice.balance, aliceInitial, "Alice balance incorrect");
        assertEq(bob.balance, bobInitial, "Bob balance incorrect");
        assertEq(charlie.balance, charlieInitial, "Charlie balance incorrect");
    }

    receive() external payable {}
}
