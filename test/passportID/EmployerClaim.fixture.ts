import { ethers } from "hardhat";

import type { Diploma, EmployerClaim, PassportID } from "../../types";
import { deployDiplomaFixture } from "./Diploma.fixture";
import { deployPassportIDFixture } from "./PassportID.fixture";

export async function deployEmployerClaimFixture(): Promise<{
  employerClaim: EmployerClaim;
  passportID: PassportID;
  diploma: Diploma;
}> {
  const passportID = await deployPassportIDFixture();
  const diploma = await deployDiplomaFixture();
  const EmployerClaimFactory = await ethers.getContractFactory("EmployerClaim");
  const employerClaim = await EmployerClaimFactory.deploy();
  await employerClaim.waitForDeployment();
  return { employerClaim, passportID, diploma };
}
