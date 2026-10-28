// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title LongTailOutcomeToken
/// @notice Multi-token (ERC-1155) representing transferable YES and NO outcome positions across all LongTail markets.
contract LongTailOutcomeToken is ERC1155, Ownable {
    address public factory;

    event FactoryUpdated(address indexed newFactory);
    event OutcomeMinted(uint256 indexed marketId, address indexed to, bool isYes, uint256 amount);
    event OutcomeBurned(uint256 indexed marketId, address indexed from, bool isYes, uint256 amount);

    modifier onlyMarket(uint256 marketId) {
        if (msg.sender != getMarketAddress(marketId)) {
            revert Errors.Unauthorized();
        }
        _;
    }

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    function setFactory(address factory_) external onlyOwner {
        if (factory_ == address(0)) revert Errors.Unauthorized();
        factory = factory_;
        emit FactoryUpdated(factory_);
    }

    function setURI(string memory newUri) external onlyOwner {
        _setURI(newUri);
    }

    /// @notice Deterministic token ID calculation: even for YES, odd for NO.
    function getTokenId(uint256 marketId, bool isYes) public pure returns (uint256) {
        return (marketId << 1) | (isYes ? 0 : 1);
    }

    /// @notice Resolves authorized market instance from factory.
    function getMarketAddress(uint256 marketId) public view returns (address) {
        if (factory == address(0)) return address(0);
        (bool success, bytes memory data) = factory.staticcall(
            abi.encodeWithSignature("getMarketAddress(uint256)", marketId)
        );
        if (!success || data.length < 32) return address(0);
        return abi.decode(data, (address));
    }

    /// @notice Returns YES and NO position balances for a trader.
    function getPosition(uint256 marketId, address account) external view returns (uint256 yesBalance, uint256 noBalance) {
        yesBalance = balanceOf(account, getTokenId(marketId, true));
        noBalance = balanceOf(account, getTokenId(marketId, false));
    }

    /// @notice Mints outcome tokens for a trader; strictly callable by authorized market instance.
    function mintOutcome(
        uint256 marketId,
        address to,
        bool isYes,
        uint256 amount
    ) external onlyMarket(marketId) {
        uint256 tokenId = getTokenId(marketId, isYes);
        _mint(to, tokenId, amount, "");
        emit OutcomeMinted(marketId, to, isYes, amount);
    }

    /// @notice Burns outcome tokens; strictly callable by authorized market instance.
    function burnOutcome(
        uint256 marketId,
        address from,
        bool isYes,
        uint256 amount
    ) external onlyMarket(marketId) {
        uint256 tokenId = getTokenId(marketId, isYes);
        _burn(from, tokenId, amount);
        emit OutcomeBurned(marketId, from, isYes, amount);
    }
}
