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
    this.employerClaimAddress = await employerClaim.getAddress();
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
});
