// Contract addresses and ABIs for LongTail Protocol

export const CONTRACT_ADDRESSES = {
  968: {
    // Bohr Testnet
    factory: '0xd72480faD3a5D732d753515dCf966aa93b9c4B8B' as `0x${string}`,
    marketImplementation: '0xaEbB38aDF3AADCd959D0667EaCa505578b206413' as `0x${string}`,
    outcomeToken: '0x4CD980838F7417a849C8d8dAF055Df50FD9648c6' as `0x${string}`,
    pricingModel: '0xfA58368866CA320da3deaA2F4fdDdf0228eDf273' as `0x${string}`,
    resolver: '0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9' as `0x${string}`,
  },
  677: {
    // BOT Chain Mainnet (Prepared placeholders - unauthorized to deploy)
    factory: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    marketImplementation: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    outcomeToken: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    pricingModel: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    resolver: '0x0000000000000000000000000000000000000000' as `0x${string}`,
  },
} as const;

export const FACTORY_ABI = [
  {
    type: 'function',
    name: 'createMarket',
    inputs: [
      {
        name: 'params',
        type: 'tuple',
        components: [
          { name: 'question', type: 'string' },
          { name: 'metadataURI', type: 'string' },
          { name: 'category', type: 'string' },
          { name: 'closingTimestamp', type: 'uint64' },
          { name: 'resolutionDeadline', type: 'uint64' },
          { name: 'resolver', type: 'address' },
          { name: 'pricingModel', type: 'address' },
          { name: 'b', type: 'uint256' },
          { name: 'feeBps', type: 'uint16' },
        ],
      },
    ],
    outputs: [
      { name: 'marketId', type: 'uint256' },
      { name: 'marketAddress', type: 'address' },
    ],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'getMarketCount',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMarketAddress',
    inputs: [{ name: 'marketId', type: 'uint256' }],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMarkets',
    inputs: [
      { name: 'offset', type: 'uint256' },
      { name: 'limit', type: 'uint256' },
    ],
    outputs: [
      {
        name: '',
        type: 'tuple[]',
        components: [
          { name: 'marketId', type: 'uint256' },
          { name: 'marketAddress', type: 'address' },
          { name: 'creator', type: 'address' },
          { name: 'question', type: 'string' },
          { name: 'category', type: 'string' },
          { name: 'closingTimestamp', type: 'uint64' },
          { name: 'resolutionDeadline', type: 'uint64' },
          { name: 'status', type: 'uint8' },
          { name: 'probabilityYes', type: 'uint256' },
          { name: 'liquidity', type: 'uint256' },
          { name: 'totalVolume', type: 'uint256' },
          { name: 'participantsCount', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'MarketCreated',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'marketAddress', type: 'address', indexed: true },
      { name: 'creator', type: 'address', indexed: true },
      { name: 'question', type: 'string', indexed: false },
      { name: 'category', type: 'string', indexed: false },
      { name: 'closingTimestamp', type: 'uint64', indexed: false },
      { name: 'resolutionDeadline', type: 'uint64', indexed: false },
      { name: 'resolver', type: 'address', indexed: false },
      { name: 'pricingModel', type: 'address', indexed: false },
      { name: 'initialLiquidity', type: 'uint256', indexed: false },
    ],
  },
] as const;

export const MARKET_ABI = [
  {
    type: 'function',
    name: 'buy',
    inputs: [
      { name: 'isYes', type: 'bool' },
      { name: 'minSharesOut', type: 'uint256' },
    ],
    outputs: [{ name: 'sharesBought', type: 'uint256' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'sell',
    inputs: [
      { name: 'isYes', type: 'bool' },
      { name: 'sharesIn', type: 'uint256' },
      { name: 'minBotOut', type: 'uint256' },
    ],
    outputs: [{ name: 'botProceeds', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'addLiquidity',
    inputs: [],
    outputs: [{ name: 'lpSharesMinted', type: 'uint256' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'removeLiquidity',
    inputs: [{ name: 'lpShares', type: 'uint256' }],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'redeem',
    inputs: [],
    outputs: [{ name: 'payout', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getProbability',
    inputs: [],
    outputs: [{ name: 'pYes', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getQuote',
    inputs: [
      { name: 'isYes', type: 'bool' },
      { name: 'shares', type: 'uint256' },
      { name: 'isBuy', type: 'bool' },
    ],
    outputs: [
      { name: 'costOrProceeds', type: 'uint256' },
      { name: 'fee', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getSharesForCost',
    inputs: [
      { name: 'isYes', type: 'bool' },
      { name: 'investmentAmount', type: 'uint256' },
    ],
    outputs: [
      { name: 'expectedShares', type: 'uint256' },
      { name: 'fee', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getLpPosition',
    inputs: [{ name: 'provider', type: 'address' }],
    outputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'withdrawableBot', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'marketId', type: 'uint256' },
          { name: 'creator', type: 'address' },
          { name: 'question', type: 'string' },
          { name: 'metadataURI', type: 'string' },
          { name: 'category', type: 'string' },
          { name: 'createdAt', type: 'uint64' },
          { name: 'closingTimestamp', type: 'uint64' },
          { name: 'resolutionDeadline', type: 'uint64' },
          { name: 'resolver', type: 'address' },
          { name: 'pricingModel', type: 'address' },
          { name: 'b', type: 'uint256' },
          { name: 'feeBps', type: 'uint16' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getState',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'status', type: 'uint8' },
          { name: 'collateralBalance', type: 'uint256' },
          { name: 'qYes', type: 'uint256' },
          { name: 'qNo', type: 'uint256' },
          { name: 'totalLpShares', type: 'uint256' },
          { name: 'reservedSettlement', type: 'uint256' },
          { name: 'totalVolume', type: 'uint256' },
          { name: 'participantsCount', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'PositionPurchased',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'buyer', type: 'address', indexed: true },
      { name: 'isYes', type: 'bool', indexed: false },
      { name: 'shares', type: 'uint256', indexed: false },
      { name: 'cost', type: 'uint256', indexed: false },
      { name: 'fee', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'PositionSold',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'seller', type: 'address', indexed: true },
      { name: 'isYes', type: 'bool', indexed: false },
      { name: 'shares', type: 'uint256', indexed: false },
      { name: 'proceeds', type: 'uint256', indexed: false },
      { name: 'fee', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'LiquidityAdded',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'provider', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'lpSharesMinted', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'LiquidityRemoved',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'provider', type: 'address', indexed: true },
      { name: 'lpSharesBurned', type: 'uint256', indexed: false },
      { name: 'amountReturned', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'PositionRedeemed',
    inputs: [
      { name: 'marketId', type: 'uint256', indexed: true },
      { name: 'redeemer', type: 'address', indexed: true },
      { name: 'shares', type: 'uint256', indexed: false },
      { name: 'payout', type: 'uint256', indexed: false },
    ],
  },
] as const;

export const OUTCOME_TOKEN_ABI = [
  {
    type: 'function',
    name: 'getPosition',
    inputs: [
      { name: 'marketId', type: 'uint256' },
      { name: 'account', type: 'address' },
    ],
    outputs: [
      { name: 'yesBalance', type: 'uint256' },
      { name: 'noBalance', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'id', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTokenId',
    inputs: [
      { name: 'marketId', type: 'uint256' },
      { name: 'isYes', type: 'bool' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'pure',
  },
] as const;

export const RESOLVER_ABI = [
  {
    type: 'function',
    name: 'proposeOutcome',
    inputs: [
      { name: 'marketId', type: 'uint256' },
      { name: 'outcome', type: 'uint8' },
      { name: 'evidenceURI', type: 'string' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'disputeProposal',
    inputs: [
      { name: 'marketId', type: 'uint256' },
      { name: 'disputeEvidenceURI', type: 'string' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'finalizeProposal',
    inputs: [{ name: 'marketId', type: 'uint256' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getProposal',
    inputs: [{ name: 'marketId', type: 'uint256' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'outcome', type: 'uint8' },
          { name: 'proposer', type: 'address' },
          { name: 'proposedAt', type: 'uint64' },
          { name: 'challengeDeadline', type: 'uint64' },
          { name: 'evidenceURI', type: 'string' },
          { name: 'bond', type: 'uint256' },
          { name: 'disputed', type: 'bool' },
          { name: 'challenger', type: 'address' },
          { name: 'disputeEvidenceURI', type: 'string' },
          { name: 'disputeBond', type: 'uint256' },
          { name: 'finalized', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
] as const;
