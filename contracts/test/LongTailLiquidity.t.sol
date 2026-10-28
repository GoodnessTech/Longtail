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
import { Errors } from "../src/libraries/Errors.sol";

contract LongTailLiquidityTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;
    ILongTailMarket public market;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public lpProvider = address(0xBB22);
    address public trader = address(0xCC33);

    uint256 public marketId;
    uint256 public initialSeed = 10 ether;

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(lpProvider, 100 ether);
        vm.deal(trader, 100 ether);

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
            question: "Will ETH ETF net inflows exceed $5B this quarter?",
            metadataURI: "ipfs://QmDeFiTest",
            category: "DeFi",
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

    function test_InitialLiquidityAssignedToCreator() public view {
        (uint256 shares, uint256 withdrawable) = market.getLpPosition(creator);
        assertEq(shares, initialSeed);
        assertEq(withdrawable, initialSeed);
    }

    function test_AddLiquidityMintsLpShares() public {
        vm.startPrank(lpProvider);
        uint256 deposit = 5 ether;
        uint256 lpShares = market.addLiquidity{ value: deposit }();
        vm.stopPrank();

        assertTrue(lpShares > 0);
        (uint256 shares, ) = market.getLpPosition(lpProvider);
        assertEq(shares, lpShares);

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(st.collateralBalance, initialSeed + deposit);
    }

    function test_RemoveFreeLiquiditySuccess() public {
        vm.startPrank(creator);
        (uint256 sharesBefore, ) = market.getLpPosition(creator);
        uint256 withdrawShares = sharesBefore / 2;

        uint256 balBefore = creator.balance;
        uint256 withdrawn = market.removeLiquidity(withdrawShares);
        vm.stopPrank();

        assertTrue(withdrawn > 0);
        assertEq(creator.balance, balBefore + withdrawn);
    }

    function test_ReservedCollateralProtection() public {
        // Trader makes large purchase of YES shares
        vm.startPrank(trader);
        uint256 tradeAmount = 20 ether;
        uint256 sharesBought = market.buy{ value: tradeAmount }(true, 1);
        vm.stopPrank();

        // Maximum potential payout liability is now sharesBought (since qYes = sharesBought, qNo = 0)
        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(st.qYes, sharesBought);

        // Creator attempts to withdraw ALL their LP shares
        vm.startPrank(creator);
        (uint256 creatorShares, uint256 withdrawable) = market.getLpPosition(creator);

        // Collateral balance must always remain >= sharesBought
        assertTrue(st.collateralBalance >= sharesBought);

        // If creator withdraws their maximum allowed free liquidity:
        if (withdrawable > 0) {
            market.removeLiquidity(creatorShares);
        }

        // Verify that after withdrawal, market collateral is still >= maximum liability!
        ILongTailMarket.MarketState memory stAfter = market.getState();
        assertTrue(stAfter.collateralBalance >= stAfter.qYes);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawingMoreSharesThanOwned() public {
        vm.startPrank(lpProvider);
        vm.expectRevert(Errors.InsufficientLpShares.selector);
        market.removeLiquidity(1 ether);
        vm.stopPrank();
    }
}
