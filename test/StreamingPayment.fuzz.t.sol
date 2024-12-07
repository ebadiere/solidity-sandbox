// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StreamingPayment.sol";

contract StreamingPaymentFuzzTest is Test {
    StreamingPayment public streamingPayment;
    address public employer;
    address public constant ZERO_ADDRESS = address(0);

    function setUp() public {
        employer = makeAddr("employer");
        vm.deal(employer, 1000 ether);
        
        vm.prank(employer);
        streamingPayment = new StreamingPayment();
    }

    function testFuzz_SetAllowanceAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= streamingPayment.MAX_MONTHLY_ALLOWANCE());
        address employee = makeAddr("employee");
        uint256 startDate = block.timestamp;

        vm.prank(employer);
        streamingPayment.setAllowance(employee, amount, startDate);

        assertEq(streamingPayment.allowances(employee), amount);
    }

    function testFuzz_SetAllowanceStartDate(uint256 futureTime) public {
        vm.assume(futureTime > block.timestamp && futureTime < type(uint256).max);
        address employee = makeAddr("employee");
        uint256 amount = 1 ether;

        vm.prank(employer);
        streamingPayment.setAllowance(employee, amount, futureTime);

        assertEq(streamingPayment.lastWithDrawal(employee), futureTime);
        assertEq(streamingPayment.employmentEndDate(employee), type(uint256).max);
    }

    function testFuzz_WithdrawSalaryPartialMonth(uint256 timeElapsed) public {
        // Constrain time elapsed to reasonable bounds (1 second to 30 days)
        vm.assume(timeElapsed > 0 && timeElapsed <= 30 days);
        
        address employee = makeAddr("employee");
        uint256 monthlyAmount = 1 ether;
        uint256 startTime = block.timestamp;

        // Setup allowance and fund contract
        vm.startPrank(employer);
        streamingPayment.setAllowance(employee, monthlyAmount, startTime + 1);
        streamingPayment.fundContract{value: 10 ether}(employer, 10 ether);
        vm.stopPrank();

        // Move time forward
        vm.warp(startTime + timeElapsed + 1);

        // Calculate expected amount
        uint256 expectedAmount = (monthlyAmount * timeElapsed) / 30 days;

        // Record initial balance
        uint256 initialBalance = address(streamingPayment).balance;
        
        // Withdraw and verify
        vm.prank(employee);
        streamingPayment.withdrawSalary();
        
        assertEq(streamingPayment.lastWithDrawal(employee), block.timestamp);
        assertGe(initialBalance - address(streamingPayment).balance, expectedAmount);
    }

    function testFuzz_MultipleEmployeeWithdrawals(
        uint256[] calldata amounts,
        uint256[] calldata timePeriods
    ) public {
        // Bound the array length directly instead of using assume
        uint256 numEmployees = bound(amounts.length, 1, 5);
        
        // Create new arrays with bounded length
        uint256[] memory boundedAmounts = new uint256[](numEmployees);
        uint256[] memory boundedTimePeriods = new uint256[](numEmployees);
        
        // Copy and bound the input values
        for(uint256 i = 0; i < numEmployees && i < amounts.length && i < timePeriods.length; i++) {
            // Ensure amount is between 0.1 ether and 10 ether (non-zero)
            boundedAmounts[i] = bound(amounts[i], 0.1 ether, 10 ether);
            boundedTimePeriods[i] = bound(timePeriods[i], 1 days, 30 days);
        }
        
        address[] memory employees = new address[](numEmployees);
        uint256 totalExpectedWithdrawal = 0;
        uint256 maxPossibleWithdrawal = 0;
        uint256 currentTime = block.timestamp;
        
        // First calculate maximum possible withdrawal to fund contract appropriately
        for(uint256 i = 0; i < numEmployees; i++) {
            maxPossibleWithdrawal += (boundedAmounts[i] * boundedTimePeriods[i]) / 30 days;
        }
        
        // Fund contract with enough to cover max possible withdrawal plus buffer
        vm.deal(employer, maxPossibleWithdrawal + 1 ether);
        vm.prank(employer);
        streamingPayment.fundContract{value: maxPossibleWithdrawal + 1 ether}(employer, maxPossibleWithdrawal + 1 ether);
        
        // Setup allowances for all employees
        for(uint256 i = 0; i < numEmployees; i++) {
            employees[i] = makeAddr(string(abi.encodePacked("employee", vm.toString(i))));
            
            // Set time to start of this employee's period
            vm.warp(currentTime);
            
            // Set allowance with future start date
            vm.prank(employer);
            streamingPayment.setAllowance(employees[i], boundedAmounts[i], currentTime + 1);
            
            // Move time forward past the start date and the time period
            currentTime += boundedTimePeriods[i] + 1;
            vm.warp(currentTime);
            
            // Calculate expected withdrawal for this employee
            uint256 expectedWithdrawal = (boundedAmounts[i] * boundedTimePeriods[i]) / 30 days;
            totalExpectedWithdrawal += expectedWithdrawal;
            
            // Perform withdrawal
            vm.prank(employees[i]);
            streamingPayment.withdrawSalary();
            
            // Verify individual withdrawal
            assertEq(streamingPayment.lastWithDrawal(employees[i]), currentTime);
        }
        
        // Verify total withdrawals
        assertGe(address(streamingPayment).balance, maxPossibleWithdrawal + 1 ether - totalExpectedWithdrawal);
        assertLe(address(streamingPayment).balance, maxPossibleWithdrawal + 1 ether);
    }

    function testFuzz_RevokeAllowanceAndReassign(uint256 amount1, uint256 amount2, uint256 timeBetween) public {
        vm.assume(amount1 > 0 && amount1 <= streamingPayment.MAX_MONTHLY_ALLOWANCE());
        vm.assume(amount2 > 0 && amount2 <= streamingPayment.MAX_MONTHLY_ALLOWANCE());
        vm.assume(timeBetween > 0 && timeBetween <= 365 days);
        
        address employee = makeAddr("employee");
        
        // Set initial allowance
        vm.prank(employer);
        streamingPayment.setAllowance(employee, amount1, block.timestamp);
        
        // Move time forward and revoke
        vm.warp(block.timestamp + timeBetween);
        vm.prank(employer);
        streamingPayment.revokeAllowance(employee);
        
        // Verify revocation
        assertEq(streamingPayment.employmentEndDate(employee), block.timestamp);
        assertEq(streamingPayment.allowances(employee), 0);
        
        // Try to set new allowance
        vm.prank(employer);
        streamingPayment.setAllowance(employee, amount2, block.timestamp);
        
        // Verify new allowance
        assertEq(streamingPayment.allowances(employee), amount2);
        assertEq(streamingPayment.employmentEndDate(employee), type(uint256).max);
    }

    function testFuzz_FundContractMultipleTimes(uint256[] calldata amounts) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10);
        
        uint256 totalFunded = 0;
        
        for(uint256 i = 0; i < amounts.length; i++) {
            // Bound amount to reasonable range (0.1 to 100 ether)
            uint256 amount = bound(amounts[i], 0.1 ether, 100 ether);
            
            vm.deal(employer, amount);
            vm.prank(employer);
            streamingPayment.fundContract{value: amount}(employer, amount);
            
            totalFunded += amount;
        }
        
        assertEq(address(streamingPayment).balance, totalFunded);
    }

    function testFuzz_InvalidEmployeeAddress(uint256 amount, uint256 startTime) public {
        vm.assume(amount > 0 && amount <= streamingPayment.MAX_MONTHLY_ALLOWANCE());
        vm.assume(startTime >= block.timestamp);
        
        vm.prank(employer);
        vm.expectRevert("Invalid employee address");
        streamingPayment.setAllowance(ZERO_ADDRESS, amount, startTime);
    }

    function testFuzz_InvalidAllowanceAmount(address employee, uint256 amount) public {
        vm.assume(amount > streamingPayment.MAX_MONTHLY_ALLOWANCE());
        vm.assume(employee != ZERO_ADDRESS);
        
        vm.prank(employer);
        vm.expectRevert("Monthly amount exceeds maximum");
        streamingPayment.setAllowance(employee, amount, block.timestamp);
    }
}
