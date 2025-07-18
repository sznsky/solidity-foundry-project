// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13; // Match your MyToken's pragma

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol"; // Import your MyToken contract

contract MyTokenTest is Test {
    MyToken public myToken;

    // The deployer address that will receive the initial tokens
    address public deployer;

    function setUp() public {
        // Set a specific address as the deployer for consistent testing.
        // In Foundry, `address(this)` represents the test contract itself,
        // which by default is the `msg.sender` for deployments within setUp.
        deployer = address(this);

        // Deploy MyToken. It will automatically mint to `msg.sender` (which is `deployer` here).
        // Pass the constructor arguments for name and symbol.
        myToken = new MyToken("MyTestToken", "MTT");
    }

    function test_InitialSupplyAndBalance() public {
        // Expected total supply: 10,000,000,000 * 10^18
        uint256 expectedSupply = 10_000_000_000 * (10**18); // Using underscores for readability

        // Verify the total supply
        assertEq(myToken.totalSupply(), expectedSupply, "Total supply should be 10 billion tokens");

        // Verify the deployer's balance
        assertEq(myToken.balanceOf(deployer), expectedSupply, "Deployer should own all initial tokens");
    }

    // You can add more tests here, for example:
    // - test_TransferFunctionality()
    // - test_ApproveAndTransferFrom()
    // - test_PausableFeatures (if you add them later)
}