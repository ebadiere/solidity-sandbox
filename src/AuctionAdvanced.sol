//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AuctionAdvanced {
    struct Auction {
        address payable seller;
        address payable highestBidder;
        uint highestBid;
        uint endTime;
        bool isActive;
        mapping(address => uint) bids;
    }

    event AuctionCreated(address _seller, uint _endTime);
    event BidPlaced(uint indexed auctionId, address indexed bidder, uint amount);
    event BidRefunded(address indexed bidder, uint amount);
    event AuctionFinalized(uint indexed auctionId, address winner, uint amount);

    modifier onlySeller(uint auctionId) {
        require(msg.sender == auctions[auctionId].seller, "Only the seller can call this function");
        _;
    }

    modifier auctionActive(uint auctionId) {
        require(auctions[auctionId].isActive, "Auction is not active");
        require(block.timestamp < auctions[auctionId].endTime, "Auction has ended");
        _;
    }

    modifier auctionEnded(uint auctionId) {
        require(block.timestamp >= auctions[auctionId].endTime, "Auction is still ongoing");
        require(auctions[auctionId].isActive, "Auction is not active");
        _;
    }

    mapping(uint => Auction) public auctions;
    uint nextAuctionId;

    function createAuction(uint _duration) external {
        uint auctionId = nextAuctionId++;
        Auction storage auction = auctions[auctionId];
        auction.seller = payable(msg.sender);
        auction.endTime = block.timestamp + _duration;
        auction.isActive = true;
        emit AuctionCreated(msg.sender, auction.endTime);
    }

    function placeBid(uint _auctionId) external payable auctionActive(_auctionId) {
        Auction storage auction = auctions[_auctionId];
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");

        // Store previous highest bidder and bid
        address previousBidder = auction.highestBidder;
        uint previousBid = auction.highestBid;

        // Update auction with new highest bid
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = msg.value;
        auction.bids[msg.sender] = msg.value;

        // Refund the previous highest bidder
        if (previousBidder != address(0)) {
            auction.bids[previousBidder] = previousBid;
            (bool success, ) = payable(previousBidder).call{value: previousBid}("");
            require(success, "Failed to refund previous bidder");
            emit BidRefunded(previousBidder, previousBid);
        }

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function withdrawBid(uint _auctionId) external auctionActive(_auctionId) {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender != auction.highestBidder, "Highest bidder cannot withdraw");
        
        uint bidAmount = auction.bids[msg.sender];
        require(bidAmount > 0, "No bid to withdraw");
        
        auction.bids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bidAmount}("");
        require(success, "Failed to withdraw bid");
        emit BidRefunded(msg.sender, bidAmount);
    }

    function finalizeAuction(uint _auctionId) external onlySeller(_auctionId) auctionEnded(_auctionId) {
        Auction storage auction = auctions[_auctionId];
        
        address winner = auction.highestBidder;
        uint finalAmount = auction.highestBid;
        
        auction.isActive = false;
        
        // Transfer the highest bid to the seller
        if (finalAmount > 0) {
            (bool success, ) = payable(auction.seller).call{value: finalAmount}("");
            require(success, "Failed to transfer funds to seller");
        }

        emit AuctionFinalized(_auctionId, winner, finalAmount);
    }
}