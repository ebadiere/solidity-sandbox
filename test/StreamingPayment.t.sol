// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StreamingPayment.sol";

contract StreamingPaymentTest is Test {
    StreamingPayment public streamingPayment;
    address public employer;
    address public employee1;
    address public employee2;
    uint256 public constant MONTHLY_ALLOWANCE = 1 ether;
    uint256 public startDate;

    function setUp() public {
        employer = makeAddr("employer");
        employee1 = makeAddr("employee1");
        employee2 = makeAddr("employee2");
        vm.deal(employer, 100 ether);
        
        vm.prank(employer);
        streamingPayment = new StreamingPayment();
        
        startDate = block.timestamp;
    }

    function testSetAllowanceFirstTime() public {
        vm.startPrank(employer);
        
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        
        vm.stopPrank();
    }

    function testCannotSetAllowanceTwice() public {
        vm.startPrank(employer);
        
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        
        vm.expectRevert("Allowance already set for this employee");
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE * 2, startDate);
        
        vm.stopPrank();
    }

    function testOnlyEmployerCanSetAllowance() public {
        vm.prank(employee1);
        vm.expectRevert("Only employer can perform this action");
        streamingPayment.setAllowance(employee2, MONTHLY_ALLOWANCE, startDate);
    }

    function testFundContract() public {
        vm.startPrank(employer);
        
        uint256 fundAmount = 10 ether;
        streamingPayment.fundContract(employer, fundAmount);
        
        vm.stopPrank();
    }

    function testSetAllowanceWithFutureStartDate() public {
        vm.startPrank(employer);
        
        uint256 futureStartDate = block.timestamp + 30 days;
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, futureStartDate);
        
        vm.stopPrank();
    }

    function testSetAllowanceWithPastStartDate() public {
        vm.startPrank(employer);
        
        vm.warp(block.timestamp + 60 days); // Move forward in time
        uint256 pastStartDate = block.timestamp - 30 days;
        vm.expectRevert("Start date must be in the future");
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, pastStartDate);
        
        vm.stopPrank();
    }

    function testSetMultipleEmployeeAllowances() public {
        vm.startPrank(employer);
        
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        streamingPayment.setAllowance(employee2, MONTHLY_ALLOWANCE * 2, startDate);
        
        vm.stopPrank();
    }

    function testSetZeroAllowance() public {
        vm.startPrank(employer);
        
        vm.expectRevert("Monthly amount must be greater than 0");
        streamingPayment.setAllowance(employee1, 0, startDate);
        
        vm.stopPrank();
    }

    function testRevokeAllowance() public {
        vm.startPrank(employer);
        
        // First set an allowance
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        
        // Then revoke it
        streamingPayment.revokeAllowance(employee1);
        
        // Verify allowance is reset and employment end date is set to current time
        assertEq(streamingPayment.allowances(employee1), 0);
        assertEq(streamingPayment.employmentEndDate(employee1), block.timestamp);
        
        vm.stopPrank();
    }

    function testOnlyEmployerCanRevokeAllowance() public {
        vm.startPrank(employer);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        vm.stopPrank();

        vm.prank(employee2);
        vm.expectRevert("Only employer can perform this action");
        streamingPayment.revokeAllowance(employee1);
    }

    function testRevokeNonExistentAllowance() public {
        vm.startPrank(employer);
        
        // Try to revoke allowance for employee that never had one
        vm.expectRevert("No allowance set for this employee");
        streamingPayment.revokeAllowance(employee1);
        
        vm.stopPrank();
    }

    function testWithdrawSalary() public {
        // Setup
        vm.startPrank(employer);
        streamingPayment.fundContract{value: 10 ether}(employer, 10 ether);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        vm.stopPrank();

        // Move forward 15 days
        vm.warp(block.timestamp + 15 days);

        // Record initial balance
        uint256 initialBalance = address(employee1).balance;

        // Withdraw salary
        vm.prank(employee1);
        streamingPayment.withdrawSalary();

        // Expected amount is half of monthly allowance (15 days)
        uint256 expectedAmount = (MONTHLY_ALLOWANCE * 15 days) / 30 days;
        assertEq(address(employee1).balance - initialBalance, expectedAmount);
    }

    function testCannotWithdrawWithoutAllowance() public {
        vm.prank(employee1);
        vm.expectRevert("No salary configured");
        streamingPayment.withdrawSalary();
    }

    function testCannotWithdrawBeforeStartDate() public {
        // Setup with future start date
        uint256 futureStart = block.timestamp + 30 days;
        vm.prank(employer);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, futureStart);

        // Try to withdraw immediately
        vm.prank(employee1);
        vm.expectRevert("No salary available yet");
        streamingPayment.withdrawSalary();
    }

    function testCannotWithdrawWithoutContractBalance() public {
        // Setup with no contract funding
        vm.prank(employer);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);

        // Move forward 15 days
        vm.warp(block.timestamp + 15 days);

        // Try to withdraw
        vm.prank(employee1);
        vm.expectRevert("Insufficient contract balance");
        streamingPayment.withdrawSalary();
    }

    function testMultipleWithdrawals() public {
        // Setup
        vm.startPrank(employer);
        streamingPayment.fundContract{value: 10 ether}(employer, 10 ether);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        vm.stopPrank();

        // First withdrawal after 10 days
        vm.warp(block.timestamp + 10 days);
        vm.prank(employee1);
        streamingPayment.withdrawSalary();

        // Second withdrawal after another 10 days
        vm.warp(block.timestamp + 10 days);
        vm.prank(employee1);
        streamingPayment.withdrawSalary();

        // Verify last withdrawal timestamp
        assertEq(streamingPayment.lastWithDrawal(employee1), block.timestamp);
    }

    function testWithdrawAfterEmploymentEnd() public {
        // Setup
        vm.startPrank(employer);
        streamingPayment.fundContract{value: 10 ether}(employer, 10 ether);
        streamingPayment.setAllowance(employee1, MONTHLY_ALLOWANCE, startDate);
        
        // Move forward and end employment
        vm.warp(block.timestamp + 15 days);
        streamingPayment.revokeAllowance(employee1);
        vm.stopPrank();

        // Move forward one more day and try to withdraw
        vm.warp(block.timestamp + 1 days);
        vm.prank(employee1);
        vm.expectRevert("Employment has ended");
        streamingPayment.withdrawSalary();
    }

    receive() external payable {}
}
