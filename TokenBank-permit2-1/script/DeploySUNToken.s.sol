// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {SUNToken} from "../src/SUNToken.sol";

contract DeploySUNToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address: ", deployer);
        console.log("Deploying SUNToken to Anvil local chain...");
        
        vm.startBroadcast(deployerPrivateKey);

        SUNToken sunToken = new SUNToken();
        console.log("SUNToken deployed at: %s", address(sunToken));
        
        vm.stopBroadcast();
        console.log("SUNToken address saved to deployment_sunt.env");
    }
}