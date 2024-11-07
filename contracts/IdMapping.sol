// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IdMapping {
    // Mapping from address to unique ID
    mapping(address => uint256) public addressToId;
    // Mapping from unique ID to address
    mapping(uint256 => address) private idToAddress;
    // Counter for the next ID to be assigned
    uint256 private nextId = 1;

    // Event emitted when a new ID is generated for a user
    event IdGenerated(address indexed user, uint256 indexed id);

    // Function to generate and set a new ID for an address
    function generateId() public returns (uint256) {
        // Ensure the caller does not already have an ID
        require(addressToId[msg.sender] == 0, "ID already generated for this address");
        // Ensure the caller's address is valid
        require(msg.sender != address(0), "Invalid address");

        // Assign the next available ID
        uint256 newId = nextId;
        // Check for overflow of the ID counter
        require(newId > 0, "ID overflow");

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
        require(_addr != address(0), "Invalid address");
        // Ensure an ID has been generated for the provided address
        require(addressToId[_addr] != 0, "No ID generated for this address");
        return addressToId[_addr];
    }

    // Function to retrieve the address for a given ID
    function getAddr(uint256 _id) public view returns (address) {
        // Ensure the provided ID is within the valid range
        require(_id > 0 && _id < nextId, "Invalid ID");
        // Retrieve the address associated with the provided ID
        address addr = idToAddress[_id];
        // Ensure an address is found for the provided ID
        require(addr != address(0), "No address found for this ID");
        return addr;
    }
}
