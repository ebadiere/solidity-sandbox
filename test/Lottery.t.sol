// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    address public manager;
    address[] public players;
    uint256 public constant TICKET_PRICE = 0.1 ether;
    uint256 public lotteryEndTime;

    event WinnerPicked(address indexed winner, uint256 amount);

    function setUp() public {
        manager = makeAddr("manager");
        vm.startPrank(manager);
        
        // Set lottery end time to 1 day from now
        lotteryEndTime = block.timestamp + 1 days;
        lottery = new Lottery(lotteryEndTime);
        
        vm.stopPrank();

        // Create test players
        for(uint i = 0; i < 3; i++) {
            players.push(makeAddr(string(abi.encodePacked("player", vm.toString(i)))));
        }
    }

    function test_Constructor() public {
        assertEq(lottery.manager(), manager);
        assertEq(lottery.lotteryEndTime(), lotteryEndTime);
        assertFalse(lottery.lotteryFinished());
    }

    function test_Enter() public {
        address player = players[0];
        vm.deal(player, TICKET_PRICE);
        
        vm.prank(player);
        lottery.enter{value: TICKET_PRICE}();

        assertEq(lottery.getPlayers().length, 1);
        assertEq(lottery.getPlayers()[0], player);
        assertEq(lottery.getLotteryBalance(), TICKET_PRICE);
    }

    function test_EnterMultiplePlayers() public {
        for(uint i = 0; i < players.length; i++) {
            vm.deal(players[i], TICKET_PRICE);
            vm.prank(players[i]);
            lottery.enter{value: TICKET_PRICE}();
        }

        assertEq(lottery.getPlayers().length, players.length);
        assertEq(lottery.getLotteryBalance(), TICKET_PRICE * players.length);
    }

    function testFail_EnterWithWrongAmount() public {
        address player = players[0];
        vm.deal(player, 1 ether);
        
        vm.prank(player);
        lottery.enter{value: 0.2 ether}();
    }

    function testFail_EnterAfterEndTime() public {
        address player = players[0];
        vm.deal(player, TICKET_PRICE);
        
        // Warp to after lottery end time
        vm.warp(lotteryEndTime + 1);
        
        vm.prank(player);
        lottery.enter{value: TICKET_PRICE}();
    }

    function test_PickWinner() public {
        // Enter players
        for(uint i = 0; i < players.length; i++) {
            vm.deal(players[i], TICKET_PRICE);
            vm.prank(players[i]);
            lottery.enter{value: TICKET_PRICE}();
        }

        uint256 totalPrize = lottery.getLotteryBalance();
        
        // Record initial balances
        uint256[] memory initialBalances = new uint256[](players.length);
        for(uint i = 0; i < players.length; i++) {
            initialBalances[i] = players[i].balance;
        }
        
        // Warp to after lottery end time
        vm.warp(lotteryEndTime + 1);

        // Pick winner
        vm.prank(manager);
        lottery.pickWinner();

        // Verify lottery state after winner picked
        assertTrue(lottery.lotteryFinished());
        assertEq(lottery.getPlayers().length, 0);
        assertEq(lottery.getLotteryBalance(), 0);

        // Verify that exactly one player received the prize
        uint256 winnersFound = 0;
        for(uint i = 0; i < players.length; i++) {
            if(players[i].balance > initialBalances[i]) {
                assertEq(players[i].balance, initialBalances[i] + totalPrize);
                winnersFound++;
            }
        }
        assertEq(winnersFound, 1);
    }

    function testFail_PickWinnerBeforeEndTime() public {
        vm.prank(manager);
        lottery.pickWinner();
    }

    function testFail_PickWinnerWithNoPlayers() public {
        // Warp to after lottery end time
        vm.warp(lotteryEndTime + 1);
        
        vm.prank(manager);
        lottery.pickWinner();
    }

    function testFail_PickWinnerTwice() public {
        // Enter a player
        vm.deal(players[0], TICKET_PRICE);
        vm.prank(players[0]);
        lottery.enter{value: TICKET_PRICE}();

        // Warp to after lottery end time
        vm.warp(lotteryEndTime + 1);
        
        vm.startPrank(manager);
        lottery.pickWinner();
        lottery.pickWinner(); // Should fail
        vm.stopPrank();
    }

    function testFail_NonManagerPickWinner() public {
        // Enter a player
        vm.deal(players[0], TICKET_PRICE);
        vm.prank(players[0]);
        lottery.enter{value: TICKET_PRICE}();

        // Warp to after lottery end time
        vm.warp(lotteryEndTime + 1);
        
        vm.prank(players[0]);
        lottery.pickWinner(); // Should fail
    }

    function test_GetPlayers() public {
        assertEq(lottery.getPlayers().length, 0);

        // Enter players
        for(uint i = 0; i < players.length; i++) {
            vm.deal(players[i], TICKET_PRICE);
            vm.prank(players[i]);
            lottery.enter{value: TICKET_PRICE}();
        }

        address[] memory lotteryPlayers = lottery.getPlayers();
        assertEq(lotteryPlayers.length, players.length);
        
        for(uint i = 0; i < players.length; i++) {
            assertEq(lotteryPlayers[i], players[i]);
        }
    }

    function test_GetLotteryBalance() public {
        assertEq(lottery.getLotteryBalance(), 0);

        // Enter players
        for(uint i = 0; i < players.length; i++) {
            vm.deal(players[i], TICKET_PRICE);
            vm.prank(players[i]);
            lottery.enter{value: TICKET_PRICE}();
        }

        assertEq(lottery.getLotteryBalance(), TICKET_PRICE * players.length);
    }
}
