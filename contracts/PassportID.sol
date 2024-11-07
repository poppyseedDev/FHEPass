// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";

contract PassportID {
    // Add role for identity registrars
    mapping(address => bool) public registrars;
    address public owner;

    struct Identity {
        euint64 id; // Encrypted unique ID
        euint8 biodata; // Encrypted biodata (e.g., biometric data or hashed identity data)
        euint8 firstname;
        euint8 lastname;
        euint64 birthdate; // Encrypted birthdate for age verification
    }

    IdMapping private idMapping;

    mapping(uint256 => Identity) private citizenIdentities; // Mapping from id to identity
    mapping(uint256 => bool) public registered; // Track if an id is registered

    event IdentityRegistered(address indexed user);
    event ClaimGenerated(eaddress indexed user, euint64 claimId);
    event RegistrarAdded(address indexed registrar);
    event RegistrarRemoved(address indexed registrar);

    constructor(address _idMappingAddress) {
        idMapping = IdMapping(_idMappingAddress);
        owner = msg.sender;
        registrars[msg.sender] = true;
    }

    // Modifier for registrar access
    modifier onlyRegistrar() {
        require(registrars[msg.sender], "Only registrars can perform this action");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Add registrar management
    function addRegistrar(address registrar) external onlyOwner {
        require(registrar != address(0), "Invalid registrar address");
        registrars[registrar] = true;
        emit RegistrarAdded(registrar);
    }

    function removeRegistrar(address registrar) external onlyOwner {
        require(registrar != owner, "Cannot remove owner as registrar");
        registrars[registrar] = false;
        emit RegistrarRemoved(registrar);
    }

    // Register a new identity
    function registerIdentity(
        uint256 userId,
        einput biodata,
        einput firstname,
        einput lastname,
        einput birthdate,
        bytes calldata inputProof
    ) public virtual onlyRegistrar returns (bool) {
        require(userId != 0, "ID not generated. Please call generateId first.");

        require(!registered[userId], "Already registered!");

        // Assign new encrypted identity fields
        euint64 newId = TFHE.randEuint64(); // Generate a random unique ID

        citizenIdentities[userId] = Identity({
            id: newId,
            biodata: TFHE.asEuint8(biodata, inputProof),
            firstname: TFHE.asEuint8(firstname, inputProof),
            lastname: TFHE.asEuint8(lastname, inputProof),
            birthdate: TFHE.asEuint64(birthdate, inputProof)
        });

        registered[userId] = true;

        address addressToBeAllowed = idMapping.getAddr(userId);

        TFHE.allow(citizenIdentities[userId].id, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].biodata, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].firstname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].lastname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].birthdate, addressToBeAllowed);

        TFHE.allow(citizenIdentities[userId].id, address(this));
        TFHE.allow(citizenIdentities[userId].biodata, address(this));
        TFHE.allow(citizenIdentities[userId].firstname, address(this));
        TFHE.allow(citizenIdentities[userId].lastname, address(this));
        TFHE.allow(citizenIdentities[userId].birthdate, address(this));

        emit IdentityRegistered(addressToBeAllowed);

        return true;
    }

    // Function to retrieve encrypted identity data
    function getIdentity(uint256 userId) public view virtual returns (euint64, euint8, euint8, euint8, euint64) {
        require(registered[userId], "Identity not registered!");
        return (
            citizenIdentities[userId].id,
            citizenIdentities[userId].biodata,
            citizenIdentities[userId].firstname,
            citizenIdentities[userId].lastname,
            citizenIdentities[userId].birthdate
        );
    }

    // Function to retrieve encrypted birthdate
    function getBirthdate(uint256 userId) public view virtual returns (euint64) {
        require(registered[userId], "Identity not registered!");
        return citizenIdentities[userId].birthdate;
    }

    // Function to retrieve encrypted firstname
    function getMyIdentityFirstname(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Identity not registered!");
        return citizenIdentities[userId].firstname;
    }

    // Allow transient access to fields for verifiable claims
    function generateClaim(address claimAddress, string memory claimFn) public {
        uint256 userId = idMapping.getId(msg.sender);

        // Grant temporary access for citizen's birthdate to be used in the claim generation
        TFHE.allowTransient(citizenIdentities[userId].birthdate, claimAddress);

        // Ensure the sender can access this citizen's birthdate
        require(TFHE.isSenderAllowed(citizenIdentities[userId].birthdate), "Access to birthdate not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId, address(this)));
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));
    }
}
