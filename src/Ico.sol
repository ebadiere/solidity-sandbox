// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Ico {

    address public admin;
    address public token;
    uint256 public tokenPrice;
    uint256 endTime;
    uint256 public tokensAvailable;

    mapping(address => uint256) public balances;

    constructor(address _token, uint256 _tokenPrice, uint256 _tokensAvailable, uint256 _duration) {
        admin = msg.sender;
        token = _token;
        tokenPrice = _tokenPrice;
        tokensAvailable = _tokensAvailable;
        endTime = block.timestamp + _duration;
    } 

    function buyTokens() public payable {
        require(block.timestamp < endTime, "ICO has ended");
        require(msg.value >= tokenPrice, "Insufficient funds");
        uint256 tokens = msg.value / tokenPrice;
        require(tokens <= tokensAvailable, "Not enough tokens available");
        
        // Transfer tokens using ERC20 interface
        (bool success, ) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, tokens)
        );
        require(success, "Token transfer failed");
        
        balances[msg.sender] += tokens;
        tokensAvailable -= tokens;
    }      

    function withdrawFunds() public {
        require(msg.sender == admin);
        payable(msg.sender).transfer(address(this).balance);
    }

}