// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract StreamingPayment {
    address public employer;
    mapping(address => uint) public allowances;
    mapping(address => uint) public lastWithDrawal;
    mapping(address => uint) public employmentEndDate;
    uint256 public constant MAX_MONTHLY_ALLOWANCE = 1000 ether;

    constructor() {
        employer = msg.sender;
    }

    modifier onlyEmployer() {
        require(msg.sender == employer, "Only employer can perform this action");
        _;
    }

    function fundContract(address _employer, uint _amount) external onlyEmployer payable {}

    function setAllowance(address _employee, uint _monthlyAmount, uint _startDate) external onlyEmployer {
        require(allowances[_employee] == 0, "Allowance already set for this employee");
        require(_employee != address(0), "Invalid employee address");
        require(_monthlyAmount > 0, "Monthly amount must be greater than 0");
        require(_monthlyAmount <= MAX_MONTHLY_ALLOWANCE, "Monthly amount exceeds maximum");
        require(_startDate >= block.timestamp, "Start date must be in the future");
        
        allowances[_employee] = _monthlyAmount;
        lastWithDrawal[_employee] = _startDate;
        employmentEndDate[_employee] = type(uint256).max;
    }

    function revokeAllowance(address _employee) external onlyEmployer {
        require(allowances[_employee] > 0, "No allowance set for this employee");
        employmentEndDate[_employee] = block.timestamp;
        allowances[_employee] = 0;
    }

    function withdrawSalary() external {
        require(employmentEndDate[msg.sender] > 0, "No salary configured");
        require(block.timestamp <= employmentEndDate[msg.sender], "Employment has ended");
        require(allowances[msg.sender] > 0, "No salary configured");
        require(block.timestamp > lastWithDrawal[msg.sender], "No salary available yet");

        uint256 timeSinceLastWithdrawal = block.timestamp - lastWithDrawal[msg.sender];
        uint256 monthlyRate = allowances[msg.sender];
        uint256 amount = (monthlyRate * timeSinceLastWithdrawal) / 30 days;

        require(amount > 0, "No salary available for withdrawal");
        require(address(this).balance >= amount, "Insufficient contract balance");

        lastWithDrawal[msg.sender] = block.timestamp;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}