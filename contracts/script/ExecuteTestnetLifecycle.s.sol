// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LongTailMarketFactory } from "../src/factory/LongTailMarketFactory.sol";
import { ILongTailMarketFactory } from "../src/factory/ILongTailMarketFactory.sol";
import { LongTailMarket } from "../src/market/LongTailMarket.sol";
import { ILongTailMarket } from "../src/market/ILongTailMarket.sol";
import { LongTailOutcomeToken } from "../src/market/LongTailOutcomeToken.sol";
import { OptimisticResolver } from "../src/resolution/OptimisticResolver.sol";
import { IOptimisticResolver } from "../src/resolution/IOptimisticResolver.sol";

contract ExecuteTestnetLifecycleScript is Script {
    address constant FACTORY_ADDR = 0xd72480faD3a5D732d753515dCf966aa93b9c4B8B;
    address constant TOKEN_ADDR = 0x4CD980838F7417a849C8d8dAF055Df50FD9648c6;
    address constant RESOLVER_ADDR = 0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9;
    address constant PRICING_ADDR = 0xfA58368866CA320da3deaA2F4fdDdf0228eDf273;

    receive() external payable {}

    function _executeMarket1(LongTailMarketFactory factory) internal returns (address marketAddr1) {
        console.log("--- Creating Market 1: Ecosystem & L1 ---");
        ILongTailMarketFactory.CreateMarketParams memory params1 = ILongTailMarketFactory.CreateMarketParams({
            question: "Will BOT Chain exceed 500,000 daily transactions in Q4 2026?",
            metadataURI: "ipfs://QmLongTailMarket1Metadata",
            category: "Ecosystem & Layer 1",
            closingTimestamp: uint64(block.timestamp + 30 days),
            resolutionDeadline: uint64(block.timestamp + 35 days),
            resolver: RESOLVER_ADDR,
            pricingModel: PRICING_ADDR,
            b: 0.2 ether,
            feeBps: 100 // 1%
        });

        uint256 marketId1;
        (marketId1, marketAddr1) = factory.createMarket{ value: 0.2 ether }(params1);
        console.log("Market 1 Created! ID:", marketId1, "Address:", marketAddr1);
        LongTailMarket market1 = LongTailMarket(payable(marketAddr1));

        console.log("--- Executing Buy YES on Market 1 (0.05 BOT) ---");
        uint256 yesShares = market1.buy{ value: 0.05 ether }(true, 0);
        console.log("Bought YES Shares:", yesShares);

        console.log("--- Executing Buy NO on Market 1 (0.04 BOT) ---");
        uint256 noShares = market1.buy{ value: 0.04 ether }(false, 0);
        console.log("Bought NO Shares:", noShares);

        uint256 sellAmount = yesShares / 4;
        console.log("--- Executing Sell YES on Market 1 ---");
        uint256 botProceeds = market1.sell(true, sellAmount, 0);
        console.log("Received BOT Proceeds:", botProceeds);

        console.log("--- Adding Liquidity to Market 1 (0.05 BOT) ---");
        uint256 lpShares = market1.addLiquidity{ value: 0.05 ether }();
        console.log("Minted LP Shares:", lpShares);

        console.log("--- Removing partial Liquidity from Market 1 ---");
        uint256 botFromLp = market1.removeLiquidity(lpShares / 4);
        console.log("Returned BOT from LP:", botFromLp);
    }

    function _executeMarket2(LongTailMarketFactory factory) internal returns (address marketAddr2) {
        console.log("--- Creating Market 2: AI & Tech ---");
        ILongTailMarketFactory.CreateMarketParams memory params2 = ILongTailMarketFactory.CreateMarketParams({
            question: "Will an Autonomous AI Agent execute a prediction market settlement on BOT Chain before December 2026?",
            metadataURI: "ipfs://QmLongTailMarket2Metadata",
            category: "AI & Tech",
            closingTimestamp: uint64(block.timestamp + 14 days),
            resolutionDeadline: uint64(block.timestamp + 21 days),
            resolver: RESOLVER_ADDR,
            pricingModel: PRICING_ADDR,
            b: 0.15 ether,
            feeBps: 150 // 1.5%
        });

        uint256 marketId2;
        (marketId2, marketAddr2) = factory.createMarket{ value: 0.15 ether }(params2);
        console.log("Market 2 Created! ID:", marketId2, "Address:", marketAddr2);
        LongTailMarket market2 = LongTailMarket(payable(marketAddr2));

        console.log("--- Executing Buy YES on Market 2 (0.05 BOT) ---");
        uint256 m2YesShares = market2.buy{ value: 0.05 ether }(true, 0);
        console.log("Market 2 YES Shares:", m2YesShares);
    }

    function _executeMarket3(LongTailMarketFactory factory, OptimisticResolver resolver) internal returns (address marketAddr3) {
        console.log("--- Creating Market 3: Fast Resolution Lifecycle ---");
        ILongTailMarketFactory.CreateMarketParams memory params3 = ILongTailMarketFactory.CreateMarketParams({
            question: "Will Bohr Testnet gas price remain at 20 Gwei throughout testing?",
            metadataURI: "ipfs://QmLongTailMarket3Metadata",
            category: "Bohr Testnet",
            closingTimestamp: uint64(block.timestamp + 1 days),
            resolutionDeadline: uint64(block.timestamp + 5 days),
            resolver: RESOLVER_ADDR,
            pricingModel: PRICING_ADDR,
            b: 0.15 ether,
            feeBps: 100 // 1%
        });

        uint256 marketId3;
        (marketId3, marketAddr3) = factory.createMarket{ value: 0.15 ether }(params3);
        console.log("Market 3 Created! ID:", marketId3, "Address:", marketAddr3);
        LongTailMarket market3 = LongTailMarket(payable(marketAddr3));

        console.log("--- Executing Buy YES on Market 3 (0.05 BOT) ---");
        uint256 m3YesShares = market3.buy{ value: 0.05 ether }(true, 0);
        console.log("Market 3 YES Shares:", m3YesShares);

        console.log("--- Configuring Fast Challenge Period on Resolver (60s) ---");
        resolver.setChallengePeriod(60);
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Executing Testnet Lifecycle on Bohr Testnet (968) ===");
        console.log("Deployer:", deployer);
        console.log("Deployer Balance:", deployer.balance);

        LongTailMarketFactory factory = LongTailMarketFactory(payable(FACTORY_ADDR));
        OptimisticResolver resolver = OptimisticResolver(payable(RESOLVER_ADDR));

        vm.startBroadcast(deployerPrivateKey);

        address m1 = _executeMarket1(factory);
        address m2 = _executeMarket2(factory);
        address m3 = _executeMarket3(factory, resolver);

        vm.stopBroadcast();

        console.log("=== Testnet Lifecycle Operations Complete ===");
        console.log("Market 1 Address:", m1);
        console.log("Market 2 Address:", m2);
        console.log("Market 3 Address:", m3);
    }
}
