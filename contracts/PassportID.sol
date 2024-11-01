// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

contract PassportID {
    // Identity fields stored separately
    mapping(address => euint64) private citizenIds; // Encrypted unique ID
    mapping(address => euint8) private citizenBiodata; // Encrypted biodata (e.g., biometric data or hashed identity data)
    mapping(address => euint8) private citizenFirstnames;
    mapping(address => euint8) private citizenLastnames;
    mapping(address => euint64) private citizenBirthdates; // Encrypted birthdate for age verification

    mapping(address => bool) public registered; // Track if an address is registered

    event IdentityRegistered(address indexed user);
    event ClaimGenerated(eaddress indexed user, euint64 claimId);

    // Register a new identity
    // TODO: Fix problem - one person can register multiple identities; checks if the identity is truthful or unique
    function registerIdentity(
        einput biodata,
        einput firstname,
        einput lastname,
        einput birthdate,
        bytes calldata inputProof
    ) public virtual returns (bool) {
        // Ensure uniqueness by checking if the address is already registered
        require(!registered[msg.sender], "Already registered!");

        // Assign new encrypted identity fields
        euint64 newId = TFHE.randEuint64(); // Generate a random unique ID
        citizenIds[msg.sender] = newId;
        citizenBiodata[msg.sender] = TFHE.asEuint8(biodata, inputProof);
        citizenFirstnames[msg.sender] = TFHE.asEuint8(firstname, inputProof);
        citizenLastnames[msg.sender] = TFHE.asEuint8(lastname, inputProof);
        citizenBirthdates[msg.sender] = TFHE.asEuint64(birthdate, inputProof);

        registered[msg.sender] = true;

        TFHE.allow(citizenIds[msg.sender], msg.sender);
        TFHE.allow(citizenBiodata[msg.sender], msg.sender);
        TFHE.allow(citizenFirstnames[msg.sender], msg.sender);
        TFHE.allow(citizenLastnames[msg.sender], msg.sender);
        TFHE.allow(citizenBirthdates[msg.sender], msg.sender);

        TFHE.allow(citizenIds[msg.sender], address(this));
        TFHE.allow(citizenBiodata[msg.sender], address(this));
        TFHE.allow(citizenFirstnames[msg.sender], address(this));
        TFHE.allow(citizenLastnames[msg.sender], address(this));
        TFHE.allow(citizenBirthdates[msg.sender], address(this));

        emit IdentityRegistered(msg.sender);

        return true;
    }

    // Function to retrieve encrypted identity data
    function getIdentity(address user) public view virtual returns (euint64, euint8, euint8, euint8, euint64) {
        require(registered[user], "Identity not registered!");
        return (
            citizenIds[user],
            citizenBiodata[user],
            citizenFirstnames[user],
            citizenLastnames[user],
            citizenBirthdates[user]
        );
    }

    // Function to retrieve encrypted firstname
    function getMyIdentityFirstname(address user) public view virtual returns (euint8) {
        require(registered[user], "Identity not registered!");
        return citizenFirstnames[user];
    }

    // Allow transient access to fields for verifiable claims
    function generateClaim(
        address claimAddress,
        string memory claimFn,
        string[] memory fields,
        address contractAddr
    ) public {
        for (uint i = 0; i < fields.length; i++) {
            bytes32 fieldHash = keccak256(abi.encodePacked(fields[i]));
            if (fieldHash == keccak256("birthdate")) {
                TFHE.allowTransient(citizenBirthdates[msg.sender], claimAddress);
            } else if (fieldHash == keccak256("biodata")) {
                TFHE.allowTransient(citizenBiodata[msg.sender], claimAddress);
            }
        }

        euint64 citizenId = citizenIds[msg.sender];
        (bool success, ) = claimAddress.call(abi.encodeWithSignature(claimFn, citizenId, contractAddr));
        require(success, "Claim generation failed.");
    }
}
