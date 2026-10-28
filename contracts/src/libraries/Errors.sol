// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LongTail Protocol Errors
/// @notice Custom gas-efficient errors for LongTail prediction-market infrastructure.
library Errors {
    // Factory errors
    error InvalidQuestion();
    error InvalidTimestamps();
    error InvalidResolver();
    error InvalidPricingModel();
    error InvalidInitialLiquidity();
    error MarketNotFound();
    error MarketAlreadyExists();
    error Unauthorized();
    error FeeTooHigh();

    // Market lifecycle errors
    error MarketNotActive();
    error MarketNotClosed();
    error MarketAlreadyClosed();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error MarketDisputedState();
    error InvalidStateTransition();
    error TradingPeriodEnded();
    error TradingPeriodActive();
    error ResolutionDeadlinePassed();
    error AlreadyInitialized();

    // Trading errors
    error InsufficientPayment();
    error SlippageExceeded();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error TradeExceedsLimit();

    // Liquidity errors
    error LiquidityLocked();
    error InsufficientLpShares();
    error CannotWithdrawReservedCollateral();

    // Resolution & Settlement errors
    error ProposalPeriodActive();
    error ChallengePeriodNotElapsed();
    error ChallengePeriodElapsed();
    error InsufficientBond();
    error InvalidOutcome();
    error NotWinningPosition();
    error AlreadyRedeemed();
    error NothingToRedeem();
    error TransferFailed();
}
