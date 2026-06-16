# GitHub Project Setup Guide

Complete guide to setting up the ΨNet project board, labels, milestones, and issues.

---

## Option 1: Automated Setup (Recommended)

### Prerequisites

1. **Install GitHub CLI:**
   ```bash
   # macOS
   brew install gh

   # Ubuntu/Debian
   sudo apt install gh

   # Windows
   winget install GitHub.cli
   ```

2. **Authenticate:**
   ```bash
   gh auth login
   # Follow the prompts to authenticate with your GitHub account
   ```

3. **Verify access:**
   ```bash
   gh repo view WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context.
   # Should show repo info
   ```

### Run the Automated Script

```bash
cd /path/to/repository
./.github/create_issues.sh
```

The script will:
- ✅ Create 40+ labels
- ✅ Create 13 milestones
- ✅ Create 6 Phase 0 issues
- ✅ All in about 30 seconds!

**Note:** The script is idempotent - safe to run multiple times.

---

## Option 2: Manual Setup

If the automated script doesn't work or you prefer manual setup:

### Step 1: Create Labels (5-10 minutes)

Go to: `https://github.com/WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context./labels`

Click "New label" and create each label below:

#### Priority Labels (🔴 Red family)

| Name | Color | Description |
|------|-------|-------------|
| `priority: critical` | `#d73a4a` | Must fix immediately (blocking) |
| `priority: high` | `#ff6b6b` | Important, address soon |
| `priority: medium` | `#ffa726` | Normal priority |
| `priority: low` | `#66bb6a` | Nice to have |

#### Phase Labels (Various)

| Name | Color | Description |
|------|-------|-------------|
| `phase-0: stop-gap` | `#8B0000` | Immediate critical fixes |
| `phase-1: foundation` | `#1976d2` | Core infrastructure build |
| `phase-2: validation` | `#7b1fa2` | Testing and simulation |
| `phase-3: launch` | `#388e3c` | Mainnet deployment |

#### Type Labels (🟢 Semantic)

| Name | Color | Description |
|------|-------|-------------|
| `type: bug` | `#d73a4a` | Something isn't working |
| `type: security` | `#b60205` | Security vulnerability |
| `type: feature` | `#0e8a16` | New functionality |
| `type: infrastructure` | `#1d76db` | DevOps/infrastructure |
| `type: documentation` | `#0075ca` | Documentation improvements |
| `type: testing` | `#5319e7` | Test coverage |
| `type: refactor` | `#fbca04` | Code improvement |

#### Component Labels (🔵 Blue family)

| Name | Color | Description |
|------|-------|-------------|
| `component: smart-contracts` | `#c5def5` | Solidity contracts |
| `component: did` | `#c5def5` | Decentralized Identity |
| `component: ipfs` | `#c5def5` | IPFS integration |
| `component: p2p` | `#c5def5` | P2P networking |
| `component: crdt` | `#c5def5` | CRDT synchronization |
| `component: crpc` | `#c5def5` | CRPC protocol |
| `component: economics` | `#c5def5` | Tokenomics/economics |
| `component: frontend` | `#c5def5` | UI/UX |
| `component: sdk` | `#c5def5` | Developer SDK |

#### Status Labels (Various)

| Name | Color | Description |
|------|-------|-------------|
| `status: blocked` | `#e99695` | Blocked by dependencies |
| `status: in-review` | `#fef2c0` | Pull request under review |
| `status: needs-design` | `#d4c5f9` | Requires design decision |
| `status: needs-testing` | `#c2e0c6` | Awaiting test coverage |

#### Effort Labels (☁️ Blue gradient)

| Name | Color | Description |
|------|-------|-------------|
| `effort: xs` | `#e1f5fe` | < 4 hours |
| `effort: s` | `#b3e5fc` | 1-2 days |
| `effort: m` | `#81d4fa` | 3-5 days |
| `effort: l` | `#4fc3f7` | 1-2 weeks |
| `effort: xl` | `#29b6f6` | 2-4 weeks |
| `effort: xxl` | `#0288d1` | 1-3 months |

---

### Step 2: Create Milestones (5 minutes)

Go to: `https://github.com/WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context./milestones`

Click "New milestone" and create each milestone:

#### Phase 0 Milestone

**Title:** M0: Critical Fixes
**Due date:** 2 weeks from today
**Description:**
```
Complete all 5 critical stop-gap fixes.

Deliverables:
- All fixes tested and deployed to testnet
- Test coverage >95%
- No critical vulnerabilities remain

Success Criteria:
✅ All 5 issues closed
✅ Deployed to Sepolia testnet
✅ Full test suite passing
```

#### Phase 1 Milestones

**Title:** M1.1: DID + IPFS
**Due date:** 8 weeks from Phase 1 start
**Description:**
```
Ed25519 DID implementation + IPFS integration complete.

Success Criteria:
✅ 1000 DIDs can be created and resolved
✅ DID documents stored on IPFS
✅ Integration tests pass
```

**Title:** M1.2: Context Graphs
**Due date:** 16 weeks from Phase 1 start
**Description:**
```
Context graph data structure + CRDT merging.

Success Criteria:
✅ Graphs can be created and serialized
✅ CRDT merging works with 10 peers
✅ Graphs stored on IPFS
```

**Title:** M1.3: P2P Network
**Due date:** 24 weeks from Phase 1 start
**Description:**
```
LibP2P integration + peer discovery.

Success Criteria:
✅ 100 nodes can communicate
✅ Peer discovery functional
✅ Context synchronization works
```

**Title:** M1.4: CRPC Fixes
**Due date:** 28 weeks from Phase 1 start
**Description:**
```
Pairwise comparison implementation + decentralized validators.

Success Criteria:
✅ Actual pairwise comparison implemented
✅ Validators decentralized (stake-based)
✅ All CRPC tests pass
```

---

### Step 3: Create Phase 0 Issues (15-20 minutes)

Go to: `https://github.com/WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context./issues/new`

#### Issue #1: Cap Shapley Hyperinflation

**Title:** `[CRITICAL] Cap Shapley coalition bonuses to prevent hyperinflation`

**Labels:**
- `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `component: economics`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #1)

---

#### Issue #2: Add Cycle Detection

**Title:** `Add cycle detection to prevent infinite loops in referral chains`

**Labels:**
- `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #2)

---

#### Issue #3: Remove Unbounded Recursion

**Title:** `Replace recursive network counting with iterative BFS`

**Labels:**
- `priority: critical`
- `phase-0: stop-gap`
- `type: bug`
- `type: security`
- `component: smart-contracts`
- `effort: s`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #3)

---

#### Issue #4: Fix Reputation Time-Weighting

**Title:** `Fix reputation time-weighting cliff at 365 days`

**Labels:**
- `priority: high`
- `phase-0: stop-gap`
- `type: bug`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #4)

---

#### Issue #5: Add Circuit Breakers

**Title:** `Implement emergency pause and daily mint limits`

**Labels:**
- `priority: critical`
- `phase-0: stop-gap`
- `type: security`
- `type: feature`
- `component: smart-contracts`
- `effort: xs`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #5)

---

#### Issue #6: Phase 0 Testing & Deployment

**Title:** `Comprehensive testing and deployment of Phase 0 fixes`

**Labels:**
- `priority: critical`
- `phase-0: stop-gap`
- `type: testing`
- `effort: s`

**Milestone:** M0: Critical Fixes

**Body:** (Copy from create_issues.sh or PROJECT_BOARD.md Issue #6)

---

## Step 4: Create Project Board (5 minutes)

1. Go to: `https://github.com/WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context./projects`
2. Click "New project"
3. Choose "Board" view
4. Name: "ΨNet Production Roadmap"
5. Description: "18-24 month roadmap to mainnet launch"
6. Create columns:

   | Column Name | Description |
   |-------------|-------------|
   | 📋 Backlog | All planned tasks not yet started |
   | 🔴 Phase 0: Critical | Immediate stop-gap fixes (2-4 weeks) |
   | 🏗️ Phase 1: Foundation | Core infrastructure (6-9 months) |
   | 🧪 Phase 2: Validation | Testing & simulation (3-6 months) |
   | 🚀 Phase 3: Launch | Mainnet deployment (3-6 months) |
   | ✅ Done | Completed tasks |

7. Add automation rules:
   - Auto-move to "Done" when issue closed
   - Auto-move to next phase when labeled with next phase

---

## Step 5: Assign Issues (2 minutes)

1. Go to each issue
2. Click "Assignees" on the right
3. Assign appropriate team member
4. Add to project board
5. Move to appropriate column

**Recommended assignments:**

- **Issue #1-3, #5:** Senior Smart Contract Developer
- **Issue #4:** Smart Contract Developer (reputation specialist)
- **Issue #6:** QA Lead + Project Manager

---

## Step 6: Start Working! 🚀

1. Team member picks up Issue #1 (highest priority)
2. Create branch: `git checkout -b fix/issue-1-shapley-caps`
3. Implement fix following specification
4. Write tests (>95% coverage)
5. Create PR with "Fixes #1" in description
6. Request 2+ reviews
7. Merge when approved
8. Move issue to "Done"
9. Celebrate! 🎉

---

## Troubleshooting

### GitHub CLI Installation Issues

**Problem:** `gh` command not found

**Solution:**
```bash
# Check installation
which gh

# If not found, install:
# macOS: brew install gh
# Linux: sudo apt install gh
# Windows: winget install GitHub.cli
```

**Problem:** Authentication failed

**Solution:**
```bash
# Re-authenticate
gh auth logout
gh auth login
# Choose HTTPS, authenticate via browser
```

### Script Permission Issues

**Problem:** Permission denied when running script

**Solution:**
```bash
chmod +x .github/create_issues.sh
./.github/create_issues.sh
```

### Label Already Exists

**Problem:** Script fails because labels already exist

**Solution:** The script uses `--force` flag which should update existing labels. If it still fails:
```bash
# Delete all labels first (CAREFUL!)
gh label list --repo $REPO --json name --jq '.[].name' | \
  xargs -I {} gh label delete {} --repo $REPO --yes

# Then re-run script
./.github/create_issues.sh
```

### Milestone Date Format

**Problem:** Invalid date format

**Solution:** Milestones require dates in ISO 8601 format: `YYYY-MM-DD`
```bash
# Correct: 2025-02-01
# Incorrect: 02/01/2025, Feb 1 2025
```

---

## Verification Checklist

After setup, verify everything is created:

```bash
# Check labels
gh label list --repo WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context.

# Check milestones
gh milestone list --repo WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context.

# Check issues
gh issue list --repo WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context. --milestone "M0: Critical Fixes"

# Should show 6 issues
```

Expected output:
```
✅ 40+ labels created
✅ 5 milestones created (M0, M1.1-M1.4)
✅ 6 Phase 0 issues created
```

---

## Next Steps

1. ✅ Complete this setup
2. ✅ Assign developers to issues
3. ✅ Start Issue #1 immediately (BLOCKING)
4. ✅ Daily standup to track progress
5. ✅ Ship Phase 0 in 2-4 weeks!

---

## Resources

- **GitHub CLI Docs:** https://cli.github.com/manual/
- **Project Board Guide:** PROJECT_BOARD.md
- **Action Plan:** ACTION_PLAN.md
- **Critical Review:** CRITICAL_REVIEW.md
- **Getting Started:** GETTING_STARTED.md

---

**Questions?** Check the documentation or ask the team lead!

**Ready to start?** Run `.github/create_issues.sh` now! 🚀
