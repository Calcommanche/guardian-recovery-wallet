# Guardian Recovery Wallet

Security-focused educational smart wallet built with Solidity and Foundry.

This project upgrades a basic learning wallet with delegated spending, guardian-based owner recovery, event logging, custom errors, and test coverage. It is a portfolio project, not production-audited wallet infrastructure, and should not be used to custody real funds.

## Features

- Owner-managed guardians
- Three-guardian owner recovery
- Delegated ETH spending with allowances
- Custom errors and event logging
- Foundry tests for permissions, recovery, reverts, events, and calldata transfers

## Quick Start

```bash
forge build
forge test -vv
```

## Project Structure

```text
src/GuardianRecoveryWallet.sol
test/GuardianRecoveryWallet.t.sol
script/DeployGuardianRecoveryWallet.s.sol
SECURITY_NOTES.md
```

## Security Notes

See [SECURITY_NOTES.md](SECURITY_NOTES.md) for the threat model, duplicate guardian confirmation fix, current limitations, and future improvement ideas.
