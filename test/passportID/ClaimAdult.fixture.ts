import { ethers } from "hardhat";

import type { ClaimAdult, PassportID } from "../../types";
import { deployPassportIDFixture } from "./PassportID.fixture";

export async function deployClaimAdultFixture(): Promise<{ claimAdult: ClaimAdult; passportID: PassportID }> {
  const passportID = await deployPassportIDFixture();
  const ClaimAdultFactory = await ethers.getContractFactory("ClaimAdult");
  const claimAdult = await ClaimAdultFactory.deploy(passportID);
  await claimAdult.waitForDeployment();
  return { claimAdult, passportID };
}
