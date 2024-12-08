// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Fundraiser} from "../src/Fundraiser.sol";

contract FundraiserTest is Test {
    Fundraiser public fundraiser;
    address public organizer;
    address public contributor1;
    address public contributor2;
    uint256 public constant GOAL = 100 ether;

    function setUp() public {
        organizer = makeAddr("organizer");
        contributor1 = makeAddr("contributor1");
        contributor2 = makeAddr("contributor2");
        
        vm.prank(organizer);
        fundraiser = new Fundraiser(organizer, GOAL);
    }

    function test_Constructor() public {
        assertEq(fundraiser.getGoal(), GOAL);
    }

    function test_Contribute() public {
        uint256 contribution = 1 ether;
        
        vm.deal(contributor1, contribution);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution}();

        assertEq(address(fundraiser).balance, contribution);
        assertEq(fundraiser.getContribution(contributor1), contribution);
        assertEq(fundraiser.contributorList(0), contributor1);
    }

    function test_MultipleContributions() public {
        uint256 contribution1 = 1 ether;
        uint256 contribution2 = 2 ether;
        
        // First contribution
        vm.deal(contributor1, contribution1);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution1}();

        // Second contribution from same contributor
        vm.deal(contributor1, contribution2);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution2}();

        assertEq(address(fundraiser).balance, contribution1 + contribution2);
        assertEq(fundraiser.getContribution(contributor1), contribution1 + contribution2);
        assertEq(fundraiser.contributorList(0), contributor1);
    }

    function test_GoalReached() public {
        vm.deal(contributor1, GOAL);
        vm.prank(contributor1);
        fundraiser.contribute{value: GOAL}();

        vm.prank(organizer);
        fundraiser.withdraw();

        assertEq(address(fundraiser).balance, 0);
        assertEq(address(organizer).balance, GOAL);
    }

    function test_WithdrawBeforeGoal() public {
        uint256 contribution = GOAL - 1 ether;
        vm.deal(contributor1, contribution);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution}();

        vm.prank(organizer);
        vm.expectRevert("Goal not reached");
        fundraiser.withdraw();
    }

    function test_WithdrawByNonOrganizer() public {
        vm.deal(contributor1, GOAL);
        vm.prank(contributor1);
        fundraiser.contribute{value: GOAL}();

        vm.prank(contributor1);
        vm.expectRevert("Only organizer can withdraw funds");
        fundraiser.withdraw();
    }

    function test_Refund() public {
        uint256 contribution1 = 1 ether;
        uint256 contribution2 = 2 ether;
        
        // Setup contributions
        vm.deal(contributor1, contribution1);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution1}();

        vm.deal(contributor2, contribution2);
        vm.prank(contributor2);
        fundraiser.contribute{value: contribution2}();

        // Record balances before refund
        uint256 contributor1BalanceBefore = contributor1.balance;
        uint256 contributor2BalanceBefore = contributor2.balance;

        // Perform refund
        vm.prank(organizer);
        fundraiser.refund();

        // Verify refunds
        assertEq(contributor1.balance, contributor1BalanceBefore + contribution1);
        assertEq(contributor2.balance, contributor2BalanceBefore + contribution2);
        assertEq(address(fundraiser).balance, 0);
    }

    function test_RefundAfterGoalReached() public {
        vm.deal(contributor1, GOAL);
        vm.prank(contributor1);
        fundraiser.contribute{value: GOAL}();

        vm.prank(organizer);
        vm.expectRevert("Goal already reached");
        fundraiser.refund();
    }

    function test_RefundByNonOrganizer() public {
        uint256 contribution = 1 ether;
        vm.deal(contributor1, contribution);
        vm.prank(contributor1);
        fundraiser.contribute{value: contribution}();

        vm.prank(contributor1);
        vm.expectRevert("Only organizer can refund funds");
        fundraiser.refund();
    }

    receive() external payable {}
}
