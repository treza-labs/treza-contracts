import { expect } from "chai";
import { ethers } from "hardhat";
import { TrezaToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("TrezaToken", function () {
  let trezaToken: TrezaToken;
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let treasury1: SignerWithAddress;
  let treasury2: SignerWithAddress;
  let teamWallet: SignerWithAddress;
  let liquidityWallet: SignerWithAddress;
  let treasuryWallet: SignerWithAddress;
  let partnershipsWallet: SignerWithAddress;
  let rndWallet: SignerWithAddress;
  let marketingWallet: SignerWithAddress;
  let timelock: SignerWithAddress;

  beforeEach(async function () {
    [owner, alice, bob, treasury1, treasury2, teamWallet, liquidityWallet, treasuryWallet, partnershipsWallet, rndWallet, marketingWallet, timelock] = await ethers.getSigners();

    const TrezaToken = await ethers.getContractFactory("TrezaToken");
    
    const constructorParams = {
      initialLiquidityWallet: liquidityWallet.address,
      teamWallet: teamWallet.address,
      treasuryWallet: treasuryWallet.address,
      partnershipsGrantsWallet: partnershipsWallet.address,
      rndWallet: rndWallet.address,
      marketingOpsWallet: marketingWallet.address,
      treasury1: treasury1.address,
      treasury2: treasury2.address,
      timelockDelay: 86400,
    };

    trezaToken = await TrezaToken.deploy(
      constructorParams,
      [owner.address], // proposers
      [owner.address]  // executors
    );

    await trezaToken.waitForDeployment();
    
    // Get the timelock controller address for owner functions
    const timelockAddress = await trezaToken.timelockController();
    timelock = await ethers.getImpersonatedSigner(timelockAddress);
    
    // Fund the timelock with ETH for transactions
    await owner.sendTransaction({
      to: timelockAddress,
      value: ethers.parseEther("10")
    });
  });

  describe("Deployment", function () {
    it("Should set the correct total supply", async function () {
      const totalSupply = await trezaToken.totalSupply();
      expect(totalSupply).to.equal(ethers.parseEther("100000000")); // 100M tokens
    });

    it("Should allocate tokens correctly", async function () {
      const totalSupply = await trezaToken.totalSupply();
      
      // Check Initial Liquidity (35%)
      const liquidityBalance = await trezaToken.balanceOf(liquidityWallet.address);
      expect(liquidityBalance).to.equal(totalSupply * 35n / 100n);
      
      // Check Team (20%)
      const teamBalance = await trezaToken.balanceOf(teamWallet.address);
      expect(teamBalance).to.equal(totalSupply * 20n / 100n);
      
      // Check Treasury (20%)
      const treasuryBalance = await trezaToken.balanceOf(treasuryWallet.address);
      expect(treasuryBalance).to.equal(totalSupply * 20n / 100n);
      
      // Check Partnerships & Grants (10%)
      const partnershipsBalance = await trezaToken.balanceOf(partnershipsWallet.address);
      expect(partnershipsBalance).to.equal(totalSupply * 10n / 100n);
      
      // Check R&D (5%)
      const rndBalance = await trezaToken.balanceOf(rndWallet.address);
      expect(rndBalance).to.equal(totalSupply * 5n / 100n);
      
      // Check Marketing & Ops (10%)
      const marketingBalance = await trezaToken.balanceOf(marketingWallet.address);
      expect(marketingBalance).to.equal(totalSupply * 10n / 100n);
    });

    it("Should set initial fee to 0% during whitelist mode", async function () {
      const currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(0); // 0% during whitelist period
    });

    it("Should exempt treasury wallets from fees", async function () {
      expect(await trezaToken.isFeeExempt(treasury1.address)).to.be.true;
      expect(await trezaToken.isFeeExempt(treasury2.address)).to.be.true;
    });
  });

  describe("Transfer Fees", function () {
    it("Should charge 0% fee during whitelist mode", async function () {
      // Enable trading but keep whitelist mode enabled
      await trezaToken.connect(timelock).setTradingEnabled(true);
      // whitelistMode is true by default
      
      const transferAmount = ethers.parseEther("1000");
      
      // Transfer from liquidityWallet (who has tokens and is whitelisted) to teamWallet (also whitelisted)
      const teamBalanceBefore = await trezaToken.balanceOf(teamWallet.address);
      
      await trezaToken.connect(liquidityWallet).transfer(teamWallet.address, transferAmount);
      
      const teamBalanceAfter = await trezaToken.balanceOf(teamWallet.address);
      const received = teamBalanceAfter - teamBalanceBefore;
      
      // Should receive the full amount (no fees during whitelist mode)
      expect(received).to.equal(transferAmount);
    });

    describe("Public Trading Fees", function () {
      beforeEach(async function () {
        // Enable trading and disable whitelist mode for testing public trading fees
        await trezaToken.connect(timelock).setTradingEnabled(true);
        await trezaToken.connect(timelock).setWhitelistMode(false);
      });

    it("Should charge 5% fee on transfers between non-exempt addresses", async function () {
      const transferAmount = ethers.parseEther("1000");
      const expectedFee = transferAmount * 5n / 100n; // 5%
      const expectedNet = transferAmount - expectedFee;
      
      // Transfer from liquidityWallet (who has tokens) to bob
      await trezaToken.connect(liquidityWallet).transfer(bob.address, transferAmount);
      
      // Check bob received the correct amount (minus fees)
      const bobBalance = await trezaToken.balanceOf(bob.address);
      expect(bobBalance).to.be.gt(expectedNet - ethers.parseEther("1")); // Allow small rounding
    });

    it("Should split fees 50/50 between treasury wallets", async function () {
      const transferAmount = ethers.parseEther("1000");
      
      const treasury1BalanceBefore = await trezaToken.balanceOf(treasury1.address);
      const treasury2BalanceBefore = await trezaToken.balanceOf(treasury2.address);
      
      await trezaToken.connect(liquidityWallet).transfer(bob.address, transferAmount);
      
      const treasury1BalanceAfter = await trezaToken.balanceOf(treasury1.address);
      const treasury2BalanceAfter = await trezaToken.balanceOf(treasury2.address);
      
      const treasury1Gain = treasury1BalanceAfter - treasury1BalanceBefore;
      const treasury2Gain = treasury2BalanceAfter - treasury2BalanceBefore;
      
      // Should be approximately equal (allowing for rounding)
      expect(treasury1Gain).to.be.approximately(treasury2Gain, ethers.parseEther("1"));
    });

    it("Should not charge fees for exempt addresses", async function () {
      const transferAmount = ethers.parseEther("1000");
      
      // First transfer some tokens to treasury1 so it can make transfers
      await trezaToken.connect(liquidityWallet).transfer(treasury1.address, transferAmount * 2n);
      
      // Transfer from treasury1 (exempt) to bob (non-exempt)
      await trezaToken.connect(treasury1).transfer(bob.address, transferAmount);
      
      // Bob should receive the full amount (no fees charged)
      const bobBalance = await trezaToken.balanceOf(bob.address);
      expect(bobBalance).to.equal(transferAmount);
    });
    });
  });

  describe("Fee Management", function () {
    it("Should allow timelock to update fee percentage", async function () {
      // Use the timelock controller as owner
      await trezaToken.connect(timelock).setFeePercentage(6);
      
      const newFee = await trezaToken.getCurrentFee();
      expect(newFee).to.equal(6);
    });

    it("Should not allow fee percentage above maximum", async function () {
      await expect(
        trezaToken.connect(timelock).setFeePercentage(15)
      ).to.be.revertedWith("Treza: fee exceeds maximum");
    });

    it("Should allow timelock to update treasury wallets", async function () {
      await trezaToken.connect(timelock).setFeeWallets(alice.address, bob.address);
      
      expect(await trezaToken.treasuryWallet1()).to.equal(alice.address);
      expect(await trezaToken.treasuryWallet2()).to.equal(bob.address);
    });
  });

  describe("Time-Based Anti-Sniper System", function () {
    beforeEach(async function () {
      // Enable trading to activate time-based anti-sniper
      await trezaToken.connect(timelock).setTradingEnabled(true);
      await trezaToken.connect(timelock).setWhitelistMode(false);
    });

    it("Should transition from 0% fee (whitelist) to 40% fee (public)", async function () {
      // First, enable trading but keep whitelist mode - should be 0% fee
      await trezaToken.connect(timelock).setTradingEnabled(true);
      await trezaToken.connect(timelock).setWhitelistMode(true); // Ensure whitelist mode is on
      
      let currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(0); // 0% during whitelist mode
      
      // Now disable whitelist mode (start public trading) - should jump to 40%
      await trezaToken.connect(timelock).setWhitelistMode(false);
      
      currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(40); // 40% in Phase 1 of public trading
    });

    it("Should start with 40% fee in Phase 1 (0-1 minute)", async function () {
      const currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(40);
    });

    it("Should have correct max wallet in Phase 1", async function () {
      const maxWallet = await trezaToken.getCurrentMaxWallet();
      const totalSupply = await trezaToken.totalSupply();
      const expectedMaxWallet = totalSupply * 10n / 10000n; // 0.10% = 10 basis points
      expect(maxWallet).to.equal(expectedMaxWallet);
    });

    it("Should prevent transfers exceeding max wallet limit", async function () {
      const maxWallet = await trezaToken.getCurrentMaxWallet();
      const excessAmount = maxWallet + ethers.parseEther("1");
      
      await expect(
        trezaToken.connect(liquidityWallet).transfer(alice.address, excessAmount)
      ).to.be.revertedWith("Treza: max wallet exceeded");
    });

    it("Should allow transfers within max wallet limit", async function () {
      const maxWallet = await trezaToken.getCurrentMaxWallet();
      const validAmount = maxWallet - ethers.parseEther("1000"); // Leave room for fees
      
      await trezaToken.connect(liquidityWallet).transfer(alice.address, validAmount);
      
      const aliceBalance = await trezaToken.balanceOf(alice.address);
      expect(aliceBalance).to.be.gt(0);
    });

    it("Should bypass max wallet limit for whitelisted addresses", async function () {
      const maxWallet = await trezaToken.getCurrentMaxWallet();
      const excessAmount = maxWallet + ethers.parseEther("1000");
      
      // Alice is not whitelisted by default, so should fail
      await expect(
        trezaToken.connect(liquidityWallet).transfer(alice.address, excessAmount)
      ).to.be.revertedWith("Treza: max wallet exceeded");
      
      // Whitelist alice
      await trezaToken.connect(timelock).setWhitelist([alice.address], true);
      
      // Now should succeed
      await trezaToken.connect(liquidityWallet).transfer(alice.address, excessAmount);
      const aliceBalance = await trezaToken.balanceOf(alice.address);
      expect(aliceBalance).to.be.gt(maxWallet);
    });

    it("Should return correct anti-sniper status", async function () {
      const status = await trezaToken.getAntiSniperStatus();
      
      expect(status._timeBasedEnabled).to.be.true;
      expect(status._currentPhase).to.equal(1); // Phase 1
      expect(status._currentFee).to.equal(40);
      expect(status._timeRemainingInPhase).to.be.gt(0);
    });

    it("Should allow disabling time-based anti-sniper", async function () {
      // Disable time-based anti-sniper
      await trezaToken.connect(timelock).setTimeBasedAntiSniper(false);
      
      // Should now use manual fee (5%) since we're not in whitelist mode
      const currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(5);
      
      // Should have no max wallet limit
      const maxWallet = await trezaToken.getCurrentMaxWallet();
      const totalSupply = await trezaToken.totalSupply();
      expect(maxWallet).to.equal(totalSupply); // 100% - no limit
    });

    it("Should allow updating anti-sniper phases", async function () {
      // Create new phase configuration
      const newPhases = [
        { duration: 30, feePercentage: 50, maxWalletPct: 5 },
        { duration: 120, feePercentage: 25, maxWalletPct: 10 },
        { duration: 180, feePercentage: 15, maxWalletPct: 15 },
        { duration: 300, feePercentage: 8, maxWalletPct: 25 }
      ];
      
      await trezaToken.connect(timelock).setAntiSniperPhases(newPhases);
      
      // Check that phases were updated
      const phase0 = await trezaToken.getAntiSniperPhase(0);
      expect(phase0.feePercentage).to.equal(50);
      expect(phase0.maxWalletPct).to.equal(5);
    });

    it("Should not allow invalid phase configurations", async function () {
      // Try to set fee too high
      const invalidPhases = [
        { duration: 60, feePercentage: 60, maxWalletPct: 10 }, // 60% > 50% max
        { duration: 240, feePercentage: 30, maxWalletPct: 15 },
        { duration: 180, feePercentage: 20, maxWalletPct: 20 },
        { duration: 420, feePercentage: 10, maxWalletPct: 30 }
      ];
      
      await expect(
        trezaToken.connect(timelock).setAntiSniperPhases(invalidPhases)
      ).to.be.revertedWith("Treza: fee too high");
    });
  });
});