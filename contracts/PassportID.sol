// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

contract PassportID {
    // Identity fields stored separately
    struct Identity {
        euint64 id; // Encrypted unique ID
        euint8 biodata; // Encrypted biodata (e.g., biometric data or hashed identity data)
        euint8 firstname;
        euint8 lastname;
        euint64 birthdate; // Encrypted birthdate for age verification
    }

    mapping(address => Identity) private citizenIdentities; // Mapping from address to identity
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
        // citizenIds[msg.sender] = newId;
        // citizenBiodata[msg.sender] = TFHE.asEuint8(biodata, inputProof);
        // citizenFirstnames[msg.sender] = TFHE.asEuint8(firstname, inputProof);
        // citizenLastnames[msg.sender] = TFHE.asEuint8(lastname, inputProof);
        // citizenBirthdates[msg.sender] = TFHE.asEuint64(birthdate, inputProof);

        citizenIdentities[msg.sender] = Identity({
            id: newId,
            biodata: TFHE.asEuint8(biodata, inputProof),
            firstname: TFHE.asEuint8(firstname, inputProof),
            lastname: TFHE.asEuint8(lastname, inputProof),
            birthdate: TFHE.asEuint64(birthdate, inputProof)
        });

        registered[msg.sender] = true;

        TFHE.allow(citizenIdentities[msg.sender].id, msg.sender);
        TFHE.allow(citizenIdentities[msg.sender].biodata, msg.sender);
        TFHE.allow(citizenIdentities[msg.sender].firstname, msg.sender);
        TFHE.allow(citizenIdentities[msg.sender].lastname, msg.sender);
        TFHE.allow(citizenIdentities[msg.sender].birthdate, msg.sender);

        TFHE.allow(citizenIdentities[msg.sender].id, address(this));
        TFHE.allow(citizenIdentities[msg.sender].biodata, address(this));
        TFHE.allow(citizenIdentities[msg.sender].firstname, address(this));
        TFHE.allow(citizenIdentities[msg.sender].lastname, address(this));
        TFHE.allow(citizenIdentities[msg.sender].birthdate, address(this));

        emit IdentityRegistered(msg.sender);

        return true;
    }

    // Function to retrieve encrypted identity data
    function getIdentity(address user) public view virtual returns (euint64, euint8, euint8, euint8, euint64) {
        require(registered[user], "Identity not registered!");
        return (
            citizenIdentities[user].id,
            citizenIdentities[user].biodata,
            citizenIdentities[user].firstname,
            citizenIdentities[user].lastname,
            citizenIdentities[user].birthdate
        );
    }

    // Function to retrieve encrypted birthdate
    function getBirthdate(address user) public view virtual returns (euint64) {
        require(registered[user], "Identity not registered!");
        return citizenIdentities[user].birthdate;
    }

    // Function to retrieve encrypted firstname
    function getMyIdentityFirstname(address user) public view virtual returns (euint8) {
        require(registered[user], "Identity not registered!");
        return citizenIdentities[user].firstname;
    }

    // Allow transient access to fields for verifiable claims
    function generateClaim(address claimAddress, string memory claimFn) public {
        // Grant temporary access for citizen's birthdate to be used in the claim generation
        TFHE.allowTransient(citizenIdentities[msg.sender].birthdate, claimAddress);

        // Ensure the sender can access this citizen's birthdate
        require(TFHE.isSenderAllowed(citizenIdentities[msg.sender].birthdate), "Access to birthdate not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(
            abi.encodeWithSignature(claimFn, msg.sender, address(this))
        );
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));
    }
}
