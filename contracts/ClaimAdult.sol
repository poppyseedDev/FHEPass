// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./PassportID.sol"; // Import PassportID contract

contract ClaimAdult {
    PassportID public passportContract; // Reference to the PassportID contract

    mapping(euint64 => ebool) public adultClaims; // Mapping of claim IDs to boolean results

    event AdultClaimGenerated(euint64 claimId, address user, ebool isAdult);

    constructor(address _passportAddress) {
        passportContract = PassportID(_passportAddress); // Initialize the PassportID contract address
    }

    // Generate an age claim to verify if a user is above a certain age (e.g., 18)
    function generateAdultClaim(euint64 ageThreshold, address user) public returns (euint64) {
        // Retrieve the user's encrypted birthdate from the PassportID contract
        PassportID.Identity memory identity = passportContract.getIdentity(user);

        // Generate a unique claim ID
        euint64 claimId = TFHE.randEuint64();

        // Verify if the user is an adult by checking if birthdate >= threshold
        ebool isAdult = TFHE.ge(identity.birthdate, ageThreshold);

        // Store the result of the claim
        adultClaims[claimId] = isAdult;

        // Grant access to the claim to both the contract and user for verification purposes
        TFHE.allowTransient(isAdult, msg.sender);
        TFHE.allowTransient(isAdult, user);

        // Emit an event for the generated claim
        emit AdultClaimGenerated(claimId, user, isAdult);

        return claimId;
    }

    // Retrieve the result of an adult claim using the claim ID
    function getAdultClaim(euint64 claimId) public view returns (ebool) {
        return adultClaims[claimId];
    }
}
