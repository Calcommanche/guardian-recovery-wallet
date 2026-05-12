# Guardian Recovery Wallet

Guardian Recovery Wallet is a clean Foundry Solidity portfolio project that upgrades a basic learning wallet with delegated spending, guardian-based owner recovery, event logging, custom errors, and focused tests.

This is intentionally educational. It is not production-audited wallet infrastructure and should not be used to custody real funds.

## Features

- Owner-controlled guardian management
- Three-guardian owner recovery flow
- Delegated spending with per-address allowances
- Owner-only allowance revocation
- ETH transfers with optional calldata payloads
- Events for deposits, allowance changes, guardian changes, recovery proposals, owner changes, and transfers
- Custom errors instead of string reverts
- Foundry tests covering happy paths, access control, reverts, event emission, and payload calls

## Project Structure

```text
.
|-- foundry.toml
|-- script/
|   `-- DeployGuardianRecoveryWallet.s.sol
|-- src/
|   `-- GuardianRecoveryWallet.sol
`-- test/
    `-- GuardianRecoveryWallet.t.sol
```

## Getting Started

Install Foundry if you do not already have it:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Build and test:

```bash
forge build
forge test -vv
```

Format Solidity files:

```bash
forge fmt
```

## Contract Overview

The wallet stores a single `owner` address. The owner can:

- add or remove guardians
- assign spending allowance to another address
- revoke a spender
- transfer ETH from the wallet without needing allowance

Approved spenders can transfer ETH up to their allowance. Each delegated transfer reduces the spender's remaining allowance.

Guardians can propose a new owner. When three guardians confirm the same proposed owner, ownership changes to that address.

## Limitations

- Guardian confirmations are tracked by proposed owner and guardian, and this sample does not clear old confirmation mappings after recovery.
- There is no guardian timelock, delay period, cancel function, or recovery dispute process.
- There is no signature validation, ERC-4337 account abstraction support, module system, nonce tracking, or replay protection beyond normal transaction semantics.
- The wallet only handles native ETH directly. ERC-20 or NFT recovery would require additional calls and review.
- A compromised owner can change guardians or allowances immediately.
- A compromised quorum of guardians can replace the owner.
- The project has tests, but it has not been audited or formally verified.

## Portfolio Notes

This project is best presented as a learning wallet that demonstrates Solidity fundamentals and security-oriented design patterns:

- explicit access control
- custom errors
- event-driven observability
- low-level call handling
- stateful recovery logic
- Foundry unit tests

Do not market it as a hardened smart account or audited multisig replacement.
