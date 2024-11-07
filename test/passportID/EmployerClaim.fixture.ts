import { ethers } from "hardhat";

import type { Diploma, EmployerClaim, IdMapping, PassportID } from "../../types";
import { deployDiplomaFixture } from "./Diploma.fixture";
import { deployPassportIDFixture } from "./PassportID.fixture";

export async function deployEmployerClaimFixture(): Promise<{
  employerClaim: EmployerClaim;
  passportID: PassportID;
  diploma: Diploma;
  idMapping: IdMapping;
}> {
  const passportID = await deployPassportIDFixture();
  const { diploma, idMapping } = await deployDiplomaFixture();
  const EmployerClaimFactory = await ethers.getContractFactory("EmployerClaim");
  const employerClaim = await EmployerClaimFactory.deploy(idMapping);
  await employerClaim.waitForDeployment();
  return { employerClaim, passportID, diploma, idMapping };
}
