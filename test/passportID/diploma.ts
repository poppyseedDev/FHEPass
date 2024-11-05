import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";
import { ethers } from "hardhat";

import type { Diploma, EmployerClaim, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEmployerClaimFixture } from "./EmployerClaim.fixture";

export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

describe("PassportID and EmployerClaim Contracts", function () {
  let passportID: PassportID;
  let employerClaim: EmployerClaim;
  let diplomaID: Diploma;

  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const deployment = await deployEmployerClaimFixture();
    employerClaim = deployment.employerClaim;
    passportID = deployment.passportID;
    diplomaID = deployment.diploma;
    this.employerClaimAddress = await employerClaim.getAddress();
    this.diplomaAddress = await diplomaID.getAddress();
    this.passportIDAddress = await passportID.getAddress();
    this.instances = await createInstances(this.signers);
  });

  it("should register an identity successfully", async function () {
    // const diplomaIdContract = await ethers.getContractAt("Diploma", diplomaID);

    // Create encrypted inputs for registration
    const input = this.instances.alice.createEncryptedInput(this.diplomaAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted university hash
      .add8(8) // Encrypted degree name
      .add8(8) // Encrypted grade name
      .encrypt(); // Encrypts and generates inputProof

    console.log("----------------------");
    console.log("diploma: ", diplomaID);
    console.log("diplomaContract: ", diplomaID);
    console.log("----------------------");

    // Register identity with encrypted inputs
    await diplomaID
      .connect(this.signers.alice)
      .registerDiploma(
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    expect(await diplomaID.registered(this.signers.alice.address));
  });

  it("should prevent duplicate registration for the same user", async function () {
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
          encryptedData.handles[0],
          encryptedData.handles[1],
          encryptedData.handles[2],
          encryptedData.inputProof,
        ),
    ).to.be.revertedWith("Diploma already registered!");
  });

  it("should retrieve the registered identity", async function () {
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
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Retrieve and validate the registered identity data
    const universityHandleAlice = await diplomaID.getMyUniversity(this.signers.alice);
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

  it("should generate an degree claim", async function () {
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
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.inputProof,
      );

    // Generate the adult claim with encrypted threshold
    const tx = await diplomaID
      .connect(this.signers.alice)
      .generateClaim(this.employerClaimAddress, "generateDegreeClaim(address,address)");

    await expect(tx).to.emit(employerClaim, "DegreeClaimGenerated");

    // emits don't work, this is how get the latest claim id
    const latestClaimId = await employerClaim.latestClaimId(this.signers.alice.address);
    const adultsClaim = await employerClaim.getDegreeClaim(latestClaimId);

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
