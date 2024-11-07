import { ethers } from "hardhat";

import type { Diploma, IdMapping } from "../../types";
import { getSigners } from "../signers";
import { deployIdMappingFixture } from "./IdMapping.fixture";

export async function deployDiplomaFixture(): Promise<{ diploma: Diploma; idMapping: IdMapping }> {
  const idMapping = await deployIdMappingFixture();
  const signers = await getSigners();
  const contractFactory = await ethers.getContractFactory("Diploma");
  const contract = await contractFactory.connect(signers.alice).deploy(idMapping);
  await contract.waitForDeployment();
  return {
    diploma: contract,
    idMapping: idMapping,
  };
}
