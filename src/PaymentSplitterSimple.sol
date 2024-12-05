// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PaymentSplitterSimple {

    function splitPayment(address[] memory recipients, uint256[] memory amounts) external payable {
        require(recipients.length == amounts.length, "Recipients and amounts arrays must be the same length");
        
        // Calculate total amount needed
        uint256 totalAmount;
        for(uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        // Verify enough ETH was sent
        require(msg.value >= totalAmount, "Insufficient ETH sent");
        
        // Process each transfer
        for(uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot send to zero address");
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            require(success, "Transfer failed");
        }
        
        // Return excess ETH if any
        uint256 excess = msg.value - totalAmount;
        if(excess > 0) {
            (bool success, ) = msg.sender.call{value: excess}("");
            require(success, "Failed to return excess ETH");
        }
    }
}