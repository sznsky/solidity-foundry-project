// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/console.sol";

contract Counter{

    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
        console.log("number set to", number);
    }

    function increment() public {
        number++;
        console.log("Number is incremented to", number);
    }
}