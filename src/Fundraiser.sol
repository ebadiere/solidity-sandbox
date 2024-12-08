// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Fundraiser {
    address organizer;
    uint256 goal;
    uint256 raised;
    mapping(address => uint256) contributions;
    address[] public contributorList;
    bool goalReached;

    constructor(address _organizer, uint256 _goal) {
        organizer = _organizer;
        goal = _goal;
    }

    function contribute() public payable {
        require(msg.value > 0, "Contribution must be greater than 0");
        if (contributions[msg.sender] == 0) {
            contributorList.push(msg.sender);
        }
        contributions[msg.sender] += msg.value;
        raised += msg.value;
        if (raised >= goal) {
            goalReached = true;
        }
    }

    function withdraw() public {
        require(goalReached, "Goal not reached");
        contributions[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: raised}("");
        require(success, "Transfer failed");
    }

    function refund() public {
        require(!goalReached, "Goal already reached");
        require(msg.sender == organizer, "Only organizer can refund funds");
        
        for (uint i = 0; i < contributorList.length; i++) {
            address contributor = contributorList[i];
            uint256 amount = contributions[contributor];
            if (amount > 0) {
                contributions[contributor] = 0;
                (bool success,) = contributor.call{value: amount}("");
                require(success, "Transfer failed");
            }
        }
        
        // Reset the contract state
        raised = 0;
        delete contributorList;
    }

    function getGoal() public view returns (uint256) {
        return goal;
    }

    function getContribution(address contributor) public view returns (uint256) {
        return contributions[contributor];
    }

    function getRaised() public view returns (uint256) {
        return raised;
    }
}