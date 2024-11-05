import { expect } from "chai";
import { ethers } from "hardhat";

import type { IdMapping } from "../../types";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployIdMappingFixture } from "./IdMapping.fixture";

describe("IdMapping Contract", function () {
  let idMapping: IdMapping;

  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    // Deploy the contract
    idMapping = await deployIdMappingFixture();
    this.idMappingAddress = await idMapping.getAddress();

    // Set up accounts
    this.instances = await createInstances(this.signers);
  });

  it("Should set the ID for an address", async function () {
    // Set ID for addr1
    await idMapping.generateId();

    // Check if the ID was set correctly
    expect(await idMapping.getId(this.signers.alice)).to.equal(1);
  });

  it("Should set IDs for multiple addresses", async function () {
    // Set IDs for addr1 and addr2
    await idMapping.connect(this.signers.alice).generateId();
    await idMapping.connect(this.signers.bob).generateId();

    // Verify each address has the correct ID
    expect(await idMapping.getId(this.signers.alice)).to.equal(1);
    expect(await idMapping.getId(this.signers.bob)).to.equal(2);
  });
});