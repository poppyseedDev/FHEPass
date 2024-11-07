import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";

import type { Diploma, EmployerClaim, IdMapping, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEmployerClaimFixture } from "./fixture/EmployerClaim.fixture";

export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

describe("PassportID and EmployerClaim Contracts", function () {
  let passportID: PassportID;
  let employerClaim: EmployerClaim;
  let diplomaID: Diploma;
  let idMapping: IdMapping;

  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

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

  it("should register an identity successfully", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Create encrypted inputs for registration
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234) // Encrypted birthdate as uint64
      .encrypt(); // Encrypts and generates inputProof

    // Register identity with encrypted inputs
    await passportID
      .connect(this.signers.alice)
      .registerIdentity(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    expect(await passportID.registered(this.signers.alice.address));
  });

  it("should prevent duplicate registration for the same user", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Register the identity once
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234)
      .encrypt();

    await passportID
      .connect(this.signers.alice)
      .registerIdentity(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    // Try to register the same identity again and expect it to revert
    await expect(
      passportID
        .connect(this.signers.alice)
        .registerIdentity(
          userId,
          encryptedData.handles[0],
          encryptedData.handles[1],
          encryptedData.handles[2],
          encryptedData.handles[3],
          encryptedData.inputProof,
        ),
    ).to.be.revertedWith("Already registered!");
  });

  it("should retrieve the registered identity", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Encrypt and register the identity
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234)
      .encrypt();

    await passportID
      .connect(this.signers.alice)
      .registerIdentity(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    // Retrieve and validate the registered identity data
    const firstnameHandleAlice = await passportID.getMyIdentityFirstname(userId);
    // Implement reencryption

    // Implement reencryption for each field
    const { publicKey: publicKeyAlice, privateKey: privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.passportIDAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

    // const reencryptField = async (handle: any) => {
    //     return this.instances.alice.reencrypt(
    //       handle,
    //       privateKeyAlice,
    //       publicKeyAlice,
    //       signature.replace("0x", ""),
    //       this.passportIDAddress,
    //       this.signers.alice.address,
    //     );
    //   };

    const reencryptedFirstname = await this.instances.alice.reencrypt(
      firstnameHandleAlice,
      privateKeyAlice,
      publicKeyAlice,
      signature.replace("0x", ""),
      this.passportIDAddress,
      this.signers.alice.address,
    );

    expect(reencryptedFirstname).to.equal(8);

    // const reencryptedFirstname = await reencryptField(firstname);
    // const reencryptedFirstname = await reencryptField(identity.firstname);
    // const reencryptedLastname = await reencryptField(identity.lastname);
    // const reencryptedBirthdate = await reencryptField(identity.birthdate);

    // // Verify reencrypted data
    // expect(reencryptedBiodata).to.equal(8);
    // expect(reencryptedFirstname).to.equal(8);
    // expect(reencryptedLastname).to.equal(8);
    // expect(reencryptedBirthdate).to.equal(1234567890);
  });

  it("should generate an adult claim", async function () {
    await idMapping.connect(this.signers.alice).generateId();
    const userId = await idMapping.getId(this.signers.alice);

    // Encrypt and register the identity
    const inputId = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = inputId
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234) // Encrypted birthdate
      .encrypt();

    await passportID
      .connect(this.signers.alice)
      .registerIdentity(
        userId,
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    // const ageThreshold = 25n; // Age threshold for adult verification

    // Generate the adult claim with encrypted threshold
    const tx = await passportID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateAdultClaim(address,address)");

    await expect(tx).to.emit(employerClaim, "AdultClaimGenerated");

    // emits don't work, this is how get the latest claim id
    const latestClaimUserId = await employerClaim.latestClaimUserId(userId);
    const adultsClaim = await employerClaim.getAdultClaim(latestClaimUserId);

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
