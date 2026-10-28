// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IOptimisticResolver } from "./IOptimisticResolver.sol";
import { ILongTailMarket } from "../market/ILongTailMarket.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title OptimisticResolver
/// @notice Bonded optimistic resolution with challenge periods, dispute arbitration, and evidence trails.
contract OptimisticResolver is IOptimisticResolver, Ownable, ReentrancyGuard {
    address public factory;
    address public arbitrator;
    uint64 public challengePeriod = 300; // 5 minutes on testnet for swift demo; up to 86400 (24h) on mainnet
    uint256 public proposalBond = 0.01 ether;
    uint256 public disputeBond = 0.02 ether;

    mapping(uint256 => Proposal) public proposals;

    event ArbitratorUpdated(address indexed newArbitrator);
    event ChallengePeriodUpdated(uint64 newChallengePeriod);
    event BondsUpdated(uint256 newProposalBond, uint256 newDisputeBond);
    event FactoryConfigured(address indexed factoryAddress);

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator && msg.sender != owner()) {
            revert Errors.Unauthorized();
        }
        _;
    }

    constructor(address initialArbitrator) Ownable(msg.sender) {
        if (initialArbitrator == address(0)) initialArbitrator = msg.sender;
        arbitrator = initialArbitrator;
    }

    function setFactory(address factory_) external onlyOwner {
        if (factory_ == address(0)) revert Errors.Unauthorized();
        factory = factory_;
        emit FactoryConfigured(factory_);
    }

    function setArbitrator(address arbitrator_) external onlyOwner {
        if (arbitrator_ == address(0)) revert Errors.Unauthorized();
        arbitrator = arbitrator_;
        emit ArbitratorUpdated(arbitrator_);
    }

    function setChallengePeriod(uint64 period) external onlyOwner {
        if (period < 60 || period > 30 days) revert Errors.InvalidTimestamps();
        challengePeriod = period;
        emit ChallengePeriodUpdated(period);
    }

    function setBonds(uint256 proposalBond_, uint256 disputeBond_) external onlyOwner {
        proposalBond = proposalBond_;
        disputeBond = disputeBond_;
        emit BondsUpdated(proposalBond_, disputeBond_);
    }

    function getMarket(uint256 marketId) public view returns (ILongTailMarket) {
        if (factory == address(0)) revert Errors.MarketNotFound();
        (bool success, bytes memory data) = factory.staticcall(
            abi.encodeWithSignature("getMarketAddress(uint256)", marketId)
        );
        if (!success || data.length < 32) revert Errors.MarketNotFound();
        address marketAddr = abi.decode(data, (address));
        if (marketAddr == address(0)) revert Errors.MarketNotFound();
        return ILongTailMarket(marketAddr);
    }

    function getProposal(uint256 marketId) external view override returns (Proposal memory) {
        return proposals[marketId];
    }

    /// @notice Proposes an outcome for a closed market by posting the proposal bond.
    function proposeOutcome(
        uint256 marketId,
        Outcome outcome,
        string calldata evidenceURI
    ) external payable override nonReentrant {
        if (outcome != Outcome.YES && outcome != Outcome.NO) revert Errors.InvalidOutcome();
        if (msg.value < proposalBond) revert Errors.InsufficientBond();

        ILongTailMarket market = getMarket(marketId);
        ILongTailMarket.MarketConfig memory config = market.getConfig();
        ILongTailMarket.MarketState memory state = market.getState();

        if (block.timestamp < config.closingTimestamp) revert Errors.TradingPeriodActive();
        if (state.status != ILongTailMarket.MarketStatus.CLOSED && state.status != ILongTailMarket.MarketStatus.ACTIVE) {
            revert Errors.InvalidStateTransition();
        }

        // Close market on-chain if still in active state
        if (state.status == ILongTailMarket.MarketStatus.ACTIVE) {
            market.closeMarket();
        }

        uint64 deadline = uint64(block.timestamp) + challengePeriod;
        proposals[marketId] = Proposal({
            outcome: outcome,
            proposer: msg.sender,
            proposedAt: uint64(block.timestamp),
            challengeDeadline: deadline,
            evidenceURI: evidenceURI,
            bond: msg.value,
            disputed: false,
            challenger: address(0),
            disputeEvidenceURI: "",
            disputeBond: 0,
            finalized: false
        });

        market.setStatus(ILongTailMarket.MarketStatus.PROPOSED);

        emit OutcomeProposed(marketId, outcome, msg.sender, deadline, evidenceURI, msg.value);
    }

    /// @notice Challenges a proposed outcome within the challenge window by posting the dispute bond.
    function disputeProposal(
        uint256 marketId,
        string calldata disputeEvidenceURI
    ) external payable override nonReentrant {
        Proposal storage p = proposals[marketId];
        if (p.proposedAt == 0 || p.finalized) revert Errors.MarketAlreadyResolved();
        if (p.disputed) revert Errors.MarketDisputedState();
        if (block.timestamp >= p.challengeDeadline) revert Errors.ChallengePeriodElapsed();
        if (msg.value < disputeBond) revert Errors.InsufficientBond();

        p.disputed = true;
        p.challenger = msg.sender;
        p.disputeEvidenceURI = disputeEvidenceURI;
        p.disputeBond = msg.value;

        ILongTailMarket market = getMarket(marketId);
        market.setStatus(ILongTailMarket.MarketStatus.DISPUTED);

        emit ProposalDisputed(marketId, msg.sender, disputeEvidenceURI, msg.value);
    }

    /// @notice Finalizes an undisputed proposal once the challenge window has elapsed.
    function finalizeProposal(uint256 marketId) external override nonReentrant {
        Proposal storage p = proposals[marketId];
        if (p.proposedAt == 0 || p.finalized) revert Errors.MarketAlreadyResolved();
        if (p.disputed) revert Errors.MarketDisputedState();
        if (block.timestamp < p.challengeDeadline) revert Errors.ChallengePeriodNotElapsed();

        p.finalized = true;
        ILongTailMarket.MarketStatus finalStatus = p.outcome == Outcome.YES
            ? ILongTailMarket.MarketStatus.RESOLVED_YES
            : ILongTailMarket.MarketStatus.RESOLVED_NO;

        // Refund proposer bond
        uint256 refundAmount = p.bond;
        p.bond = 0;
        (bool sent, ) = p.proposer.call{ value: refundAmount }("");
        if (!sent) revert Errors.TransferFailed();

        ILongTailMarket market = getMarket(marketId);
        market.setOutcome(finalStatus);

        emit ProposalFinalized(marketId, p.outcome);
    }

    /// @notice Resolves a disputed market; callable only by designated arbitrator.
    function resolveDispute(
        uint256 marketId,
        Outcome finalOutcome
    ) external override onlyArbitrator nonReentrant {
        Proposal storage p = proposals[marketId];
        if (!p.disputed || p.finalized) revert Errors.InvalidStateTransition();

        p.finalized = true;
        ILongTailMarket market = getMarket(marketId);

        if (finalOutcome == Outcome.INVALID) {
            // Cancel market and refund both parties their bonds
            uint256 pBond = p.bond;
            uint256 dBond = p.disputeBond;
            p.bond = 0;
            p.disputeBond = 0;

            if (pBond > 0) {
                (bool s1, ) = p.proposer.call{ value: pBond }("");
                if (!s1) revert Errors.TransferFailed();
            }
            if (dBond > 0) {
                (bool s2, ) = p.challenger.call{ value: dBond }("");
                if (!s2) revert Errors.TransferFailed();
            }

            market.setOutcome(ILongTailMarket.MarketStatus.CANCELLED);
            emit MarketCancelled(marketId, "Arbitrator declared market invalid");
            return;
        }

        address winner;
        uint256 totalBonds = p.bond + p.disputeBond;
        p.bond = 0;
        p.disputeBond = 0;

        if (finalOutcome == p.outcome) {
            // Proposer wins
            winner = p.proposer;
        } else {
            // Challenger wins
            winner = p.challenger;
        }

        (bool sent, ) = winner.call{ value: totalBonds }("");
        if (!sent) revert Errors.TransferFailed();

        ILongTailMarket.MarketStatus finalStatus = finalOutcome == Outcome.YES
            ? ILongTailMarket.MarketStatus.RESOLVED_YES
            : ILongTailMarket.MarketStatus.RESOLVED_NO;

        market.setOutcome(finalStatus);
        emit DisputeResolved(marketId, finalOutcome, winner);
    }

    /// @notice Direct cancellation path for markets with unresolvable or ambiguous questions.
    function cancelMarket(uint256 marketId, string calldata reasonURI) external override onlyArbitrator nonReentrant {
        Proposal storage p = proposals[marketId];
        if (p.finalized) revert Errors.MarketAlreadyResolved();

        p.finalized = true;
        uint256 pBond = p.bond;
        uint256 dBond = p.disputeBond;
        p.bond = 0;
        p.disputeBond = 0;

        if (pBond > 0) {
            (bool s1, ) = p.proposer.call{ value: pBond }("");
            if (!s1) revert Errors.TransferFailed();
        }
        if (dBond > 0) {
            (bool s2, ) = p.challenger.call{ value: dBond }("");
            if (!s2) revert Errors.TransferFailed();
        }

        ILongTailMarket market = getMarket(marketId);
        market.setOutcome(ILongTailMarket.MarketStatus.CANCELLED);
        emit MarketCancelled(marketId, reasonURI);
    }
}
