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

contract LongTailResolutionTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;
    ILongTailMarket public market;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public proposer = address(0xBB11);
    address public challenger = address(0xCC22);

    uint256 public marketId;
    uint256 public initialSeed = 5 ether;

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(challenger, 100 ether);

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
            question: "Will the next iPhone ship with a foldable display?",
            metadataURI: "ipfs://QmProductTest",
            category: "Products",
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
    }

    function test_RevertWhen_ProposeBeforeClosing() public {
        vm.startPrank(proposer);
        vm.expectRevert(Errors.TradingPeriodActive.selector);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://evidence.com/report1"
        );
        vm.stopPrank();
    }

    function test_ProposeOutcomeSuccess() public {
        // Fast-forward past closing timestamp (10 days)
        vm.warp(block.timestamp + 11 days);

        vm.startPrank(proposer);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://apple.com/keynote"
        );
        vm.stopPrank();

        IOptimisticResolver.Proposal memory p = resolver.getProposal(marketId);
        assertEq(uint256(p.outcome), uint256(IOptimisticResolver.Outcome.YES));
        assertEq(p.proposer, proposer);
        assertEq(p.bond, 0.01 ether);
        assertFalse(p.disputed);
        assertFalse(p.finalized);

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(uint256(st.status), uint256(ILongTailMarket.MarketStatus.PROPOSED));
    }

    function test_FinalizeUndisputedProposalRefundsBond() public {
        vm.warp(block.timestamp + 11 days);

        uint256 proposerBalBefore = proposer.balance;
        vm.prank(proposer);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://apple.com/keynote"
        );

        // Fast-forward past challenge period (5 minutes = 300 seconds)
        vm.warp(block.timestamp + 301);

        resolver.finalizeProposal(marketId);

        // Proposer bond should be refunded in full
        assertEq(proposer.balance, proposerBalBefore);

        // Market should be RESOLVED_YES
        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(uint256(st.status), uint256(ILongTailMarket.MarketStatus.RESOLVED_YES));
    }

    function test_DisputeAndArbitrationProposerWins() public {
        vm.warp(block.timestamp + 11 days);

        vm.prank(proposer);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://apple.com/keynote"
        );

        // Challenger disputes within challenge period
        vm.prank(challenger);
        resolver.disputeProposal{ value: 0.02 ether }(
            marketId,
            "https://apple.com/dispute-evidence"
        );

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(uint256(st.status), uint256(ILongTailMarket.MarketStatus.DISPUTED));

        // Arbitrator rules in favor of proposer (YES)
        uint256 proposerBalBefore = proposer.balance;
        resolver.resolveDispute(marketId, IOptimisticResolver.Outcome.YES);

        // Proposer receives both bonds (0.01 + 0.02 = 0.03 ether)
        assertEq(proposer.balance, proposerBalBefore + 0.03 ether);

        ILongTailMarket.MarketState memory stResolved = market.getState();
        assertEq(uint256(stResolved.status), uint256(ILongTailMarket.MarketStatus.RESOLVED_YES));
    }

    function test_DisputeAndArbitrationChallengerWins() public {
        vm.warp(block.timestamp + 11 days);

        vm.prank(proposer);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://false-evidence.com"
        );

        vm.prank(challenger);
        resolver.disputeProposal{ value: 0.02 ether }(
            marketId,
            "https://official.apple.com/press"
        );

        // Arbitrator rules in favor of challenger (NO)
        uint256 challengerBalBefore = challenger.balance;
        resolver.resolveDispute(marketId, IOptimisticResolver.Outcome.NO);

        // Challenger receives both bonds
        assertEq(challenger.balance, challengerBalBefore + 0.03 ether);

        ILongTailMarket.MarketState memory stResolved = market.getState();
        assertEq(uint256(stResolved.status), uint256(ILongTailMarket.MarketStatus.RESOLVED_NO));
    }

    function test_CancellationPath() public {
        vm.warp(block.timestamp + 11 days);

        vm.prank(proposer);
        resolver.proposeOutcome{ value: 0.01 ether }(
            marketId,
            IOptimisticResolver.Outcome.YES,
            "https://evidence.com"
        );

        vm.prank(challenger);
        resolver.disputeProposal{ value: 0.02 ether }(
            marketId,
            "https://evidence.com/dispute"
        );

        uint256 propBal = proposer.balance;
        uint256 chalBal = challenger.balance;

        // Arbitrator declares market invalid
        resolver.resolveDispute(marketId, IOptimisticResolver.Outcome.INVALID);

        // Both parties get their bonds back
        assertEq(proposer.balance, propBal + 0.01 ether);
        assertEq(challenger.balance, chalBal + 0.02 ether);

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(uint256(st.status), uint256(ILongTailMarket.MarketStatus.CANCELLED));
    }
}
