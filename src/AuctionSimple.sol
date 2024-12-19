//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AuctionSimple {
    address public seller;
    address public highestBidder;
    uint public highestBid;
    uint public endTime;
    mapping(address => uint) public cancelledBids;

    constructor(uint256 duration) {
        endTime = block.timestamp + duration;
        seller = msg.sender;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only the seller can call this function");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < endTime, "Auction has ended");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= endTime, "Auction is still ongoing");
        _;
    }    

    function placeBid() external payable  auctionActive{
        require(msg.value > highestBid);
        cancelledBids[msg.sender] = msg.value;
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdrawBid() external {
        require(msg.sender != highestBidder);
        require(block.timestamp < endTime);
        msg.sender.transfer(cancelledBids[msg.sender]);
        delete cancelledBids[msg.sender];
    }

    function finalizeAuction() public auctionEnded onlySeller{
        require(highestBidder != address(0));
        highestBidder.transfer(highestBid);
    }
}