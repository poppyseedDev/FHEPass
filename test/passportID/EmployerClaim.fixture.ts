import { ethers } from "hardhat";

import type { EmployerClaim, PassportID } from "../../types";
import { deployPassportIDFixture } from "./PassportID.fixture";

export async function deployEmployerClaimFixture(): Promise<{ employerClaim: EmployerClaim; passportID: PassportID }> {
  const passportID = await deployPassportIDFixture();
  const EmployerClaimFactory = await ethers.getContractFactory("EmployerClaim");
  const employerClaim = await EmployerClaimFactory.deploy(passportID);
  await employerClaim.waitForDeployment();
  return { employerClaim, passportID };
}
