// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultisigWalletSimple.sol";

contract MultisigWalletSimpleTest is Test {
    MultisigWalletSimple public wallet;
    address public admin = address(0x1);
    address public owner1 = address(0x2);
    address public owner2 = address(0x3);
    address public owner3 = address(0x4);
    address public nonOwner = address(0x5);
    address public recipient = address(0x6);
    uint256 public constant QUORUM = 2;

    function setUp() public {
        // Fund test addresses
        vm.deal(address(this), 100 ether);
        
        // Deploy wallet as admin
        vm.prank(admin);
        wallet = new MultisigWalletSimple();
        
        // Setup owner array
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // Setup wallet with admin
        vm.startPrank(admin);
        wallet.updateOwners(owners);
        wallet.updateQuorum(QUORUM);
        vm.stopPrank();

        // Fund the wallet
        (bool success,) = address(wallet).call{value: 10 ether}("");
        require(success, "Funding failed");
    }

    function testSubmitProposal() public {
        string memory description = "Test proposal";
        vm.prank(admin);
        wallet.submitProposal(description, 1 ether, recipient);
        
        (string memory prop_description, uint256 amount, address prop_recipient, bool executed, uint256 votes) = wallet.proposals(0);
        assertEq(prop_description, description);
        assertEq(amount, 1 ether);
        assertEq(prop_recipient, recipient);
        assertEq(votes, 0);
        assertFalse(executed);
    }

    function testOnlyAdminCanSubmitProposal() public {
        vm.prank(nonOwner);
        vm.expectRevert("Only admin can perform this action");
        wallet.submitProposal("Test", 1 ether, recipient);
    }

    function testVoting() public {
        vm.startPrank(admin);
        // Create proposal
        wallet.submitProposal("Test proposal", 1 ether, recipient);
        vm.stopPrank();
        
        uint256 recipientBalanceBefore = recipient.balance;
        
        // First vote
        vm.prank(owner1);
        wallet.vote(0, true);
        
        // Check votes
        (,,,, uint256 votes) = wallet.proposals(0);
        assertEq(votes, 1);
        
        // Second vote - should execute
        vm.prank(owner2);
        wallet.vote(0, true);
        
        // Check execution
        (,,, bool executed,) = wallet.proposals(0);
        assertTrue(executed);
        assertEq(recipient.balance - recipientBalanceBefore, 1 ether);
    }

    function testCannotVoteTwice() public {
        // Create proposal
        vm.prank(admin);
        wallet.submitProposal("Test proposal", 1 ether, recipient);
        
        // First vote
        vm.prank(owner1);
        wallet.vote(0, true);
        
        // Try to vote again
        vm.prank(owner1);
        vm.expectRevert("You have already voted");
        wallet.vote(0, true);
    }

    function testNonOwnerCannotVote() public {
        // Create proposal
        vm.prank(admin);
        wallet.submitProposal("Test proposal", 1 ether, recipient);
        
        // Try to vote as non-owner
        vm.prank(nonOwner);
        vm.expectRevert("Only owners can vote");
        wallet.vote(0, true);
    }

    function testCannotVoteOnInvalidProposal() public {
        vm.prank(owner1);
        vm.expectRevert("Invalid proposal ID");
        wallet.vote(999, true);
    }

    function testCannotVoteAfterPeriod() public {
        // Create proposal
        vm.prank(admin);
        wallet.submitProposal("Test proposal", 1 ether, recipient);
        
        // Move time forward past voting period
        skip(1 days + 1);
        
        // Try to vote
        vm.prank(owner1);
        vm.expectRevert("Voting period has ended");
        wallet.vote(0, true);
    }

    function testUpdateOwners() public {
        address[] memory newOwners = new address[](2);
        newOwners[0] = address(0x10);
        newOwners[1] = address(0x11);
        
        vm.prank(admin);
        wallet.updateOwners(newOwners);
        
        // Create a proposal first
        vm.prank(admin);
        wallet.submitProposal("Test proposal", 1 ether, recipient);
        
        // Old owner should not be able to vote
        vm.prank(owner1);
        vm.expectRevert("Only owners can vote");
        wallet.vote(0, true);
        
        // New owner should be able to vote
        vm.prank(address(0x10));
        wallet.vote(0, true);
    }

    receive() external payable {}
}
