// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract RewardDistribution {
    uint256 public MAX_ENTRIES = 100;

    struct RewardEntry {
        address recipient;
        uint256 amount;
    }

    RewardEntry[] public entries;

    uint256 public topK;

    

    

}