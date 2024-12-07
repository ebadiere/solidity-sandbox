// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultisigWalletSimple.sol";

contract MultisigWalletInvariantTest is Test {
    MultisigWalletSimple public wallet;
    address[] public actors;
    address public admin;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        // Setup initial actors
        admin = address(0x1);
        actors.push(address(0x2));
        actors.push(address(0x3));
        actors.push(address(0x4));

        // Deploy and setup wallet
        vm.startPrank(admin);
        wallet = new MultisigWalletSimple();
        wallet.updateOwners(actors);
        wallet.updateQuorum(2);
        vm.stopPrank();

        // Fund the wallet
        vm.deal(address(wallet), INITIAL_BALANCE);

        // Label addresses for better trace output
        vm.label(admin, "Admin");
        vm.label(address(wallet), "Wallet");
        for (uint i = 0; i < actors.length; i++) {
            vm.label(actors[i], string.concat("Actor", vm.toString(i)));
        }
    }

    function invariant_contractBalanceSufficientForProposals() public {
        uint256 totalPendingAmount = 0;
        uint256 nextProposalId = wallet.nextProposalId();
        
        // Sum up all non-executed proposals
        for (uint256 i = 0; i < nextProposalId; i++) {
            (,uint256 amount,, bool executed,) = wallet.proposals(i);
            if (!executed) {
                totalPendingAmount += amount;
            }
        }

        // Contract balance should be >= sum of pending proposal amounts
        assertGe(address(wallet).balance, totalPendingAmount, "Insufficient balance for pending proposals");
    }

    function invariant_executedProposalsStayExecuted() public {
        uint256 nextProposalId = wallet.nextProposalId();
        
        for (uint256 i = 0; i < nextProposalId; i++) {
            (,,, bool executed,) = wallet.proposals(i);
            if (executed) {
                // Store current execution status
                bool wasExecuted = executed;
                
                // Try to execute through voting
                for (uint j = 0; j < actors.length; j++) {
                    try wallet.vote(i, true) {} catch {}
                }
                
                // Check execution status hasn't changed
                (,,, bool isExecuted,) = wallet.proposals(i);
                assertEq(isExecuted, wasExecuted, "Executed proposal status changed");
            }
        }
    }

    function invariant_votesNotExceedOwners() public {
        uint256 nextProposalId = wallet.nextProposalId();
        uint256 ownerCount = actors.length;
        
        for (uint256 i = 0; i < nextProposalId; i++) {
            (,,,, uint256 votes) = wallet.proposals(i);
            assertLe(votes, ownerCount, "Votes exceed number of owners");
        }
    }

    function invariant_quorumValid() public {
        uint256 ownerCount = actors.length;
        uint256 currentQuorum = wallet.quorum();
        
        assertTrue(currentQuorum > 0, "Quorum must be greater than 0");
        assertLe(currentQuorum, ownerCount, "Quorum cannot exceed owner count");
    }

    function invariant_calldataConsistency() public {
        // Ensure proposal recipient is never address(0)
        uint256 nextProposalId = wallet.nextProposalId();
        for (uint256 i = 0; i < nextProposalId; i++) {
            (,, address recipient,,) = wallet.proposals(i);
            assertTrue(recipient != address(0), "Proposal recipient cannot be zero address");
        }
    }

    receive() external payable {}
}
