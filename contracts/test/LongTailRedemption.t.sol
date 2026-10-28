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
import { IOptimisticResolver } from "../src/resolution/IOptimisticResolver.sol";
import { Errors } from "../src/libraries/Errors.sol";

contract LongTailRedemptionTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;
    ILongTailMarket public market;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public winner = address(0xBB11);
    address public loser = address(0xCC22);

    uint256 public marketId;
    uint256 public initialSeed = 5 ether;

    receive() external payable {}

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(winner, 100 ether);
        vm.deal(loser, 100 ether);

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
            question: "Will Solana average over 2,000 TPS for a full week?",
            metadataURI: "ipfs://QmSolanaTest",
            category: "Protocols",
            closingTimestamp: uint64(block.timestamp + 10 days),
            resolutionDeadline: uint64(block.timestamp + 15 days),
            resolver: address(resolver),
            pricingModel: address(pricingModel),
            b: initialSeed,
            feeBps: 100
        });

        address marketAddr;
        (marketId, marketAddr) = factory.createMarket{ value: initialSeed }(params);
        market = ILongTailMarket(marketAddr);
        vm.stopPrank();

        // Winner buys YES
        vm.prank(winner);
        market.buy{ value: 2 ether }(true, 1);

        // Loser buys NO
        vm.prank(loser);
        market.buy{ value: 2 ether }(false, 1);
    }

    function test_RevertWhen_RedeemingBeforeResolution() public {
        vm.prank(winner);
        vm.expectRevert(Errors.MarketNotResolved.selector);
        market.redeem();
    }

    function test_SuccessfulRedemptionForWinnerAndRejectionForLoser() public {
        // Fast-forward past closing
        vm.warp(block.timestamp + 11 days);

        // Propose outcome YES
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://solanabeach.io/stats"
        );

        // Fast-forward past challenge period
        vm.warp(block.timestamp + 301);
        resolver.finalizeProposal(marketId);

        uint256 yesTokenId = outcomeToken.getTokenId(marketId, true);
        uint256 winningShares = outcomeToken.balanceOf(winner, yesTokenId);
        assertTrue(winningShares > 0);

        // Winner redeems
        uint256 winnerBalBefore = winner.balance;
        vm.prank(winner);
        uint256 payout = market.redeem();

        // 1 BOT payout per winning share
        assertEq(payout, winningShares);
        assertEq(winner.balance, winnerBalBefore + payout);
        assertEq(outcomeToken.balanceOf(winner, yesTokenId), 0);

        // Loser tries to redeem (holds NO shares, but YES won)
        vm.prank(loser);
        vm.expectRevert(Errors.NothingToRedeem.selector);
        market.redeem();
    }

    function test_DoubleRedemptionRejection() public {
        vm.warp(block.timestamp + 11 days);

        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://solana.com"
        );

        vm.warp(block.timestamp + 301);
        resolver.finalizeProposal(marketId);

        // Winner redeems first time
        vm.prank(winner);
        market.redeem();

        // Winner tries to redeem second time
        vm.prank(winner);
        vm.expectRevert(Errors.NothingToRedeem.selector);
        market.redeem();
    }

    function test_ClaimRefundOnCancelledMarket() public {
        vm.warp(block.timestamp + 11 days);

        // Arbitrator cancels market
        resolver.cancelMarket(marketId, "Invalid criteria");

        uint256 balBefore = winner.balance;
        vm.prank(winner);
        uint256 refund = market.claimRefund();

        assertTrue(refund > 0);
        assertEq(winner.balance, balBefore + refund);

        // Cannot claim refund twice
        vm.prank(winner);
        vm.expectRevert(Errors.NothingToRedeem.selector);
        market.claimRefund();
    }
}
