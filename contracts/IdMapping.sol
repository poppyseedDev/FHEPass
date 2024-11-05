// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IdMapping {
    mapping(address => uint256) public addressToId;
    uint256 private nextId = 1;

    // Function to generate and set a new ID for an address
    function generateId() public returns (uint256) {
        require(addressToId[msg.sender] == 0, "ID already generated for this address");

        uint256 newId = nextId;
        addressToId[msg.sender] = newId;
        nextId++;

        return newId;
    }

    // Function to retrieve the ID for a given address
    function getId(address _addr) public view returns (uint256) {
        require(addressToId[_addr] != 0, "No ID generated for this address");
        return addressToId[_addr];
    }
}
