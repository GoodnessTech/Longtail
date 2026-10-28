// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IOptimisticResolver {
    enum Outcome { INVALID, YES, NO }

    struct Proposal {
        Outcome outcome;
        address proposer;
        uint64 proposedAt;
        uint64 challengeDeadline;
        string evidenceURI;
        uint256 bond;
        bool disputed;
        address challenger;
        string disputeEvidenceURI;
        uint256 disputeBond;
        bool finalized;
    }

    event OutcomeProposed(
        uint256 indexed marketId,
        Outcome indexed outcome,
        address indexed proposer,
        uint64 challengeDeadline,
        string evidenceURI,
        uint256 bond
    );

    event ProposalDisputed(
        uint256 indexed marketId,
        address indexed challenger,
        string disputeEvidenceURI,
        uint256 disputeBond
    );

    event ProposalFinalized(uint256 indexed marketId, Outcome indexed finalOutcome);
    event DisputeResolved(uint256 indexed marketId, Outcome indexed finalOutcome, address winner);
    event MarketCancelled(uint256 indexed marketId, string reasonURI);

    function proposeOutcome(uint256 marketId, Outcome outcome, string calldata evidenceURI) external payable;
    function disputeProposal(uint256 marketId, string calldata disputeEvidenceURI) external payable;
    function finalizeProposal(uint256 marketId) external;
    function resolveDispute(uint256 marketId, Outcome finalOutcome) external;
    function cancelMarket(uint256 marketId, string calldata reasonURI) external;
    function getProposal(uint256 marketId) external view returns (Proposal memory);
}
