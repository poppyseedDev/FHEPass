// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

contract PassportID {
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

        // Assign a new encrypted identity
        euint64 newId = TFHE.randEuint64(); // Generate a random unique ID
        citizenIdentities[msg.sender] = Identity({
            id: newId,
            biodata: TFHE.asEuint8(biodata, inputProof),
            firstname: TFHE.asEuint8(firstname, inputProof),
            lastname: TFHE.asEuint8(lastname, inputProof),
            birthdate: TFHE.asEuint64(birthdate, inputProof)
        });

        registered[msg.sender] = true;

        emit IdentityRegistered(msg.sender);

        return true;
    }

    // Function to retrieve encrypted identity data
    function getIdentity(address user) public view returns (Identity memory) {
        require(registered[user], "Identity not registered!");
        return citizenIdentities[user];
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
                TFHE.allowTransient(citizenIdentities[msg.sender].birthdate, claimAddress);
            } else if (fieldHash == keccak256("biodata")) {
                TFHE.allowTransient(citizenIdentities[msg.sender].biodata, claimAddress);
            }
        }

        euint64 citizenId = citizenIdentities[msg.sender].id;
        (bool success, ) = claimAddress.call(abi.encodeWithSignature(claimFn, citizenId, contractAddr));
        require(success, "Claim generation failed.");
    }
}
