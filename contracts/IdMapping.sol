// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract IdMapping is Ownable2Step {
    // Custom errors
    error IdAlreadyGenerated();
    error InvalidAddress();
    error IdOverflow();
    error NoIdGenerated();
    error InvalidId();
    error NoAddressFound();

    // Mapping from address to unique ID
    mapping(address => uint256) public addressToId;
    // Mapping from unique ID to address
    mapping(uint256 => address) private idToAddress;
    // Counter for the next ID to be assigned
    uint256 private nextId = 1;
    // Maximum allowed ID value
    uint256 private constant MAX_ID = type(uint256).max;

    // Event emitted when a new ID is generated for a user
    event IdGenerated(address indexed user, uint256 indexed id);

    constructor() Ownable(msg.sender) {
        // Initialize the counter to start from 1
        nextId = 1;
    }

    // Function to generate and set a new ID for an address
    function generateId() public returns (uint256) {
        // Ensure the caller does not already have an ID
        if (addressToId[msg.sender] != 0) revert IdAlreadyGenerated();
        // Ensure the caller's address is valid
        if (msg.sender == address(0)) revert InvalidAddress();
        // Check for overflow before incrementing
        if (nextId >= MAX_ID) revert IdOverflow();

        // Assign the next available ID
        uint256 newId = nextId;

        // Map the caller's address to the new ID
        addressToId[msg.sender] = newId;
        // Map the new ID to the caller's address
        idToAddress[newId] = msg.sender;
        // Increment the ID counter for the next user
        nextId++;

        // Emit an event to signal that a new ID has been generated
        emit IdGenerated(msg.sender, newId);
        return newId;
    }

    // Function to retrieve the ID for a given address
    function getId(address _addr) public view returns (uint256) {
        // Ensure the provided address is valid
        if (_addr == address(0)) revert InvalidAddress();
        // Ensure an ID has been generated for the provided address
        if (addressToId[_addr] == 0) revert NoIdGenerated();
        return addressToId[_addr];
    }

    // Function to retrieve the address for a given ID
    function getAddr(uint256 _id) public view returns (address) {
        // Ensure the provided ID is within the valid range
        if (_id == 0 || _id >= nextId) revert InvalidId();
        // Retrieve the address associated with the provided ID
        address addr = idToAddress[_id];
        // Ensure an address is found for the provided ID
        if (addr == address(0)) revert NoAddressFound();
        return addr;
    }

    // Owner-only function to reset an address's ID
    function resetIdForAddress(address _addr) external onlyOwner {
        // Ensure the provided address is valid and has an ID
        uint256 id = addressToId[_addr];
        if (id == 0) revert NoIdGenerated();

        // Reset mappings
        delete addressToId[_addr];
        delete idToAddress[id];
    }
}
