# ΨNet Frontend Demo Setup Guide

## Overview

This guide explains how to create a frontend demo/dashboard for the ΨNet protocol. The demo will showcase the key features implemented in the smart contracts with Phase 0 critical fixes applied.

## Tech Stack Options

### Option 1: React + ethers.js (Recommended)
- **Best for**: Modern SPAs with full Web3 integration
- **Pros**: Large ecosystem, excellent documentation, ethers.js v6 support
- **Cons**: Requires build setup

### Option 2: Next.js + wagmi + viem
- **Best for**: Production-grade dApps with SSR
- **Pros**: SEO-friendly, TypeScript support, modern hooks
- **Cons**: More complex setup

### Option 3: Vue.js + ethers.js
- **Best for**: Developers familiar with Vue ecosystem
- **Pros**: Simpler than React for beginners
- **Cons**: Smaller Web3 ecosystem

## Quick Start (React + ethers.js)

### Step 1: Create React App

```bash
npx create-react-app psinet-dashboard
cd psinet-dashboard

# Install dependencies
npm install ethers@^6.10.0
npm install @rainbow-me/rainbowkit wagmi viem
npm install react-router-dom
npm install recharts # For charts/graphs
npm install @heroicons/react # For icons
```

### Step 2: Project Structure

```
psinet-dashboard/
├── public/
├── src/
│   ├── components/
│   │   ├── AgentDashboard.jsx
│   │   ├── ReferralNetwork.jsx
│   │   ├── ReputationPanel.jsx
│   │   ├── SkillMarketplace.jsx
│   │   ├── ValidationQueue.jsx
│   │   └── CircuitBreakerStatus.jsx
│   ├── contracts/
│   │   ├── addresses.json          # From deployments/
│   │   ├── PsiToken.json           # ABI
│   │   ├── ShapleyReferrals.json   # ABI
│   │   ├── ReputationRegistry.json # ABI
│   │   └── SkillRegistry.json      # ABI
│   ├── hooks/
│   │   ├── useContract.js
│   │   ├── useReferrals.js
│   │   ├── useReputation.js
│   │   └── useCircuitBreaker.js
│   ├── utils/
│   │   ├── contracts.js
│   │   └── formatters.js
│   ├── App.jsx
│   └── index.js
└── package.json
```

### Step 3: Contract Integration

Create `src/contracts/addresses.json`:

```json
{
  "localhost": {
    "chainId": 31337,
    "contracts": {
      "PsiToken": "0x...",
      "ShapleyReferrals": "0x...",
      "ReputationRegistry": "0x...",
      "IdentityRegistry": "0x...",
      "SkillRegistry": "0x...",
      "CRPCValidator": "0x..."
    }
  },
  "sepolia": {
    "chainId": 11155111,
    "contracts": {
      "PsiToken": "0x...",
      "ShapleyReferrals": "0x...",
      "ReputationRegistry": "0x...",
      "IdentityRegistry": "0x...",
      "SkillRegistry": "0x...",
      "CRPCValidator": "0x..."
    }
  }
}
```

### Step 4: Contract Hook

Create `src/hooks/useContract.js`:

```javascript
import { useEffect, useState } from 'react';
import { ethers } from 'ethers';
import addresses from '../contracts/addresses.json';

// Import ABIs
import PsiTokenABI from '../contracts/PsiToken.json';
import ShapleyReferralsABI from '../contracts/ShapleyReferrals.json';
import ReputationRegistryABI from '../contracts/ReputationRegistry.json';
import SkillRegistryABI from '../contracts/SkillRegistry.json';

const ABIS = {
  PsiToken: PsiTokenABI.abi,
  ShapleyReferrals: ShapleyReferralsABI.abi,
  ReputationRegistry: ReputationRegistryABI.abi,
  SkillRegistry: SkillRegistryABI.abi,
};

export function useContract(contractName) {
  const [contract, setContract] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadContract() {
      try {
        if (!window.ethereum) {
          throw new Error('Please install MetaMask!');
        }

        const provider = new ethers.BrowserProvider(window.ethereum);
        const signer = await provider.getSigner();
        const network = await provider.getNetwork();

        // Get contract address for current network
        const networkKey = network.chainId === 31337n ? 'localhost' : 'sepolia';
        const address = addresses[networkKey]?.contracts[contractName];

        if (!address) {
          throw new Error(`Contract ${contractName} not deployed on network ${networkKey}`);
        }

        const abi = ABIS[contractName];
        const contractInstance = new ethers.Contract(address, abi, signer);

        setContract(contractInstance);
        setLoading(false);
      } catch (err) {
        console.error('Error loading contract:', err);
        setError(err.message);
        setLoading(false);
      }
    }

    loadContract();
  }, [contractName]);

  return { contract, loading, error };
}
```

### Step 5: Referral Network Component

Create `src/components/ReferralNetwork.jsx`:

```javascript
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useContract } from '../hooks/useContract';

export function ReferralNetwork() {
  const { contract: shapleyContract, loading } = useContract('ShapleyReferrals');
  const [userData, setUserData] = useState(null);
  const [networkSize, setNetworkSize] = useState(0);
  const [referrer, setReferrer] = useState('');

  useEffect(() => {
    if (!shapleyContract) return;

    async function loadData() {
      try {
        const signer = await shapleyContract.runner.provider.getSigner();
        const address = await signer.getAddress();

        // Get user data
        const user = await shapleyContract.users(address);

        if (user.exists) {
          setUserData({
            address: user.userAddress,
            referrer: user.referrer,
            totalEarned: ethers.formatEther(user.totalEarned),
            chainDepth: Number(user.chainDepth),
          });

          // Get network size (Fix #0.3: iterative counting)
          const size = await shapleyContract.getNetworkSize(address);
          setNetworkSize(Number(size));
        }
      } catch (error) {
        console.error('Error loading referral data:', error);
      }
    }

    loadData();
  }, [shapleyContract]);

  async function handleJoinWithReferral() {
    if (!shapleyContract || !referrer) return;

    try {
      const tx = await shapleyContract.joinWithReferral(referrer);
      await tx.wait();
      alert('Successfully joined with referral!');
      window.location.reload();
    } catch (error) {
      console.error('Error joining:', error);
      alert('Failed to join: ' + error.message);
    }
  }

  if (loading) return <div>Loading...</div>;

  return (
    <div className="referral-network">
      <h2>📊 Referral Network</h2>

      {!userData?.address || userData.address === ethers.ZeroAddress ? (
        <div className="join-section">
          <h3>Join the Network</h3>
          <p>Enter a referrer address to join (or leave empty for no referrer):</p>
          <input
            type="text"
            placeholder="0x..."
            value={referrer}
            onChange={(e) => setReferrer(e.target.value)}
          />
          <button onClick={handleJoinWithReferral}>Join Network</button>

          <div className="info-box">
            <p><strong>✅ Phase 0 Fix #0.2:</strong> Cycle detection enabled</p>
            <p>Cannot create referral loops (A → B → A)</p>
          </div>
        </div>
      ) : (
        <div className="network-stats">
          <h3>Your Network</h3>
          <div className="stat">
            <label>Referrer:</label>
            <span>{userData.referrer === ethers.ZeroAddress ? 'None (Root)' : userData.referrer}</span>
          </div>
          <div className="stat">
            <label>Total Earned:</label>
            <span>{userData.totalEarned} PSI</span>
            <span className="badge">✅ Capped at 50k PSI (Fix #0.1)</span>
          </div>
          <div className="stat">
            <label>Chain Depth:</label>
            <span>{userData.chainDepth}</span>
          </div>
          <div className="stat">
            <label>Network Size:</label>
            <span>{networkSize} users</span>
            <span className="badge">✅ Iterative counting (Fix #0.3)</span>
          </div>
        </div>
      )}
    </div>
  );
}
```

### Step 6: Circuit Breaker Status Component

Create `src/components/CircuitBreakerStatus.jsx`:

```javascript
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useContract } from '../hooks/useContract';

export function CircuitBreakerStatus() {
  const { contract: psiToken, loading } = useContract('PsiToken');
  const [status, setStatus] = useState({
    paused: false,
    dailyLimit: '0',
    mintedToday: '0',
    percentUsed: 0,
  });

  useEffect(() => {
    if (!psiToken) return;

    async function loadStatus() {
      try {
        const paused = await psiToken.emergencyPaused();
        const dailyLimit = await psiToken.dailyMintLimit();
        const mintedToday = await psiToken.mintedToday();

        const percentUsed = Number((mintedToday * 100n) / dailyLimit);

        setStatus({
          paused,
          dailyLimit: ethers.formatEther(dailyLimit),
          mintedToday: ethers.formatEther(mintedToday),
          percentUsed,
        });
      } catch (error) {
        console.error('Error loading circuit breaker status:', error);
      }
    }

    loadStatus();

    // Poll every 10 seconds
    const interval = setInterval(loadStatus, 10000);
    return () => clearInterval(interval);
  }, [psiToken]);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="circuit-breaker-status">
      <h2>🔒 Circuit Breaker Status (Fix #0.5)</h2>

      <div className={`status-card ${status.paused ? 'paused' : 'active'}`}>
        <h3>System Status</h3>
        <div className="status-indicator">
          <span className={`indicator ${status.paused ? 'red' : 'green'}`}></span>
          <span>{status.paused ? '⏸️ PAUSED' : '✅ ACTIVE'}</span>
        </div>
      </div>

      <div className="limits-card">
        <h3>Daily Mint Limit</h3>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{
              width: `${status.percentUsed}%`,
              backgroundColor: status.percentUsed > 90 ? '#f44336' : status.percentUsed > 75 ? '#ff9800' : '#4caf50'
            }}
          ></div>
        </div>
        <p>
          {status.mintedToday} / {status.dailyLimit} PSI ({status.percentUsed.toFixed(1)}%)
        </p>
        {status.percentUsed > 90 && (
          <div className="warning">
            ⚠️ Warning: Approaching daily mint limit!
          </div>
        )}
      </div>

      <div className="info-box">
        <h4>Emergency Controls</h4>
        <ul>
          <li>✅ Emergency pause mechanism enabled</li>
          <li>✅ Daily mint limit: 1M PSI</li>
          <li>✅ Admin-only controls</li>
          <li>✅ Automatic counter reset after 24h</li>
        </ul>
      </div>
    </div>
  );
}
```

### Step 7: Main App Component

Create `src/App.jsx`:

```javascript
import React, { useState } from 'react';
import './App.css';
import { ReferralNetwork } from './components/ReferralNetwork';
import { CircuitBreakerStatus } from './components/CircuitBreakerStatus';
import { ReputationPanel } from './components/ReputationPanel';
import { SkillMarketplace } from './components/SkillMarketplace';

function App() {
  const [activeTab, setActiveTab] = useState('network');

  async function connectWallet() {
    if (!window.ethereum) {
      alert('Please install MetaMask!');
      return;
    }

    try {
      await window.ethereum.request({ method: 'eth_requestAccounts' });
      alert('Wallet connected!');
    } catch (error) {
      console.error('Error connecting wallet:', error);
    }
  }

  return (
    <div className="App">
      <header>
        <h1>ΨNet Dashboard</h1>
        <p className="tagline">The Psychic Network for AI Context</p>
        <button onClick={connectWallet}>Connect Wallet</button>
      </header>

      <div className="phase0-banner">
        <h3>✅ Phase 0 Critical Fixes Applied</h3>
        <div className="fixes">
          <span>Fix #0.1: Shapley Cap</span>
          <span>Fix #0.2: Cycle Detection</span>
          <span>Fix #0.3: Iterative Counting</span>
          <span>Fix #0.4: Smooth Time-Weighting</span>
          <span>Fix #0.5: Circuit Breakers</span>
        </div>
      </div>

      <nav className="tabs">
        <button onClick={() => setActiveTab('network')} className={activeTab === 'network' ? 'active' : ''}>
          Referral Network
        </button>
        <button onClick={() => setActiveTab('reputation')} className={activeTab === 'reputation' ? 'active' : ''}>
          Reputation
        </button>
        <button onClick={() => setActiveTab('skills')} className={activeTab === 'skills' ? 'active' : ''}>
          Skills Marketplace
        </button>
        <button onClick={() => setActiveTab('breaker')} className={activeTab === 'breaker' ? 'active' : ''}>
          Circuit Breaker
        </button>
      </nav>

      <main>
        {activeTab === 'network' && <ReferralNetwork />}
        {activeTab === 'reputation' && <ReputationPanel />}
        {activeTab === 'skills' && <SkillMarketplace />}
        {activeTab === 'breaker' && <CircuitBreakerStatus />}
      </main>

      <footer>
        <p>ΨNet Protocol v0.1.0 | Phase 0 Fixes Applied</p>
        <p>
          <a href="https://github.com/WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context." target="_blank" rel="noopener noreferrer">
            GitHub
          </a>
          {' | '}
          <a href="/CRITICAL_REVIEW.md">Critical Review</a>
          {' | '}
          <a href="/ACTION_PLAN.md">Action Plan</a>
        </p>
      </footer>
    </div>
  );
}

export default App;
```

### Step 8: Basic CSS

Create `src/App.css`:

```css
.App {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', sans-serif;
}

header {
  text-align: center;
  margin-bottom: 40px;
}

header h1 {
  font-size: 2.5rem;
  margin-bottom: 10px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.phase0-banner {
  background: #e8f5e9;
  border: 2px solid #4caf50;
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 30px;
}

.phase0-banner h3 {
  margin-top: 0;
  color: #2e7d32;
}

.phase0-banner .fixes {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 15px;
}

.phase0-banner .fixes span {
  background: #fff;
  padding: 8px 15px;
  border-radius: 20px;
  font-size: 0.9rem;
  border: 1px solid #4caf50;
}

.tabs {
  display: flex;
  gap: 10px;
  margin-bottom: 30px;
  border-bottom: 2px solid #ddd;
}

.tabs button {
  padding: 12px 24px;
  border: none;
  background: none;
  cursor: pointer;
  font-size: 1rem;
  border-bottom: 3px solid transparent;
}

.tabs button.active {
  border-bottom-color: #667eea;
  color: #667eea;
  font-weight: bold;
}

.referral-network,
.circuit-breaker-status {
  background: #fff;
  padding: 30px;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.stat {
  display: flex;
  justify-content: space-between;
  padding: 15px;
  margin: 10px 0;
  background: #f5f5f5;
  border-radius: 8px;
}

.badge {
  background: #4caf50;
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 0.85rem;
  margin-left: 10px;
}

.status-card {
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.status-card.active {
  background: #e8f5e9;
  border: 2px solid #4caf50;
}

.status-card.paused {
  background: #ffebee;
  border: 2px solid #f44336;
}

.indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  display: inline-block;
  margin-right: 10px;
}

.indicator.green {
  background: #4caf50;
  box-shadow: 0 0 8px #4caf50;
}

.indicator.red {
  background: #f44336;
  box-shadow: 0 0 8px #f44336;
}

.progress-bar {
  width: 100%;
  height: 30px;
  background: #e0e0e0;
  border-radius: 15px;
  overflow: hidden;
  margin: 15px 0;
}

.progress-fill {
  height: 100%;
  transition: width 0.3s ease;
}

.info-box {
  background: #e3f2fd;
  border-left: 4px solid #2196f3;
  padding: 15px;
  margin: 20px 0;
  border-radius: 4px;
}

.warning {
  background: #fff3cd;
  border: 2px solid #ffc107;
  padding: 15px;
  border-radius: 8px;
  margin-top: 15px;
  color: #856404;
  font-weight: bold;
}

footer {
  text-align: center;
  margin-top: 60px;
  padding-top: 30px;
  border-top: 1px solid #ddd;
  color: #666;
}

button {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 1rem;
  transition: transform 0.2s;
}

button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

input {
  padding: 12px;
  border: 2px solid #ddd;
  border-radius: 6px;
  font-size: 1rem;
  width: 100%;
  max-width: 400px;
  margin: 10px 0;
}
```

## Deployment Steps

### 1. Copy Contract ABIs and Addresses

```bash
# From your Hardhat project root
cd psinet-dashboard/src/contracts/

# Copy ABIs
cp ../../artifacts/contracts/PsiToken.sol/PsiToken.json ./
cp ../../artifacts/contracts/ShapleyReferrals.sol/ShapleyReferrals.json ./
cp ../../artifacts/contracts/erc8004/ReputationRegistry.sol/ReputationRegistry.json ./
cp ../../artifacts/contracts/SkillRegistry.sol/SkillRegistry.json ./

# Copy deployment addresses
cp ../../deployments/localhost-full.json ./addresses.json
```

### 2. Run Development Server

```bash
npm start
```

Open http://localhost:3000

### 3. Connect MetaMask

1. Open MetaMask
2. Add Hardhat local network:
   - Network Name: Hardhat Local
   - RPC URL: http://127.0.0.1:8545
   - Chain ID: 31337
   - Currency Symbol: ETH

3. Import test account:
   - Use private key from Hardhat node output
   - Account #0: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

### 4. Test Features

- ✅ Join referral network (Fix #0.2: cycle detection)
- ✅ View network size (Fix #0.3: iterative counting)
- ✅ Check earned rewards (Fix #0.1: capped at 50k PSI)
- ✅ Monitor circuit breaker status (Fix #0.5)
- ✅ View reputation scores (Fix #0.4: smooth time-weighting)

## Production Deployment

### Vercel/Netlify

```bash
# Build for production
npm run build

# Deploy to Vercel
npx vercel deploy

# Or deploy to Netlify
npx netlify deploy --prod
```

### Environment Variables

Create `.env.production`:

```
REACT_APP_NETWORK=sepolia
REACT_APP_CHAIN_ID=11155111
REACT_APP_INFURA_KEY=your_infura_key
```

## Advanced Features

### Event Listening

Add real-time updates using contract events:

```javascript
useEffect(() => {
  if (!contract) return;

  // Listen for EmergencyPause events
  contract.on('EmergencyPause', (admin, reason) => {
    alert(`🚨 Emergency pause activated: ${reason}`);
  });

  // Listen for DailyMintLimitExceeded events
  contract.on('DailyMintLimitExceeded', (attempted, limit) => {
    console.warn('Approaching mint limit:', attempted, '/', limit);
  });

  return () => {
    contract.removeAllListeners();
  };
}, [contract]);
```

### Graph Visualization

Add D3.js or vis.js for referral network visualization:

```bash
npm install d3 # or
npm install vis-network
```

## Resources

- **React Documentation**: https://react.dev/
- **ethers.js v6**: https://docs.ethers.org/v6/
- **RainbowKit**: https://www.rainbowkit.com/
- **Wagmi Hooks**: https://wagmi.sh/
- **Web3 UI Libraries**: https://web3-ui.github.io/web3-ui/

## Troubleshooting

### MetaMask Connection Issues

```javascript
// Add error handling
if (!window.ethereum) {
  alert('Please install MetaMask extension');
  return;
}

// Request accounts with better error handling
try {
  await window.ethereum.request({ method: 'eth_requestAccounts' });
} catch (error) {
  if (error.code === 4001) {
    alert('Please connect to MetaMask');
  } else {
    console.error('Error:', error);
  }
}
```

### Contract Not Found

Check that:
1. Contracts are deployed to correct network
2. `addresses.json` has correct network configuration
3. ABIs are copied from `artifacts/` directory

### Transaction Failures

Add detailed error messages:

```javascript
try {
  const tx = await contract.someFunction();
  await tx.wait();
  alert('Success!');
} catch (error) {
  console.error('Full error:', error);

  if (error.code === 'ACTION_REJECTED') {
    alert('Transaction rejected by user');
  } else if (error.message.includes('daily mint limit exceeded')) {
    alert('Daily mint limit exceeded - circuit breaker active!');
  } else {
    alert('Transaction failed: ' + error.message);
  }
}
```

---

**Created**: 2025-11-07
**Status**: Ready for development
**Dependencies**: Deployed contracts with Phase 0 fixes applied
