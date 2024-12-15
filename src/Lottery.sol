// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Lottery {
    address public manager;
    address[] public players;
    uint256 public lotteryEndTime;
    bool public lotteryFinished;

    error LotteryClosed();
    error ZeroPointOneEthNotSent();
    error LotteryNotEnded();
    error NoPlayers();
    error TransferFailed();

    event WinnerPicked(address indexed winner, uint256 amount);

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can perform this action");
        _;
    }

    constructor(uint256 _lotteryEndTime) {
        manager = msg.sender;
        lotteryEndTime = _lotteryEndTime;
        lotteryFinished = false;
    }

    function enter() public payable {
        if(block.timestamp > lotteryEndTime) {
            revert LotteryClosed();
        }

        if(msg.value != 0.1 ether) {
            revert ZeroPointOneEthNotSent();
        }
        players.push(msg.sender);
    }

    function pickWinner() public onlyManager {
        if(block.timestamp <= lotteryEndTime) {
            revert LotteryNotEnded();
        }
        
        if(players.length == 0) {
            revert NoPlayers();
        }

        if(lotteryFinished) {
            revert LotteryClosed();
        }

        // Using block difficulty, timestamp, and players array for better randomness
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.difficulty,
                    block.timestamp,
                    players
                )
            )
        ) % players.length;

        address winner = players[randomIndex];
        uint256 prizeAmount = address(this).balance;
        
        // Mark lottery as finished before transfer to prevent reentrancy
        lotteryFinished = true;
        
        // Transfer the prize
        (bool success, ) = winner.call{value: prizeAmount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit WinnerPicked(winner, prizeAmount);

        // Clear the players array
        delete players;
    }

    function getPlayers() public view returns (address[] memory) {
        return players;
    }

    function getLotteryBalance() public view returns (uint256) {
        return address(this).balance;
    }
}