// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Diploma
 * @author ZAMA
 * @dev Contract for managing encrypted diploma records using TFHE encryption
 * @notice Allows universities to register encrypted diploma data and graduates to generate claims
 */
contract Diploma is AccessControl {
    /// @dev Constants
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @dev Custom errors
    error OnlyRegistrarAllowed();
    error InvalidRegistrarAddress();
    error DiplomaAlreadyRegistered();
    error DiplomaNotRegistered();
    error AccessNotPermitted();
    error ClaimGenerationFailed(bytes data);
    error CannotRemoveOwnerAsRegistrar();

    /// @dev Structure to hold encrypted diploma data
    struct DiplomaData {
        euint64 id; // Encrypted unique diploma ID
        euint8 university; // Encrypted university identifier
        euint8 degree; // Encrypted degree type
        euint8 grade; // Encrypted grade
    }

    /// @dev Instance of IdMapping contract
    IdMapping private idMapping;

    /// @dev Mapping to store diploma records by user ID
    mapping(uint256 => DiplomaData) private diplomaRecords;
    /// @dev Mapping to track registered diplomas
    mapping(uint256 => bool) public registered;

    /// @dev Event emitted when a diploma is registered
    event DiplomaRegistered(address indexed graduate);
    /// @dev Event emitted when a claim is generated
    event ClaimGenerated(address indexed graduate, address claimAddress, string claimFn);

    /**
     * @dev Constructor to initialize the contract with IdMapping address
     * @param _idMappingAddress Address of the IdMapping contract
     */
    constructor(address _idMappingAddress) {
        TFHE.setFHEVM(FHEVMConfig.defaultConfig()); // Set up the FHEVM configuration for this contract
        idMapping = IdMapping(_idMappingAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // Admin role for contract owner
        _grantRole(REGISTRAR_ROLE, msg.sender); // Registrar role for contract owner
    }

    /**
     * @dev Adds a new registrar address
     * @param registrar Address to be granted registrar role
     */
    function addRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @dev Removes a registrar address
     * @param registrar Address to be revoked registrar role
     */
    function removeRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @dev Registers a new encrypted diploma for a user
     * @param userId ID of the user to register diploma for
     * @param university Encrypted university identifier
     * @param degree Encrypted degree type
     * @param grade Encrypted grade
     * @param inputProof Proof for encrypted inputs
     * @return bool indicating success
     */
    function registerDiploma(
        uint256 userId,
        einput university,
        einput degree,
        einput grade,
        bytes calldata inputProof
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
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

    /**
     * @dev Retrieves encrypted university identifier for a user
     * @param userId ID of the user to get university for
     * @return euint8 Encrypted university identifier
     */
    function getMyUniversity(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].university;
    }

    /**
     * @dev Retrieves encrypted degree type for a user
     * @param userId ID of the user to get degree for
     * @return euint8 Encrypted degree type
     */
    function getMyDegree(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].degree;
    }

    /**
     * @dev Retrieves encrypted grade for a user
     * @param userId ID of the user to get grade for
     * @return euint8 Encrypted grade
     */
    function getMyGrade(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert DiplomaNotRegistered();
        return diplomaRecords[userId].grade;
    }

    /**
     * @dev Checks if a diploma is registered for a user
     * @param userId ID of the user to check
     * @return bool indicating if diploma exists
     */
    function hasDiploma(uint256 userId) public view virtual returns (bool) {
        return registered[userId];
    }

    /**
     * @dev Generates a claim for a diploma
     * @param claimAddress Address of the claim contract
     * @param claimFn Function signature to call on claim contract
     */
    function generateClaim(address claimAddress, string memory claimFn) public {
        /// @dev Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);

        /// @dev Grant temporary access for graduate's data to be used in claim generation
        TFHE.allowTransient(diplomaRecords[userId].degree, claimAddress);

        /// @dev Ensure the sender can access this graduate's data
        if (!TFHE.isSenderAllowed(diplomaRecords[userId].degree)) revert AccessNotPermitted();

        /// @dev Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId));
        if (!success) revert ClaimGenerationFailed(data);

        emit ClaimGenerated(msg.sender, claimAddress, claimFn); /// @dev Emit event for claim generation
    }
}
