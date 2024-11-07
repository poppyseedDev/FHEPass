import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";

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
   * Test case: Diploma Registration
   * Verifies that a user can successfully register their encrypted diploma credentials
   *
   * Flow:
   * 1. Generate user ID for Alice
   * 2. Create encrypted inputs for university, degree and grade data
   * 3. Register encrypted diploma data on-chain
   * 4. Verify successful registration status
   */
  it("should register an identity successfully", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Create encrypted inputs for registration
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // University identifier (encrypted)
      .add8(8) // Degree type (encrypted)
      .add8(8) // Grade classification (encrypted)
      .encrypt();

    // Register encrypted diploma data
    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    expect(await diplomaID.registered(userId));
  });

  /**
   * Test case: Duplicate Registration Prevention
   * Ensures the system prevents multiple registrations for the same user
   *
   * Flow:
   * 1. Register diploma credentials for a user
   * 2. Attempt to register again with same credentials
   * 3. Verify the second registration is rejected with appropriate error
   */
  it("should prevent duplicate registration for the same user", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Initial registration
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // University identifier (encrypted)
      .add8(8) // Degree type (encrypted)
      .add8(8) // Grade classification (encrypted)
      .encrypt();

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Attempt duplicate registration
    await expect(
      diplomaID
        .connect(this.signers.alice)
        .registerDiploma(
          userId,
          encryptedData.handles[0],
          encryptedData.handles[1],
          encryptedData.handles[2],
          encryptedData.inputProof,
        ),
    ).to.be.revertedWith("Diploma already registered!");
  });

  /**
   * Test case: Diploma Data Retrieval and Decryption
   * Verifies that registered encrypted diploma data can be retrieved and correctly decrypted
   *
   * Flow:
   * 1. Register encrypted diploma credentials
   * 2. Retrieve encrypted university data
   * 3. Generate reencryption keys and signature for secure decryption
   * 4. Decrypt and verify the university data matches original input
   */
  it("should retrieve the registered identity", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Register encrypted diploma data
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // University identifier (encrypted)
      .add8(8) // Degree type (encrypted)
      .add8(8) // Grade classification (encrypted)
      .encrypt();

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Retrieve encrypted university data
    const universityHandleAlice = await diplomaID.getMyUniversity(userId);

    // Set up secure reencryption
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.diplomaAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

    // Decrypt and verify university data
    const reencryptedFirstname = await this.instances.alice.reencrypt(
      universityHandleAlice,
      privateKeyAlice,
      publicKeyAlice,
      signature.replace("0x", ""),
      this.diplomaAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(8);
  });

  /**
   * Test case: Degree Claim Generation
   * Tests the creation and verification of degree claims based on registered diploma data
   *
   * Flow:
   * 1. Register encrypted diploma credentials
   * 2. Generate a verifiable degree claim
   * 3. Verify claim generation event is emitted
   * 4. Retrieve, decrypt and validate claim data
   */
  it("should generate an degree claim", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Register encrypted diploma data
    const inputId = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = inputId
      .add8(8) // University identifier (encrypted)
      .add8(8) // Degree type (encrypted)
      .add8(8) // Grade classification (encrypted)
      .encrypt();

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Generate degree verification claim
    const tx = await diplomaID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateDegreeClaim(uint256,address)");

    await expect(tx).to.emit(employerClaim, "DegreeClaimGenerated");

    // Retrieve and decrypt claim result
    const latestClaimUserId = await employerClaim.latestClaimUserId(userId);
    const adultsClaim = await employerClaim.getDegreeClaim(latestClaimUserId);

    // Set up secure reencryption for claim verification
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.employerClaimAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

    // Decrypt and verify claim result
    const reencryptedFirstname = await this.instances.alice.reencrypt(
      adultsClaim,
      privateKeyAlice,
      publicKeyAlice,
      signature.replace("0x", ""),
      this.employerClaimAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(0);
  });
});
