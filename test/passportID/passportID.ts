import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";
import type { FhevmInstance } from "fhevmjs";

import type { Diploma, EmployerClaim, IdMapping, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEmployerClaimFixture } from "./fixture/EmployerClaim.fixture";

// Helper function to convert bigint to bytes
export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

describe("PassportID and EmployerClaim Contracts", function () {
  let passportID: PassportID;
  let employerClaim: EmployerClaim;
  let diplomaID: Diploma;
  let idMapping: IdMapping;

  // Initialize signers before running tests
  before(async function () {
    await initSigners(2);
    this.signers = await getSigners();
  });

  // Deploy fresh contract instances before each test
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

  // Helper function to register identity
  async function registerIdentity(
    userId: bigint,
    instance: FhevmInstance,
    passportAddress: string,
    signer: HardhatEthersSigner,
    biodata = 8,
    firstname = 8,
    lastname = 8,
    birthdate = 1234n,
  ) {
    const input = instance.createEncryptedInput(passportAddress, signer.address);
    const encryptedData = await input.add8(biodata).add8(firstname).add8(lastname).add64(birthdate).encrypt();

    await passportID
      .connect(signer)
      .registerIdentity(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );
  }

  // Helper function to setup reencryption
  async function setupReencryption(instance: FhevmInstance, signer: HardhatEthersSigner, contractAddress: string) {
    const { publicKey, privateKey } = instance.generateKeypair();
    const eip712 = instance.createEIP712(publicKey, contractAddress);
    const signature = await signer.signTypedData(eip712.domain, { Reencrypt: eip712.types.Reencrypt }, eip712.message);

    return { publicKey, privateKey, signature: signature.replace("0x", "") };
  }

  // Test case: Register an identity successfully
  it("should register an identity successfully", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice);

    expect(await passportID.registered(this.signers.alice.address));
  });

  // Test case: Prevent duplicate registration for the same user
  it("should prevent duplicate registration for the same user", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice);

    await expect(
      registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice),
    ).to.be.revertedWithCustomError(passportID, "AlreadyRegistered");
  });

  // Test case: Retrieve the registered identity
  it("should retrieve the registered identity", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice);

    const firstnameHandleAlice = await passportID.getMyIdentityFirstname(userId);

    const { publicKey, privateKey, signature } = await setupReencryption(
      this.instances.alice,
      this.signers.alice,
      this.passportIDAddress,
    );

    const reencryptedFirstname = await this.instances.alice.reencrypt(
      firstnameHandleAlice,
      privateKey,
      publicKey,
      signature,
      this.passportIDAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(8);
  });

  // Test case: Generate an adult claim
  it("should generate an adult claim", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await registerIdentity(userId, this.instances.alice, this.passportIDAddress, this.signers.alice);

    const tx = await passportID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateAdultClaim(uint256)");

    await expect(tx).to.emit(employerClaim, "AdultClaimGenerated");

    const latestClaimUserId = await employerClaim.lastClaimId();
    const adultsClaim = await employerClaim.getAdultClaim(latestClaimUserId);

    const { publicKey, privateKey, signature } = await setupReencryption(
      this.instances.alice,
      this.signers.alice,
      this.employerClaimAddress,
    );

    const reencryptedFirstname = await this.instances.alice.reencrypt(
      adultsClaim,
      privateKey,
      publicKey,
      signature,
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(1);
  });

  // Test case: Should fail verification with invalid claim IDs
  it("should fail verification with invalid claim IDs", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    await expect(employerClaim.connect(this.signers.alice).verifyClaims(userId, 0, 1)).to.be.revertedWithCustomError(
      employerClaim,
      "InvalidClaimId",
    );

    await expect(employerClaim.connect(this.signers.alice).verifyClaims(userId, 1, 0)).to.be.revertedWithCustomError(
      employerClaim,
      "InvalidClaimId",
    );
  });
});
