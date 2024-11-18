/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title IdMapping
 * @author ZAMA
 * @notice Manages unique ID mappings between addresses and sequential IDs
 * @dev Inherits from Ownable2Step for secure ownership transfer
 */
contract IdMapping is Ownable2Step {
    /// Custom errors
    error IdAlreadyGenerated();
    error InvalidAddress();
    error IdOverflow();
    error NoIdGenerated();
    error InvalidId();
    error NoAddressFound();

    /// @notice Maps user addresses to their unique IDs
    mapping(address => uint256) public addressToId;
    /// @dev Maps unique IDs back to user addresses
    mapping(uint256 => address) private idToAddress;
    /// @dev Counter for assigning sequential IDs, starts at 1
    uint256 private nextId = 1;
    /// @dev Maximum possible ID value to prevent overflow
    uint256 private constant MAX_ID = type(uint256).max;

    /**
     * @notice Emitted when a new ID is generated for a user
     * @param user The address of the user receiving the ID
     * @param id The unique ID assigned to the user
     */
    event IdGenerated(address indexed user, uint256 indexed id);

    /**
     * @notice Initializes the contract with the deployer as owner
     * @dev Sets initial ID counter to 1
     */
    constructor() Ownable(msg.sender) {
        nextId = 1;
    }

    /**
     * @notice Generates a unique ID for the calling address
     * @dev Each address can only generate one ID. IDs are assigned sequentially starting from 1
     * @return uint256 The newly generated ID
     * @custom:throws IdAlreadyGenerated if caller already has an ID
     * @custom:throws InvalidAddress if caller is zero address
     * @custom:throws IdOverflow if maximum ID value is reached
     */
    function generateId() public returns (uint256) {
        if (addressToId[msg.sender] != 0) revert IdAlreadyGenerated();
        if (msg.sender == address(0)) revert InvalidAddress();
        if (nextId >= MAX_ID) revert IdOverflow();

        uint256 newId = nextId;

        addressToId[msg.sender] = newId;
        idToAddress[newId] = msg.sender;
        nextId++;

        emit IdGenerated(msg.sender, newId);
        return newId;
    }

    /**
     * @notice Looks up the ID associated with a given address
     * @dev Reverts if address has no ID or is zero address
     * @param _addr The address to lookup
     * @return uint256 The ID associated with the address
     * @custom:throws InvalidAddress if provided address is zero address
     * @custom:throws NoIdGenerated if address has no ID assigned
     */
    function getId(address _addr) public view returns (uint256) {
        if (_addr == address(0)) revert InvalidAddress();
        if (addressToId[_addr] == 0) revert NoIdGenerated();
        return addressToId[_addr];
    }

    /**
     * @notice Looks up the address associated with a given ID
     * @dev Reverts if ID is invalid or has no associated address
     * @param _id The ID to lookup
     * @return address The address associated with the ID
     * @custom:throws InvalidId if ID is 0 or greater than the last assigned ID
     * @custom:throws NoAddressFound if no address is associated with the ID
     */
    function getAddr(uint256 _id) public view returns (address) {
        if (_id <= 0 || _id >= nextId) revert InvalidId();
        address addr = idToAddress[_id];
        if (addr == address(0)) revert NoAddressFound();
        return addr;
    }

    /**
     * @notice Removes an address's ID mapping
     * @dev Only callable by contract owner. Removes both address->ID and ID->address mappings
     * @param _addr The address whose ID mapping should be reset
     * @custom:throws NoIdGenerated if address has no ID assigned
     */
    function resetIdForAddress(address _addr) external onlyOwner {
        uint256 id = addressToId[_addr];
        if (id == 0) revert NoIdGenerated();

        delete addressToId[_addr];
        delete idToAddress[id];
    }
}
