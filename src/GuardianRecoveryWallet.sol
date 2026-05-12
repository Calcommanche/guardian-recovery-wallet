// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GuardianRecoveryWallet {
    address payable public owner;
    address payable public nextOwner;

    uint256 public constant REQUIRED_GUARDIAN_CONFIRMATIONS = 3;
    uint256 public guardianResetCount;

    mapping(address => uint256) public allowance;
    mapping(address => bool) public isAllowedToSend;
    mapping(address => bool) public guardian;
    mapping(address => mapping(address => bool)) public hasConfirmedReset;

    error NotOwner();
    error NotGuardian();
    error NotAllowed();
    error AllowanceTooLow();
    error InsufficientBalance();
    error TransactionFailed();
    error AlreadyConfirmed();

    event Deposit(address indexed sender, uint256 amount);
    event AllowanceChanged(address indexed user, uint256 amount);
    event SendingDenied(address indexed user);
    event GuardianSet(address indexed guardian, bool status);
    event OwnerResetProposed(address indexed guardian, address indexed proposedOwner);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event TransferExecuted(address indexed by, address indexed to, uint256 amount, bytes data);

    constructor() {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function setGuardian(address _guardian, bool _status) external onlyOwner {
        guardian[_guardian] = _status;
        emit GuardianSet(_guardian, _status);
    }

    function proposeNewOwner(address payable newOwner) external {
        if (!guardian[msg.sender]) revert NotGuardian();

        if (nextOwner != newOwner) {
            nextOwner = newOwner;
            guardianResetCount = 0;
        }

        if (hasConfirmedReset[newOwner][msg.sender]) revert AlreadyConfirmed();

        hasConfirmedReset[newOwner][msg.sender] = true;
        guardianResetCount++;

        emit OwnerResetProposed(msg.sender, newOwner);

        if (guardianResetCount >= REQUIRED_GUARDIAN_CONFIRMATIONS) {
            address oldOwner = owner;
            owner = nextOwner;
            nextOwner = payable(address(0));
            guardianResetCount = 0;

            emit OwnerChanged(oldOwner, owner);
        }
    }

    function setAllowance(address user, uint256 amount) external onlyOwner {
        allowance[user] = amount;
        isAllowedToSend[user] = amount > 0;

        emit AllowanceChanged(user, amount);
    }

    function denySending(address user) external onlyOwner {
        isAllowedToSend[user] = false;
        allowance[user] = 0;

        emit SendingDenied(user);
    }

    function transfer(
        address payable to,
        uint256 amount,
        bytes calldata payload
    ) external returns (bytes memory) {
        if (amount > address(this).balance) revert InsufficientBalance();

        if (msg.sender != owner) {
            if (!isAllowedToSend[msg.sender]) revert NotAllowed();
            if (allowance[msg.sender] < amount) revert AllowanceTooLow();

            allowance[msg.sender] -= amount;
        }

        (bool success, bytes memory returnData) = to.call{ value: amount }(payload);
        if (!success) revert TransactionFailed();

        emit TransferExecuted(msg.sender, to, amount, payload);

        return returnData;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
