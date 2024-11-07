// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

interface IPassportID {
    // Register a new identity
    function registerIdentity(
        einput biodata,
        einput firstname,
        einput lastname,
        einput birthdate,
        bytes calldata inputProof
    ) external returns (bool);

    // Retrieve encrypted identity data
    function getIdentity(address user) external view returns (euint64, euint8, euint8, euint8, euint64);

    // Retrieve encrypted birthdate
    function getBirthdate(address user) external view returns (euint64);

    // Retrieve encrypted firstname
    function getMyIdentityFirstname(address user) external view returns (euint8);

    // Generate claim with transient access
    function generateClaim(address claimAddress, string memory claimFn) external;

    // Public mapping getter
    function registered(address) external view returns (bool);
}
