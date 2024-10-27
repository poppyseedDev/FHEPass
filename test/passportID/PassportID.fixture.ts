import { ethers } from "hardhat";

import type { PassportID } from "../../types";
import { getSigners } from "../signers";

export async function deployPassportIDFixture(): Promise<PassportID> {
  const signers = await getSigners();
  const contractFactory = await ethers.getContractFactory("PassportID");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();
  return contract;
}
