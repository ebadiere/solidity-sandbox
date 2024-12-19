// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract RockPaperScissors {

    address public player1;
    address public player2;
    uint256 STAKE = 0.01 ether;
    bool gameActive;

    enum Choice{
        None,
        Rock,
        Paper,
        Scissors
    }

    mapping(address => Choice) choices;
    mapping(address => bytes32) commitments;

    modifier onlyPlayer(){
        require(msg.sender == player1 || msg.sender == player2);
        _;
    }


    error incorrectFee();
    error onlyTwoPlayersCanJoin();
    error gameNotActive();
    error alreadyCommitted();
    error notAPlayer();
    error noCommitment();
    error invalidReveal();
    error choiceNotRevealed();

    function joinGame(uint256 _fee) external payable  {
        if (_fee != 0.01 ether){
            revert incorrectFee();
        } 

        if (player1 != address(0) && player2 != address(0)){
            revert onlyTwoPlayersCanJoin();
        }

        if (player1 == address(0)) {
            player1 = msg.sender;
        } else {
            player2 = msg.sender;
            gameActive = true; // Game becomes active when second player joins
        }
    }

    // Players must commit hash = keccak256(abi.encodePacked(choice, salt))
    function commitChoice(bytes32 hashedChoice) external {
        if (msg.sender != player1 && msg.sender != player2) {
            revert notAPlayer();
        }
        if (!gameActive) {
            revert gameNotActive();
        }
        if (commitments[msg.sender] != bytes32(0)) {
            revert alreadyCommitted();
        }
        
        commitments[msg.sender] = hashedChoice;
    }

    // Verify the revealed choice and salt match the original commitment
    function revealChoice(Choice choice, bytes32 salt) external {
        if (msg.sender != player1 && msg.sender != player2) {
            revert notAPlayer();
        }
        if (!gameActive) {
            revert gameNotActive();
        }
        if (commitments[msg.sender] == bytes32(0)) {
            revert noCommitment();
        }
        
        bytes32 hash = keccak256(abi.encodePacked(choice, salt));
        if (hash != commitments[msg.sender]) {
            revert invalidReveal();
        }
        
        choices[msg.sender] = choice;
    }

    function resetGame() private {
        gameActive = false;
        delete choices[player1];
        delete choices[player2];
        delete commitments[player1];
        delete commitments[player2];
        player1 = address(0);
        player2 = address(0);
    }

    function determineWinner() external {
        if (!gameActive) {
            revert gameNotActive();
        }
        Choice player1Choice = choices[player1];
        Choice player2Choice = choices[player2];

        // Ensure both players have revealed their choices
        if (player1Choice == Choice.None || player2Choice == Choice.None) {
            revert choiceNotRevealed();
        }
        
        uint256 totalStake = address(this).balance;
        
        if (player1Choice == player2Choice) {
            // Draw - split the stakes
            payable(player1).transfer(totalStake / 2);
            payable(player2).transfer(totalStake / 2);
        } else if (
            (player1Choice == Choice.Rock && player2Choice == Choice.Scissors) ||
            (player1Choice == Choice.Paper && player2Choice == Choice.Rock) ||
            (player1Choice == Choice.Scissors && player2Choice == Choice.Paper)
        ) {
            // Player 1 wins - transfer total stake
            payable(player1).transfer(totalStake);
        } else {
            // Player 2 wins - transfer total stake
            payable(player2).transfer(totalStake);
        }

        resetGame();
    }

}