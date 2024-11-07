// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IdMapping {
    mapping(address => uint256) public addressToId;
    mapping(uint256 => address) private idToAddress;
    uint256 private nextId = 1;

    event IdGenerated(address indexed user, uint256 indexed id);

    // Function to generate and set a new ID for an address
    function generateId() public returns (uint256) {
        require(addressToId[msg.sender] == 0, "ID already generated for this address");
        require(msg.sender != address(0), "Invalid address");

        uint256 newId = nextId;
        // Check for overflow
        require(newId > 0, "ID overflow");

        addressToId[msg.sender] = newId;
        idToAddress[newId] = msg.sender;
        nextId++;

        emit IdGenerated(msg.sender, newId);
        return newId;
    }

    // Function to retrieve the ID for a given address
    function getId(address _addr) public view returns (uint256) {
        require(_addr != address(0), "Invalid address");
        require(addressToId[_addr] != 0, "No ID generated for this address");
        return addressToId[_addr];
    }

    // Function to retrieve the address for a given ID
    function getAddr(uint256 _id) public view returns (address) {
        require(_id > 0 && _id < nextId, "Invalid ID");
        address addr = idToAddress[_id];
        require(addr != address(0), "No address found for this ID");
        return addr;
    }
}
