//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AuctionAdvanced.sol";

contract AuctionAdvancedTest is Test {
    AuctionAdvanced public auction;
    address public seller;
    address public bidder1;
    address public bidder2;
    uint public constant AUCTION_DURATION = 1 days;
    uint public constant INITIAL_BALANCE = 10 ether;

    function setUp() public {
        auction = new AuctionAdvanced();
        seller = makeAddr("seller");
        bidder1 = makeAddr("bidder1");
        bidder2 = makeAddr("bidder2");

        // Fund the bidders
        vm.deal(bidder1, INITIAL_BALANCE);
        vm.deal(bidder2, INITIAL_BALANCE);
    }

    function test_CreateAuction() public {
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);
        
        (address _seller, address highestBidder, uint highestBid, uint endTime, bool isActive) = auction.auctions(0);
        assertEq(_seller, seller);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertEq(endTime, block.timestamp + AUCTION_DURATION);
        assertTrue(isActive);
    }

    function test_PlaceBid() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place first bid
        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(0);

        // Check bid was recorded
        (,address highestBidder, uint highestBid,,) = auction.auctions(0);
        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 1 ether);
    }

    function test_PlaceHigherBid() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place first bid
        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(0);

        // Place higher bid
        vm.prank(bidder2);
        auction.placeBid{value: 2 ether}(0);

        // Check new bid was recorded and previous bidder was refunded
        (,address highestBidder, uint highestBid,,) = auction.auctions(0);
        assertEq(highestBidder, bidder2);
        assertEq(highestBid, 2 ether);
        assertEq(bidder1.balance, INITIAL_BALANCE);
    }

    function testFail_PlaceLowerBid() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place first bid
        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(0);

        // Try to place lower bid
        vm.prank(bidder2);
        auction.placeBid{value: 1 ether}(0);
    }

    function test_WithdrawBid() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place bids
        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(0);
        
        vm.prank(bidder2);
        auction.placeBid{value: 2 ether}(0);

        // Bidder1 should be able to withdraw their refunded bid
        uint initialBalance = bidder1.balance;
        vm.prank(bidder1);
        auction.withdrawBid(0);
        
        assertEq(bidder1.balance, initialBalance + 1 ether);
    }

    function testFail_HighestBidderWithdraw() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place bid
        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(0);

        // Try to withdraw highest bid
        vm.prank(bidder1);
        auction.withdrawBid(0);
    }

    function test_FinalizeAuction() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Place bids
        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(0);
        
        vm.prank(bidder2);
        auction.placeBid{value: 2 ether}(0);

        // Fast forward past auction end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Finalize auction
        vm.prank(seller);
        auction.finalizeAuction(0);

        // Check auction state
        (,,,, bool isActive) = auction.auctions(0);
        assertFalse(isActive);
        assertEq(seller.balance, 2 ether);
    }

    function testFail_EarlyFinalize() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Try to finalize before end time
        vm.prank(seller);
        auction.finalizeAuction(0);
    }

    function testFail_NonSellerFinalize() public {
        // Create auction
        vm.prank(seller);
        auction.createAuction(AUCTION_DURATION);

        // Fast forward past auction end
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        // Try to finalize from non-seller account
        vm.prank(bidder1);
        auction.finalizeAuction(0);
    }
}
