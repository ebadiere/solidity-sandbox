//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AuctionSimple {
    address payable public seller;
    address payable public highestBidder;
    uint public highestBid;
    uint public endTime;
    bool public ended;

    mapping(address => uint) public cancelledBids;

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= endTime, "Auction not yet ended");
        require(!ended, "Auction already ended");
        _;
    }

    constructor(uint _duration) {
        seller = payable(msg.sender);
        endTime = block.timestamp + _duration;
    }

    function placeBid() external payable {
        require(block.timestamp < endTime, "Auction already ended");
        require(msg.value > highestBid, "Bid not high enough");

        if (highestBidder != address(0)) {
            cancelledBids[highestBidder] = highestBid;
        }

        highestBidder = payable(msg.sender);
        highestBid = msg.value;
    }

    function cancelBid() public {
        require(cancelledBids[msg.sender] > 0, "No bid to cancel");
        uint amount = cancelledBids[msg.sender];
        cancelledBids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to refund bid");
    }

    function finalizeAuction() public auctionEnded onlySeller {
        ended = true;
        (bool success, ) = payable(highestBidder).call{value: highestBid}("");
        require(success, "Failed to transfer funds to highest bidder");
    }
}