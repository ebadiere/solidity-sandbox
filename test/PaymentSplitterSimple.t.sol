// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PaymentSplitterSimple.sol";

contract PaymentSplitterSimpleTest is Test {
    PaymentSplitterSimple public splitter;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        splitter = new PaymentSplitterSimple();
        // Fund test addresses
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function testBasicSplit() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        uint256 totalAmount = 3 ether;
        
        // Record initial balances
        uint256 aliceInitialBalance = alice.balance;
        uint256 bobInitialBalance = bob.balance;

        // Make the split payment
        splitter.splitPayment{value: totalAmount}(recipients, amounts);

        // Verify balances
        assertEq(alice.balance, aliceInitialBalance + 1 ether);
        assertEq(bob.balance, bobInitialBalance + 2 ether);
    }

    function testSplitWithExcessEth() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;

        // Send more ETH than needed
        uint256 totalAmount = 3 ether;
        uint256 senderInitialBalance = address(this).balance;
        
        splitter.splitPayment{value: totalAmount}(recipients, amounts);

        // Verify excess was returned
        assertEq(address(this).balance, senderInitialBalance - 2 ether);
    }

    function testFailInsufficientEth() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2 ether;
        amounts[1] = 2 ether;

        // Send less ETH than needed
        splitter.splitPayment{value: 3 ether}(recipients, amounts);
    }

    function testFailArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        splitter.splitPayment{value: 1 ether}(recipients, amounts);
    }

    function testFailZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);  // zero address
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;

        splitter.splitPayment{value: 2 ether}(recipients, amounts);
    }

    receive() external payable {}
}
