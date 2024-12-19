// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Dao.sol";

// Mock contract to test proposal execution
contract MockTarget {
    uint public value;
    
    function setValue(uint _value) external {
        value = _value;
    }
}

contract DaoTest is Test {
    Dao dao;
    MockTarget mockTarget;
    address alice = address(0x1);
    address bob = address(0x2);
    
    function setUp() public {
        dao = new Dao(1000); // Initialize with 1000 shares
        mockTarget = new MockTarget();
        
        // Give some initial shares to Alice and Bob
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        dao.buyShares{value: 1 ether}(100);
        vm.stopPrank();
        
        vm.startPrank(bob);
        vm.deal(bob, 10 ether);
        dao.buyShares{value: 0.5 ether}(50);
        vm.stopPrank();
    }
    
    function testProposalCreationAndVoting() public {
        // Create a proposal to set value in mock contract
        bytes memory action = abi.encodeWithSignature("setValue(uint256)", 42);
        
        vm.startPrank(alice);
        dao.createProposal("Set value to 42", action, address(mockTarget));
        
        // Vote in favor with Alice's shares (100)
        dao.vote(0, true);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // Vote against with Bob's shares (50)
        dao.vote(0, false);
        vm.stopPrank();
        
        // Fast forward past voting period
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Execute the proposal
        dao.executeProposal(0);
        
        // Verify the mock contract's value was updated
        assertEq(mockTarget.value(), 42, "Proposal execution failed to update value");
    }
    
    function testFailDoubleVoting() public {
        bytes memory action = abi.encodeWithSignature("setValue(uint256)", 42);
        
        vm.startPrank(alice);
        dao.createProposal("Set value to 42", action, address(mockTarget));
        
        // First vote should succeed
        dao.vote(0, true);
        
        // Second vote should fail
        vm.expectRevert("Already voted");
        dao.vote(0, true);
        vm.stopPrank();
    }
    
    function testFailEarlyExecution() public {
        bytes memory action = abi.encodeWithSignature("setValue(uint256)", 42);
        
        vm.startPrank(alice);
        dao.createProposal("Set value to 42", action, address(mockTarget));
        dao.vote(0, true);
        
        // Try to execute before voting period ends
        vm.expectRevert("Voting period has not ended");
        dao.executeProposal(0);
        vm.stopPrank();
    }
    
    function testFailExecuteFailedProposal() public {
        bytes memory action = abi.encodeWithSignature("setValue(uint256)", 42);
        
        vm.startPrank(alice);
        dao.createProposal("Set value to 42", action, address(mockTarget));
        vm.stopPrank();
        
        vm.startPrank(bob);
        dao.vote(0, false);
        vm.stopPrank();
        
        // Wait for voting period to end
        vm.warp(block.timestamp + dao.VOTING_PERIOD() + 1);
        
        // Try to execute failed proposal
        vm.expectRevert("Not enough votes for execution");
        dao.executeProposal(0);
    }
}
