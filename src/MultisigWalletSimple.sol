// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MultisigWalletSimple {

    struct Proposal {
        string description;
        uint amount;
        address recipient;
        bool executed;
        uint votes;
    }

    mapping(address => bool) public approvals;

    address[] owners;
    uint public quorum;
    address admin;
    mapping(uint => Proposal) public proposals;
    uint public nextProposalId;
    uint votingEndTime;
    uint constant VOTING_PERIOD = 1 days;
    mapping(uint => mapping(address => bool)) public hasVoted;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier votingActive() {
        require(block.timestamp <= votingEndTime, "Voting period has ended");
        _;
    }

    function findIndex(address[] storage array, address value) internal view returns (int) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return int(i);
            }
        }
        return -1; // Return -1 if not found
    }

    constructor() {
        admin = msg.sender;
        votingEndTime = type(uint).max; // Set initial voting time to max to allow setup
    }

    function updateOwners(address[] calldata _owners) external onlyAdmin {
        owners = _owners;
    }

    function updateQuorum(uint256 _quorum) external onlyAdmin {
        quorum = _quorum;
    }

    function submitProposal(string calldata _description, uint256 _amount, address _recipient) external onlyAdmin {
        votingEndTime = block.timestamp + VOTING_PERIOD;
        proposals[nextProposalId] = Proposal({
            description: _description,
            amount: _amount,
            recipient: _recipient,
            executed: false,
            votes: 0
        });
        nextProposalId++;
    }

    function executeProposal(uint256 _proposalId) internal votingActive {
        require(_proposalId < nextProposalId, "Invalid proposal ID");
        require(proposals[_proposalId].votes >= quorum, "Not enough votes to execute");
        require(!proposals[_proposalId].executed, "Proposal has already been executed");
        address recipient = proposals[_proposalId].recipient;
        uint256 amount = proposals[_proposalId].amount;
        (bool success,) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        proposals[_proposalId].executed = true;
    }

    function vote(uint256 _proposalId, bool _approve) external votingActive {
        require(_proposalId < nextProposalId, "Invalid proposal ID");
        require(findIndex(owners, msg.sender) != -1, "Only owners can vote");
        require(!hasVoted[_proposalId][msg.sender], "You have already voted");
        hasVoted[_proposalId][msg.sender] = true;
        if (_approve) {
            proposals[_proposalId].votes++;
            if (proposals[_proposalId].votes >= quorum) {
                executeProposal(_proposalId);
            }
        }
    }

    receive() external payable {}
}