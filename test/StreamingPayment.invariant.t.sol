// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StreamingPayment.sol";

contract StreamingPaymentHandler is Test {
    StreamingPayment public streamingPayment;
    address public employer;
    address[] public employees;
    uint256 public constant MONTHLY_ALLOWANCE = 1 ether;

    constructor(StreamingPayment _streamingPayment, address _employer) {
        streamingPayment = _streamingPayment;
        employer = _employer;
        
        // Create some test employees
        for(uint256 i = 0; i < 5; i++) {
            employees.push(makeAddr(string(abi.encodePacked("employee", vm.toString(i)))));
        }
    }

    function setAllowance(uint256 employeeIndex, uint256 amount) public {
        if (employeeIndex >= employees.length) return;
        if (amount == 0) amount = 1; // Avoid zero amount
        amount = bound(amount, 1, streamingPayment.MAX_MONTHLY_ALLOWANCE());
        
        vm.prank(employer);
        try streamingPayment.setAllowance(
            employees[employeeIndex],
            amount,
            uint256(block.timestamp)
        ) {} catch {}
    }

    function revokeAllowance(uint256 employeeIndex) public {
        if (employeeIndex >= employees.length) return;
        
        vm.prank(employer);
        try streamingPayment.revokeAllowance(employees[employeeIndex]) {} catch {}
    }

    function fundContract(uint256 amount) public {
        if (amount == 0) return;
        amount = bound(amount, uint256(0.1 ether), uint256(100 ether));
        
        vm.prank(employer);
        vm.deal(employer, amount);
        try streamingPayment.fundContract{value: amount}(employer, amount) {} catch {}
    }

    function withdrawSalary(uint256 employeeIndex) public {
        if (employeeIndex >= employees.length) return;
        
        // Move time forward randomly between 1 and 30 days
        uint256 timeJump = bound(uint256(1 days), uint256(1 days), uint256(30 days));
        vm.warp(uint256(block.timestamp) + timeJump);
        
        vm.prank(employees[employeeIndex]);
        try streamingPayment.withdrawSalary() {} catch {}
    }

    function getEmployees() external view returns (address[] memory) {
        return employees;
    }
}

contract StreamingPaymentInvariantTest is Test {
    StreamingPayment public streamingPayment;
    StreamingPaymentHandler public handler;
    address public employer;

    function setUp() public {
        employer = makeAddr("employer");
        vm.prank(employer);
        streamingPayment = new StreamingPayment();
        
        handler = new StreamingPaymentHandler(streamingPayment, employer);
        targetContract(address(handler));

        // Fund contract initially
        vm.deal(employer, 1000 ether);
        vm.prank(employer);
        streamingPayment.fundContract{value: 1000 ether}(employer, 1000 ether);
    }

    function invariant_contractBalanceCoversLiabilities() public view {
        address[] memory employees = handler.getEmployees();
        uint256 totalPendingWithdrawals;
        
        for (uint256 i = 0; i < employees.length; i++) {
            address employee = employees[i];
            if (streamingPayment.allowances(employee) > 0 &&
                uint256(block.timestamp) > streamingPayment.lastWithDrawal(employee) &&
                uint256(block.timestamp) <= streamingPayment.employmentEndDate(employee)) {
                    
                uint256 timeSinceLastWithdrawal = uint256(block.timestamp) - streamingPayment.lastWithDrawal(employee);
                uint256 monthlyRate = streamingPayment.allowances(employee);
                uint256 pendingAmount = (monthlyRate * timeSinceLastWithdrawal) / uint256(30 days);
                
                totalPendingWithdrawals += pendingAmount;
            }
        }
        
        assertLe(totalPendingWithdrawals, address(streamingPayment).balance);
    }

    function invariant_validEmploymentHasAllowance() public view {
        address[] memory employees = handler.getEmployees();
        
        for (uint256 i = 0; i < employees.length; i++) {
            address employee = employees[i];
            if (streamingPayment.allowances(employee) > 0) {
                assertTrue(
                    uint256(block.timestamp) <= streamingPayment.employmentEndDate(employee) ||
                    streamingPayment.employmentEndDate(employee) == type(uint256).max
                );
            }
        }
    }

    function invariant_withdrawalBeforeEmploymentEnd() public view {
        address[] memory employees = handler.getEmployees();
        
        for (uint256 i = 0; i < employees.length; i++) {
            address employee = employees[i];
            if (streamingPayment.employmentEndDate(employee) > 0) {
                assertLe(
                    streamingPayment.lastWithDrawal(employee),
                    streamingPayment.employmentEndDate(employee)
                );
            }
        }
    }

    function invariant_onlyEmployerControl() public view {
        assertEq(streamingPayment.employer(), employer);
    }

    receive() external payable {}
}
