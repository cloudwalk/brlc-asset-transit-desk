/* eslint @typescript-eslint/no-unused-expressions: "off" */
import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { TransactionResponse } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { setUpFixture } from "../test-utils/common";
import * as Contracts from "../typechain-types";
import { checkTokenPath } from "../test-utils/eth";

const ADDRESS_ZERO = ethers.ZeroAddress;
const SOME_ADDRESS = "0x1234567890123456789012345678901234567890";
const BALANCE_INITIAL = 10000n;

const OWNER_ROLE = ethers.id("OWNER_ROLE");
const GRANTOR_ROLE = ethers.id("GRANTOR_ROLE");
const MANAGER_ROLE = ethers.id("MANAGER_ROLE");
const CASHBACK_OPERATOR_ROLE = ethers.id("CASHBACK_OPERATOR_ROLE");
const PAUSER_ROLE = ethers.id("PAUSER_ROLE");
const RESCUER_ROLE = ethers.id("RESCUER_ROLE");
const ADMIN_ROLE = ethers.id("ADMIN_ROLE");

let assetTransitDeskFactory: Contracts.AssetTransitDesk__factory;
let tokenMockFactory: Contracts.ERC20TokenMock__factory;
let liquidityPoolFactory: Contracts.LiquidityPoolMock__factory;

let deployer: HardhatEthersSigner; // has GRANTOR_ROLE AND OWNER_ROLE
let manager: HardhatEthersSigner; // has MANAGER_ROLE
let account: HardhatEthersSigner; // has no roles
let pauser: HardhatEthersSigner; // has PAUSER_ROLE
let surplusTreasury: HardhatEthersSigner; // has no roles
let stranger: HardhatEthersSigner; // has no roles

const EXPECTED_VERSION = {
  major: 1,
  minor: 0,
  patch: 0,
};

async function deployContracts() {
  const name = "ERC20 Test";
  const symbol = "TEST";

  const tokenMockDeployment = await tokenMockFactory.deploy(name, symbol);
  await tokenMockDeployment.waitForDeployment();

  const tokenMock = tokenMockDeployment.connect(deployer);
  const assetTransitDesk = await upgrades.deployProxy(assetTransitDeskFactory, [await tokenMock.getAddress()]);
  await assetTransitDesk.waitForDeployment();

  const liquidityPool = await upgrades.deployProxy(
    liquidityPoolFactory,
    [await tokenMock.getAddress(), [await assetTransitDesk.getAddress()]],
  );
  await liquidityPool.waitForDeployment();

  return { assetTransitDesk, tokenMock, liquidityPool };
}

async function configureContracts(
  assetTransitDesk: Contracts.AssetTransitDesk,
  tokenMock: Contracts.ERC20TokenMock,
  liquidityPool: Contracts.LiquidityPoolMock,
) {
  await assetTransitDesk.grantRole(GRANTOR_ROLE, deployer.address);
  await assetTransitDesk.grantRole(MANAGER_ROLE, manager.address);
  await assetTransitDesk.grantRole(PAUSER_ROLE, pauser.address);

  await tokenMock.mint(account, BALANCE_INITIAL);
  await tokenMock.mint(liquidityPool, BALANCE_INITIAL);
  await tokenMock.mint(surplusTreasury, BALANCE_INITIAL);

  await tokenMock.connect(surplusTreasury).approve(assetTransitDesk, BALANCE_INITIAL);
  await tokenMock.connect(account).approve(assetTransitDesk, BALANCE_INITIAL);

  await liquidityPool.connect(deployer).grantRole(ADMIN_ROLE, assetTransitDesk);

  await assetTransitDesk.approve(liquidityPool, BALANCE_INITIAL);
  await assetTransitDesk.setLiquidityPool(liquidityPool);
  await assetTransitDesk.setSurplusTreasury(surplusTreasury);
}

async function deployAndConfigureContracts() {
  const contracts = await deployContracts();

  await configureContracts(contracts.assetTransitDesk, contracts.tokenMock, contracts.liquidityPool);
  return contracts;
}

describe("Contract 'AssetTransitDesk'", () => {
  before(async () => {
    [deployer, manager, account, surplusTreasury, pauser, stranger] =
     await ethers.getSigners();

    assetTransitDeskFactory = await ethers.getContractFactory("AssetTransitDesk");
    assetTransitDeskFactory = assetTransitDeskFactory.connect(deployer);
    tokenMockFactory = await ethers.getContractFactory("ERC20TokenMock");
    tokenMockFactory = tokenMockFactory.connect(deployer);
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolMock");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer);
  });

  let assetTransitDesk: Contracts.AssetTransitDesk;
  let tokenMock: Contracts.ERC20TokenMock;
  let liquidityPool: Contracts.LiquidityPoolMock;

  beforeEach(async () => {
    ({ assetTransitDesk, tokenMock, liquidityPool } = await setUpFixture(deployAndConfigureContracts));
  });

  describe("Method 'initialize()'", () => {
    let deployedContract: Contracts.AssetTransitDesk;

    beforeEach(async () => {
      // deploying contract without configuration to test the default state
      const contracts = await setUpFixture(deployContracts);
      deployedContract = contracts.assetTransitDesk;
    });

    describe("Should execute as expected when called properly and", () => {
      it("should expose correct role hashes", async () => {
        expect(await deployedContract.OWNER_ROLE()).to.equal(OWNER_ROLE);
        expect(await deployedContract.GRANTOR_ROLE()).to.equal(GRANTOR_ROLE);
        expect(await deployedContract.PAUSER_ROLE()).to.equal(PAUSER_ROLE);
        expect(await deployedContract.RESCUER_ROLE()).to.equal(RESCUER_ROLE);
        expect(await deployedContract.MANAGER_ROLE()).to.equal(MANAGER_ROLE);
      });

      it("should set correct role admins", async () => {
        expect(await deployedContract.getRoleAdmin(OWNER_ROLE)).to.equal(OWNER_ROLE);
        expect(await deployedContract.getRoleAdmin(GRANTOR_ROLE)).to.equal(OWNER_ROLE);
        expect(await deployedContract.getRoleAdmin(PAUSER_ROLE)).to.equal(GRANTOR_ROLE);
        expect(await deployedContract.getRoleAdmin(RESCUER_ROLE)).to.equal(GRANTOR_ROLE);
        expect(await deployedContract.getRoleAdmin(MANAGER_ROLE)).to.equal(GRANTOR_ROLE);
      });

      it("should set correct roles for the deployer", async () => {
        expect(await deployedContract.hasRole(OWNER_ROLE, deployer)).to.be.true;
        expect(await deployedContract.hasRole(GRANTOR_ROLE, deployer)).to.be.false;
        expect(await deployedContract.hasRole(PAUSER_ROLE, deployer)).to.be.false;
        expect(await deployedContract.hasRole(RESCUER_ROLE, deployer)).to.be.false;
        expect(await deployedContract.hasRole(MANAGER_ROLE, deployer)).to.be.false;
        expect(await deployedContract.hasRole(CASHBACK_OPERATOR_ROLE, deployer)).to.be.false;
      });

      it("should not pause the contract", async () => {
        expect(await deployedContract.paused()).to.equal(false);
      });

      it("should set correct underlying token address", async () => {
        expect(await assetTransitDesk.underlyingToken()).to.equal(tokenMock);
      });
    });

    describe("Should revert if", () => {
      it("called a second time", async () => {
        await expect(deployedContract.initialize(tokenMock))
          .to.be.revertedWithCustomError(deployedContract, "InvalidInitialization");
      });

      it("the provided token address is zero", async () => {
        const tx = upgrades.deployProxy(assetTransitDeskFactory, [ADDRESS_ZERO]);
        await expect(tx)
          .to.be.revertedWithCustomError(assetTransitDeskFactory, "AssetTransitDesk_TokenAddressZero");
      });
    });
  });

  describe("Method 'upgradeToAndCall()'", () => {
    describe("Should execute as expected when called properly and", () => {
      it("should upgrade the contract to a new implementation", async () => {
        const newImplementation = await assetTransitDeskFactory.deploy();
        await newImplementation.waitForDeployment();

        const tx = assetTransitDesk.upgradeToAndCall(await newImplementation.getAddress(), "0x");
        await expect(tx).to.emit(assetTransitDesk, "Upgraded").withArgs(await newImplementation.getAddress());
      });
    });

    describe("Should revert if", () => {
      it("called with the address of an incompatible implementation", async () => {
        const tx = assetTransitDesk.upgradeToAndCall(await tokenMock.getAddress(), "0x");
        await expect(tx)
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_ImplementationAddressInvalid");
      });

      it("called by a non-owner", async () => {
        const tx = assetTransitDesk.connect(stranger).upgradeToAndCall(tokenMock.getAddress(), "0x");
        await expect(tx)
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });
    });
  });

  describe("Method '$__VERSION()'", () => {
    it("should return the expected version", async () => {
      expect(await assetTransitDesk.$__VERSION()).to.deep.equal([
        EXPECTED_VERSION.major,
        EXPECTED_VERSION.minor,
        EXPECTED_VERSION.patch,
      ]);
    });
  });

  describe("Method 'issueAsset()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;
      const principalAmount = 100n;
      const assetDepositId = ethers.encodeBytes32String("assetDepositId");

      beforeEach(async () => {
        tx = await assetTransitDesk.connect(manager).issueAsset(
          assetDepositId,
          account.address, principalAmount,
        );
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetTransitDesk, "AssetIssued").withArgs(
          assetDepositId,
          account.address,
          principalAmount,
        );
      });

      it("should update token balances correctly", async () => {
        await expect(tx).to.changeTokenBalances(tokenMock,
          [liquidityPool, account, surplusTreasury, assetTransitDesk],
          [principalAmount, -principalAmount, 0, 0],
        );
      });

      it("should transfer tokens correctly", async () => {
        await checkTokenPath(tx,
          tokenMock,
          [account, assetTransitDesk, liquidityPool],
          principalAmount,
        );
      });
    });

    describe("Should revert if", () => {
      const assetDepositId = ethers.encodeBytes32String("assetDepositId");
      it("called by a non-manager", async () => {
        await expect(
          assetTransitDesk.connect(stranger).issueAsset(assetDepositId, account.address, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, MANAGER_ROLE);
      });

      it("the principal amount is zero", async () => {
        await expect(
          assetTransitDesk.connect(manager).issueAsset(assetDepositId, account.address, 0n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_PrincipalAmountZero");
      });

      it("the buyer address is zero", async () => {
        await expect(
          assetTransitDesk.connect(manager).issueAsset(assetDepositId, ADDRESS_ZERO, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_BuyerAddressZero");
      });

      it("the contract is paused", async () => {
        await assetTransitDesk.connect(pauser).pause();
        await expect(
          assetTransitDesk.connect(manager).issueAsset(assetDepositId, account.address, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "EnforcedPause");
      });
    });
  });

  describe("Method 'redeemAsset()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;
      const principalAmount = 100n;
      const netYieldAmount = 10n;
      const assetRedemptionId = ethers.encodeBytes32String("assetRedemptionId");

      beforeEach(async () => {
        tx = await assetTransitDesk.connect(manager).redeemAsset(
          assetRedemptionId,
          account.address,
          principalAmount,
          netYieldAmount,
        );
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetTransitDesk, "AssetRedeemed")
          .withArgs(assetRedemptionId, account.address, principalAmount, netYieldAmount);
      });

      it("should update token balances correctly", async () => {
        await expect(tx).to.changeTokenBalances(tokenMock,
          [liquidityPool, account, surplusTreasury, assetTransitDesk],
          [-principalAmount, principalAmount + netYieldAmount, -netYieldAmount, 0],
        );
      });

      it("should transfer tokens correctly", async () => {
        await checkTokenPath(tx,
          tokenMock,
          [liquidityPool, assetTransitDesk],
          principalAmount,
        );
        await checkTokenPath(tx,
          tokenMock,
          [surplusTreasury, assetTransitDesk],
          netYieldAmount,
        );
        await checkTokenPath(tx,
          tokenMock,
          [assetTransitDesk, account],
          principalAmount + netYieldAmount,
        );
      });
    });

    describe("Should revert if", () => {
      const assetRedemptionId = ethers.encodeBytes32String("assetRedemptionId");
      it("called by a non-manager", async () => {
        await expect(
          assetTransitDesk.connect(stranger).redeemAsset(assetRedemptionId, account.address, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, MANAGER_ROLE);
      });

      it("the principal amount is zero", async () => {
        await expect(
          assetTransitDesk.connect(manager).redeemAsset(assetRedemptionId, account.address, 0n, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_PrincipalAmountZero");
      });

      it("the net yield amount is zero", async () => {
        await expect(
          assetTransitDesk.connect(manager).redeemAsset(assetRedemptionId, account.address, 10n, 0n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_NetYieldAmountZero");
      });

      it("the buyer address is zero", async () => {
        await expect(
          assetTransitDesk.connect(manager).redeemAsset(assetRedemptionId, ADDRESS_ZERO, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_BuyerAddressZero");
      });

      it("the contract is paused", async () => {
        await assetTransitDesk.connect(pauser).pause();
        await expect(
          assetTransitDesk.connect(manager).redeemAsset(assetRedemptionId, account.address, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "EnforcedPause");
      });
    });
  });

  describe("Method 'setLiquidityPool()'", () => {
    let newLiquidityPool: Contracts.LiquidityPoolMock;

    async function getNewValidLiquidityPool() {
      const liquidityPool = await upgrades.deployProxy(
        liquidityPoolFactory,
        [await tokenMock.getAddress(), [await assetTransitDesk.getAddress()]],
      );
      await liquidityPool.waitForDeployment();
      await liquidityPool.connect(deployer).grantRole(ADMIN_ROLE, assetTransitDesk);
      return liquidityPool;
    }

    beforeEach(async () => {
      newLiquidityPool = await setUpFixture(getNewValidLiquidityPool);
    });

    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;

      beforeEach(async () => {
        tx = await assetTransitDesk.setLiquidityPool(newLiquidityPool);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetTransitDesk, "LiquidityPoolChanged").withArgs(newLiquidityPool, liquidityPool);
      });

      it("should update the liquidity pool address", async () => {
        expect(await assetTransitDesk.getLiquidityPool()).to.equal(newLiquidityPool);
      });
    });

    describe("Should revert if", () => {
      it("called by a non-owner", async () => {
        await expect(
          assetTransitDesk.connect(stranger).setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });

      it("the new liquidity pool address is zero", async () => {
        await expect(
          assetTransitDesk.setLiquidityPool(ADDRESS_ZERO),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_TreasuryAddressZero");
      });

      it("the new liquidity pool address is the same as the current liquidity pool address", async () => {
        await expect(
          assetTransitDesk.setLiquidityPool(liquidityPool),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_TreasuryAlreadyConfigured");
      });

      it("the new liquidity pool address is not smart-contract", async () => {
        await expect(
          assetTransitDesk.setLiquidityPool(stranger),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_LiquidityPoolAddressInvalid");
      });

      it("the new liquidity pool address is not implementing the required interface", async () => {
        await expect(
          assetTransitDesk.setLiquidityPool(tokenMock),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_LiquidityPoolAddressInvalid");
      });

      it("the new liquidity pool token does not match the underlying token", async () => {
        await newLiquidityPool.setToken(SOME_ADDRESS);

        await expect(
          assetTransitDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_LiquidityPoolTokenMismatch");
      });

      it("the new liquidity pool has not configured the contract required role", async () => {
        await newLiquidityPool.connect(deployer).revokeRole(ADMIN_ROLE, assetTransitDesk);

        await expect(
          assetTransitDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_LiquidityPoolNotAdmin");
      });

      it("the new liquidity pool is not registered as a working treasury", async () => {
        await newLiquidityPool.setWorkingTreasuries([SOME_ADDRESS]);

        await expect(
          assetTransitDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(
            assetTransitDesk,
            "AssetTransitDesk_ContractNotRegisteredAsWorkingTreasury",
          );
      });
    });
  });

  describe("Method 'setSurplusTreasury()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;
      let newSurplusTreasury: HardhatEthersSigner;

      beforeEach(async () => {
        newSurplusTreasury = stranger;
        await tokenMock.connect(newSurplusTreasury).approve(assetTransitDesk.getAddress(), BALANCE_INITIAL);
        tx = await assetTransitDesk.setSurplusTreasury(newSurplusTreasury);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetTransitDesk, "SurplusTreasuryChanged")
          .withArgs(newSurplusTreasury, surplusTreasury.address);
      });

      it("should update the surplus treasury address", async () => {
        expect(await assetTransitDesk.getSurplusTreasury()).to.equal(newSurplusTreasury);
      });
    });

    describe("Should revert if", () => {
      it("called by a non-owner", async () => {
        const newSurplusTreasury = stranger;
        await tokenMock.connect(newSurplusTreasury).approve(assetTransitDesk.getAddress(), BALANCE_INITIAL);
        await expect(
          assetTransitDesk.connect(stranger).setSurplusTreasury(stranger.address),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });

      it("the new surplus treasury address is zero", async () => {
        await expect(
          assetTransitDesk.setSurplusTreasury(ADDRESS_ZERO),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_TreasuryAddressZero");
      });

      it("the new surplus treasury address is the same as the current surplus treasury address", async () => {
        await expect(
          assetTransitDesk.setSurplusTreasury(surplusTreasury.address),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_TreasuryAlreadyConfigured");
      });

      it("the new surplus treasury address has not granted the contract allowance to spend tokens", async () => {
        await expect(
          assetTransitDesk.setSurplusTreasury(stranger.address),
        )
          .to.be.revertedWithCustomError(assetTransitDesk, "AssetTransitDesk_TreasuryAllowanceZero");
      });
    });
  });

  describe("Method 'approve()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;

      beforeEach(async () => {
        tx = await assetTransitDesk.approve(liquidityPool, BALANCE_INITIAL);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(tokenMock, "Approval").withArgs(assetTransitDesk, liquidityPool, BALANCE_INITIAL);
      });

      it("should update the allowance", async () => {
        expect(await tokenMock.allowance(assetTransitDesk, liquidityPool)).to.equal(BALANCE_INITIAL);
      });
    });

    describe("Should revert if", () => {
      it("called by a non-owner", async () => {
        await expect(assetTransitDesk.connect(stranger).approve(liquidityPool, BALANCE_INITIAL))
          .to.be.revertedWithCustomError(assetTransitDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });
    });
  });

  describe("Snapshot scenarios", () => {
    it("Simple usage scenario", async () => {
      await expect.startChainshot({
        name: "Usage example",
        accounts: { deployer, manager, account, surplusTreasury, pauser, stranger },
        contracts: { assetTransitDesk, LP: liquidityPool },
        tokens: { BRLC: tokenMock },
      });

      await assetTransitDesk.connect(manager).issueAsset(
        ethers.encodeBytes32String("issue-id"),
        account.address,
        100n,
      );
      await assetTransitDesk.connect(manager).redeemAsset(
        ethers.encodeBytes32String("redeem-id"),
        account.address,
        100n,
        10n,
      );
      await expect.stopChainshot();
    });

    it("Configuration scenario", async () => {
      const { assetTransitDesk, tokenMock, liquidityPool } = await deployContracts();

      await expect.startChainshot({
        name: "Configuration",
        accounts: { deployer, manager, account, surplusTreasury },
        contracts: { assetTransitDesk: assetTransitDesk, LP: liquidityPool },
        tokens: { BRLC: tokenMock },
      });

      await liquidityPool.grantRole(ADMIN_ROLE, assetTransitDesk);
      await liquidityPool.setWorkingTreasuries([assetTransitDesk]);
      await tokenMock.connect(surplusTreasury).approve(assetTransitDesk, BALANCE_INITIAL);
      await assetTransitDesk.approve(liquidityPool, BALANCE_INITIAL);
      await assetTransitDesk.setLiquidityPool(liquidityPool);
      await assetTransitDesk.setSurplusTreasury(surplusTreasury);

      await expect.stopChainshot();
    });
  });
});
