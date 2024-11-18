// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PassportID is AccessControl {
    // Constants
    uint256 private constant INVALID_ID = 0;
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // Custom errors
    error OnlyRegistrarAllowed();
    error InvalidRegistrarAddress();
    error CannotRemoveOwnerAsRegistrar();
    error InvalidUserId();
    error AlreadyRegistered();
    error IdentityNotRegistered();
    error AccessNotPermitted();
    error ClaimGenerationFailed(bytes data);

    // Structure to hold encrypted identity data
    struct Identity {
        euint64 id; // Encrypted unique ID
        euint8 biodata; // Encrypted biodata (e.g., biometric data or hashed identity data)
        euint8 firstname; // Encrypted first name
        euint8 lastname; // Encrypted last name
        euint64 birthdate; // Encrypted birthdate for age verification
    }

    // Instance of IdMapping contract
    IdMapping private idMapping;

    // Mapping to store identities by user ID
    mapping(uint256 => Identity) private citizenIdentities;
    // Mapping to track registered identities
    mapping(uint256 => bool) public registered;

    // Event emitted when an identity is registered
    event IdentityRegistered(address indexed user);

    // Constructor to initialize the contract with IdMapping address
    constructor(address _idMappingAddress) {
        TFHE.setFHEVM(FHEVMConfig.defaultConfig());
        idMapping = IdMapping(_idMappingAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // Admin role for contract owner
        _grantRole(REGISTRAR_ROLE, msg.sender); // Registrar role for contract owner
    }

    // Function to add a new registrar, only callable by the admin
    function addRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    // Function to remove a registrar, only callable by the admin
    function removeRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(REGISTRAR_ROLE, registrar);
    }

    // Function to register a new identity, only callable by a registrar
    function registerIdentity(
        uint256 userId,
        einput biodata,
        einput firstname,
        einput lastname,
        einput birthdate,
        bytes calldata inputProof
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        if (userId == INVALID_ID) revert InvalidUserId();
        if (registered[userId]) revert AlreadyRegistered();

        // Generate a new encrypted unique ID
        euint64 newId = TFHE.randEuint64();

        // Store the encrypted identity data
        citizenIdentities[userId] = Identity({
            id: newId,
            biodata: TFHE.asEuint8(biodata, inputProof),
            firstname: TFHE.asEuint8(firstname, inputProof),
            lastname: TFHE.asEuint8(lastname, inputProof),
            birthdate: TFHE.asEuint64(birthdate, inputProof)
        });

        registered[userId] = true; // Mark the identity as registered

        // Get the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Allow the user to access their own data
        TFHE.allow(citizenIdentities[userId].id, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].biodata, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].firstname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].lastname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].birthdate, addressToBeAllowed);

        // Allow the contract to access the data
        TFHE.allow(citizenIdentities[userId].id, address(this));
        TFHE.allow(citizenIdentities[userId].biodata, address(this));
        TFHE.allow(citizenIdentities[userId].firstname, address(this));
        TFHE.allow(citizenIdentities[userId].lastname, address(this));
        TFHE.allow(citizenIdentities[userId].birthdate, address(this));

        emit IdentityRegistered(addressToBeAllowed); // Emit event for identity registration

        return true;
    }

    // Function to get the encrypted identity data for a user
    function getIdentity(uint256 userId) public view virtual returns (euint64, euint8, euint8, euint8, euint64) {
        if (!registered[userId]) revert IdentityNotRegistered();
        return (
            citizenIdentities[userId].id,
            citizenIdentities[userId].biodata,
            citizenIdentities[userId].firstname,
            citizenIdentities[userId].lastname,
            citizenIdentities[userId].birthdate
        );
    }

    // Function to get the encrypted birthdate for a user
    function getBirthdate(uint256 userId) public view virtual returns (euint64) {
        if (!registered[userId]) revert IdentityNotRegistered();
        return citizenIdentities[userId].birthdate;
    }

    // Function to get the encrypted first name for a user
    function getMyIdentityFirstname(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert IdentityNotRegistered();
        return citizenIdentities[userId].firstname;
    }

    // Function to generate a claim for a user's identity
    function generateClaim(address claimAddress, string memory claimFn) public {
        // Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);

        // Grant temporary access for citizen's birthdate to be used in claim generation
        TFHE.allowTransient(citizenIdentities[userId].birthdate, claimAddress);

        // Ensure the sender can access this citizen's birthdate
        if (!TFHE.isSenderAllowed(citizenIdentities[userId].birthdate)) revert AccessNotPermitted();

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId));
        if (!success) revert ClaimGenerationFailed(data);
    }
}
