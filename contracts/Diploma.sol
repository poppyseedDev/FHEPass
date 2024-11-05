// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

contract Diploma {
    struct DiplomaData {
        euint64 id; // Encrypted unique diploma ID
        euint8 university; // Encrypted university identifier
        euint8 degree; // Encrypted degree type
        euint8 grade; // Encrypted grade
    }

    mapping(address => DiplomaData) private diplomaRecords;
    mapping(address => bool) public registered;

    event DiplomaRegistered(address indexed graduate);
    event ClaimGenerated(address indexed graduate, euint64 claimId);

    function registerDiploma(
        einput university,
        einput degree,
        einput grade,
        bytes calldata inputProof
    ) public virtual returns (bool) {
        require(!registered[msg.sender], "Diploma already registered!");

        euint64 newId = TFHE.randEuint64();

        diplomaRecords[msg.sender] = DiplomaData({
            id: newId,
            university: TFHE.asEuint8(university, inputProof),
            degree: TFHE.asEuint8(degree, inputProof),
            grade: TFHE.asEuint8(grade, inputProof)
        });

        registered[msg.sender] = true;

        // Allow the graduate to access their own data
        TFHE.allow(diplomaRecords[msg.sender].id, msg.sender);
        TFHE.allow(diplomaRecords[msg.sender].university, msg.sender);
        TFHE.allow(diplomaRecords[msg.sender].degree, msg.sender);
        TFHE.allow(diplomaRecords[msg.sender].grade, msg.sender);

        // Allow the contract to access the data
        TFHE.allow(diplomaRecords[msg.sender].id, address(this));
        TFHE.allow(diplomaRecords[msg.sender].university, address(this));
        TFHE.allow(diplomaRecords[msg.sender].degree, address(this));
        TFHE.allow(diplomaRecords[msg.sender].grade, address(this));

        emit DiplomaRegistered(msg.sender);

        return true;
    }

    function getMyUniversity(address graduate) public view virtual returns (euint8) {
        require(registered[graduate], "Diploma not registered!");
        return diplomaRecords[graduate].university;
    }

    function generateClaim(address claimAddress, string memory claimFn) public {
        // Grant temporary access for graduate's data to be used in claim generation
        TFHE.allowTransient(diplomaRecords[msg.sender].grade, claimAddress);
        TFHE.allowTransient(diplomaRecords[msg.sender].university, claimAddress);
        TFHE.allowTransient(diplomaRecords[msg.sender].degree, claimAddress);

        // Ensure the sender can access this graduate's data
        require(TFHE.isSenderAllowed(diplomaRecords[msg.sender].grade), "Access to grade not permitted");

        // Attempt the external call and capture the result
        (bool success, bytes memory data) = claimAddress.call(
            abi.encodeWithSignature(claimFn, msg.sender, address(this))
        );
        require(success, string(abi.encodePacked("Claim generation failed: ", data)));
    }
}
