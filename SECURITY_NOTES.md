# Security Notes

Guardian Recovery Wallet is an educational portfolio project. It demonstrates common Solidity wallet patterns, but it is not audited, hardened, or intended for real funds.

## Duplicate Guardian Confirmation Fix

The recovery flow requires three guardian confirmations for the same proposed owner. A common bug in this kind of design is allowing one guardian to confirm the same recovery proposal more than once, which would let a single guardian inflate the confirmation count.

This project prevents that with:

```solidity
mapping(address => mapping(address => bool)) public hasConfirmedReset;
```

The first key is the proposed new owner, and the second key is the guardian address. In `proposeNewOwner`, the contract checks whether that guardian has already confirmed that proposed owner:

```solidity
if (hasConfirmedReset[newOwner][msg.sender]) revert AlreadyConfirmed();
```

Only after that check passes does the contract mark the guardian as having confirmed and increment `guardianResetCount`. The test `testGuardianCannotConfirmSameProposedOwnerTwice` covers this behavior.

When guardians switch to a different proposed owner, `nextOwner` changes and `guardianResetCount` resets. This is covered by `testChangingProposedOwnerResetsCount`.

## Threat Model

This wallet focuses on a narrow learning scenario:

- The owner is trusted to manage guardians and spending allowances.
- Guardians are trusted recovery participants.
- A delegated spender may transfer ETH only up to their assigned allowance.
- External recipients may be arbitrary contracts, and transfers may include calldata.
- Observers can monitor wallet activity through emitted events.

The design tries to reduce these risks:

- Unauthorized users setting guardians or allowances
- Unauthorized users spending wallet funds
- Delegated spenders exceeding their allowance
- A single guardian completing account recovery alone
- Silent state changes without event logs
- Failed low-level calls being treated as successful transfers

## Current Limitations

- Guardian confirmations are not cleared from `hasConfirmedReset` after a successful recovery.
- There is no recovery delay, cancel function, challenge window, or timelock.
- There is no minimum or maximum guardian set size.
- The owner can immediately add or remove guardians.
- A compromised owner can drain funds, change guardians, or grant allowances.
- A compromised quorum of guardians can replace the owner.
- The contract only handles native ETH directly.
- There is no ERC-20, ERC-721, or ERC-1155 recovery helper.
- There is no signature validation, nonce system, ERC-1271 support, or ERC-4337 account abstraction integration.
- The low-level transfer function intentionally supports calldata, so recipients can execute arbitrary logic.
- There is no reentrancy guard. Current state changes happen before the external call for delegated allowance deduction, but this project has not been audited for all reentrancy scenarios.
- There is no formal verification, invariant suite, fuzzing campaign, or third-party audit.

## Future Improvements

- Track guardian confirmations by proposal ID instead of proposed owner alone.
- Clear old guardian confirmations after recovery or proposal cancellation.
- Add a recovery delay and owner cancellation path.
- Add guardian add/remove delays for stronger compromise resistance.
- Add configurable guardian thresholds.
- Add events that include remaining allowance after delegated transfers.
- Add ERC-20 and NFT recovery helpers.
- Add fuzz and invariant tests for recovery and delegated spending.
- Add reentrancy analysis and, if needed, a reentrancy guard.
- Add signature-based spending approvals.
- Explore ERC-1271 and ERC-4337 compatibility as separate learning milestones.

## Portfolio Framing

Present this as a learning project that demonstrates access control, event design, custom errors, stateful recovery logic, low-level calls, and Foundry testing.

Do not present it as a production smart account, multisig replacement, or audited recovery wallet.
