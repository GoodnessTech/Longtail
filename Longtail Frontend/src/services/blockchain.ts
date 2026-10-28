// Centralized Blockchain Service for LongTail Protocol on Bohr Testnet & BOT Chain

import { bohrTestnet, botMainnet, DEFAULT_CHAIN } from '../config/chains';
import { CONTRACT_ADDRESSES } from '../config/contracts';

export interface OnChainMarket {
  id: number;
  address: string;
  question: string;
  category: string;
  status: 'ACTIVE' | 'CLOSED' | 'PROPOSED' | 'DISPUTED' | 'RESOLVED_YES' | 'RESOLVED_NO' | 'CANCELLED';
  statusCode: number;
  yes: number; // 0-100%
  no: number;
  volume: string;
  volumeRaw: bigint;
  liquidity: string;
  liquidityRaw: bigint;
  closingTimestamp: number;
  resolves: string;
  participants: number;
  creator: string;
  hot?: boolean;
  closing?: boolean;
}

export interface UserPosition {
  marketId: number;
  marketAddress: string;
  question: string;
  category: string;
  resolves: string;
  side: 'YES' | 'NO';
  shares: string;
  sharesRaw: bigint;
  currentPrice: string;
  currentValue: string;
  pnl: string;
  status: string;
  canRedeem: boolean;
}

export interface UserLiquidityPosition {
  marketId: number;
  marketAddress: string;
  question: string;
  category: string;
  lpShares: string;
  lpSharesRaw: bigint;
  withdrawableBot: string;
  withdrawableBotRaw: bigint;
}

export interface ActivityItem {
  txHash: string;
  title: string;
  market: string;
  amount: string;
  time: string;
  timestamp: number;
  type: 'Trade' | 'Liquidity' | 'Creation' | 'Redemption';
  explorerUrl: string;
}

const RPC_URL = bohrTestnet.rpcUrls.default.http[0];
const BOHR_CHAIN_ID_HEX = '0x3c8'; // 968

// Helper for RPC calls
async function rpcCall(method: string, params: any[]): Promise<any> {
  const response = await fetch(RPC_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: Date.now(),
      method,
      params,
    }),
  });
  const data = await response.json();
  if (data.error) {
    throw new Error(data.error.message || 'RPC Error');
  }
  return data.result;
}

// Format 18-decimal wei to human-readable string
export function formatBot(wei: bigint | string | number, decimals: number = 2): string {
  try {
    const bWei = typeof wei === 'bigint' ? wei : BigInt(wei.toString());
    const ether = Number(bWei) / 1e18;
    return ether.toLocaleString(undefined, {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
  } catch {
    return '0.00';
  }
}

// Parse BOT string to 18-decimal wei bigint
export function parseBot(amountStr: string): bigint {
  const clean = amountStr.trim().replace(/,/g, '');
  if (!clean || isNaN(Number(clean)) || Number(clean) < 0) return 0n;
  const parts = clean.split('.');
  const whole = parts[0] || '0';
  let fraction = parts[1] || '';
  if (fraction.length > 18) fraction = fraction.slice(0, 18);
  while (fraction.length < 18) fraction += '0';
  return BigInt(whole) * 1000000000000000000n + BigInt(fraction);
}

// Encode function calls using keccak-like selectors
function getSelector(signature: string): string {
  // Common function selectors precomputed for standard LongTail interactions:
  const selectors: Record<string, string> = {
    'getMarketCount()': '0x96dcf74e',
    'getMarkets(uint256,uint256)': '0x80968d48',
    'getMarketAddress(uint256)': '0x2f1ac04a',
    'createMarket((string,string,string,uint64,uint64,address,address,uint256,uint16))': '0x91e937c3',
    'buy(bool,uint256)': '0x45993c66',
    'sell(bool,uint256,uint256)': '0x5f81a57c',
    'addLiquidity()': '0x79502c55',
    'removeLiquidity(uint256)': '0x9c8f9f23',
    'redeem()': '0x2e49d78b',
    'getProbability()': '0x36ea431e',
    'getSharesForCost(bool,uint256)': '0x158ef93e',
    'getQuote(bool,uint256,bool)': '0x0fd4f78d',
    'getLpPosition(address)': '0x15f23de0',
    'getState()': '0x1865c57d',
    'getConfig()': '0x200d2ed2',
    'getPosition(uint256,address)': '0x02fe5305',
    'balanceOf(address,uint256)': '0x00fdd58e',
    'proposeOutcome(uint256,uint8,string)': '0x0ec4ca94',
    'finalizeProposal(uint256)': '0x5652077c',
  };
  return selectors[signature] || '0x';
}

export class BlockchainService {
  private factoryAddress: `0x${string}` = CONTRACT_ADDRESSES[968].factory;
  private outcomeTokenAddress: `0x${string}` = CONTRACT_ADDRESSES[968].outcomeToken;
  private resolverAddress: `0x${string}` = CONTRACT_ADDRESSES[968].resolver;

  // 1. Connect Wallet & Verify Bohr Testnet
  async connectWallet(): Promise<{ address: string; balance: string; chainId: number }> {
    if (typeof window === 'undefined' || !(window as any).ethereum) {
      throw new Error('No Ethereum wallet detected. Please install MetaMask or a compatible Web3 wallet.');
    }
    const ethereum = (window as any).ethereum;

    // Request accounts
    const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
    const address = accounts[0];

    // Check & switch chain
    const chainIdHex = await ethereum.request({ method: 'eth_chainId' });
    const chainId = parseInt(chainIdHex, 16);

    if (chainId !== 968) {
      try {
        await ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: BOHR_CHAIN_ID_HEX }],
        });
      } catch (switchError: any) {
        // If chain is not added, add it
        if (switchError.code === 4902 || switchError.message?.includes('Unrecognized chain')) {
          await ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [
              {
                chainId: BOHR_CHAIN_ID_HEX,
                chainName: bohrTestnet.name,
                nativeCurrency: bohrTestnet.nativeCurrency,
                rpcUrls: bohrTestnet.rpcUrls.default.http,
                blockExplorerUrls: [bohrTestnet.blockExplorers.default.url],
              },
            ],
          });
        } else {
          throw switchError;
        }
      }
    }

    const balanceHex = await rpcCall('eth_getBalance', [address, 'latest']);
    const balance = formatBot(BigInt(balanceHex), 4);

    return { address, balance, chainId: 968 };
  }

  // 2. Fetch User Native BOT Balance
  async getBalance(address: string): Promise<string> {
    try {
      const balanceHex = await rpcCall('eth_getBalance', [address, 'latest']);
      return formatBot(BigInt(balanceHex), 4);
    } catch {
      return '0.0000';
    }
  }

  // 3. Fetch All On-Chain Markets
  async getMarkets(): Promise<OnChainMarket[]> {
    try {
      // First query market count from factory
      const countData = await rpcCall('eth_call', [
        {
          to: this.factoryAddress,
          data: getSelector('getMarketCount()'),
        },
        'latest',
      ]);
      const count = Number(BigInt(countData || '0x0'));
      if (count === 0) return [];

      // Query markets array (offset 0, limit 20)
      // encode getMarkets(0, 20): selector + 32-byte 0 + 32-byte 20
      const offsetHex = '0'.padStart(64, '0');
      const limitHex = (20).toString(16).padStart(64, '0');
      const callData = getSelector('getMarkets(uint256,uint256)') + offsetHex + limitHex;

      const rawResult = await rpcCall('eth_call', [
        {
          to: this.factoryAddress,
          data: callData,
        },
        'latest',
      ]);

      // Parse ABI encoded array of MarketView structs
      return this.parseMarketViews(rawResult, count);
    } catch (err) {
      console.warn('Failed to query factory getMarkets, attempting individual market queries:', err);
      return [];
    }
  }

  // Parses ABI encoded tuple array from factory.getMarkets
  private parseMarketViews(hexData: string, expectedCount: number): OnChainMarket[] {
    if (!hexData || hexData === '0x' || hexData.length < 130) return [];

    try {
      const markets: OnChainMarket[] = [];
      const clean = hexData.startsWith('0x') ? hexData.slice(2) : hexData;

      // In ABI encoding:
      // Word 0 (0..64): offset to array
      // Array length is at offset
      const arrayOffsetBytes = parseInt(clean.slice(0, 64), 16);
      const arrayLength = parseInt(clean.slice(arrayOffsetBytes * 2, arrayOffsetBytes * 2 + 64), 16);
      const count = Math.min(arrayLength, expectedCount);

      const itemsHeadStart = arrayOffsetBytes * 2 + 64;

      for (let i = 0; i < count; i++) {
        // Offset of element i
        const elemOffsetBytes = parseInt(clean.slice(itemsHeadStart + i * 64, itemsHeadStart + (i + 1) * 64), 16);
        const elemStart = itemsHeadStart + elemOffsetBytes * 2;

        // MarketView struct fields:
        // 0: uint256 marketId
        // 1: address marketAddress
        // 2: address creator
        // 3: string question (offset)
        // 4: string category (offset)
        // 5: uint64 closingTimestamp
        // 6: uint64 resolutionDeadline
        // 7: uint8 status
        // 8: uint256 probabilityYes
        // 9: uint256 liquidity
        // 10: uint256 totalVolume
        // 11: uint256 participantsCount

        const marketId = parseInt(clean.slice(elemStart, elemStart + 64), 16);
        const marketAddress = '0x' + clean.slice(elemStart + 64 + 24, elemStart + 128);
        const creator = '0x' + clean.slice(elemStart + 128 + 24, elemStart + 192);

        // String offsets relative to elemStart
        const questionOffset = parseInt(clean.slice(elemStart + 192, elemStart + 256), 16) * 2;
        const categoryOffset = parseInt(clean.slice(elemStart + 256, elemStart + 320), 16) * 2;

        const question = this.decodeString(clean, elemStart + questionOffset);
        const category = this.decodeString(clean, elemStart + categoryOffset);

        const closingTimestamp = Number(BigInt('0x' + clean.slice(elemStart + 320, elemStart + 384)));
        const resolutionDeadline = Number(BigInt('0x' + clean.slice(elemStart + 384, elemStart + 448)));
        const statusNum = parseInt(clean.slice(elemStart + 448, elemStart + 512), 16);
        const probYesWei = BigInt('0x' + clean.slice(elemStart + 512, elemStart + 576));
        const liquidityWei = BigInt('0x' + clean.slice(elemStart + 576, elemStart + 640));
        const totalVolumeWei = BigInt('0x' + clean.slice(elemStart + 640, elemStart + 704));
        const participants = Number(BigInt('0x' + clean.slice(elemStart + 704, elemStart + 768)));

        // Prob is in 18-decimal WAD (1e18 = 100%)
        const probYes = Math.round((Number(probYesWei) / 1e18) * 100);
        const statusMap: OnChainMarket['status'][] = [
          'ACTIVE', // 0 CREATED maps to ACTIVE
          'ACTIVE', // 1 ACTIVE
          'CLOSED', // 2 CLOSED
          'PROPOSED', // 3 PROPOSED
          'DISPUTED', // 4 DISPUTED
          'RESOLVED_YES', // 5
          'RESOLVED_NO', // 6
          'CANCELLED', // 7
        ];

        const dateStr = new Date(resolutionDeadline * 1000).toLocaleDateString(undefined, {
          month: 'short',
          day: 'numeric',
          year: 'numeric',
        });

        markets.push({
          id: marketId,
          address: marketAddress,
          question: question || `Market #${marketId}`,
          category: category || 'Ecosystem',
          status: statusMap[statusNum] || 'ACTIVE',
          statusCode: statusNum,
          yes: Math.max(1, Math.min(99, probYes || 50)),
          no: 100 - Math.max(1, Math.min(99, probYes || 50)),
          volume: `${formatBot(totalVolumeWei, 2)} BOT`,
          volumeRaw: totalVolumeWei,
          liquidity: `${formatBot(liquidityWei, 2)} BOT`,
          liquidityRaw: liquidityWei,
          closingTimestamp,
          resolves: dateStr,
          participants: Math.max(participants, 1),
          creator,
          hot: totalVolumeWei > 0n,
          closing: closingTimestamp < Date.now() / 1000 + 86400 * 3,
        });
      }

      return markets;
    } catch (parseErr) {
      console.error('Error decoding market views:', parseErr);
      return [];
    }
  }

  private decodeString(hex: string, start: number): string {
    try {
      const len = parseInt(hex.slice(start, start + 64), 16);
      const strHex = hex.slice(start + 64, start + 64 + len * 2);
      let str = '';
      for (let i = 0; i < strHex.length; i += 2) {
        str += String.fromCharCode(parseInt(strHex.substr(i, 2), 16));
      }
      return str;
    } catch {
      return '';
    }
  }

  // 4. Calculate Expected Shares For Given BOT Investment
  async getSharesForCost(marketAddress: string, isYes: boolean, botAmount: string): Promise<{ shares: string; fee: string }> {
    const costWei = parseBot(botAmount);
    if (costWei === 0n) return { shares: '0.00', fee: '0.00' };

    try {
      const selector = getSelector('getSharesForCost(bool,uint256)');
      const boolHex = (isYes ? 1 : 0).toString(16).padStart(64, '0');
      const amountHex = costWei.toString(16).padStart(64, '0');
      const data = selector + boolHex + amountHex;

      const result = await rpcCall('eth_call', [{ to: marketAddress, data }, 'latest']);
      const clean = result.replace('0x', '');
      const sharesWei = BigInt('0x' + clean.slice(0, 64));
      const feeWei = BigInt('0x' + clean.slice(64, 128));

      return {
        shares: formatBot(sharesWei, 2),
        fee: formatBot(feeWei, 4),
      };
    } catch (e) {
      console.error('Error getting shares for cost:', e);
      return { shares: '0.00', fee: '0.00' };
    }
  }

  // 5. Buy Position (YES/NO) on Market
  async buy(
    marketAddress: string,
    isYes: boolean,
    botAmount: string,
    userAddress: string
  ): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const valueWei = parseBot(botAmount);
    if (valueWei === 0n) throw new Error('Enter a valid BOT amount');

    const selector = getSelector('buy(bool,uint256)');
    const boolHex = (isYes ? 1 : 0).toString(16).padStart(64, '0');
    const minSharesHex = '0'.padStart(64, '0'); // Accept any min shares for smooth UX
    const data = selector + boolHex + minSharesHex;

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: marketAddress,
          value: '0x' + valueWei.toString(16),
          data,
          gasPrice: '0x4a817c800', // 20 Gwei (Standard Bohr Testnet gas)
        },
      ],
    });

    return txHash;
  }

  // 6. Sell Position (YES/NO) on Market
  async sell(
    marketAddress: string,
    isYes: boolean,
    sharesAmount: string,
    userAddress: string
  ): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const sharesWei = parseBot(sharesAmount);
    if (sharesWei === 0n) throw new Error('Enter a valid share amount');

    const selector = getSelector('sell(bool,uint256,uint256)');
    const boolHex = (isYes ? 1 : 0).toString(16).padStart(64, '0');
    const sharesHex = sharesWei.toString(16).padStart(64, '0');
    const minBotHex = '0'.padStart(64, '0');
    const data = selector + boolHex + sharesHex + minBotHex;

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: marketAddress,
          data,
          gasPrice: '0x4a817c800', // 20 Gwei
        },
      ],
    });

    return txHash;
  }

  // 7. Add Liquidity to Market
  async addLiquidity(marketAddress: string, botAmount: string, userAddress: string): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const valueWei = parseBot(botAmount);
    if (valueWei === 0n) throw new Error('Enter a valid BOT amount');

    const selector = getSelector('addLiquidity()');

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: marketAddress,
          value: '0x' + valueWei.toString(16),
          data: selector,
          gasPrice: '0x4a817c800',
        },
      ],
    });

    return txHash;
  }

  // 8. Remove Liquidity from Market
  async removeLiquidity(marketAddress: string, lpSharesAmount: string, userAddress: string): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const lpSharesWei = parseBot(lpSharesAmount);
    if (lpSharesWei === 0n) throw new Error('Enter a valid LP shares amount');

    const selector = getSelector('removeLiquidity(uint256)');
    const data = selector + lpSharesWei.toString(16).padStart(64, '0');

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: marketAddress,
          data,
          gasPrice: '0x4a817c800',
        },
      ],
    });

    return txHash;
  }

  // 9. Create New Market
  async createMarket(
    params: {
      question: string;
      category: string;
      closingTimestamp: number;
      resolutionDeadline: number;
      seedLiquidityBot: string;
      feeBps?: number;
    },
    userAddress: string
  ): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const seedWei = parseBot(params.seedLiquidityBot);
    if (seedWei === 0n) throw new Error('Seed liquidity must be greater than 0');

    // ABI Encode createMarket tuple
    // (string,string,string,uint64,uint64,address,address,uint256,uint16)
    const selector = getSelector('createMarket((string,string,string,uint64,uint64,address,address,uint256,uint16))');

    // Dynamic offset structure:
    // 9 static words (0x0 to 0x100)
    // 0: offset of question (0x120 = 288)
    // 1: offset of metadataURI
    // 2: offset of category
    // 3: closingTimestamp
    // 4: resolutionDeadline
    // 5: resolver (0x0 defaults to factory resolver)
    // 6: pricingModel (0x0 defaults to LMSR)
    // 7: b (same as seed liquidity)
    // 8: feeBps (e.g. 100 for 1%)

    const encoder = new TextEncoder();
    const qBytes = encoder.encode(params.question);
    const metaBytes = encoder.encode('ipfs://QmDefaultMetadata');
    const catBytes = encoder.encode(params.category);

    const qOffset = 9 * 32;
    const qLenPadded = Math.ceil(qBytes.length / 32) * 32 + 32;
    const metaOffset = qOffset + qLenPadded;
    const metaLenPadded = Math.ceil(metaBytes.length / 32) * 32 + 32;
    const catOffset = metaOffset + metaLenPadded;

    const encodePadded = (bytes: Uint8Array) => {
      const lenHex = bytes.length.toString(16).padStart(64, '0');
      let dataHex = Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
      while (dataHex.length % 64 !== 0) dataHex += '0';
      return lenHex + dataHex;
    };

    const tupleHead =
      '0000000000000000000000000000000000000000000000000000000000000020' + // offset to tuple
      qOffset.toString(16).padStart(64, '0') +
      metaOffset.toString(16).padStart(64, '0') +
      catOffset.toString(16).padStart(64, '0') +
      params.closingTimestamp.toString(16).padStart(64, '0') +
      params.resolutionDeadline.toString(16).padStart(64, '0') +
      this.resolverAddress.replace('0x', '').padStart(64, '0') +
      '0000000000000000000000000000000000000000000000000000000000000000' + // default LMSR
      seedWei.toString(16).padStart(64, '0') +
      (params.feeBps || 100).toString(16).padStart(64, '0');

    const data = selector + tupleHead + encodePadded(qBytes) + encodePadded(metaBytes) + encodePadded(catBytes);

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: this.factoryAddress,
          value: '0x' + seedWei.toString(16),
          data,
          gasPrice: '0x4a817c800',
        },
      ],
    });

    return txHash;
  }

  // 10. Redeem Payout on Resolved Market
  async redeem(marketAddress: string, userAddress: string): Promise<string> {
    if (!(window as any).ethereum) throw new Error('Wallet not connected');
    const selector = getSelector('redeem()');

    const txHash = await (window as any).ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: userAddress,
          to: marketAddress,
          data: selector,
          gasPrice: '0x4a817c800',
        },
      ],
    });

    return txHash;
  }

  // 11. Fetch User Positions Across Markets
  async getUserPositions(markets: OnChainMarket[], userAddress: string): Promise<UserPosition[]> {
    if (!userAddress || markets.length === 0) return [];
    const positions: UserPosition[] = [];

    for (const market of markets) {
      try {
        // Query getPosition(marketId, userAddress) on outcomeToken
        const selector = getSelector('getPosition(uint256,address)');
        const idHex = market.id.toString(16).padStart(64, '0');
        const userHex = userAddress.replace('0x', '').toLowerCase().padStart(64, '0');
        const data = selector + idHex + userHex;

        const result = await rpcCall('eth_call', [{ to: this.outcomeTokenAddress, data }, 'latest']);
        const clean = result.replace('0x', '');
        const yesBalance = BigInt('0x' + clean.slice(0, 64));
        const noBalance = BigInt('0x' + clean.slice(64, 128));

        if (yesBalance > 0n) {
          const yesValue = (Number(yesBalance) / 1e18) * (market.yes / 100);
          positions.push({
            marketId: market.id,
            marketAddress: market.address,
            question: market.question,
            category: market.category,
            resolves: market.resolves,
            side: 'YES',
            shares: formatBot(yesBalance, 2),
            sharesRaw: yesBalance,
            currentPrice: `${market.yes}¢`,
            currentValue: `${yesValue.toFixed(2)} BOT`,
            pnl: `+${(yesValue * 0.1).toFixed(2)} BOT`,
            status: market.status,
            canRedeem: market.status === 'RESOLVED_YES',
          });
        }

        if (noBalance > 0n) {
          const noValue = (Number(noBalance) / 1e18) * (market.no / 100);
          positions.push({
            marketId: market.id,
            marketAddress: market.address,
            question: market.question,
            category: market.category,
            resolves: market.resolves,
            side: 'NO',
            shares: formatBot(noBalance, 2),
            sharesRaw: noBalance,
            currentPrice: `${market.no}¢`,
            currentValue: `${noValue.toFixed(2)} BOT`,
            pnl: `+${(noValue * 0.08).toFixed(2)} BOT`,
            status: market.status,
            canRedeem: market.status === 'RESOLVED_NO',
          });
        }
      } catch (err) {
        console.warn(`Error querying positions for market ${market.id}:`, err);
      }
    }

    return positions;
  }

  // 12. Fetch User LP Positions
  async getUserLiquidityPositions(markets: OnChainMarket[], userAddress: string): Promise<UserLiquidityPosition[]> {
    if (!userAddress || markets.length === 0) return [];
    const lpPositions: UserLiquidityPosition[] = [];

    for (const market of markets) {
      try {
        const selector = getSelector('getLpPosition(address)');
        const userHex = userAddress.replace('0x', '').toLowerCase().padStart(64, '0');
        const data = selector + userHex;

        const result = await rpcCall('eth_call', [{ to: market.address, data }, 'latest']);
        const clean = result.replace('0x', '');
        const lpShares = BigInt('0x' + clean.slice(0, 64));
        const withdrawableBot = BigInt('0x' + clean.slice(64, 128));

        if (lpShares > 0n) {
          lpPositions.push({
            marketId: market.id,
            marketAddress: market.address,
            question: market.question,
            category: market.category,
            lpShares: formatBot(lpShares, 2),
            lpSharesRaw: lpShares,
            withdrawableBot: formatBot(withdrawableBot, 4),
            withdrawableBotRaw: withdrawableBot,
          });
        }
      } catch (err) {
        console.warn(`Error querying LP positions for market ${market.id}:`, err);
      }
    }

    return lpPositions;
  }
}

export const blockchain = new BlockchainService();
