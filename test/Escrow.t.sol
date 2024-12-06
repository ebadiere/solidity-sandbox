// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    address public admin = address(0x1);
    address public buyer1 = address(0x2);
    address public buyer2 = address(0x3);
    address public seller1 = address(0x4);
    address public seller2 = address(0x5);

    function setUp() public {
        // Fund test addresses
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        
        // Setup arrays for escrow
        address[] memory buyers = new address[](2);
        buyers[0] = buyer1;
        buyers[1] = buyer2;

        address[] memory sellers = new address[](2);
        sellers[0] = seller1;
        sellers[1] = seller2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        escrow = new Escrow(buyers, sellers, amounts, admin);
    }

    function testConstructor() public {
        // Test with zero address admin
        address[] memory buyers = new address[](1);
        address[] memory sellers = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        vm.expectRevert("Admin cannot be zero address");
        new Escrow(buyers, sellers, amounts, address(0));
    }

    function testDeposit() public {
        // Test successful deposit from buyer1
        vm.prank(buyer1);
        escrow.deposit{value: 1 ether}();

        // Test successful deposit from buyer2
        vm.prank(buyer2);
        escrow.deposit{value: 2 ether}();

        // Test deposit from non-buyer
        address nonBuyer = address(0x9);
        vm.deal(nonBuyer, 1 ether);
        vm.prank(nonBuyer);
        vm.expectRevert("Only buyers can deposit");
        escrow.deposit{value: 1 ether}();

        // Test zero value deposit
        vm.prank(buyer1);
        vm.expectRevert("Must send ETH");
        escrow.deposit{value: 0}();
    }

    function testAuthorizationRequiresAllDeposits() public {
        // Only buyer1 deposits
        vm.prank(buyer1);
        escrow.deposit{value: 1 ether}();

        // Try to authorize without buyer2's deposit
        vm.prank(admin);
        vm.expectRevert("All buyers must deposit");
        escrow.authorizeTransaction();

        // Now let buyer2 deposit
        vm.prank(buyer2);
        escrow.deposit{value: 2 ether}();

        // Authorization should now succeed
        vm.prank(admin);
        escrow.authorizeTransaction();
    }

    function testAuthorizeTransaction() public {
        // Setup: make deposits from all buyers
        vm.prank(buyer1);
        escrow.deposit{value: 1 ether}();
        vm.prank(buyer2);
        escrow.deposit{value: 2 ether}();

        // Test non-admin cannot authorize
        vm.prank(buyer1);
        vm.expectRevert("Only admin can perform this action");
        escrow.authorizeTransaction();

        // Test successful authorization by admin
        vm.prank(admin);
        // vm.expectRevert("All buyers must deposit");
        escrow.authorizeTransaction();

        // Test cannot authorize twice
        vm.prank(admin);
        vm.expectRevert("Transaction already authorized");
        escrow.authorizeTransaction();
    }

    function testWithdraw() public {
        // Setup: make deposits
        vm.prank(buyer1);
        escrow.deposit{value: 1 ether}();
        vm.prank(buyer2);
        escrow.deposit{value: 2 ether}();

        // Try withdraw before authorization
        vm.prank(seller1);
        vm.expectRevert("Transaction not yet authorized");
        escrow.withdraw();

        // Authorize transaction
        vm.prank(admin);
        escrow.authorizeTransaction();

        // Test successful withdrawal
        uint256 seller1BalanceBefore = seller1.balance;
        vm.prank(seller1);
        escrow.withdraw();
        assertEq(seller1.balance, seller1BalanceBefore + 1 ether);

        // Test cannot withdraw twice
        vm.prank(seller1);
        vm.expectRevert("No funds to withdraw");
        escrow.withdraw();

        // Test non-seller cannot withdraw
        vm.prank(buyer1);
        vm.expectRevert("No funds to withdraw");
        escrow.withdraw();
    }

    receive() external payable {}
}
