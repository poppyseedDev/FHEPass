import { ethers } from "hardhat";

import type { Diploma } from "../../types";
import { getSigners } from "../signers";

export async function deployDiplomaFixture(): Promise<Diploma> {
  const signers = await getSigners();
  const contractFactory = await ethers.getContractFactory("Diploma");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();
  return contract;
}
