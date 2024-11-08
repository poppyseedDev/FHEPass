// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./PassportID.sol"; // Import PassportID contract
import "./Diploma.sol";

contract EmployerClaim {
    // Constants
    uint64 private constant AGE_THRESHOLD_TIMESTAMP = 1704067200; // Jan 1, 2024 - 18 years
    uint8 private constant REQUIRED_DEGREE_LEVEL = 1;
    uint256 private constant INVALID_ID = 0;
    uint256 private constant INVALID_CLAIM = 0;

    // Custom errors
    error OnlyUserCanGenerateClaim();
    error InvalidClaimId();
    error InvalidUserId();
    error InvalidContractAddress();
    error UnauthorizedAccess();

    uint64 public lastClaimId = 0;
    // Mapping of claim IDs to boolean results for adult claims
    mapping(uint64 => ebool) public adultClaims;
    // Mapping of claim IDs to boolean results for degree claims
    mapping(uint64 => ebool) public degreeClaims;
    // Mapping of user IDs to boolean results for verified claims
    mapping(uint256 => ebool) public verifiedClaims;

    // Event emitted when an adult claim is generated
    event AdultClaimGenerated(uint64 claimId, uint256 userId);
    // Event emitted when a degree claim is generated
    event DegreeClaimGenerated(uint64 claimId, uint256 userId);

    // Instance of IdMapping contract
    IdMapping private idMapping;
    // Address of the contract owner
    address public owner;

    // Constructor to initialize the contract with IdMapping address
    constructor(address _idMappingAddress) {
        if (_idMappingAddress == address(0)) revert InvalidContractAddress();
        idMapping = IdMapping(_idMappingAddress);
        owner = msg.sender;
    }

    // Generate an age claim to verify if a user is above a certain age (e.g., 18)
    function generateAdultClaim(uint256 userId, address _passportContract) public returns (uint64) {
        if (_passportContract == address(0)) revert InvalidContractAddress();
        if (userId == INVALID_ID) revert InvalidUserId();

        // Retrieve the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Retrieve the user's encrypted birthdate from the PassportID contract
        euint64 birthdate = PassportID(_passportContract).getBirthdate(userId);

        // Set age threshold to 18 years (in Unix timestamp)
        euint64 ageThreshold = TFHE.asEuint64(AGE_THRESHOLD_TIMESTAMP);

        lastClaimId++;

        // Check if birthdate indicates user is over 18
        ebool isAdult = TFHE.le(birthdate, ageThreshold);

        // Store the result of the claim
        adultClaims[lastClaimId] = isAdult;

        // Grant access to the claim to both the contract and user for verification purposes
        TFHE.allow(isAdult, address(this));
        TFHE.allow(isAdult, addressToBeAllowed);

        // Emit an event for the generated claim
        emit AdultClaimGenerated(lastClaimId, userId);

        return lastClaimId;
    }

    // Retrieve the result of an adult claim using the claim ID
    function getAdultClaim(uint64 claimId) public view returns (ebool) {
        if (claimId == 0 || claimId > lastClaimId) revert InvalidClaimId();
        return adultClaims[claimId];
    }

    // Generate a claim to verify if a user has a specific degree from a specific university
    function generateDegreeClaim(uint256 userId, address _diplomaContract) public returns (uint64) {
        if (_diplomaContract == address(0)) revert InvalidContractAddress();
        if (userId == INVALID_ID) revert InvalidUserId();

        // Retrieve the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Get the diploma data from the Diploma contract
        euint8 userUniversity = Diploma(_diplomaContract).getMyDegree(userId);

        lastClaimId++;

        // Use constant for required degree
        euint8 requiredDegree = TFHE.asEuint8(REQUIRED_DEGREE_LEVEL);

        // Check if university and degree match requirements
        ebool degreeMatch = TFHE.eq(userUniversity, requiredDegree);

        // Store the result of the claim
        degreeClaims[lastClaimId] = degreeMatch;

        // Grant access to the claim
        TFHE.allow(degreeMatch, address(this));
        TFHE.allow(degreeMatch, addressToBeAllowed);

        // Emit an event for the generated claim
        emit DegreeClaimGenerated(lastClaimId, userId);

        return lastClaimId;
    }

    // Retrieve the result of a degree claim using the claim ID
    function getDegreeClaim(uint64 claimId) public view returns (ebool) {
        if (claimId == 0 || claimId > lastClaimId) revert InvalidClaimId();
        return degreeClaims[claimId];
    }

    // Function to verify if both adult and degree claims are true for a user
    function verifyClaims(uint256 userId, uint64 adultClaim, uint64 degreeClaim) public {
        if (userId == INVALID_ID) revert InvalidUserId();
        if (adultClaim == INVALID_CLAIM || adultClaim > lastClaimId) revert InvalidClaimId();
        if (degreeClaim == INVALID_CLAIM || degreeClaim > lastClaimId) revert InvalidClaimId();

        ebool isAdult = adultClaims[adultClaim];
        ebool hasDegree = degreeClaims[degreeClaim];

        ebool verify = TFHE.and(isAdult, hasDegree);

        // Store the verification result under the userId mapping
        verifiedClaims[userId] = verify;

        // Retrieve the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Grant access to the claim
        TFHE.allow(verify, address(this));
        TFHE.allow(verify, addressToBeAllowed);
    }

    // Retrieve the result of a degree claim using the claim ID
    function getVerifyClaim(uint256 userId) public view returns (ebool) {
        if (userId == 0) revert InvalidUserId();
        return verifiedClaims[userId];
    }
}
