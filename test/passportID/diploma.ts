import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";

import type { Diploma, EmployerClaim, IdMapping, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEmployerClaimFixture } from "./EmployerClaim.fixture";

/**
 * Converts a bigint value to a 256-bit byte array
 */
export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

/**
 * Test suite for PassportID and EmployerClaim contract integration
 */
describe("PassportID and EmployerClaim Contracts", function () {
  let passportID: PassportID;
  let employerClaim: EmployerClaim;
  let diplomaID: Diploma;
  let idMapping: IdMapping;

  /**
   * Initialize signers before all tests
   */
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  /**
   * Deploy fresh contracts and set up test environment before each test
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
   * Test case: Verifies that a user can successfully register their diploma identity
   * Steps:
   * 1. Create encrypted inputs for university, degree and grade
   * 2. Register the diploma with encrypted data
   * 3. Verify registration status
   */
  it("should register an identity successfully", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Create encrypted inputs for registration
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted university hash
      .add8(8) // Encrypted degree name
      .add8(8) // Encrypted grade name
      .encrypt(); // Encrypts and generates inputProof

    // Register identity with encrypted inputs
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
   * Test case: Ensures that a user cannot register their diploma multiple times
   * Steps:
   * 1. Register diploma once successfully
   * 2. Attempt to register again with same data
   * 3. Verify the second attempt is rejected
   */
  it("should prevent duplicate registration for the same user", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Register the identity once
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted university hash
      .add8(8) // Encrypted degree name
      .add8(8) // Encrypted grade name
      .encrypt(); // Encrypts and generates inputProof

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Try to register the same identity again and expect it to revert
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
   * Test case: Verifies that registered diploma data can be retrieved and decrypted
   * Steps:
   * 1. Register encrypted diploma data
   * 2. Retrieve the university data
   * 3. Generate reencryption keys and signature
   * 4. Reencrypt and verify the data
   */
  it("should retrieve the registered identity", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Encrypt and register the identity
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted university hash
      .add8(8) // Encrypted degree name
      .add8(8) // Encrypted grade name
      .encrypt(); // Encrypts and generates inputProof

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Retrieve and validate the registered identity data
    const universityHandleAlice = await diplomaID.getMyUniversity(userId);
    // Implement reencryption

    // Implement reencryption for each field
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.diplomaAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

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
   * Test case: Tests the generation of a degree claim from registered diploma
   * Steps:
   * 1. Register encrypted diploma data
   * 2. Generate a degree claim
   * 3. Verify claim generation event
   * 4. Retrieve and decrypt claim data
   */
  it("should generate an degree claim", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Encrypt and register the identity
    const inputId = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = inputId
      .add8(8) // Encrypted university hash
      .add8(8) // Encrypted degree name
      .add8(8) // Encrypted grade name
      .encrypt(); // Encrypts and generates inputProof

    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Generate the adult claim with encrypted threshold
    const tx = await diplomaID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateDegreeClaim(uint256,address)");

    console.log("----------------------");
    console.log("diploma: ", diplomaID);
    console.log("diplomaContract: ", diplomaID);
    console.log("----------------------");

    await expect(tx).to.emit(employerClaim, "DegreeClaimGenerated");

    // emits don't work, this is how get the latest claim id
    const latestClaimUserId = await employerClaim.latestClaimUserId(userId);
    const adultsClaim = await employerClaim.getDegreeClaim(latestClaimUserId);

    // Implement reencryption for each field
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.employerClaimAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

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
