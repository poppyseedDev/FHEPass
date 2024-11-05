// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./PassportID.sol"; // Import PassportID contract

contract EmployerClaim {
    // PassportID public passportContract; // Reference to the PassportID contract

    mapping(euint64 => ebool) public adultClaims; // Mapping of claim IDs to boolean results

    mapping(address => euint64) public latestClaimId;

    event AdultClaimGenerated(euint64 claimId, address user);

    // constructor(address _passportAddress) {
    //     passportContract = PassportID(_passportAddress); // Initialize the PassportID contract address
    // }

    // Generate an age claim to verify if a user is above a certain age (e.g., 18)
    function generateAdultClaim(address user, address _passportContract) public returns (euint64) {
        // Retrieve the user's encrypted birthdate from the PassportID contract
        PassportID passport = PassportID(_passportContract);
        euint64 birthdate = passport.getBirthdate(user);

        // // Set age threshold to 18 years (in Unix timestamp)
        euint64 ageThreshold = TFHE.asEuint64(1704067200); // Jan 1, 2024 - 18 years

        // // Generate a unique claim ID
        euint64 claimId = TFHE.randEuint64();

        // // Check if birthdate indicates user is over 18
        ebool isAdult = TFHE.ge(birthdate, ageThreshold);

        // // Store the result of the claim
        adultClaims[claimId] = isAdult;

        // // Grant access to the claim to both the contract and user for verification purposes
        TFHE.allow(isAdult, _passportContract);
        TFHE.allow(isAdult, address(this));
        TFHE.allow(isAdult, msg.sender);
        TFHE.allow(isAdult, user);

        latestClaimId[user] = claimId; // Store claimId for the user

        // // Emit an event for the generated claim
        emit AdultClaimGenerated(claimId, user);

        return claimId;
    }

    // Retrieve the result of an adult claim using the claim ID
    function getAdultClaim(euint64 claimId) public view returns (ebool) {
        return adultClaims[claimId];
    }
}
