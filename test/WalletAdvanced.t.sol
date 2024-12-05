// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {WalletAdvanced} from "../src/WalletAdvanced.sol";

contract WalletAdvancedTest is Test {
    WalletAdvanced public wallet;
    address public admin;
    address public user;
    uint256 constant MONTHLY_ALLOWANCE = 1 ether;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        vm.prank(admin);
        wallet = new WalletAdvanced();
        
        // Fund the wallet contract
        vm.deal(address(wallet), 10 ether);
        
        // Set initial allowance
        vm.prank(admin);
        wallet.setAllowance(MONTHLY_ALLOWANCE);
    }

    function testSetAllowance() public {
        vm.prank(admin);
        wallet.setAllowance(2 ether);
        
        // Try setting allowance from non-admin (should fail)
        vm.prank(user);
        vm.expectRevert("Only admin can set the allowance");
        wallet.setAllowance(3 ether);
    }

    function testBasicSpend() public {
        uint256 initialBalance = user.balance;
        uint256 spendAmount = 0.5 ether;

        vm.prank(user);
        wallet.spend(spendAmount);

        assertEq(user.balance, initialBalance + spendAmount, "User balance should increase");
    }

    function testSpendExceedingAllowance() public {
        // Try to spend more than monthly allowance
        vm.prank(user);
        vm.expectRevert("Would exceed monthly allowance");
        wallet.spend(1.5 ether);
    }

    function testMonthlyReset() public {
        // First spend
        vm.prank(user);
        wallet.spend(0.5 ether);

        // Move time forward by 31 days
        skip(31 days);

        // Should be able to spend full amount again
        vm.prank(user);
        wallet.spend(1 ether);
    }

    function testMultipleSpends() public {
        // First spend
        vm.prank(user);
        wallet.spend(0.3 ether);

        // Second spend
        vm.prank(user);
        wallet.spend(0.3 ether);

        // Third spend should fail as it would exceed monthly allowance
        vm.prank(user);
        vm.expectRevert("Would exceed monthly allowance");
        wallet.spend(0.5 ether);
    }

    function testSpendWithInsufficientContractBalance() public {
        // Create new wallet with small balance
        vm.prank(admin);
        WalletAdvanced poorWallet = new WalletAdvanced();
        vm.deal(address(poorWallet), 0.1 ether);
        
        vm.prank(admin);
        poorWallet.setAllowance(1 ether);

        // Try to spend more than contract has
        vm.prank(user);
        vm.expectRevert("Transfer failed");
        poorWallet.spend(0.2 ether);
    }
}
