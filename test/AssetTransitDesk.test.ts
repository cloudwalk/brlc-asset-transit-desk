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

let assetDeskFactory: Contracts.AssetTransitDesk__factory;
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
  const assetDesk = await upgrades.deployProxy(assetDeskFactory, [await tokenMock.getAddress()]);
  await assetDesk.waitForDeployment();

  const liquidityPool = await upgrades.deployProxy(
    liquidityPoolFactory,
    [await tokenMock.getAddress(), [await assetDesk.getAddress()]],
  );
  await liquidityPool.waitForDeployment();

  return { assetDesk, tokenMock, liquidityPool };
}

async function configureContracts(
  assetDesk: Contracts.AssetTransitDesk,
  tokenMock: Contracts.ERC20TokenMock,
  liquidityPool: Contracts.LiquidityPoolMock,
) {
  await assetDesk.grantRole(GRANTOR_ROLE, deployer.address);
  await assetDesk.grantRole(MANAGER_ROLE, manager.address);
  await assetDesk.grantRole(PAUSER_ROLE, pauser.address);

  await tokenMock.mint(account, BALANCE_INITIAL);
  await tokenMock.mint(liquidityPool, BALANCE_INITIAL);
  await tokenMock.mint(surplusTreasury, BALANCE_INITIAL);

  await tokenMock.connect(surplusTreasury).approve(assetDesk, BALANCE_INITIAL);
  await tokenMock.connect(account).approve(assetDesk, BALANCE_INITIAL);

  await liquidityPool.connect(deployer).grantRole(ADMIN_ROLE, assetDesk);

  await assetDesk.setLiquidityPool(liquidityPool);
  await assetDesk.setSurplusTreasury(surplusTreasury);
}

async function deployAndConfigureContracts() {
  const contracts = await deployContracts();

  await configureContracts(contracts.assetDesk, contracts.tokenMock, contracts.liquidityPool);
  return contracts;
}

describe("Contract 'AssetTransitDesk'", () => {
  before(async () => {
    [deployer, manager, account, surplusTreasury, pauser, stranger] =
     await ethers.getSigners();

    assetDeskFactory = await ethers.getContractFactory("AssetTransitDesk");
    assetDeskFactory = assetDeskFactory.connect(deployer);
    tokenMockFactory = await ethers.getContractFactory("ERC20TokenMock");
    tokenMockFactory = tokenMockFactory.connect(deployer);
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolMock");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer);
  });

  let assetDesk: Contracts.AssetTransitDesk;
  let tokenMock: Contracts.ERC20TokenMock;
  let liquidityPool: Contracts.LiquidityPoolMock;

  beforeEach(async () => {
    ({ assetDesk, tokenMock, liquidityPool } = await setUpFixture(deployAndConfigureContracts));
  });

  describe("Method 'initialize()'", () => {
    let deployedContract: Contracts.AssetTransitDesk;

    beforeEach(async () => {
      // deploying contract without configuration to test the default state
      const contracts = await setUpFixture(deployContracts);
      deployedContract = contracts.assetDesk;
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
        expect(await assetDesk.underlyingToken()).to.equal(tokenMock);
      });
    });

    describe("Should revert if", () => {
      it("called a second time", async () => {
        await expect(deployedContract.initialize(tokenMock))
          .to.be.revertedWithCustomError(deployedContract, "InvalidInitialization");
      });

      it("the provided token address is zero", async () => {
        const tx = upgrades.deployProxy(assetDeskFactory, [ADDRESS_ZERO]);
        await expect(tx)
          .to.be.revertedWithCustomError(assetDeskFactory, "AssetTransitDesk_TokenAddressZero");
      });
    });
  });

  describe("Method 'upgradeToAndCall()'", () => {
    describe("Should execute as expected when called properly and", () => {
      it("should upgrade the contract to a new implementation", async () => {
        const newImplementation = await assetDeskFactory.deploy();
        await newImplementation.waitForDeployment();

        const tx = assetDesk.upgradeToAndCall(await newImplementation.getAddress(), "0x");
        await expect(tx).to.emit(assetDesk, "Upgraded").withArgs(await newImplementation.getAddress());
      });
    });

    describe("Should revert if", () => {
      it("called with the address of an incompatible implementation", async () => {
        const tx = assetDesk.upgradeToAndCall(await tokenMock.getAddress(), "0x");
        await expect(tx)
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_ImplementationAddressInvalid");
      });

      it("called by a non-owner", async () => {
        const tx = assetDesk.connect(stranger).upgradeToAndCall(tokenMock.getAddress(), "0x");
        await expect(tx)
          .to.be.revertedWithCustomError(assetDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });
    });
  });

  describe("Method '$__VERSION()'", () => {
    it("should return the expected version", async () => {
      expect(await assetDesk.$__VERSION()).to.deep.equal([
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

      beforeEach(async () => {
        tx = await assetDesk.connect(manager).issueAsset(account.address, principalAmount);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetDesk, "AssetIssued").withArgs(account.address, principalAmount);
      });

      it("should update token balances correctly", async () => {
        await expect(tx).to.changeTokenBalances(tokenMock,
          [liquidityPool, account, surplusTreasury, assetDesk],
          [principalAmount, -principalAmount, 0, 0],
        );
      });

      it("should transfer tokens correctly", async () => {
        await checkTokenPath(tx,
          tokenMock,
          [account, assetDesk, liquidityPool],
          principalAmount,
        );
      });
    });

    describe("Should revert if", () => {
      it("called by a non-manager", async () => {
        await expect(
          assetDesk.connect(stranger).issueAsset(account.address, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, MANAGER_ROLE);
      });

      it("the principal amount is zero", async () => {
        await expect(
          assetDesk.connect(manager).issueAsset(account.address, 0n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_PrincipalAmountZero");
      });

      it("the buyer address is zero", async () => {
        await expect(
          assetDesk.connect(manager).issueAsset(ADDRESS_ZERO, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_BuyerAddressZero");
      });

      it("the contract is paused", async () => {
        await assetDesk.connect(pauser).pause();
        await expect(
          assetDesk.connect(manager).issueAsset(account.address, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "EnforcedPause");
      });
    });
  });

  describe("Method 'redeemAsset()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;
      const principalAmount = 100n;
      const netYieldAmount = 10n;

      beforeEach(async () => {
        tx = await assetDesk.connect(manager).redeemAsset(account.address, principalAmount, netYieldAmount);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetDesk, "AssetRedeemed")
          .withArgs(account.address, principalAmount, netYieldAmount);
      });

      it("should update token balances correctly", async () => {
        await expect(tx).to.changeTokenBalances(tokenMock,
          [liquidityPool, account, surplusTreasury, assetDesk],
          [-principalAmount, principalAmount + netYieldAmount, -netYieldAmount, 0],
        );
      });

      it("should transfer tokens correctly", async () => {
        await checkTokenPath(tx,
          tokenMock,
          [liquidityPool, assetDesk],
          principalAmount,
        );
        await checkTokenPath(tx,
          tokenMock,
          [surplusTreasury, assetDesk],
          netYieldAmount,
        );
        await checkTokenPath(tx,
          tokenMock,
          [assetDesk, account],
          principalAmount + netYieldAmount,
        );
      });
    });

    describe("Should revert if", () => {
      it("called by a non-manager", async () => {
        await expect(
          assetDesk.connect(stranger).redeemAsset(account.address, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, MANAGER_ROLE);
      });

      it("the principal amount is zero", async () => {
        await expect(
          assetDesk.connect(manager).redeemAsset(account.address, 0n, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_PrincipalAmountZero");
      });

      it("the net yield amount is zero", async () => {
        await expect(
          assetDesk.connect(manager).redeemAsset(account.address, 10n, 0n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_NetYieldAmountZero");
      });

      it("the buyer address is zero", async () => {
        await expect(
          assetDesk.connect(manager).redeemAsset(ADDRESS_ZERO, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_BuyerAddressZero");
      });

      it("the contract is paused", async () => {
        await assetDesk.connect(pauser).pause();
        await expect(
          assetDesk.connect(manager).redeemAsset(account.address, 10n, 10n),
        )
          .to.be.revertedWithCustomError(assetDesk, "EnforcedPause");
      });
    });
  });

  describe.only("Method 'setLiquidityPool()'", () => {
    let newLiquidityPool: Contracts.LiquidityPoolMock;

    async function getNewValidLiquidityPool() {
      const liquidityPool = await upgrades.deployProxy(
        liquidityPoolFactory,
        [await tokenMock.getAddress(), [await assetDesk.getAddress()]],
      );
      await liquidityPool.waitForDeployment();
      await liquidityPool.connect(deployer).grantRole(ADMIN_ROLE, assetDesk);
      return liquidityPool;
    }

    beforeEach(async () => {
      newLiquidityPool = await setUpFixture(getNewValidLiquidityPool);
    });

    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;

      beforeEach(async () => {
        tx = await assetDesk.setLiquidityPool(newLiquidityPool);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetDesk, "LiquidityPoolChanged").withArgs(newLiquidityPool, liquidityPool);
      });

      it("should update the liquidity pool address", async () => {
        expect(await assetDesk.getLiquidityPool()).to.equal(newLiquidityPool);
      });

      it("should grant allowance to the new liquidity pool", async () => {
        expect(await tokenMock.allowance(assetDesk, newLiquidityPool)).to.equal(ethers.MaxUint256);
      });

      it("should revoke allowance from the old liquidity pool", async () => {
        expect(await tokenMock.allowance(assetDesk, liquidityPool)).to.equal(0);
      });
    });

    describe("Should revert if", () => {
      it("called by a non-owner", async () => {
        await expect(
          assetDesk.connect(stranger).setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });

      it("the new liquidity pool address is zero", async () => {
        await expect(
          assetDesk.setLiquidityPool(ADDRESS_ZERO),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_TreasuryZero");
      });

      it("the new liquidity pool address is the same as the current liquidity pool address", async () => {
        await expect(
          assetDesk.setLiquidityPool(liquidityPool),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_TreasuryAlreadyConfigured");
      });

      it("the new liquidity pool address is not smart-contract", async () => {
        await expect(
          assetDesk.setLiquidityPool(stranger),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_LiquidityPoolAddressInvalid");
      });

      it("the new liquidity pool address is not implementing the required interface", async () => {
        await expect(
          assetDesk.setLiquidityPool(tokenMock),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_LiquidityPoolAddressInvalid");
      });

      it("the new liquidity pool token does not match the underlying token", async () => {
        await newLiquidityPool.setToken(SOME_ADDRESS);

        await expect(
          assetDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_LiquidityPoolTokenMismatch");
      });

      it("the new liquidity pool has not configured the contract required role", async () => {
        await newLiquidityPool.connect(deployer).revokeRole(ADMIN_ROLE, assetDesk);

        await expect(
          assetDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_LiquidityPoolNotAdmin");
      });

      it("the new liquidity pool is not registered as a working treasury", async () => {
        await newLiquidityPool.setWorkingTreasuries([SOME_ADDRESS]);

        await expect(
          assetDesk.setLiquidityPool(newLiquidityPool),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_LiquidityPoolNotRegisteredAsWorkingTreasury");
      });
    });
  });

  describe("Method 'setSurplusTreasury()'", () => {
    describe("Should execute as expected when called properly and", () => {
      let tx: TransactionResponse;
      let newSurplusTreasury: HardhatEthersSigner;

      beforeEach(async () => {
        newSurplusTreasury = stranger;
        await tokenMock.connect(newSurplusTreasury).approve(assetDesk.getAddress(), BALANCE_INITIAL);
        tx = await assetDesk.setSurplusTreasury(newSurplusTreasury);
      });

      it("should emit the required event", async () => {
        await expect(tx).to.emit(assetDesk, "SurplusTreasuryChanged")
          .withArgs(newSurplusTreasury, surplusTreasury.address);
      });

      it("should update the surplus treasury address", async () => {
        expect(await assetDesk.getSurplusTreasury()).to.equal(newSurplusTreasury);
      });
    });

    describe("Should revert if", () => {
      it("called by a non-owner", async () => {
        const newSurplusTreasury = stranger;
        await tokenMock.connect(newSurplusTreasury).approve(assetDesk.getAddress(), BALANCE_INITIAL);
        await expect(
          assetDesk.connect(stranger).setSurplusTreasury(stranger.address),
        )
          .to.be.revertedWithCustomError(assetDesk, "AccessControlUnauthorizedAccount")
          .withArgs(stranger.address, OWNER_ROLE);
      });

      it("the new surplus treasury address is zero", async () => {
        await expect(
          assetDesk.setSurplusTreasury(ADDRESS_ZERO),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_TreasuryZero");
      });

      it("the new surplus treasury address is the same as the current surplus treasury address", async () => {
        await expect(
          assetDesk.setSurplusTreasury(surplusTreasury.address),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_TreasuryAlreadyConfigured");
      });

      it("the new surplus treasury address has not granted the contract allowance to spend tokens", async () => {
        await expect(
          assetDesk.setSurplusTreasury(stranger.address),
        )
          .to.be.revertedWithCustomError(assetDesk, "AssetTransitDesk_TreasuryAllowanceZero");
      });
    });
  });

  describe("Snapshot scenarios", () => {
    it("simple scenario", async () => {
      await expect.startChainshot({
        name: "simple scenario",
        accounts: { deployer, manager, account, liquidityPool, surplusTreasury, pauser, stranger },
        contracts: { assetDesk },
        tokens: { brlc: tokenMock },
      });
      await assetDesk.connect(manager).issueAsset(account.address, 100n);
      await assetDesk.connect(manager).redeemAsset(account.address, 100n, 10n);
      await expect.stopChainshot();
    });
  });
});
