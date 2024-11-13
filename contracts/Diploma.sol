// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Diploma is AccessControl {
    // Constants
    uint256 private constant INVALID_ID = 0;
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // Custom errors
    error OnlyRegistrarAllowed();
    error InvalidRegistrarAddress();
    error InvalidUserId();
    error DiplomaAlreadyRegistered();
    error DiplomaNotRegistered();
    error AccessNotPermitted();
    error ClaimGenerationFailed(bytes data);
    error CannotRemoveOwnerAsRegistrar();
    error InvalidField();

    // Structure to hold encrypted diploma data
    struct DiplomaData {
        euint64 id; // Encrypted unique diploma ID
        euint8 university; // Encrypted university identifier
        euint8 degree; // Encrypted degree type
        euint8 grade; // Encrypted grade
    }

    // Instance of IdMapping contract
    IdMapping private idMapping;

    // Mapping to store diploma records by user ID
    mapping(uint256 => DiplomaData) private diplomaRecords;
    // Mapping to track registered diplomas
    mapping(uint256 => bool) public registered;

    // Event emitted when a diploma is registered
    event DiplomaRegistered(address indexed graduate);
    // Event emitted when a claim is generated
    event ClaimGenerated(address indexed graduate, address claimAddress, string claimFn);

    // Constructor to initialize the contract with IdMapping address
    constructor(address _idMappingAddress) {
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

    // Function to register a diploma, only callable by a registrar
    function registerDiploma(
        uint256 userId,
        einput university,
        einput degree,
        einput grade,
        bytes calldata inputProof
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        if (userId == INVALID_ID) revert InvalidUserId();
        if (registered[userId]) revert DiplomaAlreadyRegistered();

        // Generate a new encrypted diploma ID
        euint64 newId = TFHE.randEuint64();

        // Store the encrypted diploma data
        diplomaRecords[userId] = DiplomaData({
            id: newId,
            university: TFHE.asEuint8(university, inputProof),
            degree: TFHE.asEuint8(degree, inputProof),
            grade: TFHE.asEuint8(grade, inputProof)
        });

        registered[userId] = true; // Mark the diploma as registered

        // Get the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        // Allow the graduate to access their own data
        TFHE.allow(diplomaRecords[userId].id, addressToBeAllowed);
        TFHE.allow(diplomaRecords[userId].university, addressToBeAllowed);
        TFHE.allow(diplomaRecords[userId].degree, addressToBeAllowed);
        TFHE.allow(diplomaRecords[userId].grade, addressToBeAllowed);

        // Allow the contract to access the data
        TFHE.allow(diplomaRecords[userId].id, address(this));
        TFHE.allow(diplomaRecords[userId].university, address(this));
        TFHE.allow(diplomaRecords[userId].degree, address(this));
        TFHE.allow(diplomaRecords[userId].grade, address(this));

        emit DiplomaRegistered(addressToBeAllowed); // Emit event for diploma registration

        return true;
    }

    // Function to get the encrypted university identifier for a user
    function getMyUniversity(uint256 userId) public view returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].university;
    }

    // Function to get the encrypted degree type for a user
    function getMyDegree(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].degree;
    }

    // Function to get the encrypted grade for a user
    function getMyGrade(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].grade;
    }

    // Function to check if a diploma is registered for a user
    function hasDiploma(uint256 userId) public view returns (bool) {
        return registered[userId];
    }
    // Function to generate a claim for a diploma
    function generateClaim(address claimAddress, string memory claimFn, string[] memory fields) public {
        // Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);
        if (userId == INVALID_ID) revert InvalidUserId();

        // Grant temporary access for each requested field
        for (uint i = 0; i < fields.length; i++) {
            if (bytes(fields[i]).length == 0) revert InvalidField();

            if (keccak256(bytes(fields[i])) == keccak256(bytes("university"))) {
                TFHE.allowTransient(diplomaRecords[userId].university, claimAddress);
                // Ensure the sender can access this university's data
                if (!TFHE.isSenderAllowed(diplomaRecords[userId].university)) revert AccessNotPermitted();
            } else if (keccak256(bytes(fields[i])) == keccak256(bytes("degree"))) {
                TFHE.allowTransient(diplomaRecords[userId].degree, claimAddress);
                // Ensure the sender can access this university's data
                if (!TFHE.isSenderAllowed(diplomaRecords[userId].university)) revert AccessNotPermitted();
            } else if (keccak256(bytes(fields[i])) == keccak256(bytes("grade"))) {
                TFHE.allowTransient(diplomaRecords[userId].grade, claimAddress);
                // Ensure the sender can access this university's data
                if (!TFHE.isSenderAllowed(diplomaRecords[userId].university)) revert AccessNotPermitted();
            } else {
                revert InvalidField();
            }
        }

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId, address(this)));
        if (!success) revert ClaimGenerationFailed(data);

        emit ClaimGenerated(msg.sender, claimAddress, claimFn); // Emit event for claim generation
    }
}
