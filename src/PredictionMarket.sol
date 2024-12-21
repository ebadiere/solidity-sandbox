// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PredictionMarket {
    error EventDoesNotExist();
    error InsufficientBetAmount();

    struct Event {
        uint id;
        uint totalYesBets;
        uint totalNoBets;
        bool outcomeDeclared;
        bool winningOutcome;
        bool active;
        mapping(address => uint256) yesBets;
        mapping(address => uint256) noBets;
    }

    mapping(uint256 => Event) public events;
    uint public nextEventId;
    address immutable admin;

    event BetPlaced(uint256 indexed eventId, address indexed bettor, bool yesBet, uint256 amount);
    event EventCreated(uint256 indexed eventId, address indexed bettor, bool yesBet, uint256 amount);
    event OutcomeDeclared(uint256 indexed eventId, bool outcome);
    event WinningsClaimed(uint256 indexed eventId, address indexed winner, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier eventExists(uint eventId) {
        require(events[eventId].active, "Event does not exist");
        _;
    }

    modifier outcomeNotDeclared(uint eventId) {
        require(!events[eventId].outcomeDeclared, "Outcome already declared");
        _;
    }

    modifier outcomeDeclared(uint eventId) {
        require(events[eventId].outcomeDeclared, "Outcome not declared yet");
        _;
    }    

    constructor(address _admin) {
        admin = _admin;
    }

    function createEvent() external onlyAdmin {
        nextEventId++;
        Event storage newEvent = events[nextEventId];
        newEvent.id = nextEventId;
        newEvent.active = true;
        emit EventCreated(nextEventId, msg.sender, true, 0);
    }

    function placeBet(uint _eventId, bool _yesBet) external payable eventExists(_eventId) outcomeNotDeclared(_eventId) {
        Event storage betEvent = events[_eventId];
        if (msg.value == 0) {
            revert InsufficientBetAmount();
        }

        if (_yesBet) {
            betEvent.yesBets[msg.sender] += msg.value;
            betEvent.totalYesBets += msg.value;
        } else {
            betEvent.noBets[msg.sender] += msg.value;
            betEvent.totalNoBets += msg.value;
        }
        emit BetPlaced(_eventId, msg.sender, _yesBet, msg.value);
    }

    function declareOutcome(uint _eventId, bool _winningOutcome) external onlyAdmin outcomeNotDeclared(_eventId) { 
        Event storage betEvent = events[_eventId];
        
        betEvent.outcomeDeclared = true;
        betEvent.winningOutcome = _winningOutcome;
        betEvent.active = false;
        emit OutcomeDeclared(_eventId, _winningOutcome);
    }

    function claimWinnings(uint _eventId) external eventExists(_eventId) outcomeDeclared(_eventId) {
        Event storage betEvent = events[_eventId];
        require(betEvent.outcomeDeclared, "Outcome not declared");

        uint256 winnings;
        if (betEvent.winningOutcome) {
            winnings = betEvent.yesBets[msg.sender];
            if (winnings > 0) {
                uint256 totalPool = betEvent.totalYesBets + betEvent.totalNoBets;
                winnings = (winnings * totalPool) / betEvent.totalYesBets;
                betEvent.yesBets[msg.sender] = 0;
                (bool success, ) = payable(msg.sender).call{value: winnings}("");
                require(success, "Failed to transfer funds to winner");
                emit WinningsClaimed(_eventId, msg.sender, winnings);
            }
        } else {
            winnings = betEvent.noBets[msg.sender];
            if (winnings > 0) {
                uint256 totalPool = betEvent.totalYesBets + betEvent.totalNoBets;
                winnings = (winnings * totalPool) / betEvent.totalNoBets;
                betEvent.noBets[msg.sender] = 0;
                (bool success, ) = payable(msg.sender).call{value: winnings}("");
                require(success, "Failed to transfer funds to winner");
                emit WinningsClaimed(_eventId, msg.sender, winnings);
            }
        }
    }

    // View functions
    function getEventDetails(uint256 _eventId) external view returns (
        uint256 id,
        uint256 totalYesBets,
        uint256 totalNoBets,
        bool outcomeDeclared,
        bool winningOutcome,
        bool active
    ) {
        if (_eventId > nextEventId || _eventId == 0) {
            revert EventDoesNotExist();
        }
        Event storage betEvent = events[_eventId];
        return (
            betEvent.id,
            betEvent.totalYesBets,
            betEvent.totalNoBets,
            betEvent.outcomeDeclared,
            betEvent.winningOutcome,
            betEvent.active
        );
    }

    function getBetAmount(uint256 _eventId, address _bettor, bool _yesBet) external view returns (uint256) {
        if (_eventId > nextEventId || _eventId == 0) {
            revert EventDoesNotExist();
        }
        Event storage betEvent = events[_eventId];
        return _yesBet ? betEvent.yesBets[_bettor] : betEvent.noBets[_bettor];
    }
}