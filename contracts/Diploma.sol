// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";
import "./IdMapping.sol";

contract Diploma {
    // Add role for diploma registrars
    mapping(address => bool) public registrars;
    address public owner;

    struct DiplomaData {
        euint64 id; // Encrypted unique diploma ID
        euint8 university; // Encrypted university identifier
        euint8 degree; // Encrypted degree type
        euint8 grade; // Encrypted grade
    }

    IdMapping private idMapping;

    mapping(uint256 => DiplomaData) private diplomaRecords;
    mapping(uint256 => bool) public registered;

    event DiplomaRegistered(address indexed graduate);
    event ClaimGenerated(address indexed graduate, address claimAddress, string claimFn);
    event RegistrarAdded(address indexed registrar);
    event RegistrarRemoved(address indexed registrar);

    constructor(address _idMappingAddress) {
        idMapping = IdMapping(_idMappingAddress);
        owner = msg.sender;
        registrars[msg.sender] = true;
    }

    // Modifier for registrar access - everyone at the university who has a right to make changes to the diploma
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

    // only registrar can submit a diploma for specific id
    function registerDiploma(
        uint256 userId,
        einput university,
        einput degree,
        einput grade,
        bytes calldata inputProof
    ) public virtual onlyRegistrar returns (bool) {
        require(userId != 0, "ID not generated. Please call generateId first.");

        require(!registered[userId], "Diploma already registered!");

        euint64 newId = TFHE.randEuint64();

        diplomaRecords[userId] = DiplomaData({
            id: newId,
            university: TFHE.asEuint8(university, inputProof),
            degree: TFHE.asEuint8(degree, inputProof),
            grade: TFHE.asEuint8(grade, inputProof)
        });

        registered[userId] = true;

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

        emit DiplomaRegistered(addressToBeAllowed);

        return true;
    }

    function getMyUniversity(uint256 userId) public view returns (euint8) {
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].university;
    }

    function getMyDegree(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].degree;
    }

    // grade getter
    function getMyGrade(uint256 userId) public view virtual returns (euint8) {
        require(registered[userId], "Diploma not registered!");
        return diplomaRecords[userId].grade;
    }

    // Diploma existence check
    function hasDiploma(uint256 userId) public view returns (bool) {
        return registered[userId];
    }

    function generateClaim(address claimAddress, string memory claimFn) public {
        // only the msg.sender that is registered under the user id can make the claim
        uint256 userId = idMapping.getId(msg.sender);
        require(userId != 0, "ID not generated. Please call generateId first.");

        // Grant temporary access for graduate's data to be used in claim generation
        // TFHE.allowTransient(diplomaRecords[userId].grade, claimAddress);
        // TFHE.allowTransient(diplomaRecords[userId].university, claimAddress);
        TFHE.allowTransient(diplomaRecords[userId].degree, claimAddress);

        // Ensure the sender can access this graduate's data
        require(TFHE.isSenderAllowed(diplomaRecords[userId].degree), "Access to degree not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(
            abi.encodeWithSignature(claimFn, msg.sender, address(this))
        );
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));

        emit ClaimGenerated(msg.sender, claimAddress, claimFn);
    }
}
