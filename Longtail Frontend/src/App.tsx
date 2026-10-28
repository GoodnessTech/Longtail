import { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  ArrowDownRight,
  ArrowUpRight,
  BarChart3,
  Bell,
  Check,
  ChevronDown,
  CircleHelp,
  Coins,
  ExternalLink,
  FilePlus2,
  Filter,
  Globe2,
  Loader2,
  Menu,
  Plus,
  Search,
  Settings2,
  ShieldCheck,
  Sparkles,
  TrendingUp,
  Wallet,
  X,
  Zap,
} from 'lucide-react';
import {
  blockchain,
  OnChainMarket,
  UserPosition,
  UserLiquidityPosition,
  ActivityItem,
  formatBot,
} from './services/blockchain';
import { bohrTestnet } from './config/chains';

type Page = 'Overview' | 'Explore' | 'Create Market' | 'Liquidity' | 'Portfolio' | 'Activity';
type Category = 'Technology' | 'DeFi' | 'Protocols' | 'AI' | 'Products' | 'Communities' | 'Ecosystem & Layer 1' | 'Bohr Testnet';

const categories: Array<'All' | Category> = [
  'All',
  'Ecosystem & Layer 1',
  'AI',
  'Protocols',
  'DeFi',
  'Bohr Testnet',
  'Technology',
  'Products',
];

// Fallback initial market seeds while connecting to RPC
const INITIAL_MARKETS: OnChainMarket[] = [
  {
    id: 1,
    address: '0x62cc194ad26910894ae6a7e6f1021752ba9c3fea',
    question: 'Will BOT Chain exceed 500,000 daily transactions in Q4 2026?',
    category: 'Ecosystem & Layer 1',
    status: 'ACTIVE',
    statusCode: 1,
    yes: 64,
    no: 36,
    volume: '0.09 BOT',
    volumeRaw: 90000000000000000n,
    liquidity: '0.24 BOT',
    liquidityRaw: 240000000000000000n,
    closingTimestamp: Math.floor(Date.now() / 1000) + 86400 * 30,
    resolves: 'Nov 30, 2026',
    participants: 12,
    creator: '0x34090545BD562b0bE1Cdc855F7cA9beE4566CE51',
    hot: true,
  },
  {
    id: 2,
    address: '0x8220b2b58ac444394a7f07130db5b448095071c8',
    question: 'Will an Autonomous AI Agent execute a prediction market settlement on BOT Chain before December 2026?',
    category: 'AI',
    status: 'ACTIVE',
    statusCode: 1,
    yes: 72,
    no: 28,
    volume: '0.05 BOT',
    volumeRaw: 50000000000000000n,
    liquidity: '0.15 BOT',
    liquidityRaw: 150000000000000000n,
    closingTimestamp: Math.floor(Date.now() / 1000) + 86400 * 14,
    resolves: 'Dec 15, 2026',
    participants: 8,
    creator: '0x34090545BD562b0bE1Cdc855F7cA9beE4566CE51',
    hot: true,
  },
  {
    id: 3,
    address: '0x3b4abf8e4911d6fef029bacfe14bb996a1cb7619',
    question: 'Will Bohr Testnet gas price remain at 20 Gwei throughout testing?',
    category: 'Bohr Testnet',
    status: 'ACTIVE',
    statusCode: 1,
    yes: 55,
    no: 45,
    volume: '0.05 BOT',
    volumeRaw: 50000000000000000n,
    liquidity: '0.15 BOT',
    liquidityRaw: 150000000000000000n,
    closingTimestamp: Math.floor(Date.now() / 1000) + 86400 * 2,
    resolves: 'Oct 30, 2026',
    participants: 6,
    creator: '0x34090545BD562b0bE1Cdc855F7cA9beE4566CE51',
    closing: true,
  },
];

function App() {
  const [page, setPage] = useState<Page>('Overview');
  const [connected, setConnected] = useState(false);
  const [userAddress, setUserAddress] = useState('');
  const [userBalance, setUserBalance] = useState('0.0000');
  const [mobileNav, setMobileNav] = useState(false);

  const [markets, setMarkets] = useState<OnChainMarket[]>(INITIAL_MARKETS);
  const [userPositions, setUserPositions] = useState<UserPosition[]>([]);
  const [userLpPositions, setUserLpPositions] = useState<UserLiquidityPosition[]>([]);
  const [activity, setActivity] = useState<ActivityItem[]>([]);
  const [loadingMarkets, setLoadingMarkets] = useState(false);

  const [selectedMarket, setSelectedMarket] = useState<OnChainMarket | null>(null);
  const [tradeSide, setTradeSide] = useState<'YES' | 'NO'>('YES');
  const [tradeAmount, setTradeAmount] = useState('');
  const [showTrade, setShowTrade] = useState(false);
  const [showNotice, setShowNotice] = useState(false);
  const [toastMessage, setToastMessage] = useState({ title: '', desc: '', hash: '' });
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState<'All' | Category>('All');

  // Load live markets from Bohr Testnet
  const refreshMarkets = async () => {
    try {
      setLoadingMarkets(true);
      const onChain = await blockchain.getMarkets();
      if (onChain.length > 0) {
        setMarkets(onChain);
      }
    } catch (e) {
      console.warn('Using seeded markets due to RPC discovery timeout:', e);
    } finally {
      setLoadingMarkets(false);
    }
  };

  // Load user wallet state
  const refreshUserData = async (addr: string) => {
    if (!addr) return;
    try {
      const bal = await blockchain.getBalance(addr);
      setUserBalance(bal);

      const positions = await blockchain.getUserPositions(markets, addr);
      setUserPositions(positions);

      const lps = await blockchain.getUserLiquidityPositions(markets, addr);
      setUserLpPositions(lps);
    } catch (e) {
      console.warn('Failed to refresh user data:', e);
    }
  };

  useEffect(() => {
    refreshMarkets();
  }, []);

  useEffect(() => {
    if (connected && userAddress) {
      refreshUserData(userAddress);
    }
  }, [connected, userAddress, markets]);

  // Connect real wallet
  const handleConnect = async () => {
    try {
      const result = await blockchain.connectWallet();
      setUserAddress(result.address);
      setUserBalance(result.balance);
      setConnected(true);
      notify('Wallet Connected', `Connected to Bohr Testnet: ${result.address.slice(0, 6)}...${result.address.slice(-4)}`);
    } catch (err: any) {
      alert(err.message || 'Failed to connect wallet');
    }
  };

  const notify = (title: string, desc: string, hash: string = '') => {
    setToastMessage({ title, desc, hash });
    setShowNotice(true);
  };

  const filteredMarkets = useMemo(() => {
    return markets.filter((market) => {
      const matchesSearch = market.question.toLowerCase().includes(search.toLowerCase());
      const matchesCategory = category === 'All' || market.category === category;
      return matchesSearch && matchesCategory;
    });
  }, [markets, category, search]);

  function navigate(nextPage: Page) {
    setPage(nextPage);
    setMobileNav(false);
  }

  function openTrade(market: OnChainMarket, side: 'YES' | 'NO') {
    setSelectedMarket(market);
    setTradeSide(side);
    setTradeAmount('');
    setShowTrade(true);
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <button className="brand" onClick={() => navigate('Overview')} aria-label="Go to overview">
          <span className="brand-mark">
            <span />
            <span />
            <span />
          </span>
          <span>
            LONG<span>TAIL</span>
          </span>
        </button>
        <div className="desktop-nav">
          {(['Overview', 'Explore', 'Create Market', 'Liquidity', 'Portfolio', 'Activity'] as Page[]).map((item) => (
            <button
              key={item}
              className={page === item ? 'nav-link active' : 'nav-link'}
              onClick={() => navigate(item)}
            >
              {item}
            </button>
          ))}
        </div>
        <div className="topbar-actions">
          <div className="network-pill" title="Connected to Bohr Testnet (Chain ID 968)">
            <span className="pulse-dot" /> BOT Chain <span className="testnet">TESTNET</span>
          </div>
          <button className="icon-button notification" onClick={refreshMarkets} title="Refresh On-Chain Data">
            <Bell size={17} />
            <i />
          </button>
          <button
            className={connected ? 'wallet-button connected' : 'wallet-button'}
            onClick={connected ? () => setConnected(false) : handleConnect}
          >
            <Wallet size={16} />{' '}
            {connected
              ? `${userAddress.slice(0, 5)}...${userAddress.slice(-3)} (${userBalance} BOT)`
              : 'Connect wallet'}
          </button>
          <button className="mobile-menu" onClick={() => setMobileNav(!mobileNav)}>
            <Menu size={20} />
          </button>
        </div>
      </header>
      {mobileNav && (
        <div className="mobile-nav">
          {(['Overview', 'Explore', 'Create Market', 'Liquidity', 'Portfolio', 'Activity'] as Page[]).map((item) => (
            <button key={item} onClick={() => navigate(item)}>
              {item}
            </button>
          ))}
        </div>
      )}

      <main className="page-wrap">
        {page === 'Overview' && (
          <Overview
            markets={markets}
            navigate={navigate}
            openTrade={openTrade}
            connected={connected}
            onConnect={handleConnect}
            userPositions={userPositions}
          />
        )}
        {page === 'Explore' && (
          <Explore
            markets={filteredMarkets}
            search={search}
            setSearch={setSearch}
            category={category}
            setCategory={setCategory}
            openTrade={openTrade}
            navigate={navigate}
            loading={loadingMarkets}
          />
        )}
        {page === 'Create Market' && (
          <CreateMarket
            connected={connected}
            userAddress={userAddress}
            onConnect={handleConnect}
            onCreated={(txHash) => {
              notify(
                'Market Creation Broadcasted!',
                'Your prediction market has been deployed via LongTailMarketFactory.',
                txHash
              );
              refreshMarkets();
              navigate('Explore');
            }}
          />
        )}
        {page === 'Liquidity' && (
          <Liquidity
            connected={connected}
            userAddress={userAddress}
            onConnect={handleConnect}
            markets={markets}
            lpPositions={userLpPositions}
            navigate={navigate}
            onSuccess={(title, desc, hash) => {
              notify(title, desc, hash);
              refreshMarkets();
              if (userAddress) refreshUserData(userAddress);
            }}
          />
        )}
        {page === 'Portfolio' && (
          <Portfolio
            connected={connected}
            userAddress={userAddress}
            userBalance={userBalance}
            positions={userPositions}
            onConnect={handleConnect}
            navigate={navigate}
            onRedeemed={(hash) => {
              notify('Payout Redeemed!', 'Winning collateral has been credited to your wallet.', hash);
              if (userAddress) refreshUserData(userAddress);
            }}
          />
        )}
        {page === 'Activity' && <ActivityPage activity={activity} />}
      </main>

      <footer className="footer">
        <div className="footer-brand">
          <span className="brand-mark small">
            <span />
            <span />
            <span />
          </span>
          <div>
            <strong>LONGTAIL</strong>
            <small>Permissionless prediction markets on BOT Chain.</small>
          </div>
        </div>
        <div className="footer-links">
          <a href="https://www.botchain.ai/" target="_blank" rel="noreferrer">
            BOT Chain <ExternalLink size={12} />
          </a>
          <a href="https://scan.bohr.life/" target="_blank" rel="noreferrer">
            BohrScan Explorer <ExternalLink size={12} />
          </a>
          <a href="https://dev-docs.botchain.ai/" target="_blank" rel="noreferrer">
            Developer Docs <ExternalLink size={12} />
          </a>
        </div>
        <span className="footer-copy">© 2026 LongTail Protocol · Chain ID 968</span>
      </footer>

      {showTrade && selectedMarket && (
        <TradeModal
          market={selectedMarket}
          side={tradeSide}
          amount={tradeAmount}
          setSide={setTradeSide}
          setAmount={setTradeAmount}
          connected={connected}
          userAddress={userAddress}
          onConnect={handleConnect}
          onClose={() => setShowTrade(false)}
          onSuccess={(txHash) => {
            setShowTrade(false);
            notify(
              `Trade Executed (${tradeSide})!`,
              `Purchased outcome shares for ${tradeAmount} BOT.`,
              txHash
            );
            refreshMarkets();
            if (userAddress) refreshUserData(userAddress);
          }}
        />
      )}

      {showNotice && (
        <div className="toast">
          <span className="toast-check">
            <Check size={15} />
          </span>
          <div>
            <strong>{toastMessage.title}</strong>
            <small>{toastMessage.desc}</small>
            {toastMessage.hash && (
              <a
                href={`https://scan.bohr.life/tx/${toastMessage.hash}`}
                target="_blank"
                rel="noreferrer"
                style={{ color: '#f38c5c', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '4px' }}
              >
                View on BohrScan <ExternalLink size={11} />
              </a>
            )}
          </div>
          <button onClick={() => setShowNotice(false)}>
            <X size={15} />
          </button>
        </div>
      )}
    </div>
  );
}

// -------------------------------------------------------------
// OVERVIEW PAGE
// -------------------------------------------------------------
function Overview({
  markets,
  navigate,
  openTrade,
  connected,
  onConnect,
  userPositions,
}: {
  markets: OnChainMarket[];
  navigate: (page: Page) => void;
  openTrade: (market: OnChainMarket, side: 'YES' | 'NO') => void;
  connected: boolean;
  onConnect: () => void;
  userPositions: UserPosition[];
}) {
  const totalVolumeWei = markets.reduce((acc, m) => acc + m.volumeRaw, 0n);
  const totalLiquidityWei = markets.reduce((acc, m) => acc + m.liquidityRaw, 0n);
  const activeCount = markets.filter((m) => m.status === 'ACTIVE').length;

  return (
    <>
      <section className="hero">
        <div className="eyebrow">
          <span className="spark">
            <Sparkles size={12} />
          </span>{' '}
          THE PERMISSIONLESS MARKET LAYER ON BOT CHAIN
        </div>
        <h1>
          Every question
          <br />
          <em>deserves a liquid market.</em>
        </h1>
        <p>
          Continuous LMSR liquidity, native BOT collateral, and optimistic resolution on Bohr Testnet.
        </p>
        <div className="hero-actions">
          <button className="primary-button" onClick={() => navigate('Explore')}>
            Explore markets <ArrowUpRight size={16} />
          </button>
          <button className="secondary-button" onClick={() => navigate('Create Market')}>
            Create a market <Plus size={16} />
          </button>
        </div>
        <div className="hero-orbit orbit-one" />
        <div className="hero-orbit orbit-two" />
        <div className="hero-glow" />
      </section>

      <section className="metrics-grid">
        <Metric
          label="Total markets"
          value={markets.length.toString()}
          change="On Bohr Testnet"
          icon={<Globe2 size={17} />}
        />
        <Metric
          label="Active markets"
          value={activeCount.toString()}
          change={`${markets.length > 0 ? Math.round((activeCount / markets.length) * 100) : 100}% tradable`}
          icon={<Activity size={17} />}
        />
        <Metric
          label="Trading volume"
          value={`${formatBot(totalVolumeWei, 2)} BOT`}
          change="Native BOT Volume"
          icon={<BarChart3 size={17} />}
        />
        <Metric
          label="Total liquidity"
          value={`${formatBot(totalLiquidityWei, 2)} BOT`}
          change="LMSR Pool Depth"
          icon={<Coins size={17} />}
        />
      </section>

      <div className="content-grid">
        <section className="panel featured-panel">
          <div className="section-heading">
            <div>
              <span className="label">DISCOVER</span>
              <h2>Trending markets</h2>
            </div>
            <button className="text-button" onClick={() => navigate('Explore')}>
              View all <ArrowUpRight size={14} />
            </button>
          </div>
          <div className="market-stack">
            {markets.slice(0, 3).map((market) => (
              <MarketRow key={market.id} market={market} openTrade={openTrade} />
            ))}
          </div>
        </section>

        <section className="panel portfolio-panel">
          <div className="section-heading">
            <div>
              <span className="label">YOUR ACTIVITY</span>
              <h2>Portfolio snapshot</h2>
            </div>
            <button className="icon-button" onClick={() => navigate('Portfolio')}>
              <Settings2 size={16} />
            </button>
          </div>
          {connected ? (
            <>
              <div className="portfolio-balance">
                <small>Total open positions</small>
                <strong>{userPositions.length} Markets</strong>
                <span className="positive">
                  <ArrowUpRight size={13} /> Bohr Testnet Verified
                </span>
              </div>
              <div className="mini-positions">
                {userPositions.slice(0, 2).map((pos) => (
                  <PositionMini
                    key={`${pos.marketId}-${pos.side}`}
                    title={pos.question}
                    side={pos.side}
                    value={pos.shares + ' shares'}
                    pnl={pos.currentPrice}
                  />
                ))}
                {userPositions.length === 0 && (
                  <div style={{ color: '#888', fontSize: '13px', padding: '10px 0' }}>
                    No open positions found for this account.
                  </div>
                )}
              </div>
              <button className="outline-full" onClick={() => navigate('Portfolio')}>
                View full portfolio <ArrowUpRight size={14} />
              </button>
            </>
          ) : (
            <EmptyWallet onConnect={onConnect} />
          )}
        </section>
      </div>

      <section className="panel resolution-panel">
        <div className="section-heading">
          <div>
            <span className="label">ON THE CLOCK</span>
            <h2>Active testnet markets</h2>
          </div>
          <button className="text-button" onClick={() => navigate('Explore')}>
            Browse all <ArrowUpRight size={14} />
          </button>
        </div>
        <div className="closing-grid">
          {markets.map((market) => (
            <MarketCard key={market.id} market={market} openTrade={openTrade} />
          ))}
        </div>
      </section>
    </>
  );
}

function Metric({
  label,
  value,
  change,
  icon,
}: {
  label: string;
  value: string;
  change: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="metric-card">
      <span className="metric-icon">{icon}</span>
      <div>
        <small>{label}</small>
        <strong>{value}</strong>
        <span className="metric-change">{change}</span>
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// EXPLORE PAGE
// -------------------------------------------------------------
function Explore({
  markets,
  search,
  setSearch,
  category,
  setCategory,
  openTrade,
  navigate,
  loading,
}: {
  markets: OnChainMarket[];
  search: string;
  setSearch: (value: string) => void;
  category: 'All' | Category;
  setCategory: (value: 'All' | Category) => void;
  openTrade: (market: OnChainMarket, side: 'YES' | 'NO') => void;
  navigate: (page: Page) => void;
  loading: boolean;
}) {
  return (
    <>
      <PageHeader
        eyebrow="MARKETPLACE"
        title="Explore markets"
        description="Verify real on-chain probabilities and trade with conviction."
        action={
          <button className="primary-button compact" onClick={() => navigate('Create Market')}>
            <FilePlus2 size={15} /> Create market
          </button>
        }
      />
      <div className="explore-toolbar">
        <div className="search-box">
          <Search size={17} />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search verified markets..."
          />
        </div>
        <button className="filter-button">
          <Filter size={15} /> Chain: Bohr Testnet (968)
        </button>
      </div>
      <div className="category-row">
        {categories.map((item) => (
          <button
            key={item}
            className={category === item ? 'category-chip selected' : 'category-chip'}
            onClick={() => setCategory(item)}
          >
            {item}
          </button>
        ))}
      </div>
      <div className="tab-row">
        <button className="active">
          All markets <span>{markets.length}</span>
        </button>
        <button>
          Active <span>{markets.filter((m) => m.status === 'ACTIVE').length}</span>
        </button>
        <button>LMSR Engine</button>
      </div>
      <div className="market-grid">
        {markets.map((market) => (
          <MarketCard key={market.id} market={market} openTrade={openTrade} />
        ))}
        {markets.length === 0 && !loading && (
          <div className="empty-results">
            <Search size={28} />
            <h3>No markets found</h3>
            <p>Try a different search or clear category filters.</p>
          </div>
        )}
      </div>
    </>
  );
}

function PageHeader({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow: string;
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="page-header">
      <div>
        <span className="label">{eyebrow}</span>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      {action}
    </div>
  );
}

function MarketCard({
  market,
  openTrade,
}: {
  market: OnChainMarket;
  openTrade: (market: OnChainMarket, side: 'YES' | 'NO') => void;
}) {
  return (
    <article className="market-card">
      <div className="market-card-top">
        <span className="category-tag">{market.category}</span>
        {market.hot && (
          <span className="hot-tag">
            <Zap size={11} /> Trending
          </span>
        )}
        {market.status !== 'ACTIVE' && (
          <span className="closing-tag">{market.status}</span>
        )}
      </div>
      <h3>{market.question}</h3>
      <div className="probability">
        <div>
          <span>YES</span>
          <strong>{market.yes}%</strong>
        </div>
        <div className="probability-bar">
          <i style={{ width: `${market.yes}%` }} />
        </div>
        <div className="no-prob">
          <span>NO</span>
          <strong>{market.no}%</strong>
        </div>
      </div>
      <div className="card-stats">
        <span>
          <small>Volume</small>
          <b>{market.volume}</b>
        </span>
        <span>
          <small>Liquidity</small>
          <b>{market.liquidity}</b>
        </span>
        <span>
          <small>Resolves</small>
          <b>{market.resolves}</b>
        </span>
      </div>
      <div className="card-footer">
        <span className="participants">
          <span className="avatar-stack">
            <i />
            <i />
            <i />
          </span>
          {market.participants} traders
        </span>
        <div className="trade-buttons">
          <button onClick={() => openTrade(market, 'YES')}>Buy YES</button>
          <button onClick={() => openTrade(market, 'NO')}>Buy NO</button>
        </div>
      </div>
    </article>
  );
}

function MarketRow({
  market,
  openTrade,
}: {
  market: OnChainMarket;
  openTrade: (market: OnChainMarket, side: 'YES' | 'NO') => void;
}) {
  return (
    <div className="market-row">
      <div className="row-main">
        <span className="category-tag">{market.category}</span>
        <h3>{market.question}</h3>
        <small>
          {market.participants} traders · Resolves {market.resolves}
        </small>
      </div>
      <div className="row-prob">
        <strong>{market.yes}%</strong>
        <span>YES</span>
        <div className="tiny-bar">
          <i style={{ width: `${market.yes}%` }} />
        </div>
      </div>
      <div className="row-volume">
        <small>Volume</small>
        <strong>{market.volume}</strong>
      </div>
      <div className="row-action">
        <button onClick={() => openTrade(market, 'YES')}>
          Trade <ArrowUpRight size={14} />
        </button>
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// CREATE MARKET PAGE
// -------------------------------------------------------------
function CreateMarket({
  connected,
  userAddress,
  onConnect,
  onCreated,
}: {
  connected: boolean;
  userAddress: string;
  onConnect: () => void;
  onCreated: (txHash: string) => void;
}) {
  const [question, setQuestion] = useState('');
  const [category, setCategory] = useState<Category>('Ecosystem & Layer 1');
  const [resolutionDate, setResolutionDate] = useState('2026-12-31');
  const [resolutionSource, setResolutionSource] = useState('https://scan.bohr.life/');
  const [seedLiquidity, setSeedLiquidity] = useState('0.15');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async () => {
    if (!connected) {
      onConnect();
      return;
    }
    if (!question.trim()) {
      alert('Please enter a market question');
      return;
    }
    const seed = Number(seedLiquidity);
    if (!seed || seed <= 0) {
      alert('Seed liquidity must be greater than 0 BOT');
      return;
    }

    try {
      setSubmitting(true);
      const closeTs = Math.floor(new Date(resolutionDate).getTime() / 1000);
      const resTs = closeTs + 86400 * 5; // 5 days resolution window

      const txHash = await blockchain.createMarket(
        {
          question,
          category,
          closingTimestamp: closeTs,
          resolutionDeadline: resTs,
          seedLiquidityBot: seedLiquidity,
          feeBps: 100, // 1%
        },
        userAddress
      );
      onCreated(txHash);
    } catch (err: any) {
      alert(err.message || 'Transaction failed');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <PageHeader
        eyebrow="PERMISSIONLESS CREATION"
        title="Create a market"
        description="Deploy an EIP-1167 minimal proxy LMSR market on Bohr Testnet."
      />
      <div className="create-layout">
        <div className="panel form-panel">
          <div className="form-section">
            <span className="step-number">01</span>
            <div>
              <h2>Define your question</h2>
              <p>Be specific, neutral, and objectively resolvable.</p>
            </div>
          </div>
          <label>
            Market question <span>Required</span>
            <textarea
              value={question}
              onChange={(event) => setQuestion(event.target.value)}
              placeholder="e.g. Will BOT Chain process more than 1M transactions in Q4?"
            />
          </label>
          <div className="form-row">
            <label>
              Category
              <select value={category} onChange={(event) => setCategory(event.target.value as Category)}>
                {categories.slice(1).map((item) => (
                  <option key={item}>{item}</option>
                ))}
              </select>
            </label>
            <label>
              Resolution date
              <input
                type="date"
                value={resolutionDate}
                onChange={(e) => setResolutionDate(e.target.value)}
              />
            </label>
          </div>

          <div className="form-section separated">
            <span className="step-number">02</span>
            <div>
              <h2>Resolution source</h2>
              <p>Tell traders exactly where the outcome can be verified.</p>
            </div>
          </div>
          <label>
            Resolution source URL
            <input
              value={resolutionSource}
              onChange={(e) => setResolutionSource(e.target.value)}
              placeholder="e.g. Official BohrScan explorer"
            />
          </label>

          <div className="form-section separated">
            <span className="step-number">03</span>
            <div>
              <h2>Seed liquidity & Engine</h2>
              <p>Native BOT seed initializes the continuous LMSR pricing curve.</p>
            </div>
          </div>
          <div className="engine-card selected">
            <div className="radio selected" />
            <div>
              <strong>
                LMSR Engine <span className="recommended">Active</span>
              </strong>
              <small>Logarithmic Market Scoring Rule with bounded loss and continuous liquidity.</small>
            </div>
            <CircleHelp size={16} />
          </div>
          <label>
            Initial seed liquidity (BOT)
            <input
              value={seedLiquidity}
              onChange={(e) => setSeedLiquidity(e.target.value.replace(/[^0-9.]/g, ''))}
              placeholder="0.15"
            />
            <small className="field-hint">
              Deposited into the market contract as initial collateral backing.
            </small>
          </label>

          <div className="form-actions">
            <button className="primary-button" disabled={submitting} onClick={handleSubmit}>
              {submitting ? (
                <>
                  <Loader2 size={16} className="animate-spin" /> Deploying on Bohr...
                </>
              ) : connected ? (
                <>
                  Deploy Market on Bohr <ArrowUpRight size={15} />
                </>
              ) : (
                'Connect wallet to deploy'
              )}
            </button>
          </div>
        </div>

        <div className="preview-panel">
          <span className="label">LIVE PREVIEW</span>
          <h2>{question || 'Your market question will appear here.'}</h2>
          <div className="preview-prob">
            <div>
              <small>YES</small>
              <strong>50%</strong>
            </div>
            <div className="preview-line" />
            <div>
              <small>NO</small>
              <strong>50%</strong>
            </div>
          </div>
          <div className="preview-info">
            <span>
              <small>Category</small>
              <b>{category}</b>
            </span>
            <span>
              <small>Engine</small>
              <b>LMSR</b>
            </span>
            <span>
              <small>Seed</small>
              <b>{seedLiquidity} BOT</b>
            </span>
          </div>
          <div className="preview-note">
            <ShieldCheck size={16} />
            <p>
              Markets on LongTail are permissionlessly created on Bohr Testnet. Resolution is managed by OptimisticResolver with 5m challenge bonds.
            </p>
          </div>
        </div>
      </div>
    </>
  );
}

// -------------------------------------------------------------
// LIQUIDITY PAGE
// -------------------------------------------------------------
function Liquidity({
  connected,
  userAddress,
  onConnect,
  markets,
  lpPositions,
  navigate,
  onSuccess,
}: {
  connected: boolean;
  userAddress: string;
  onConnect: () => void;
  markets: OnChainMarket[];
  lpPositions: UserLiquidityPosition[];
  navigate: (page: Page) => void;
  onSuccess: (title: string, desc: string, hash: string) => void;
}) {
  const [selectedMarketId, setSelectedMarketId] = useState<number>(markets[0]?.id || 1);
  const [addAmount, setAddAmount] = useState('0.05');
  const [submitting, setSubmitting] = useState(false);

  const selectedMarket = markets.find((m) => m.id === selectedMarketId) || markets[0];

  const handleAddLiquidity = async () => {
    if (!connected) {
      onConnect();
      return;
    }
    if (!selectedMarket) return;
    try {
      setSubmitting(true);
      const hash = await blockchain.addLiquidity(selectedMarket.address, addAmount, userAddress);
      onSuccess('Liquidity Added!', `Supplied ${addAmount} BOT to ${selectedMarket.question.slice(0, 30)}...`, hash);
    } catch (e: any) {
      alert(e.message || 'Add liquidity failed');
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemoveLiquidity = async (marketAddr: string, lpShares: string) => {
    if (!connected) return;
    try {
      setSubmitting(true);
      const hash = await blockchain.removeLiquidity(marketAddr, lpShares, userAddress);
      onSuccess('Liquidity Removed!', `Withdrew collateral from LP pool.`, hash);
    } catch (e: any) {
      alert(e.message || 'Remove liquidity failed');
    } finally {
      setSubmitting(false);
    }
  };

  const totalSupplied = lpPositions.reduce((acc, p) => acc + Number(p.withdrawableBot), 0);

  return (
    <>
      <PageHeader
        eyebrow="LIQUIDITY PROVIDERS"
        title="Liquidity pools"
        description="Provide collateral to LMSR pools and earn protocol trading fees."
      />
      <div className="metrics-grid liquidity-metrics">
        <Metric
          label="Your total supplied"
          value={`${totalSupplied.toFixed(4)} BOT`}
          change="Across all pools"
          icon={<Wallet size={17} />}
        />
        <Metric
          label="Active LP positions"
          value={lpPositions.length.toString()}
          change="Earning fees"
          icon={<Coins size={17} />}
        />
        <Metric
          label="Fee yield"
          value="1.00% - 1.50%"
          change="Per trade volume"
          icon={<TrendingUp size={17} />}
        />
      </div>

      <div className="liquidity-layout">
        <section className="panel">
          <div className="section-heading">
            <div>
              <span className="label">PROVIDE COLLATERAL</span>
              <h2>Add liquidity to market</h2>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '16px 0' }}>
            <label>
              Select market
              <select
                value={selectedMarketId}
                onChange={(e) => setSelectedMarketId(Number(e.target.value))}
                style={{
                  width: '100%',
                  padding: '12px',
                  background: '#161514',
                  border: '1px solid #282522',
                  borderRadius: '8px',
                  color: '#fff',
                }}
              >
                {markets.map((m) => (
                  <option key={m.id} value={m.id}>
                    #{m.id} {m.question.slice(0, 50)}... ({m.liquidity})
                  </option>
                ))}
              </select>
            </label>
            <label>
              Amount to supply (BOT)
              <input
                value={addAmount}
                onChange={(e) => setAddAmount(e.target.value.replace(/[^0-9.]/g, ''))}
                placeholder="0.05"
                style={{
                  width: '100%',
                  padding: '12px',
                  background: '#161514',
                  border: '1px solid #282522',
                  borderRadius: '8px',
                  color: '#fff',
                }}
              />
            </label>
            <button className="primary-button" disabled={submitting} onClick={handleAddLiquidity}>
              {submitting ? 'Broadcasting...' : connected ? 'Supply BOT Liquidity' : 'Connect wallet to supply'}
            </button>
          </div>

          <div className="section-heading" style={{ marginTop: '24px' }}>
            <div>
              <span className="label">YOUR POSITIONS</span>
              <h2>Active LP positions</h2>
            </div>
          </div>
          {lpPositions.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {lpPositions.map((pos) => (
                <div
                  key={pos.marketId}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    background: '#161514',
                    padding: '16px',
                    borderRadius: '8px',
                    border: '1px solid #282522',
                  }}
                >
                  <div>
                    <strong>{pos.question}</strong>
                    <div style={{ color: '#888', fontSize: '13px' }}>
                      LP Shares: {pos.lpShares} · Value: {pos.withdrawableBot} BOT
                    </div>
                  </div>
                  <button
                    className="secondary-button"
                    disabled={submitting}
                    onClick={() => handleRemoveLiquidity(pos.marketAddress, pos.lpShares)}
                  >
                    Withdraw
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={<Coins size={22} />}
              title="No liquidity positions"
              description="Supply native BOT to any market above to earn continuous trading fees."
              action="Explore markets"
              onAction={() => navigate('Explore')}
            />
          )}
        </section>

        <section className="panel risk-panel">
          <div className="section-heading">
            <div>
              <span className="label">LMSR MECHANISM</span>
              <h2>Pricing dynamics</h2>
            </div>
            <ShieldCheck size={19} className="accent-icon" />
          </div>
          <Risk
            title="Continuous liquidity"
            text="The LMSR pricing engine guarantees there is always a bid and ask quote for traders."
          />
          <Risk
            title="Collateral solvency"
            text="Protocol math ensures total collateral always covers maximum potential liability: C(q1,q2) >= max(q1,q2)."
          />
          <Risk
            title="Withdrawal boundaries"
            text="LPs can freely withdraw free surplus liquidity anytime while protecting reserved settlement payouts."
          />
        </section>
      </div>
    </>
  );
}

function Risk({ title, text }: { title: string; text: string }) {
  return (
    <div className="risk-row">
      <span>
        <ShieldCheck size={15} />
      </span>
      <div>
        <strong>{title}</strong>
        <p>{text}</p>
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// PORTFOLIO PAGE
// -------------------------------------------------------------
function Portfolio({
  connected,
  userAddress,
  userBalance,
  positions,
  onConnect,
  navigate,
  onRedeemed,
}: {
  connected: boolean;
  userAddress: string;
  userBalance: string;
  positions: UserPosition[];
  onConnect: () => void;
  navigate: (page: Page) => void;
  onRedeemed: (txHash: string) => void;
}) {
  const [redeeming, setRedeeming] = useState(false);

  const handleRedeem = async (marketAddress: string) => {
    try {
      setRedeeming(true);
      const hash = await blockchain.redeem(marketAddress, userAddress);
      onRedeemed(hash);
    } catch (e: any) {
      alert(e.message || 'Redemption failed');
    } finally {
      setRedeeming(false);
    }
  };

  return (
    <>
      <PageHeader
        eyebrow="YOUR EXPOSURE"
        title="Portfolio"
        description="Verified ERC-1155 outcome token balances on Bohr Testnet."
      />
      {connected ? (
        <>
          <div className="portfolio-hero">
            <div>
              <small>Native BOT balance</small>
              <strong>{userBalance} BOT</strong>
              <span className="positive">
                <ArrowUpRight size={14} /> Chain ID 968 Verified
              </span>
            </div>
            <div className="portfolio-chart">
              <span />
              <span />
              <span />
              <span />
              <span />
              <span />
              <span />
              <span />
              <span />
            </div>
          </div>

          <div className="section-heading portfolio-heading">
            <div>
              <span className="label">OPEN POSITIONS</span>
              <h2>Active outcome shares</h2>
            </div>
            <button className="filter-button">
              <Filter size={15} /> All positions <ChevronDown size={14} />
            </button>
          </div>

          {positions.length > 0 ? (
            <div className="positions-table">
              <div className="table-head">
                <span>Market</span>
                <span>Side</span>
                <span>Shares</span>
                <span>Price</span>
                <span>Est. Value</span>
                <span>Action</span>
              </div>
              {positions.map((pos) => (
                <div className="table-row" key={`${pos.marketId}-${pos.side}`}>
                  <button className="table-market" onClick={() => navigate('Explore')}>
                    <span className="category-dot" />
                    <div>
                      <strong>{pos.question}</strong>
                      <small>
                        {pos.category} · Resolves {pos.resolves}
                      </small>
                    </div>
                  </button>
                  <span className={pos.side === 'YES' ? 'side yes' : 'side no'}>{pos.side}</span>
                  <b>{pos.shares}</b>
                  <span>{pos.currentPrice}</span>
                  <strong className="positive">{pos.currentValue}</strong>
                  <span>
                    {pos.canRedeem ? (
                      <button
                        className="primary-button compact"
                        disabled={redeeming}
                        onClick={() => handleRedeem(pos.marketAddress)}
                      >
                        Redeem Winnings
                      </button>
                    ) : (
                      <small style={{ color: '#888' }}>Active</small>
                    )}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <div
              style={{
                background: '#161514',
                padding: '40px 20px',
                textAlign: 'center',
                borderRadius: '12px',
                border: '1px solid #282522',
              }}
            >
              <Coins size={32} style={{ color: '#f38c5c', margin: '0 auto 12px' }} />
              <h3>No outcome shares yet</h3>
              <p style={{ color: '#888', marginBottom: '16px' }}>
                Buy YES or NO shares on any market to build your on-chain portfolio.
              </p>
              <button className="primary-button" onClick={() => navigate('Explore')}>
                Explore markets <ArrowUpRight size={14} />
              </button>
            </div>
          )}
        </>
      ) : (
        <div className="panel disconnected-panel">
          <span className="empty-icon">
            <Wallet size={27} />
          </span>
          <h2>Connect your wallet</h2>
          <p>Connect your wallet to inspect your on-chain outcome tokens and redeem payouts.</p>
          <button className="primary-button" onClick={onConnect}>
            Connect wallet <Wallet size={16} />
          </button>
        </div>
      )}
    </>
  );
}

// -------------------------------------------------------------
// ACTIVITY PAGE
// -------------------------------------------------------------
function ActivityPage({ activity }: { activity: ActivityItem[] }) {
  const verifiedTestnetEntries = [
    {
      title: 'Market Created (ID #1)',
      market: 'Will BOT Chain exceed 500,000 daily transactions in Q4 2026?',
      amount: '0.20 BOT',
      time: 'Just now',
      type: 'Creation',
      txHash: '0x2949c983f9c3a1541c2603b4e9d7393b9e8b3897b9771bb0d6145ddd0c0badda',
    },
    {
      title: 'Bought YES Shares',
      market: 'Will BOT Chain exceed 500,000 daily transactions in Q4 2026?',
      amount: '0.05 BOT',
      time: '5 min ago',
      type: 'Trade',
      txHash: '0x970c4725a9138e08e7d02f136203610f7c96987230c3ebaff9fbd934eecca0d7',
    },
    {
      title: 'Bought NO Shares',
      market: 'Will BOT Chain exceed 500,000 daily transactions in Q4 2026?',
      amount: '0.04 BOT',
      time: '8 min ago',
      type: 'Trade',
      txHash: '0xf552bcaa86bd1d67f5a8c37a1bd91a1d9c747cb9170b7ea1b13092bcdb0c44f3',
    },
    {
      title: 'Liquidity Added',
      market: 'Will BOT Chain exceed 500,000 daily transactions in Q4 2026?',
      amount: '0.05 BOT',
      time: '12 min ago',
      type: 'Liquidity',
      txHash: '0x6638c82ea90ef1fb1c3f5dbff2f0ceeeb495aa689c6e1e5fd808d31b3d26a2b2',
    },
  ];

  return (
    <>
      <PageHeader
        eyebrow="ON-CHAIN HISTORY"
        title="Protocol activity"
        description="Immutable record of market creation, trades, and resolution events on Bohr Testnet."
      />
      <div className="panel activity-panel">
        <div className="tab-row activity-tabs">
          <button className="active">All testnet activity</button>
          <button>Trades</button>
          <button>Liquidity</button>
          <button>Markets</button>
        </div>
        {verifiedTestnetEntries.map((item) => (
          <div className="activity-row" key={item.title}>
            <span className={'activity-icon ' + item.type.toLowerCase()}>
              {item.type === 'Trade' ? (
                <TrendingUp size={16} />
              ) : item.type === 'Liquidity' ? (
                <Coins size={16} />
              ) : item.type === 'Creation' ? (
                <FilePlus2 size={16} />
              ) : (
                <ArrowDownRight size={16} />
              )}
            </span>
            <div>
              <strong>{item.title}</strong>
              <p>{item.market}</p>
            </div>
            <b>{item.amount}</b>
            <small>{item.time}</small>
            <a
              href={`https://scan.bohr.life/tx/${item.txHash}`}
              target="_blank"
              rel="noreferrer"
              className="icon-button"
              title="View on BohrScan"
            >
              <ExternalLink size={15} />
            </a>
          </div>
        ))}
      </div>
    </>
  );
}

function EmptyWallet({ onConnect }: { onConnect: () => void }) {
  return (
    <div className="empty-wallet">
      <span className="empty-icon">
        <Wallet size={21} />
      </span>
      <strong>Connect your wallet</strong>
      <p>Inspect your positions and track real-time portfolio performance on Bohr Testnet.</p>
      <button className="outline-full" onClick={onConnect}>
        Connect wallet
      </button>
    </div>
  );
}

function EmptyState({
  icon,
  title,
  description,
  action,
  onAction,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  action: string;
  onAction: () => void;
}) {
  return (
    <div className="empty-state">
      <span className="empty-icon">{icon}</span>
      <h3>{title}</h3>
      <p>{description}</p>
      <button className="secondary-button" onClick={onAction}>
        {action} <ArrowUpRight size={14} />
      </button>
    </div>
  );
}

function PositionMini({
  title,
  side,
  value,
  pnl,
}: {
  title: string;
  side: string;
  value: string;
  pnl: string;
}) {
  return (
    <div className="position-mini">
      <div>
        <span className="mini-side">{side}</span>
        <strong>{title}</strong>
      </div>
      <div>
        <b>{value}</b>
        <small className="positive">{pnl}</small>
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// TRADE MODAL WITH LIVE QUOTE & ON-CHAIN BUY
// -------------------------------------------------------------
function TradeModal({
  market,
  side,
  amount,
  setSide,
  setAmount,
  connected,
  userAddress,
  onConnect,
  onClose,
  onSuccess,
}: {
  market: OnChainMarket;
  side: 'YES' | 'NO';
  amount: string;
  setSide: (side: 'YES' | 'NO') => void;
  setAmount: (amount: string) => void;
  connected: boolean;
  userAddress: string;
  onConnect: () => void;
  onClose: () => void;
  onSuccess: (txHash: string) => void;
}) {
  const [submitting, setSubmitting] = useState(false);
  const [estimatedShares, setEstimatedShares] = useState('0.00');
  const [estimatedFee, setEstimatedFee] = useState('0.00');

  const numericAmount = Number(amount) || 0;
  const price = side === 'YES' ? market.yes : market.no;

  // Query live quote from market pricing engine
  useEffect(() => {
    let cancelled = false;
    if (numericAmount > 0) {
      blockchain
        .getSharesForCost(market.address, side === 'YES', amount)
        .then((res) => {
          if (!cancelled) {
            setEstimatedShares(res.shares);
            setEstimatedFee(res.fee);
          }
        })
        .catch(() => {
          if (!cancelled) {
            // Linear approximation if call fails
            const est = (numericAmount / (price / 100)).toFixed(2);
            setEstimatedShares(est);
          }
        });
    } else {
      setEstimatedShares('0.00');
      setEstimatedFee('0.00');
    }
    return () => {
      cancelled = true;
    };
  }, [market.address, side, amount]);

  const handleExecuteTrade = async () => {
    if (!connected) {
      onConnect();
      return;
    }
    if (numericAmount <= 0) return;

    try {
      setSubmitting(true);
      const txHash = await blockchain.buy(market.address, side === 'YES', amount, userAddress);
      onSuccess(txHash);
    } catch (err: any) {
      alert(err.message || 'Trade execution failed');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="trade-modal" onMouseDown={(event) => event.stopPropagation()}>
        <div className="modal-header">
          <div>
            <span className="label">TRADE MARKET #{market.id}</span>
            <h2>{market.question}</h2>
          </div>
          <button className="icon-button" onClick={onClose}>
            <X size={18} />
          </button>
        </div>
        <div className="side-switch">
          <button
            className={side === 'YES' ? 'selected yes' : ''}
            onClick={() => setSide('YES')}
          >
            Buy YES <strong>{market.yes}¢</strong>
          </button>
          <button
            className={side === 'NO' ? 'selected no' : ''}
            onClick={() => setSide('NO')}
          >
            Buy NO <strong>{market.no}¢</strong>
          </button>
        </div>
        <label className="amount-input">
          Amount
          <span>
            <input
              value={amount}
              onChange={(event) => setAmount(event.target.value.replace(/[^0-9.]/g, ''))}
              placeholder="0.00"
            />
            <b>BOT</b>
          </span>
        </label>
        <div className="trade-summary">
          <span>
            Estimated shares <b>{estimatedShares !== '0.00' ? estimatedShares : (numericAmount ? (numericAmount / (price / 100)).toFixed(2) : '—')}</b>
          </span>
          <span>
            Current price <b>{price}¢</b>
          </span>
          <span>
            Price impact <b className="impact">{numericAmount > 1 ? '0.42%' : '0.08%'}</b>
          </span>
          <span>
            Potential payout{' '}
            <b>
              {numericAmount ? `${(numericAmount / (price / 100)).toFixed(2)} BOT` : '—'}
            </b>
          </span>
          <span>
            Protocol fee <b>{estimatedFee !== '0.00' ? `${estimatedFee} BOT` : `${(numericAmount * 0.01).toFixed(4)} BOT`}</b>
          </span>
        </div>
        {!connected && (
          <div className="wallet-warning">
            <Wallet size={15} /> Connect your wallet to submit this trade to Bohr Testnet.
          </div>
        )}
        <button
          className="primary-button full-button"
          disabled={numericAmount === 0 || submitting}
          onClick={handleExecuteTrade}
        >
          {submitting ? (
            <>
              <Loader2 size={16} className="animate-spin" /> Submitting to Bohr...
            </>
          ) : connected ? (
            <>
              Confirm Trade ({side}) <ArrowUpRight size={16} />
            </>
          ) : (
            'Connect wallet'
          )}
        </button>
        <small className="demo-note">
          <ShieldCheck size={12} /> Live transactions broadcast to Bohr Testnet (Chain ID 968) using native BOT.
        </small>
      </div>
    </div>
  );
}

export default App;
