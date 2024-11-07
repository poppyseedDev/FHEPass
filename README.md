# Decentralized Identity (DID) Contract System

The DID contract system provides a framework for managing decentralized identities (DIDs) on-chain, using fully homomorphic encryption (FHE) for confidential data. This setup includes tools to create, manage, and verify identity claims securely on the blockchain, leveraging Zama's FHE technology and allowing DIDs to be integrated seamlessly with external contracts, such as employer or credential verification systems.

- [fhEVM](https://github.com/zama-ai/fhevm): Enables confidential smart contracts by allowing encrypted data operations directly on-chain.
- [TFHE Solidity Library](https://github.com/zama-ai/fhevm/blob/main/examples): Provides support for encrypted types and permissions, facilitating privacy-preserving DIDs.

## Getting Started

To start using the DID system, you’ll need to set up a local environment that includes the `fhEVM` for encrypted smart contracts.

### Prerequisites

1. Install [Docker](https://docs.docker.com/engine/install/)
2. Install [pnpm](https://pnpm.io/installation)
3. Use **Node.js v20** or later

Then create a `.env` file to store environment variables (see `.env.example` for an example).

### Setup and Run

1. **Install Dependencies**:
    ```sh
    pnpm install
    ```

2. **Start fhEVM Node**:
   Set up and run a local `fhEVM` node using Docker to enable encrypted smart contract testing and deployment:
   ```sh
   pnpm fhevm:start
   ```
   Allow 2–3 minutes for initialization. Monitor logs to confirm the node is ready.

3. **Run Tests**:
   Open a new terminal and execute:
   ```sh
   pnpm test
   ```

4. **Stop fhEVM Node**:
   After tests, stop the `fhEVM` node:
   ```sh
   pnpm fhevm:stop
   ```

## Contract Overview

The DID contract manages core identity data and allows the creation of encrypted identity claims for external verification. An example structure for the `DID` and `EmployerClaim` contracts is as follows:

### DID Contract

```solidity
contract DID {
  struct Identity {
    uint256 id;
    bytes32 biodata;   // Encrypted bio information
    string firstname;
    string lastname;
    euint64 birthdate; // Encrypted birthdate
  }

  // Maps each address to an Identity
  mapping(address => Identity) public citizens;

  function getCitizen(address wallet) public view returns (Identity memory) {
    return citizens[wallet];
  }

  function generateClaim(address claimAddress, string memory claimFn, string[] memory fields, address contract) public {
    uint256 citizenId = citizens[msg.sender].id;
    for (uint i = 0; i < fields.length; i++) {
      TFHE.allowTransient(citizens[msg.sender][fields[i]], claimAddress);
    }
    claimAddress.call(abi.encodeWithSignature(claimFn, citizenId, contract));
  }
}
```

### EmployerClaim Contract

```solidity
contract EmployerClaim {
  address didAddress;

  mapping(uint256 => ebool) public employerClaims;

  function generateAdultClaim(uint id, address contract) public returns (bytes32) {
    euint64 birthdate = DID(didAddress).getCitizen(id).birthdate;
    bytes32 claimId = keccak256("age_check");
    employerClaims[claimId] = TFHE.ge(birthdate, 18); // Check if birthdate meets age threshold
    TFHE.allow(employerClaims[claimId], contract);
    return claimId;
  }
}
```

## Features

### Identity and Claim Management
- **Identity Creation**: Each DID is created and managed in the `DID` contract, linking an `Identity` struct to an address.
- **Encrypted Claims**: Using FHE, claims are generated and stored as encrypted data, protecting sensitive identity information.

### Access Control with Transient Permissions
- **Claim Generation**: Allows external contracts to verify claims, with permissions granted for each field temporarily.
- **Employer Claims**: Employers can verify specific claims (e.g., age) without accessing sensitive data directly.

## Usage

### Compile Contracts

```sh
pnpm compile
```

### TypeChain Bindings

Generate TypeChain bindings for TypeScript:

```sh
pnpm typechain
```

### Run Tests

Run tests to verify contract functionality:

```sh
pnpm test
```

### Additional Commands

**List Accounts**:

```sh
pnpm task:accounts
```

**Get Native Tokens**:

```sh
pnpm fhevm:faucet
```

## Mocked Mode for Testing

The mocked mode provides a faster way to test and analyze code coverage. In this mode, encryption is disabled, enabling local testing without the need for actual encryption on `fhEVM`.

```sh
pnpm test:mock
```

For code coverage:

```sh
pnpm coverage:mock
```

## Syntax Highlighting

For VSCode users, [Solidity syntax highlighting](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) is recommended.

## License

This project is licensed under the MIT License.
