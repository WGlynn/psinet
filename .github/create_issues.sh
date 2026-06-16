#!/bin/bash

# ΨNet GitHub Issues Creation Script
# This script creates all labels, milestones, and Phase 0 issues
# Prerequisites: GitHub CLI (gh) must be installed and authenticated

set -e  # Exit on error

REPO="WGlynn/-Net-PsiNet---the-Psychic-Network-for-AI-Context."

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ΨNet GitHub Project Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script will create:"
echo "  • 40+ labels (priority, phase, type, component, effort)"
echo "  • 13 milestones"
echo "  • 6 Phase 0 issues (ready to work on)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 1: Creating Labels"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Priority Labels
echo "Creating priority labels..."
gh label create "priority: critical" --repo $REPO --color "d73a4a" --description "Must fix immediately (blocking)" --force
gh label create "priority: high" --repo $REPO --color "ff6b6b" --description "Important, address soon" --force
gh label create "priority: medium" --repo $REPO --color "ffa726" --description "Normal priority" --force
gh label create "priority: low" --repo $REPO --color "66bb6a" --description "Nice to have" --force

# Phase Labels
echo "Creating phase labels..."
gh label create "phase-0: stop-gap" --repo $REPO --color "8B0000" --description "Immediate critical fixes" --force
gh label create "phase-1: foundation" --repo $REPO --color "1976d2" --description "Core infrastructure build" --force
gh label create "phase-2: validation" --repo $REPO --color "7b1fa2" --description "Testing and simulation" --force
gh label create "phase-3: launch" --repo $REPO --color "388e3c" --description "Mainnet deployment" --force

# Type Labels
echo "Creating type labels..."
gh label create "type: bug" --repo $REPO --color "d73a4a" --description "Something isn't working" --force
gh label create "type: security" --repo $REPO --color "b60205" --description "Security vulnerability" --force
gh label create "type: feature" --repo $REPO --color "0e8a16" --description "New functionality" --force
gh label create "type: infrastructure" --repo $REPO --color "1d76db" --description "DevOps/infrastructure" --force
gh label create "type: documentation" --repo $REPO --color "0075ca" --description "Documentation improvements" --force
gh label create "type: testing" --repo $REPO --color "5319e7" --description "Test coverage" --force
gh label create "type: refactor" --repo $REPO --color "fbca04" --description "Code improvement" --force

# Component Labels
echo "Creating component labels..."
gh label create "component: smart-contracts" --repo $REPO --color "c5def5" --description "Solidity contracts" --force
gh label create "component: did" --repo $REPO --color "c5def5" --description "Decentralized Identity" --force
gh label create "component: ipfs" --repo $REPO --color "c5def5" --description "IPFS integration" --force
gh label create "component: p2p" --repo $REPO --color "c5def5" --description "P2P networking" --force
gh label create "component: crdt" --repo $REPO --color "c5def5" --description "CRDT synchronization" --force
gh label create "component: crpc" --repo $REPO --color "c5def5" --description "CRPC protocol" --force
gh label create "component: economics" --repo $REPO --color "c5def5" --description "Tokenomics/economics" --force
gh label create "component: frontend" --repo $REPO --color "c5def5" --description "UI/UX" --force
gh label create "component: sdk" --repo $REPO --color "c5def5" --description "Developer SDK" --force

# Status Labels
echo "Creating status labels..."
gh label create "status: blocked" --repo $REPO --color "e99695" --description "Blocked by dependencies" --force
gh label create "status: in-review" --repo $REPO --color "fef2c0" --description "Pull request under review" --force
gh label create "status: needs-design" --repo $REPO --color "d4c5f9" --description "Requires design decision" --force
gh label create "status: needs-testing" --repo $REPO --color "c2e0c6" --description "Awaiting test coverage" --force

# Effort Labels
echo "Creating effort labels..."
gh label create "effort: xs" --repo $REPO --color "e1f5fe" --description "< 4 hours" --force
gh label create "effort: s" --repo $REPO --color "b3e5fc" --description "1-2 days" --force
gh label create "effort: m" --repo $REPO --color "81d4fa" --description "3-5 days" --force
gh label create "effort: l" --repo $REPO --color "4fc3f7" --description "1-2 weeks" --force
gh label create "effort: xl" --repo $REPO --color "29b6f6" --description "2-4 weeks" --force
gh label create "effort: xxl" --repo $REPO --color "0288d1" --description "1-3 months" --force

echo "✅ Labels created successfully!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 2: Creating Milestones"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Calculate due dates (relative to today)
TODAY=$(date +%Y-%m-%d)
TWO_WEEKS=$(date -d "+2 weeks" +%Y-%m-%d)
EIGHT_WEEKS=$(date -d "+8 weeks" +%Y-%m-%d)
SIXTEEN_WEEKS=$(date -d "+16 weeks" +%Y-%m-%d)
TWENTYFOUR_WEEKS=$(date -d "+24 weeks" +%Y-%m-%d)
TWENTYEIGHT_WEEKS=$(date -d "+28 weeks" +%Y-%m-%d)

echo "Creating Phase 0 milestone..."
gh milestone create "M0: Critical Fixes" \
    --repo $REPO \
    --due-date $TWO_WEEKS \
    --description "Complete all 5 critical stop-gap fixes. Deliverables: All fixes tested and deployed to testnet. Success: No critical vulnerabilities remain."

echo "Creating Phase 1 milestones..."
gh milestone create "M1.1: DID + IPFS" \
    --repo $REPO \
    --due-date $EIGHT_WEEKS \
    --description "Ed25519 DID implementation + IPFS integration complete. Success: 1000 DIDs can be created and resolved, documents stored on IPFS."

gh milestone create "M1.2: Context Graphs" \
    --repo $REPO \
    --due-date $SIXTEEN_WEEKS \
    --description "Context graph data structure + CRDT merging. Success: Graphs can be created, synchronized across 10 peers, and stored on IPFS."

gh milestone create "M1.3: P2P Network" \
    --repo $REPO \
    --due-date $TWENTYFOUR_WEEKS \
    --description "LibP2P integration + peer discovery. Success: 100 nodes can communicate and synchronize context."

gh milestone create "M1.4: CRPC Fixes" \
    --repo $REPO \
    --due-date $TWENTYEIGHT_WEEKS \
    --description "Pairwise comparison implementation + decentralized validators. Success: All CRPC tests pass, validators decentralized."

echo "✅ Milestones created successfully!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 3: Creating Phase 0 Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Issue #1: Cap Shapley Hyperinflation
echo "Creating Issue #1: Cap Shapley Hyperinflation..."
gh issue create --repo $REPO \
    --title "[CRITICAL] Cap Shapley coalition bonuses to prevent hyperinflation" \
    --milestone "M0: Critical Fixes" \
    --label "priority: critical" \
    --label "phase-0: stop-gap" \
    --label "type: bug" \
    --label "type: security" \
    --label "component: smart-contracts" \
    --label "component: economics" \
    --label "effort: xs" \
    --body "## Problem

The current Shapley referral implementation can mint unlimited PSI tokens through quadratic coalition bonuses. With just 1,000 users, the entire 1B PSI supply can be minted.

\`\`\`solidity
// ShapleyReferrals.sol:237
uint256 networkEffect = (size * size * 10 * 10**18) / 100;
// At size 20: 40,000 PSI per new member
// At size 100: Can mint entire supply!
\`\`\`

**Risk Level:** 🔴 CRITICAL - Can cause complete token hyperinflation

## Required Fix

Add hard caps to coalition value calculation:

\`\`\`solidity
function _calculateCoalitionValue(address[] memory coalition) internal view returns (uint256) {
    uint256 size = coalition.length;

    // Cap coalition size for rewards
    if (size > MAX_COALITION_SIZE_FOR_REWARDS) {
        size = MAX_COALITION_SIZE_FOR_REWARDS; // Set to 10
    }

    uint256 baseValue = 20 * 10**18 * size;
    uint256 depthBonus = CHAIN_DEPTH_BONUS * (size - 1);
    uint256 sizeBonus = (size / 3) * COALITION_SIZE_BONUS;

    // Cap network effect
    uint256 networkEffect = (size * size * 10 * 10**18) / 100;
    if (networkEffect > 10_000 * 10**18) {
        networkEffect = 10_000 * 10**18;
    }

    uint256 totalValue = baseValue + depthBonus + sizeBonus + networkEffect;

    // Global maximum
    if (totalValue > 50_000 * 10**18) {
        totalValue = 50_000 * 10**18;
    }

    uint256 activityMultiplier = _calculateActivityMultiplier(coalition);
    totalValue = (totalValue * activityMultiplier) / 100;

    return totalValue;
}
\`\`\`

## Testing Requirements

- [ ] Test coalition of size 50 stays under cap
- [ ] Test coalition of size 100 stays under cap
- [ ] Verify max possible reward ≤ 50,000 PSI
- [ ] Test existing functionality still works
- [ ] Gas test with max coalition size

## Files to Modify

- \`contracts/ShapleyReferrals.sol\`
- \`test/ShapleyReferrals.test.js\`

## Acceptance Criteria

- ✅ Coalition bonuses capped at 50,000 PSI max
- ✅ All existing tests pass
- ✅ New tests for caps pass
- ✅ Gas cost acceptable

**Estimated Effort:** 4 hours

**Blocking:** All other work (this is catastrophic if deployed)

**References:**
- ACTION_PLAN.md: Fix #0.1
- CRITICAL_REVIEW.md: ISSUE #9"

# Issue #2: Add Cycle Detection
echo "Creating Issue #2: Add Cycle Detection..."
gh issue create --repo $REPO \
    --title "Add cycle detection to prevent infinite loops in referral chains" \
    --milestone "M0: Critical Fixes" \
    --label "priority: critical" \
    --label "phase-0: stop-gap" \
    --label "type: bug" \
    --label "type: security" \
    --label "component: smart-contracts" \
    --label "effort: xs" \
    --body "## Problem

No validation to prevent referral cycles (A → B → C → A), which causes infinite loops in chain traversal functions.

\`\`\`solidity
// ShapleyReferrals.sol:82 - No cycle check
function joinWithReferral(address referrer) external {
    require(!users[msg.sender].exists, \"User already exists\");
    require(referrer != msg.sender, \"Cannot refer yourself\");
    // Missing: Check if referrer is in msg.sender's chain
}
\`\`\`

## Attack Scenario

1. Alice joins (no referrer)
2. Bob joins with Alice as referrer: Alice → Bob
3. Charlie joins with Bob as referrer: Alice → Bob → Charlie
4. Alice tries to join again with Charlie as referrer: Would create Alice → Bob → Charlie → Alice
5. Any chain traversal function enters infinite loop

## Required Fix

\`\`\`solidity
function joinWithReferral(address referrer) external nonReentrant {
    require(!users[msg.sender].exists, \"User already exists\");
    require(referrer != msg.sender, \"Cannot refer yourself\");

    if (referrer != address(0)) {
        require(users[referrer].exists, \"Referrer must be registered\");
        require(!_isInChain(referrer, msg.sender), \"Cycle detected\");
    }

    // ... rest of function
}

function _isInChain(address ancestor, address descendant) internal view returns (bool) {
    address current = ancestor;
    uint256 depth = 0;

    while (current != address(0) && depth < 100) {
        if (current == descendant) {
            return true;
        }
        current = users[current].referrer;
        depth++;
    }

    return false;
}
\`\`\`

## Testing Requirements

- [ ] Test A → B → C → A is rejected
- [ ] Test A → B → C → D (valid chain) works
- [ ] Test self-referral is rejected
- [ ] Test gas cost with max depth (100)
- [ ] Test edge case: A → B, then B tries to refer A

## Files to Modify

- \`contracts/ShapleyReferrals.sol\`
- \`test/ShapleyReferrals.test.js\`

## Acceptance Criteria

- ✅ Cycles are detected and rejected
- ✅ Valid chains work normally
- ✅ Gas cost reasonable (<50k gas)
- ✅ All tests pass

**Estimated Effort:** 2 hours

**References:**
- ACTION_PLAN.md: Fix #0.2
- CRITICAL_REVIEW.md: ISSUE #16"

# Issue #3: Remove Unbounded Recursion
echo "Creating Issue #3: Remove Unbounded Recursion..."
gh issue create --repo $REPO \
    --title "Replace recursive network counting with iterative BFS" \
    --milestone "M0: Critical Fixes" \
    --label "priority: critical" \
    --label "phase-0: stop-gap" \
    --label "type: bug" \
    --label "type: security" \
    --label "component: smart-contracts" \
    --label "effort: s" \
    --body "## Problem

The \`_countNetwork\` function uses unbounded recursion, which can exceed gas limits and cause DoS.

\`\`\`solidity
// ShapleyReferrals.sol:366 - UNBOUNDED RECURSION
function _countNetwork(address user) internal view returns (uint256) {
    uint256 count = 1;
    address[] memory referees = users[user].referees;

    for (uint256 i = 0; i < referees.length; i++) {
        count += _countNetwork(referees[i]); // RECURSIVE
    }

    return count;
}
\`\`\`

## Attack Scenario

1. Attacker builds network of 1,000 nodes
2. Anyone calling \`getNetworkSize()\` on attacker hits gas limit
3. Function becomes unusable for large networks

## Required Fix

Replace with iterative BFS with depth limit (see ACTION_PLAN.md for full code).

## Testing Requirements

- [ ] Test network of 10 nodes (works correctly)
- [ ] Test network of 100 nodes (works correctly)
- [ ] Test network of 1,000 nodes (doesn't exceed gas limit)
- [ ] Test network of 10,000 nodes (returns capped value)
- [ ] Test deep chain (depth 50) returns correct count
- [ ] Test wide tree (100 direct referees) returns correct count
- [ ] Gas benchmark with various network sizes

## Files to Modify

- \`contracts/ShapleyReferrals.sol\`
- \`test/ShapleyReferrals.test.js\`

## Acceptance Criteria

- ✅ No more recursion
- ✅ Gas cost predictable (<1M gas for any network)
- ✅ Returns accurate count for small networks
- ✅ Returns capped value for large networks
- ✅ All tests pass

**Estimated Effort:** 3 hours

**References:**
- ACTION_PLAN.md: Fix #0.3
- CRITICAL_REVIEW.md: ISSUE #14"

# Issue #4: Fix Reputation Time-Weighting
echo "Creating Issue #4: Fix Reputation Time-Weighting..."
gh issue create --repo $REPO \
    --title "Fix reputation time-weighting cliff at 365 days" \
    --milestone "M0: Critical Fixes" \
    --label "priority: high" \
    --label "phase-0: stop-gap" \
    --label "type: bug" \
    --label "component: smart-contracts" \
    --label "effort: xs" \
    --body "## Problem

Reputation calculation has a discontinuity at exactly 365 days, causing unfair weighting.

\`\`\`solidity
// ReputationRegistry.sol:244
uint256 timeWeight = age > 365 days ? 1 : (365 days - age) / 1 days + 1;

// Results:
// Age 364 days: weight = 2
// Age 365 days: weight = 1  <- CLIFF!
// Age 366 days: weight = 1
\`\`\`

Additionally, staked feedback with quadratic weighting can dominate entire history:
- Fresh staked: 365 × 2 = 730 weight
- Old unstaked: 1 × 1 = 1 weight
- Ratio: 730:1 (single review dominates)

## Required Fix

Smooth exponential decay with capped stake multiplier (see ACTION_PLAN.md for full code).

## Testing Requirements

- [ ] Test feedback at 364, 365, 366 days (smooth transition)
- [ ] Test feedback at 2 years (properly decayed)
- [ ] Test staked vs unstaked feedback weight ratio (<10:1)
- [ ] Test reputation with 100 feedbacks across 3 years
- [ ] Compare old vs new algorithm results

## Files to Modify

- \`contracts/erc8004/ReputationRegistry.sol\`
- \`test/ReputationRegistry.test.js\`

## Acceptance Criteria

- ✅ No cliff at 365 days
- ✅ Smooth exponential decay
- ✅ Stake multiplier capped at 1.5x
- ✅ All tests pass
- ✅ Gas cost similar to before

**Estimated Effort:** 2 hours

**References:**
- ACTION_PLAN.md: Fix #0.4
- CRITICAL_REVIEW.md: ISSUE #6"

# Issue #5: Add Circuit Breakers
echo "Creating Issue #5: Add Circuit Breakers..."
gh issue create --repo $REPO \
    --title "Implement emergency pause and daily mint limits" \
    --milestone "M0: Critical Fixes" \
    --label "priority: critical" \
    --label "phase-0: stop-gap" \
    --label "type: security" \
    --label "type: feature" \
    --label "component: smart-contracts" \
    --label "effort: xs" \
    --body "## Problem

No emergency stop mechanism if economic attack is detected. No limits on daily minting.

## Required Fix

Add emergency controls to PsiToken (see ACTION_PLAN.md for full code):

- Emergency pause function
- Daily mint limits (1M PSI/day default)
- Admin controls with proper access control

## Testing Requirements

- [ ] Test emergency pause stops all minting
- [ ] Test emergency unpause restores functionality
- [ ] Test daily limit enforcement
- [ ] Test daily limit resets after 24 hours
- [ ] Test admin can adjust daily limit
- [ ] Test non-admin cannot pause/unpause
- [ ] Test events are emitted correctly

## Files to Modify

- \`contracts/PsiToken.sol\`
- \`test/PsiToken.test.js\`

## Acceptance Criteria

- ✅ Emergency pause works
- ✅ Daily mint limit enforced
- ✅ Admin controls functional
- ✅ Access control correct
- ✅ All tests pass

**Estimated Effort:** 4 hours

**References:**
- ACTION_PLAN.md: Fix #0.5"

# Issue #6: Phase 0 Testing & Deployment
echo "Creating Issue #6: Phase 0 Testing & Deployment..."
gh issue create --repo $REPO \
    --title "Comprehensive testing and deployment of Phase 0 fixes" \
    --milestone "M0: Critical Fixes" \
    --label "priority: critical" \
    --label "phase-0: stop-gap" \
    --label "type: testing" \
    --label "effort: s" \
    --body "## Objective

Ensure all Phase 0 fixes work correctly together and are ready for deployment.

## Dependencies

Issues #1-5 must be completed first.

## Tasks

### Testing
- [ ] Run full test suite (all existing tests pass)
- [ ] Run new Phase 0 tests (all pass)
- [ ] Gas optimization tests
- [ ] Integration tests (fixes work together)
- [ ] Edge case tests
- [ ] Test coverage >95%

### Code Review
- [ ] All PRs reviewed by 2+ developers
- [ ] Security review by team lead
- [ ] Code follows style guide
- [ ] Documentation updated

### Deployment
- [ ] Deploy to local testnet
- [ ] Deploy to Sepolia testnet
- [ ] Verify contracts on Etherscan
- [ ] Test on testnet with real transactions
- [ ] Create deployment report

### Documentation
- [ ] Update CHANGELOG.md
- [ ] Update README.md if needed
- [ ] Document new constants (caps, limits)
- [ ] Create upgrade guide

## Acceptance Criteria

- ✅ All tests pass (100%)
- ✅ Test coverage >95%
- ✅ All PRs merged
- ✅ Deployed to testnet
- ✅ Documentation complete

**Estimated Effort:** 1-2 days"

echo ""
echo "✅ All Phase 0 issues created successfully!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup Complete! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. View issues: gh issue list --repo $REPO"
echo "  2. Assign developers to issues"
echo "  3. Start with Issue #1 (BLOCKING)"
echo "  4. Move issues to project board columns"
echo ""
echo "Project board: https://github.com/$REPO/projects"
echo "Issues: https://github.com/$REPO/issues"
echo ""
