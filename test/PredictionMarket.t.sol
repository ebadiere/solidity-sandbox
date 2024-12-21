// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";

contract PredictionMarketTest is Test {
    PredictionMarket public market;
    address public admin;
    address public user1;
    address public user2;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund test accounts
        vm.deal(admin, INITIAL_BALANCE);
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);

        // Deploy contract
        vm.prank(admin);
        market = new PredictionMarket(admin);
    }

    function test_CreateEvent() public {
        vm.prank(admin);
        market.createEvent();
        assertEq(market.nextEventId(), 1);

        (
            uint256 id,
            uint256 totalYesBets,
            uint256 totalNoBets,
            bool outcomeDeclared,
            bool winningOutcome,
            bool active
        ) = market.getEventDetails(1);

        assertEq(id, 1);
        assertEq(totalYesBets, 0);
        assertEq(totalNoBets, 0);
        assertEq(outcomeDeclared, false);
        assertEq(winningOutcome, false);
        assertEq(active, true);
    }

    function test_CreateEventNonAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Only admin can perform this action");
        market.createEvent();
    }

    function test_PlaceBet() public {
        // Create event first
        vm.prank(admin);
        market.createEvent();

        // Place YES bet
        vm.prank(user1);
        market.placeBet{value: 1 ether}(1, true);
        assertEq(market.getBetAmount(1, user1, true), 1 ether);

        // Place NO bet
        vm.prank(user2);
        market.placeBet{value: 1 ether}(1, false);
        assertEq(market.getBetAmount(1, user2, false), 1 ether);
    }

    function test_PlaceBetInvalidEvent() public {
        vm.prank(user1);
        vm.expectRevert(PredictionMarket.EventDoesNotExist.selector);
        market.placeBet{value: 1 ether}(999, true);
    }

    function test_PlaceBetZeroAmount() public {
        // Create event first
        vm.prank(admin);
        market.createEvent();

        // Try to place bet with zero amount
        vm.prank(user1);
        vm.expectRevert(PredictionMarket.InsufficientBetAmount.selector);
        market.placeBet{value: 0}(1, true);
    }

    function test_DeclareOutcome() public {
        // Create event
        vm.prank(admin);
        market.createEvent();

        // Place bets
        vm.prank(user1);
        market.placeBet{value: 1 ether}(1, true);
        vm.prank(user2);
        market.placeBet{value: 1 ether}(1, false);

        // Declare outcome as admin
        vm.prank(admin);
        market.declareOutcome(1, true);

        (,,, bool outcomeDeclared, bool winningOutcome, bool active) = market.getEventDetails(1);
        assertEq(outcomeDeclared, true);
        assertEq(winningOutcome, true);
        assertEq(active, false);
    }

    function test_DeclareOutcomeNonAdmin() public {
        // Create event
        vm.prank(admin);
        market.createEvent();

        // Try to declare outcome as non-admin
        vm.prank(user1);
        vm.expectRevert("Only admin can perform this action");
        market.declareOutcome(1, true);
    }

    function test_ClaimWinningsYesBet() public {
        // Create event
        vm.prank(admin);
        market.createEvent();

        // Place bets
        vm.prank(user1);
        market.placeBet{value: 5 ether}(1, true);
        vm.prank(user2);
        market.placeBet{value: 3 ether}(1, false);

        // Declare YES as winning outcome
        vm.prank(admin);
        market.declareOutcome(1, true);

        // Record initial balance
        uint256 initialBalance = user1.balance;

        // Claim winnings
        vm.prank(user1);
        market.claimWinnings(1);

        // Winner should receive total pool (8 ETH)
        assertEq(user1.balance, initialBalance + 8 ether);
        assertEq(market.getBetAmount(1, user1, true), 0);
    }

    function test_ClaimWinningsNoBet() public {
        // Create event
        vm.prank(admin);
        market.createEvent();

        // Place bets
        vm.prank(user1);
        market.placeBet{value: 5 ether}(1, true);
        vm.prank(user2);
        market.placeBet{value: 3 ether}(1, false);

        // Declare NO as winning outcome
        vm.prank(admin);
        market.declareOutcome(1, false);

        // Record initial balance
        uint256 initialBalance = user2.balance;

        // Claim winnings
        vm.prank(user2);
        market.claimWinnings(1);

        // Winner should receive total pool (8 ETH)
        assertEq(user2.balance, initialBalance + 8 ether);
        assertEq(market.getBetAmount(1, user2, false), 0);
    }

    function test_ClaimWinningsInvalidEvent() public {
        vm.prank(user1);
        vm.expectRevert(PredictionMarket.EventDoesNotExist.selector);
        market.claimWinnings(999);
    }

    function test_ClaimWinningsBeforeOutcomeDeclared() public {
        // Create event
        vm.prank(admin);
        market.createEvent();

        // Place bet
        vm.prank(user1);
        market.placeBet{value: 5 ether}(1, true);

        // Try to claim before outcome is declared
        vm.prank(user1);
        vm.expectRevert("Outcome not declared");
        market.claimWinnings(1);
    }
}
