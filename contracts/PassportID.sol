// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PassportID
 * @author ZAMA
 * @notice Manages encrypted passport identity data and verification claims
 * @dev Implements role-based access control for registrars and admins to manage identity registration
 */
contract PassportID is AccessControl {
    /// @dev Constants
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /// @dev Custom errors
    error OnlyRegistrarAllowed();
    error InvalidRegistrarAddress();
    error CannotRemoveOwnerAsRegistrar();
    error AlreadyRegistered();
    error IdentityNotRegistered();
    error AccessNotPermitted();
    error ClaimGenerationFailed(bytes data);

    /**
     * @dev Structure to hold encrypted identity data
     * @param id Encrypted unique identifier for the identity record
     * @param biodata Encrypted biometric data like fingerprints or facial data
     * @param firstname Encrypted legal first name from passport
     * @param lastname Encrypted legal last name from passport
     * @param birthdate Encrypted date of birth in unix timestamp format
     */
    struct Identity {
        euint64 id; /// @dev Encrypted unique ID
        euint8 biodata; /// @dev Encrypted biodata (e.g., biometric data or hashed identity data)
        euint8 firstname; /// @dev Encrypted first name
        euint8 lastname; /// @dev Encrypted last name
        euint64 birthdate; /// @dev Encrypted birthdate for age verification
    }

    /// @dev Instance of IdMapping contract
    IdMapping private idMapping;

    /// @dev Mapping to store identities by user ID
    mapping(uint256 => Identity) private citizenIdentities;
    /// @dev Mapping to track registered identities
    mapping(uint256 => bool) public registered;

    /// @dev Event emitted when an identity is registered
    event IdentityRegistered(address indexed user);

    /**
     * @notice Initializes the passport identity management system
     * @dev Sets up FHEVM config and grants admin/registrar roles to deployer
     * @param _idMappingAddress Address of the IdMapping contract for user ID management
     */
    constructor(address _idMappingAddress) {
        TFHE.setFHEVM(FHEVMConfig.defaultConfig());
        idMapping = IdMapping(_idMappingAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); /// @dev Admin role for contract owner
        _grantRole(REGISTRAR_ROLE, msg.sender); /// @dev Registrar role for contract owner
    }

    /**
     * @notice Grants registrar privileges to a new address
     * @dev Only callable by admin role
     * @param registrar Address to be granted registrar permissions
     */
    function addRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Revokes registrar privileges from an address
     * @dev Only callable by admin role
     * @param registrar Address to have registrar permissions revoked
     */
    function removeRegistrar(address registrar) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(REGISTRAR_ROLE, registrar);
    }

    /**
     * @notice Creates a new encrypted identity record
     * @dev Only admin role can register new identities. All data is stored in encrypted form
     * @param userId Unique identifier for the user from IdMapping contract
     * @param biodata Encrypted biometric/identity data with proof
     * @param firstname Encrypted first name with proof
     * @param lastname Encrypted last name with proof
     * @param birthdate Encrypted birthdate with proof
     * @param inputProof Zero-knowledge proof validating the encrypted inputs
     * @return bool True if registration was successful
     * @custom:throws AlreadyRegistered if userId already has an identity registered
     */
    function registerIdentity(
        uint256 userId,
        einput biodata,
        einput firstname,
        einput lastname,
        einput birthdate,
        bytes calldata inputProof
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        if (registered[userId]) revert AlreadyRegistered();

        /// @dev Generate a new encrypted unique ID
        euint64 newId = TFHE.randEuint64();

        /// @dev Store the encrypted identity data
        citizenIdentities[userId] = Identity({
            id: newId,
            biodata: TFHE.asEuint8(biodata, inputProof),
            firstname: TFHE.asEuint8(firstname, inputProof),
            lastname: TFHE.asEuint8(lastname, inputProof),
            birthdate: TFHE.asEuint64(birthdate, inputProof)
        });

        registered[userId] = true; /// @dev Mark the identity as registered

        /// @dev Get the address associated with the user ID
        address addressToBeAllowed = idMapping.getAddr(userId);

        /// @dev Allow the user to access their own data
        TFHE.allow(citizenIdentities[userId].id, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].biodata, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].firstname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].lastname, addressToBeAllowed);
        TFHE.allow(citizenIdentities[userId].birthdate, addressToBeAllowed);

        /// @dev Allow the contract to access the data
        TFHE.allow(citizenIdentities[userId].id, address(this));
        TFHE.allow(citizenIdentities[userId].biodata, address(this));
        TFHE.allow(citizenIdentities[userId].firstname, address(this));
        TFHE.allow(citizenIdentities[userId].lastname, address(this));
        TFHE.allow(citizenIdentities[userId].birthdate, address(this));

        emit IdentityRegistered(addressToBeAllowed); /// @dev Emit event for identity registration

        return true;
    }

    /**
     * @notice Retrieves the complete encrypted identity record for a user
     * @dev Returns all encrypted identity fields as a tuple
     * @param userId ID of the user whose identity to retrieve
     * @return Tuple containing (id, biodata, firstname, lastname, birthdate)
     * @custom:throws IdentityNotRegistered if no identity exists for userId
     */
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

    /**
     * @notice Retrieves only the encrypted birthdate for a user
     * @dev Useful for age verification claims
     * @param userId ID of the user whose birthdate to retrieve
     * @return Encrypted birthdate as euint64
     * @custom:throws IdentityNotRegistered if no identity exists for userId
     */
    function getBirthdate(uint256 userId) public view virtual returns (euint64) {
        if (!registered[userId]) revert IdentityNotRegistered();
        return citizenIdentities[userId].birthdate;
    }

    /**
     * @notice Retrieves only the encrypted first name for a user
     * @dev Useful for identity verification claims
     * @param userId ID of the user whose first name to retrieve
     * @return Encrypted first name as euint8
     * @custom:throws IdentityNotRegistered if no identity exists for userId
     */
    function getMyIdentityFirstname(uint256 userId) public view virtual returns (euint8) {
        if (!registered[userId]) revert IdentityNotRegistered();
        return citizenIdentities[userId].firstname;
    }

    /**
     * @notice Generates a verification claim using the user's identity data
     * @dev Temporarily grants claim contract access to required encrypted data
     * @param claimAddress Contract address that will process the claim
     * @param claimFn Function signature in the claim contract to call
     * @custom:throws AccessNotPermitted if sender lacks permission to access data
     * @custom:throws ClaimGenerationFailed if external claim call fails
     */
    function generateClaim(address claimAddress, string memory claimFn) public {
        /// @dev Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);

        /// @dev Grant temporary access for citizen's birthdate to be used in claim generation
        TFHE.allowTransient(citizenIdentities[userId].birthdate, claimAddress);

        /// @dev Ensure the sender can access this citizen's birthdate
        if (!TFHE.isSenderAllowed(citizenIdentities[userId].birthdate)) revert AccessNotPermitted();

        /// @dev Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId));
        if (!success) revert ClaimGenerationFailed(data);
    }
}
