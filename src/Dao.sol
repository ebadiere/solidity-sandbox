//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract Dao {
    mapping(address => uint) shares;
    mapping(uint => Proposal) proposals;
    
    uint public nextProposalId;
    uint public totalShares;
    uint public constant SHARE_PRICE = 0.01 ether; 
    uint public constant VOTING_PERIOD = 604800; // 7 days * 24 hours * 60 minutes * 60 seconds
    
    struct Proposal {
        uint id;
        string description;
        uint votesFor;
        uint votesAgainst;
        address creator;
        bool executed;
        bytes action;
        address target;
        uint startTime;
        mapping(address => bool) hasVoted;
    }

    constructor(uint initialShares) {
        totalShares = initialShares;
    }

    function buyShares(uint _amount) external payable {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= totalShares, "Not enough shares available for purchase");    
        uint purchasedShares = msg.value / SHARE_PRICE;
        require(purchasedShares >= _amount, "Insufficient funds for purchase");
        
        shares[msg.sender] += purchasedShares;
        totalShares -= purchasedShares;
    }

    function createProposal(string calldata _description, bytes calldata _action, address _target) external {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_action.length > 0, "Action cannot be empty");
        require(_target != address(0), "Target cannot be zero address");
        
        proposals[nextProposalId].id = nextProposalId;
        proposals[nextProposalId].description = _description;
        proposals[nextProposalId].creator = msg.sender;
        proposals[nextProposalId].action = _action;
        proposals[nextProposalId].target = _target;
        proposals[nextProposalId].startTime = block.timestamp;
        
        nextProposalId++;
    }

    function vote(uint _proposalId, bool _vote) external {
        require(_proposalId < nextProposalId, "Proposal does not exist");
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted");
        require(shares[msg.sender] > 0, "Must have shares to vote");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting period has not started");
        require(block.timestamp <= proposals[_proposalId].startTime + VOTING_PERIOD, "Voting period has ended");
        
        uint votingPower = shares[msg.sender];
        
        if (_vote) {
            proposals[_proposalId].votesFor += votingPower;
        } else {
            proposals[_proposalId].votesAgainst += votingPower;
        }
        
        proposals[_proposalId].hasVoted[msg.sender] = true;
    }

    function executeProposal(uint _proposalId) external {
        require(_proposalId < nextProposalId, "Proposal does not exist");
        require(!proposals[_proposalId].executed, "Proposal has already been executed");
        require(block.timestamp > proposals[_proposalId].startTime + VOTING_PERIOD, "Voting period has not ended");
        require(proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst, "Not enough votes for execution");
        
        proposals[_proposalId].executed = true;
        
        require(proposals[_proposalId].action.length > 0, "Action cannot be empty");
        require(proposals[_proposalId].target != address(0), "Target cannot be zero address");
        
        (bool success, ) = proposals[_proposalId].target.call(proposals[_proposalId].action);
        require(success, "Proposal execution failed");
    }
}