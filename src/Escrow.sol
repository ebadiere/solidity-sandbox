// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Escrow {
    address admin;
    mapping(address => uint) deposits;
    mapping(address => uint) withdrawals;
    bool transactionAuthorized;

    address[] buyers;
    address[] sellers;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(address[] memory _buyers, 
        address[] memory _sellers,
        uint256[] memory _amounts,
        address _admin
    ) {
        require(_amounts.length == _sellers.length, "Amounts and sellers arrays must be the same length");
        require(_admin != address(0), "Admin cannot be zero address");

        buyers = _buyers;
        sellers = _sellers;
        admin = _admin;
        
        // Populate withdrawals mapping with seller shares
        for(uint i = 0; i < _sellers.length; i++) {
            require(_sellers[i] != address(0), "Seller cannot be zero address");
            require(_amounts[i] > 0, "Amount must be greater than 0");
            withdrawals[_sellers[i]] = _amounts[i];
        }
    }

    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        
        // Verify sender is a buyer
        bool isBuyer = false;
        for(uint i = 0; i < buyers.length; i++) {
            if(msg.sender == buyers[i]) {
                isBuyer = true;
                break;
            }
        }
        require(isBuyer, "Only buyers can deposit");

        // Track deposit
        deposits[msg.sender] += msg.value;
    }

    function authorizeTransaction() external onlyAdmin {
        require(!transactionAuthorized, "Transaction already authorized");
        for (uint i = 0; i < buyers.length; i++) {
            require(deposits[buyers[i]] > 0, "All buyers must deposit");
        }
        transactionAuthorized = true;
    }

    function withdraw() external {
        require(transactionAuthorized, "Transaction not yet authorized");
        
        // Verify sender is a seller with funds to withdraw
        require(withdrawals[msg.sender] > 0, "No funds to withdraw");
        
        // Verify all buyers have deposited
        uint256 totalDeposits;
        for(uint i = 0; i < buyers.length; i++) {
            totalDeposits += deposits[buyers[i]];
        }
        
        uint256 totalRequired;
        for(uint i = 0; i < sellers.length; i++) {
            totalRequired += withdrawals[sellers[i]];
        }
        
        require(totalDeposits >= totalRequired, "Insufficient deposits from buyers");

        // Get amount to withdraw
        uint256 amount = withdrawals[msg.sender];
        withdrawals[msg.sender] = 0;  // Update state before transfer

        // Transfer funds using call
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}