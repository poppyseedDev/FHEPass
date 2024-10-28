import { toBufferBE } from "bigint-buffer";
import { expect } from "chai";
import { ethers } from "hardhat";

import type { ClaimAdult, PassportID } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployClaimAdultFixture } from "./ClaimAdult.fixture";

export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};

describe("PassportID and ClaimAdult Contracts", function () {
  let passportID: PassportID;
  let claimAdult: ClaimAdult;

  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const deployment = await deployClaimAdultFixture();
    claimAdult = deployment.claimAdult;
    passportID = deployment.passportID;
    this.claimAdultAddress = await claimAdult.getAddress();
    this.passportIDAddress = await passportID.getAddress();
    this.instances = await createInstances(this.signers);
  });

  it("should register an identity successfully", async function () {
    const passportContract = await ethers.getContractAt("PassportID", passportID);

    // Create encrypted inputs for registration
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234) // Encrypted birthdate as uint64
      .encrypt(); // Encrypts and generates inputProof

    // Register identity with encrypted inputs
    await passportContract
      .connect(this.signers.alice)
      .registerIdentity(
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    expect(await passportContract.registered(this.signers.alice.address));
  });

  it("should prevent duplicate registration for the same user", async function () {
    const passportContract = await ethers.getContractAt("PassportID", passportID);

    // Register the identity once
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234)
      .encrypt();

    await passportContract
      .connect(this.signers.alice)
      .registerIdentity(
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    // Try to register the same identity again and expect it to revert
    await expect(
      passportContract
        .connect(this.signers.alice)
        .registerIdentity(
          encryptedData.handles[0],
          encryptedData.handles[1],
          encryptedData.handles[2],
          encryptedData.handles[3],
          encryptedData.inputProof,
        ),
    ).to.be.revertedWith("Already registered!");
  });

  it("should retrieve the registered identity", async function () {
    const passportContract = await ethers.getContractAt("PassportID", this.passportIDAddress);

    // Encrypt and register the identity
    const input = this.instances.alice.createEncryptedInput(this.passportIDAddress, this.signers.alice.address);
    const encryptedData = input
      .add8(8) // Encrypted biodata hash
      .add8(8) // Encrypted first name
      .add8(8) // Encrypted last name
      .add64(1234567890)
      .encrypt();

    await passportContract
      .connect(this.signers.alice)
      .registerIdentity(
        encryptedData.handles[0],
        encryptedData.handles[1],
        encryptedData.handles[2],
        encryptedData.handles[3],
        encryptedData.inputProof,
      );

    // Retrieve and validate the registered identity data
    const identity = await passportContract.getIdentity(this.signers.alice.address);

    // // Check if the retrieved data is not null or undefined
    expect(identity.biodata).to.not.equal(0);
    expect(identity.firstname).to.not.equal(0);
    expect(identity.lastname).to.not.equal(0);
    expect(identity.birthdate).to.not.equal(0);

    // Implement reencryption

    // Implement reencryption for each field
    const { publicKeyAlice, privateKeyAlice } = this.instances.alice.generateKeypair();
    const eip712 = this.instances.alice.createEIP712(publicKeyAlice, this.passportIDAddress);
    const signature = await this.signers.alice.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message,
    );

    const reencryptField = async (handle: bigint) => {
      return this.instances.alice.reencrypt(
        handle,
        privateKeyAlice,
        publicKeyAlice,
        signature.replace("0x", ""),
        this.passportIDAddress,
        this.signers.alice.address,
      );
    };

    const reencryptedBiodata = await reencryptField(identity.biodata);
    // const reencryptedFirstname = await reencryptField(identity.firstname);
    // const reencryptedLastname = await reencryptField(identity.lastname);
    // const reencryptedBirthdate = await reencryptField(identity.birthdate);

    // // Verify reencrypted data
    // expect(reencryptedBiodata).to.equal(8);
    // expect(reencryptedFirstname).to.equal(8);
    // expect(reencryptedLastname).to.equal(8);
    // expect(reencryptedBirthdate).to.equal(1234567890);
  });

  //   it("should generate an adult claim", async function () {
  //     const ageThreshold = 567890123; // Age threshold for adult verification

  //     // Encrypt the age threshold
  //     const input = this.instances.alice.createEncryptedInput(this.claimAdultAddress, this.signers.alice.address);
  //     const encryptedAgeThreshold = input.add64(ageThreshold).encrypt();

  //     // Generate the adult claim with encrypted threshold
  //     const tx = await claimAdult
  //       .connect(this.signers.alice)
  //       .generateAdultClaim(
  //         encryptedAgeThreshold.handles[0],
  //         this.signers.alice.address,
  //         encryptedAgeThreshold.inputProof,
  //       );

  //     const receipt = await tx.wait();
  //     const event = receipt.events?.find((e: any) => e.event === "AdultClaimGenerated");
  //     const claimId = event?.args?.claimId;

  //     // Verify the claim result is stored
  //     const claimResult = await claimAdult.getAdultClaim(claimId);
  //     expect(claimResult);
  //   });
});
