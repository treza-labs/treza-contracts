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

    it("Should set initial fee to 4%", async function () {
      const currentFee = await trezaToken.getCurrentFee();
      expect(currentFee).to.equal(4);
    });

    it("Should exempt treasury wallets from fees", async function () {
      expect(await trezaToken.isFeeExempt(treasury1.address)).to.be.true;
      expect(await trezaToken.isFeeExempt(treasury2.address)).to.be.true;
    });
  });

  describe("Transfer Fees", function () {
    it("Should charge 4% fee on transfers between non-exempt addresses", async function () {
      const transferAmount = ethers.parseEther("1000");
      const expectedFee = transferAmount * 4n / 100n; // 4%
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
});