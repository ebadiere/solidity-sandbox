// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PaymentSplitterAdvanced {
    address[] recipients;
    mapping(address => uint256) shares;

    constructor(address[] memory _recipients, uint256[] memory _shares) {
        require(_recipients.length == _shares.length, "Recipients and shares arrays must be the same length");
        require(_recipients.length > 0, "No recipients provided");

        for(uint i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Cannot assign shares to zero address");
            require(_shares[i] > 0, "Share must be greater than 0");
            require(shares[_recipients[i]] == 0, "Duplicate recipient");
            
            recipients.push(_recipients[i]);
            shares[_recipients[i]] = _shares[i];
        }
    }

    function splitPayment() external payable {
        require(msg.value > 0, "Must send ETH");
        
        // Calculate total shares and verify it equals 100
        uint256 totalShares;
        for(uint i = 0; i < recipients.length; i++) {
            totalShares += shares[recipients[i]];
        }
        require(totalShares == 100, "Total shares must equal 100");

        // Calculate and transfer each recipient's portion
        for(uint i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 payment = (msg.value * shares[recipient]) / 100;
            
            (bool success, ) = recipient.call{value: payment}("");
            require(success, "Transfer failed");
        }
    }
}