// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IPricingModel
/// @notice Interface for modular prediction-market pricing engines.
interface IPricingModel {
    /// @notice Returns the human-readable identifier of the pricing model.
    function name() external pure returns (string memory);

    /// @notice Calculates current probability of YES outcome in 18 decimals (WAD, 1e18 = 100%).
    function getProbability(uint256 b, uint256 qYes, uint256 qNo) external pure returns (uint256 pYes);

    /// @notice Calculates the total LMSR cost function for inventory (qYes, qNo).
    function getCost(uint256 b, uint256 qYes, uint256 qNo) external pure returns (uint256 cost);

    /// @notice Calculates the collateral required to buy `deltaShares` of an outcome.
    function getBuyQuote(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 deltaShares
    ) external pure returns (uint256 cost);

    /// @notice Calculates the collateral returned when selling `deltaShares` of an outcome.
    function getSellQuote(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 deltaShares
    ) external pure returns (uint256 proceeds);

    /// @notice Calculates expected shares received for a specified collateral cost.
    function calcSharesForCost(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 netCost
    ) external pure returns (uint256 shares);
}
