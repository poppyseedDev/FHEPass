import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";
import type { FhevmInstance } from "fhevmjs";

import type { Diploma, EmployerClaim, IdMapping, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEmployerClaimFixture } from "./fixture/EmployerClaim.fixture";

/**
 * Utility function to convert a bigint value to a 256-bit byte array
 * @param value - The bigint value to convert
 * @returns A Uint8Array representing the 256-bit byte array
 */
export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

/**
 * Integration test suite for PassportID and EmployerClaim contracts
 * Tests the core functionality of diploma registration, verification and claim generation
 */
describe("PassportID and EmployerClaim Contracts", function () {
  let passportID: PassportID;
  let employerClaim: EmployerClaim;
  let diplomaID: Diploma;
  let idMapping: IdMapping;

  /**
   * Initialize test signers before running any tests
   * Sets up alice and other signers that will be used across test cases
   */
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  /**
   * Deploy fresh contract instances before each test
   * Sets up clean state with new PassportID, EmployerClaim, Diploma and IdMapping contracts
   */
  beforeEach(async function () {
    const deployment = await deployEmployerClaimFixture();
    employerClaim = deployment.employerClaim;
    passportID = deployment.passportID;
    diplomaID = deployment.diploma;
    idMapping = deployment.idMapping;

    this.employerClaimAddress = await employerClaim.getAddress();
    this.diplomaAddress = await diplomaID.getAddress();
    this.passportIDAddress = await passportID.getAddress();
    this.idMappingAddress = await idMapping.getAddress();

    this.instances = await createInstances(this.signers);
  });

  /**
   * Helper function to register a diploma for a user
   */
  async function registerDiploma(
    userId: bigint,
    instance: FhevmInstance,
    diplomaAddress: string,
    signer: HardhatEthersSigner,
    university = 8,
    degree = 8,
    grade = 8,
  ) {
    const input = instance.createEncryptedInput(diplomaAddress, signer.address);
    const encryptedData = input.add8(university).add8(degree).add8(grade).encrypt();

    await diplomaID
      .connect(signer)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );
  }

  /**
   * Helper function to setup reencryption
   */
  async function setupReencryption(instance: FhevmInstance, signer: HardhatEthersSigner, contractAddress: string) {
    const { publicKey, privateKey } = instance.generateKeypair();
    const eip712 = instance.createEIP712(publicKey, contractAddress);
    const signature = await signer.signTypedData(eip712.domain, { Reencrypt: eip712.types.Reencrypt }, eip712.message);

    return { publicKey, privateKey, signature: signature.replace("0x", "") };
  }

  /**
   * Helper function to register identity
   */
  async function registerIdentity(
    userId: bigint,
    instance: FhevmInstance,
    passportAddress: string,
    signer: HardhatEthersSigner,
  ) {
    const identityInput = instance.createEncryptedInput(passportAddress, signer.address);
    const identityEncryptedData = identityInput.add8(8).add8(8).add8(8).add64(1234).encrypt();

    await passportID
      .connect(signer)
      .registerIdentity(
        userId,
        identityEncryptedData.handles[0],
        identityEncryptedData.handles[1],
        identityEncryptedData.handles[2],
        identityEncryptedData.handles[3],
        identityEncryptedData.inputProof,
      );
  }

  it("should register an identity successfully", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice);

    expect(await diplomaID.registered(userId));
  });

  it("should prevent duplicate registration for the same user", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice);

    await expect(
      registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice),
    ).to.be.revertedWithCustomError(diplomaID, "DiplomaAlreadyRegistered");
  });

  it("should retrieve the registered identity", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice);

    const universityHandleAlice = await diplomaID.getMyUniversity(userId);

    const { publicKey, privateKey, signature } = await setupReencryption(
      this.instances.alice,
      this.signers.alice,
      this.diplomaAddress,
    );

    // Decrypt and verify university data
    const reencryptedFirstname = await this.instances.alice.reencrypt(
      universityHandleAlice,
      privateKey,
      publicKey,
      signature,
      this.diplomaAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(8);
  });

  it("should generate an degree claim", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice, 8, 8, 8);

    const tx = await diplomaID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateDegreeClaim(uint256,address)");

    await expect(tx).to.emit(employerClaim, "DegreeClaimGenerated");

    const latestClaimUserId = await employerClaim.lastClaimId();
    const adultsClaim = await employerClaim.getDegreeClaim(latestClaimUserId);

    const { publicKey, privateKey, signature } = await setupReencryption(
      this.instances.alice,
      this.signers.alice,
      this.employerClaimAddress,
    );

    // Decrypt and verify claim result
    const reencryptedFirstname = await this.instances.alice.reencrypt(
      adultsClaim,
      privateKey,
      publicKey,
      signature,
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(0);
  });

  it("should generate both degree and adult claims", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerDiploma(userId, this.instances.alice, this.diplomaAddress, this.signers.alice, 8, 1, 8);

    const degreeTx = await diplomaID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateDegreeClaim(uint256,address)");

    await expect(degreeTx).to.emit(employerClaim, "DegreeClaimGenerated");

    const latestDegreeClaimUserId = await employerClaim.lastClaimId();
    const degreeClaim = await employerClaim.getDegreeClaim(latestDegreeClaimUserId);

    await registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice);

    const adultTx = await passportID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateAdultClaim(uint256,address)");

    await expect(adultTx).to.emit(employerClaim, "AdultClaimGenerated");

    const latestAdultClaimUserId = await employerClaim.lastClaimId();
    const adultClaim = await employerClaim.getAdultClaim(latestAdultClaimUserId);

    const { publicKey, privateKey, signature } = await setupReencryption(
      this.instances.alice,
      this.signers.alice,
      this.employerClaimAddress,
    );

    const reencryptedDegreeClaim = await this.instances.alice.reencrypt(
      degreeClaim,
      privateKey,
      publicKey,
      signature,
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    const reencryptedAdultClaim = await this.instances.alice.reencrypt(
      adultClaim,
      privateKey,
      publicKey,
      signature,
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    expect(reencryptedDegreeClaim).to.equal(1);
    expect(reencryptedAdultClaim).to.equal(1);

    await employerClaim.verifyClaims(userId, latestAdultClaimUserId, latestDegreeClaimUserId);
    const verifyResult = await employerClaim.getVerifyClaim(userId);

    const reencryptedVerifyResult = await this.instances.alice.reencrypt(
      verifyResult,
      privateKey,
      publicKey,
      signature,
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    expect(reencryptedVerifyResult).to.equal(1);
  });
});
