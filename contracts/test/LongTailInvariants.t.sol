// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { LongTailMarketFactory } from "../src/factory/LongTailMarketFactory.sol";
import { ILongTailMarketFactory } from "../src/factory/ILongTailMarketFactory.sol";
import { LongTailMarket } from "../src/market/LongTailMarket.sol";
import { ILongTailMarket } from "../src/market/ILongTailMarket.sol";
import { LongTailOutcomeToken } from "../src/market/LongTailOutcomeToken.sol";
import { LMSRPricingModel } from "../src/pricing/LMSRPricingModel.sol";
import { OptimisticResolver } from "../src/resolution/OptimisticResolver.sol";
import { FixedPointMath } from "../src/libraries/FixedPointMath.sol";

contract LongTailInvariantsTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;
    ILongTailMarket public market;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public trader1 = address(0xBB11);
    address public trader2 = address(0xCC22);

    uint256 public marketId;
    uint256 public initialSeed = 10 ether;

    function setUp() public {
        vm.deal(creator, 500 ether);
        vm.deal(trader1, 500 ether);
        vm.deal(trader2, 500 ether);

        implementation = new LongTailMarket();
        outcomeToken = new LongTailOutcomeToken("https://api.longtail.io/token/{id}.json");
        pricingModel = new LMSRPricingModel();
        resolver = new OptimisticResolver(owner);

        factory = new LongTailMarketFactory(
            address(implementation),
            address(outcomeToken),
            address(resolver),
            address(pricingModel),
            owner
        );

        outcomeToken.setFactory(address(factory));
        resolver.setFactory(address(factory));

        vm.startPrank(creator);
        ILongTailMarketFactory.CreateMarketParams memory params = ILongTailMarketFactory.CreateMarketParams({
            question: "Will AI agents account for 10% of DeFi volume?",
            metadataURI: "ipfs://QmAIInvariant",
            category: "AI",
            closingTimestamp: uint64(block.timestamp + 30 days),
            resolutionDeadline: uint64(block.timestamp + 35 days),
            resolver: address(resolver),
            pricingModel: address(pricingModel),
            b: initialSeed,
            feeBps: 100
        });

        address marketAddr;
        (marketId, marketAddr) = factory.createMarket{ value: initialSeed }(params);
        market = ILongTailMarket(marketAddr);
        vm.stopPrank();
    }

    /// @notice Invariant: Market collateral balance must always be >= max(qYes, qNo) under all trade trajectories
    function testFuzz_SolvencyInvariant(uint256 amount1, uint256 amount2, bool side1, bool side2) public {
        // Bound inputs to realistic testnet amounts: 0.05 ether to 10 ether
        amount1 = bound(amount1, 0.05 ether, 10 ether);
        amount2 = bound(amount2, 0.05 ether, 10 ether);

        vm.prank(trader1);
        market.buy{ value: amount1 }(side1, 1);

        ILongTailMarket.MarketState memory st1 = market.getState();
        uint256 maxLiability1 = st1.qYes >= st1.qNo ? st1.qYes : st1.qNo;
        assertTrue(st1.collateralBalance >= maxLiability1, "Solvency invariant violated after trade 1");

        vm.prank(trader2);
        market.buy{ value: amount2 }(side2, 1);

        ILongTailMarket.MarketState memory st2 = market.getState();
        uint256 maxLiability2 = st2.qYes >= st2.qNo ? st2.qYes : st2.qNo;
        assertTrue(st2.collateralBalance >= maxLiability2, "Solvency invariant violated after trade 2");
    }

    /// @notice Invariant: Outcome tokens minted must match market inventory state
    function test_TokenSupplyMatchesAccounting() public {
        vm.prank(trader1);
        uint256 yesShares = market.buy{ value: 3 ether }(true, 1);

        vm.prank(trader2);
        uint256 noShares = market.buy{ value: 4 ether }(false, 1);

        uint256 yesTokenId = outcomeToken.getTokenId(marketId, true);
        uint256 noTokenId = outcomeToken.getTokenId(marketId, false);

        assertEq(outcomeToken.balanceOf(trader1, yesTokenId), yesShares);
        assertEq(outcomeToken.balanceOf(trader2, noTokenId), noShares);

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(st.qYes, yesShares);
        assertEq(st.qNo, noShares);
    }
}
