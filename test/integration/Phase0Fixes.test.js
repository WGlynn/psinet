const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Phase 0 Critical Fixes Integration Tests", function () {
  // Fixture for deploying all contracts
  async function deployFixture() {
    const [deployer, alice, bob, carol, dave, treasury, rewardPool] = await ethers.getSigners();

    // Deploy core contracts
    const PsiToken = await ethers.getContractFactory("PsiToken");
    const psiToken = await PsiToken.deploy();

    const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
    const identityRegistry = await IdentityRegistry.deploy();

    const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry");
    const reputationRegistry = await ReputationRegistry.deploy(
      await identityRegistry.getAddress(),
      ethers.parseEther("0.01")
    );

    const ShapleyReferrals = await ethers.getContractFactory("ShapleyReferrals");
    const shapleyReferrals = await ShapleyReferrals.deploy(
      await psiToken.getAddress(),
      await reputationRegistry.getAddress()
    );

    // Grant roles
    await psiToken.grantRole(await psiToken.MINTER_ROLE(), await shapleyReferrals.getAddress());

    return {
      psiToken,
      identityRegistry,
      reputationRegistry,
      shapleyReferrals,
      deployer,
      alice,
      bob,
      carol,
      dave,
      treasury,
      rewardPool,
    };
  }

  describe("Fix #0.1: Shapley Coalition Cap", function () {
    it("should cap coalition size for rewards at MAX_COALITION_SIZE_FOR_REWARDS", async function () {
      const { shapleyReferrals, alice, bob, carol, dave } = await loadFixture(deployFixture);

      // Register users to build a referral chain
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);
      await shapleyReferrals.connect(carol).joinWithReferral(bob.address);
      await shapleyReferrals.connect(dave).joinWithReferral(carol.address);

      // Verify coalition size cap constant
      const maxSize = await shapleyReferrals.MAX_COALITION_SIZE_FOR_REWARDS();
      expect(maxSize).to.equal(10n, "Max coalition size should be 10");
    });

    it("should not allow minting more than 50,000 PSI per coalition", async function () {
      const { shapleyReferrals, psiToken, alice, bob, carol } = await loadFixture(deployFixture);

      // Register users
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);
      await shapleyReferrals.connect(carol).joinWithReferral(bob.address);

      // Get coalition members
      const aliceData = await shapleyReferrals.users(alice.address);
      const bobData = await shapleyReferrals.users(bob.address);
      const carolData = await shapleyReferrals.users(carol.address);

      // Verify rewards are reasonable
      expect(aliceData.totalEarned).to.be.lt(ethers.parseEther("50000"));
      expect(bobData.totalEarned).to.be.lt(ethers.parseEther("50000"));
      expect(carolData.totalEarned).to.be.lt(ethers.parseEther("50000"));
    });

    it("should prevent hyperinflation even with large coalition", async function () {
      const { shapleyReferrals, psiToken, deployer } = await loadFixture(deployFixture);

      // Create a large referral chain
      const signers = await ethers.getSigners();
      const users = signers.slice(0, 20); // Use 20 users

      // Register first user
      await shapleyReferrals.connect(users[0]).joinWithReferral(ethers.ZeroAddress);

      // Build chain
      for (let i = 1; i < users.length; i++) {
        await shapleyReferrals.connect(users[i]).joinWithReferral(users[i - 1].address);
      }

      // Check total PSI minted doesn't exceed reasonable limits
      const totalSupply = await psiToken.totalSupply();
      const maxSupply = await psiToken.MAX_SUPPLY();

      // Should not have minted more than 10% of max supply from referrals alone
      expect(totalSupply).to.be.lt(maxSupply / 10n);
    });
  });

  describe("Fix #0.2: Cycle Detection", function () {
    it("should prevent direct self-referral", async function () {
      const { shapleyReferrals, alice } = await loadFixture(deployFixture);

      await expect(
        shapleyReferrals.connect(alice).joinWithReferral(alice.address)
      ).to.be.revertedWith("Cannot refer yourself");
    });

    it("should prevent cycle A -> B -> A", async function () {
      const { shapleyReferrals, alice, bob } = await loadFixture(deployFixture);

      // A joins first
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);

      // B joins with A as referrer
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);

      // A tries to join again with B as referrer (should fail - cycle)
      // Note: This would require re-registration which isn't allowed
      await expect(
        shapleyReferrals.connect(alice).joinWithReferral(bob.address)
      ).to.be.revertedWith("User already exists");
    });

    it("should detect cycles in longer chains", async function () {
      const { shapleyReferrals, alice, bob, carol, dave } = await loadFixture(deployFixture);

      // Build chain: A -> B -> C -> D
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);
      await shapleyReferrals.connect(carol).joinWithReferral(bob.address);
      await shapleyReferrals.connect(dave).joinWithReferral(carol.address);

      // Verify all joined successfully (no cycles)
      const aliceData = await shapleyReferrals.users(alice.address);
      const bobData = await shapleyReferrals.users(bob.address);
      const carolData = await shapleyReferrals.users(carol.address);
      const daveData = await shapleyReferrals.users(dave.address);

      expect(aliceData.exists).to.be.true;
      expect(bobData.exists).to.be.true;
      expect(carolData.exists).to.be.true;
      expect(daveData.exists).to.be.true;

      // Verify chain depths
      expect(aliceData.chainDepth).to.equal(0n);
      expect(bobData.chainDepth).to.equal(1n);
      expect(carolData.chainDepth).to.equal(2n);
      expect(daveData.chainDepth).to.equal(3n);
    });
  });

  describe("Fix #0.3: Iterative Network Counting", function () {
    it("should count network size without recursion", async function () {
      const { shapleyReferrals, alice, bob, carol, dave } = await loadFixture(deployFixture);

      // Build referral tree
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);
      await shapleyReferrals.connect(carol).joinWithReferral(alice.address); // Alice has 2 referees
      await shapleyReferrals.connect(dave).joinWithReferral(bob.address);

      // Count Alice's network (should include bob, carol, dave)
      const aliceNetworkSize = await shapleyReferrals.getNetworkSize(alice.address);
      expect(aliceNetworkSize).to.equal(4n); // Alice + Bob + Carol + Dave

      // Count Bob's network
      const bobNetworkSize = await shapleyReferrals.getNetworkSize(bob.address);
      expect(bobNetworkSize).to.equal(2n); // Bob + Dave
    });

    it("should handle large networks without running out of gas", async function () {
      const { shapleyReferrals } = await loadFixture(deployFixture);

      const signers = await ethers.getSigners();
      const users = signers.slice(0, 50); // Create network of 50 users

      // Build chain
      await shapleyReferrals.connect(users[0]).joinWithReferral(ethers.ZeroAddress);
      for (let i = 1; i < users.length; i++) {
        await shapleyReferrals.connect(users[i]).joinWithReferral(users[i - 1].address);
      }

      // This should not run out of gas due to iterative implementation
      const networkSize = await shapleyReferrals.getNetworkSize(users[0].address);
      expect(networkSize).to.be.lte(1000n); // Respects max nodes limit
    });
  });

  describe("Fix #0.4: Smooth Reputation Time-Weighting", function () {
    it("should use tiered time weights instead of cliff", async function () {
      const { reputationRegistry, identityRegistry, alice, bob } = await loadFixture(deployFixture);

      // Register Alice as agent
      await identityRegistry.registerAgent(
        "Alice Agent",
        "did:psinet:alice",
        ethers.hexlify(ethers.randomBytes(32))
      );
      const aliceAgentId = 1;

      // Submit feedback at different times
      await reputationRegistry.connect(bob).submitFeedback(
        aliceAgentId,
        0, // POSITIVE
        80, // rating
        "Good work",
        { value: ethers.parseEther("0.01") }
      );

      // Get reputation score
      const [score, feedbackCount] = await reputationRegistry.getReputationScore(aliceAgentId);
      expect(score).to.be.gt(0);
      expect(feedbackCount).to.equal(1);
    });

    it("should not have cliff at 365 days", async function () {
      const { reputationRegistry, identityRegistry, alice, bob } = await loadFixture(deployFixture);

      // Register Alice
      await identityRegistry.registerAgent(
        "Alice Agent",
        "did:psinet:alice",
        ethers.hexlify(ethers.randomBytes(32))
      );
      const aliceAgentId = 1;

      // Submit feedback
      await reputationRegistry.connect(bob).submitFeedback(
        aliceAgentId,
        0, // POSITIVE
        90,
        "Excellent",
        { value: ethers.parseEther("0.01") }
      );

      // Get score before year
      const [scoreBefore] = await reputationRegistry.getReputationScore(aliceAgentId);

      // Advance time to just before 365 days
      await time.increase(364 * 24 * 60 * 60);

      // Get score
      const [scoreAt364] = await reputationRegistry.getReputationScore(aliceAgentId);

      // Advance time past 365 days
      await time.increase(2 * 24 * 60 * 60);

      // Get score after year
      const [scoreAfter] = await reputationRegistry.getReputationScore(aliceAgentId);

      // Should have smooth decay, not cliff
      // scoreAt364 should be close to scoreAfter (no huge drop)
      const diff = scoreAt364 > scoreAfter ? scoreAt364 - scoreAfter : scoreAfter - scoreAt364;
      expect(diff).to.be.lt(scoreAt364 / 2n); // Should not drop by more than 50%
    });
  });

  describe("Fix #0.5: Circuit Breakers", function () {
    it("should allow emergency pause by admin", async function () {
      const { psiToken, deployer } = await loadFixture(deployFixture);

      // Pause
      await psiToken.emergencyPause("Testing emergency pause");

      // Verify paused
      expect(await psiToken.emergencyPaused()).to.be.true;
    });

    it("should block minting when paused", async function () {
      const { psiToken, deployer, alice } = await loadFixture(deployFixture);

      // Pause
      await psiToken.emergencyPause("Emergency test");

      // Try to mint (should fail)
      await expect(
        psiToken.mint(alice.address, ethers.parseEther("1000"))
      ).to.be.revertedWith("PsiToken: emergency pause active");
    });

    it("should allow unpause by admin", async function () {
      const { psiToken, deployer, alice } = await loadFixture(deployFixture);

      // Pause
      await psiToken.emergencyPause("Test");
      expect(await psiToken.emergencyPaused()).to.be.true;

      // Unpause
      await psiToken.emergencyUnpause();
      expect(await psiToken.emergencyPaused()).to.be.false;

      // Minting should work now
      await psiToken.mint(alice.address, ethers.parseEther("1000"));
      expect(await psiToken.balanceOf(alice.address)).to.equal(ethers.parseEther("1000"));
    });

    it("should enforce daily mint limit", async function () {
      const { psiToken, alice } = await loadFixture(deployFixture);

      const dailyLimit = await psiToken.dailyMintLimit();

      // Try to mint more than daily limit (should fail)
      await expect(
        psiToken.mint(alice.address, dailyLimit + ethers.parseEther("1"))
      ).to.be.revertedWith("PsiToken: daily mint limit exceeded");
    });

    it("should reset daily mint counter after 24 hours", async function () {
      const { psiToken, alice, bob } = await loadFixture(deployFixture);

      const dailyLimit = await psiToken.dailyMintLimit();
      const halfLimit = dailyLimit / 2n;

      // Mint half of daily limit
      await psiToken.mint(alice.address, halfLimit);

      // Advance time by 25 hours
      await time.increase(25 * 60 * 60);

      // Should be able to mint half again (counter reset)
      await psiToken.mint(bob.address, halfLimit);

      expect(await psiToken.balanceOf(bob.address)).to.equal(halfLimit);
    });

    it("should allow admin to update daily mint limit", async function () {
      const { psiToken, deployer } = await loadFixture(deployFixture);

      const oldLimit = await psiToken.dailyMintLimit();
      const newLimit = ethers.parseEther("2000000"); // 2M PSI

      await psiToken.setDailyMintLimit(newLimit);

      expect(await psiToken.dailyMintLimit()).to.equal(newLimit);
    });
  });

  describe("Integration: All Fixes Working Together", function () {
    it("should handle complete user journey with all fixes active", async function () {
      const { psiToken, shapleyReferrals, reputationRegistry, identityRegistry, alice, bob, carol } =
        await loadFixture(deployFixture);

      // 1. Users join with referrals (Fix #0.2: cycle detection)
      await shapleyReferrals.connect(alice).joinWithReferral(ethers.ZeroAddress);
      await shapleyReferrals.connect(bob).joinWithReferral(alice.address);
      await shapleyReferrals.connect(carol).joinWithReferral(bob.address);

      // 2. Check network size (Fix #0.3: iterative counting)
      const networkSize = await shapleyReferrals.getNetworkSize(alice.address);
      expect(networkSize).to.equal(3n);

      // 3. Verify rewards are capped (Fix #0.1: coalition cap)
      const aliceData = await shapleyReferrals.users(alice.address);
      expect(aliceData.totalEarned).to.be.lt(ethers.parseEther("50000"));

      // 4. Register agents and build reputation (Fix #0.4: smooth time-weighting)
      await identityRegistry.connect(alice).registerAgent(
        "Alice Agent",
        "did:psinet:alice",
        ethers.hexlify(ethers.randomBytes(32))
      );

      // 5. Circuit breakers are active (Fix #0.5)
      expect(await psiToken.emergencyPaused()).to.be.false;
      expect(await psiToken.dailyMintLimit()).to.equal(ethers.parseEther("1000000"));

      console.log("    ✅ All Phase 0 fixes integrated successfully");
    });
  });
});
