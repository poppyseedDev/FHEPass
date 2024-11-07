// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./PassportID.sol"; // Import PassportID contract
import "./Diploma.sol";

contract EmployerClaim {
    // Mapping of claim IDs to boolean results for adult claims
    mapping(euint64 => ebool) public adultClaims;
    // Mapping of claim IDs to boolean results for degree claims
    mapping(euint64 => ebool) public degreeClaims;

    // Mapping to store the latest claim ID for each user
    mapping(uint256 => euint64) public latestClaimUserId;

    // Event emitted when an adult claim is generated
    event AdultClaimGenerated(euint64 claimId, uint256 userId);
    // Event emitted when a degree claim is generated
    event DegreeClaimGenerated(euint64 claimId, uint256 userId);

    // Instance of IdMapping contract
    IdMapping private idMapping;
    // Address of the contract owner
    address public owner;

    // Constructor to initialize the contract with IdMapping address
    constructor(address _idMappingAddress) {
        idMapping = IdMapping(_idMappingAddress);
        owner = msg.sender;
    }

    // Generate an age claim to verify if a user is above a certain age (e.g., 18)
    function generateAdultClaim(uint256 userId, address _passportContract) public returns (euint64) {
        // Retrieve the user's encrypted birthdate from the PassportID contract
        PassportID passport = PassportID(_passportContract);
        euint64 birthdate = passport.getBirthdate(userId);

        // Set age threshold to 18 years (in Unix timestamp)
        euint64 ageThreshold = TFHE.asEuint64(1704067200); // Jan 1, 2024 - 18 years

        // Generate a unique claim ID
        euint64 claimId = TFHE.randEuint64();

        // Check if birthdate indicates user is over 18
        ebool isAdult = TFHE.ge(birthdate, ageThreshold);

        // Store the result of the claim
        adultClaims[claimId] = isAdult;

        // Retrieve the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Grant access to the claim to both the contract and user for verification purposes
        TFHE.allow(isAdult, _passportContract);
        TFHE.allow(isAdult, address(this));
        TFHE.allow(isAdult, addressToBeAllowed);

        // Update the latest claim ID for the user
        latestClaimUserId[userId] = claimId;

        // Emit an event for the generated claim
        emit AdultClaimGenerated(claimId, userId);

        return claimId;
    }

    // Retrieve the result of an adult claim using the claim ID
    function getAdultClaim(euint64 claimId) public view returns (ebool) {
        return adultClaims[claimId];
    }

    // Generate a claim to verify if a user has a specific degree from a specific university
    function generateDegreeClaim(uint256 userId, address _diplomaContract) public returns (euint64) {
        // Get the diploma data from the Diploma contract
        Diploma diploma = Diploma(_diplomaContract);
        euint8 userUniversity = diploma.getMyDegree(userId);

        // Generate a unique claim ID
        euint64 claimId = TFHE.randEuint64();

        // Generate a random required degree for comparison
        euint8 requiredDegree = TFHE.randEuint8();

        // Check if university and degree match requirements
        ebool degreeMatch = TFHE.eq(userUniversity, requiredDegree);

        // Store the result of the claim
        degreeClaims[claimId] = degreeMatch;

        // Retrieve the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Grant access to the claim
        TFHE.allow(degreeMatch, address(this));
        TFHE.allow(degreeMatch, addressToBeAllowed);

        // Update the latest claim ID for the user
        latestClaimUserId[userId] = claimId;

        // Emit an event for the generated claim
        emit DegreeClaimGenerated(claimId, userId);

        return claimId;
    }

    // Retrieve the result of a degree claim using the claim ID
    function getDegreeClaim(euint64 claimId) public view returns (ebool) {
        return degreeClaims[claimId];
    }
}
