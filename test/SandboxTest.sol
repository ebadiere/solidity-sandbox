// test/Sandbox.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract SandboxTest is Test {
    address user = makeAddr("user");
    
    function setUp() public {
        vm.deal(user, 100 ether); // Give test address some ETH
    }
    
    function test_Something() public {
        // Your test code here
        console2.log("Balance:", address(user).balance);
    }
}