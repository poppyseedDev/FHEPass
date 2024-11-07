// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";

contract Diploma {
    // Mapping to store addresses with registrar role
    mapping(address => bool) public registrars;
    // Address of the contract owner
    address public owner;

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

    // Function to register a diploma, only callable by a registrar
    function registerDiploma(
        uint256 userId,
        einput university,
        einput degree,
        einput grade,
        bytes calldata inputProof
    ) public virtual onlyRegistrar returns (bool) {
        require(userId != 0, "ID not generated. Please call generateId first.");
        require(!registered[userId], "Diploma already registered!");

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
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].university;
    }

    // Function to get the encrypted degree type for a user
    function getMyDegree(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].degree;
    }

    // Function to get the encrypted grade for a user
    function getMyGrade(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].grade;
    }

    // Function to check if a diploma is registered for a user
    function hasDiploma(uint256 userId) public view returns (bool) {
        return registered[userId];
    }

    // Function to generate a claim for a diploma
    function generateClaim(address claimAddress, string memory claimFn) public {
        // Only the msg.sender that is registered under the user ID can make the claim
        uint256 userId = idMapping.getId(msg.sender);
        require(userId != 0, "ID not generated. Please call generateId first.");

        // Grant temporary access for graduate's data to be used in claim generation
        // TFHE.allowTransient(diplomaRecords[userId].grade, claimAddress);
        // TFHE.allowTransient(diplomaRecords[userId].university, claimAddress);
        TFHE.allowTransient(diplomaRecords[userId].degree, claimAddress);

        // Ensure the sender can access this graduate's data
        require(TFHE.isSenderAllowed(diplomaRecords[userId].degree), "Access to degree not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(abi.encodeWithSignature(claimFn, userId, address(this)));
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));

        emit ClaimGenerated(msg.sender, claimAddress, claimFn); // Emit event for claim generation
    }
}
