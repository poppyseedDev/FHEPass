// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";

contract PassportID {
    // Mapping to store addresses with registrar role
    mapping(address => bool) public registrars;
    // Address of the contract owner
    address public owner;

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
    // Event emitted when a claim is generated
    event ClaimGenerated(eaddress indexed user, euint64 claimId);
    // Event emitted when a registrar is added
    event RegistrarAdded(address indexed registrar);
    // Event emitted when a registrar is removed
    event RegistrarRemoved(address indexed registrar);

    // Constructor to initialize the contract with IdMapping address
    constructor(address _idMappingAddress) {
        idMapping = IdMapping(_idMappingAddress);
        owner = msg.sender;
        registrars[msg.sender] = true; // Assign owner as a registrar
    }

    // Modifier to restrict access to registrars
    modifier onlyRegistrar() {
        require(registrars[msg.sender], "Only registrars can perform this action");
        _;
    }

    // Modifier to restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Function to add a new registrar, only callable by the owner
    function addRegistrar(address registrar) external onlyOwner {
        require(registrar != address(0), "Invalid registrar address");
        registrars[registrar] = true;
        emit RegistrarAdded(registrar);
    }

    // Function to remove a registrar, only callable by the owner
    function removeRegistrar(address registrar) external onlyOwner {
        require(registrar != owner, "Cannot remove owner as registrar");
        registrars[registrar] = false;
        emit RegistrarRemoved(registrar);
    }

    // Function to register a new identity, only callable by a registrar
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
        require(registered[userId], "Identity not registered!");
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
        require(registered[userId], "Identity not registered!");
        return citizenIdentities[userId].birthdate;
    }

    // Function to get the encrypted first name for a user
    function getMyIdentityFirstname(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Identity not registered!");
        return citizenIdentities[userId].firstname;
    }

    // Function to generate a claim for a user's identity
    function generateClaim(address claimAddress, string memory claimFn) public {
        // Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);

        // Grant temporary access for citizen's birthdate to be used in claim generation
        TFHE.allowTransient(citizenIdentities[userId].birthdate, claimAddress);

        // Ensure the sender can access this citizen's birthdate
        require(TFHE.isSenderAllowed(citizenIdentities[userId].birthdate), "Access to birthdate not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId, address(this)));
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));
    }
}
