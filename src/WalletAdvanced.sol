// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract WalletAdvanced {
    address admin;
    uint monthlyAllowance;
    uint spentThisMonth;
    uint lastReset;

    constructor() {
        admin = msg.sender;
        lastReset = block.timestamp;
    }

    function setAllowance(uint _monthlyAllowance) public {
        require(msg.sender == admin, "Only admin can set the allowance");
        monthlyAllowance = _monthlyAllowance;
    }

    function spend(uint _amount) public {
        // Check if a month (30 days) has passed since last reset
        if (block.timestamp >= lastReset + 30 days) {
            spentThisMonth = 0;
            lastReset = block.timestamp;
        }

        // Check if new spend would exceed monthly allowance
        require(
            spentThisMonth + _amount <= monthlyAllowance,
            "Would exceed monthly allowance"
        );

        // Update spent amount BEFORE transfer (Checks-Effects-Interactions pattern)
        spentThisMonth += _amount;

        // Transfer ETH using low-level call
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
