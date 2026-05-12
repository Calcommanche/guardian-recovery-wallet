// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/GuardianRecoveryWallet.sol";

interface Vm {
    function deal(address account, uint256 newBalance) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function expectRevert(bytes4 revertData) external;
    function prank(address msgSender) external;
}

contract GuardianRecoveryWalletTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    GuardianRecoveryWallet private wallet;

    address payable private owner = payable(address(0xA11CE));
    address payable private newOwner = payable(address(0xB0B));
    address payable private recipient = payable(address(0xCAFE));
    address private spender = address(0xDAD);
    address private guardianOne = address(0x1);
    address private guardianTwo = address(0x2);
    address private guardianThree = address(0x3);
    address private stranger = address(0xBAD);

    event Deposit(address indexed sender, uint256 amount);
    event AllowanceChanged(address indexed user, uint256 amount);
    event SendingDenied(address indexed user);
    event GuardianSet(address indexed guardian, bool status);
    event OwnerResetProposed(address indexed guardian, address indexed proposedOwner);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event TransferExecuted(address indexed by, address indexed to, uint256 amount, bytes data);

    function setUp() public {
        vm.prank(owner);
        wallet = new GuardianRecoveryWallet();

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);
    }

    function testConstructorSetsOwner() public view {
        assertEq(wallet.owner(), owner);
    }

    function testReceiveEmitsDeposit() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(this), 1 ether);

        (bool success,) = address(wallet).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(wallet).balance, 1 ether);
    }

    function testOnlyOwnerCanSetGuardian() public {
        vm.expectRevert(GuardianRecoveryWallet.NotOwner.selector);
        wallet.setGuardian(guardianOne, true);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit GuardianSet(guardianOne, true);
        wallet.setGuardian(guardianOne, true);

        assertTrue(wallet.guardian(guardianOne));
    }

    function testGuardiansCanRecoverOwnerAfterThreeConfirmations() public {
        _setThreeGuardians();

        vm.prank(guardianOne);
        vm.expectEmit(true, true, false, true);
        emit OwnerResetProposed(guardianOne, newOwner);
        wallet.proposeNewOwner(newOwner);

        assertEq(wallet.nextOwner(), newOwner);
        assertEq(wallet.guardianResetCount(), 1);

        vm.prank(guardianTwo);
        wallet.proposeNewOwner(newOwner);

        vm.prank(guardianThree);
        vm.expectEmit(true, true, false, true);
        emit OwnerResetProposed(guardianThree, newOwner);
        vm.expectEmit(true, true, false, true);
        emit OwnerChanged(owner, newOwner);
        wallet.proposeNewOwner(newOwner);

        assertEq(wallet.owner(), newOwner);
        assertEq(wallet.nextOwner(), address(0));
        assertEq(wallet.guardianResetCount(), 0);
    }

    function testNonGuardianCannotProposeOwnerReset() public {
        vm.prank(stranger);
        vm.expectRevert(GuardianRecoveryWallet.NotGuardian.selector);
        wallet.proposeNewOwner(newOwner);
    }

    function testGuardianCannotConfirmSameProposedOwnerTwice() public {
        _setThreeGuardians();

        vm.prank(guardianOne);
        wallet.proposeNewOwner(newOwner);

        vm.prank(guardianOne);
        vm.expectRevert(GuardianRecoveryWallet.AlreadyConfirmed.selector);
        wallet.proposeNewOwner(newOwner);
    }

    function testChangingProposedOwnerResetsCount() public {
        _setThreeGuardians();
        address payable alternateOwner = payable(address(0xF00D));

        vm.prank(guardianOne);
        wallet.proposeNewOwner(newOwner);

        vm.prank(guardianTwo);
        wallet.proposeNewOwner(alternateOwner);

        assertEq(wallet.nextOwner(), alternateOwner);
        assertEq(wallet.guardianResetCount(), 1);
    }

    function testOwnerCanSetAndDenyAllowance() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit AllowanceChanged(spender, 2 ether);
        wallet.setAllowance(spender, 2 ether);

        assertEq(wallet.allowance(spender), 2 ether);
        assertTrue(wallet.isAllowedToSend(spender));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SendingDenied(spender);
        wallet.denySending(spender);

        assertEq(wallet.allowance(spender), 0);
        assertFalse(wallet.isAllowedToSend(spender));
    }

    function testAllowedSpenderCanTransferWithinAllowance() public {
        _fundWallet(5 ether);

        vm.prank(owner);
        wallet.setAllowance(spender, 2 ether);

        bytes memory payload = "";
        vm.prank(spender);
        vm.expectEmit(true, true, false, true);
        emit TransferExecuted(spender, recipient, 1 ether, payload);
        wallet.transfer(recipient, 1 ether, payload);

        assertEq(wallet.allowance(spender), 1 ether);
        assertEq(recipient.balance, 1 ether);
    }

    function testOwnerCanTransferWithoutAllowance() public {
        _fundWallet(5 ether);

        vm.prank(owner);
        wallet.transfer(recipient, 2 ether, "");

        assertEq(recipient.balance, 2 ether);
    }

    function testUnauthorizedSpenderCannotTransfer() public {
        _fundWallet(5 ether);

        vm.prank(stranger);
        vm.expectRevert(GuardianRecoveryWallet.NotAllowed.selector);
        wallet.transfer(recipient, 1 ether, "");
    }

    function testSpenderCannotExceedAllowance() public {
        _fundWallet(5 ether);

        vm.prank(owner);
        wallet.setAllowance(spender, 1 ether);

        vm.prank(spender);
        vm.expectRevert(GuardianRecoveryWallet.AllowanceTooLow.selector);
        wallet.transfer(recipient, 2 ether, "");
    }

    function testCannotTransferMoreThanWalletBalance() public {
        vm.prank(owner);
        vm.expectRevert(GuardianRecoveryWallet.InsufficientBalance.selector);
        wallet.transfer(recipient, 1 ether, "");
    }

    function testRevertsWhenRecipientCallFails() public {
        _fundWallet(5 ether);
        RevertingRecipient rejectingRecipient = new RevertingRecipient();

        vm.prank(owner);
        vm.expectRevert(GuardianRecoveryWallet.TransactionFailed.selector);
        wallet.transfer(payable(address(rejectingRecipient)), 1 ether, "");
    }

    function testTransferCanCallRecipientPayload() public {
        _fundWallet(5 ether);
        PayloadRecipient payloadRecipient = new PayloadRecipient();
        bytes memory payload = abi.encodeCall(PayloadRecipient.recordPayment, (42));

        vm.prank(owner);
        bytes memory returnData = wallet.transfer(payable(address(payloadRecipient)), 1 ether, payload);

        assertEq(payloadRecipient.lastValue(), 42);
        assertEq(address(payloadRecipient).balance, 1 ether);
        assertEq(abi.decode(returnData, (uint256)), 84);
    }

    function _setThreeGuardians() private {
        vm.prank(owner);
        wallet.setGuardian(guardianOne, true);

        vm.prank(owner);
        wallet.setGuardian(guardianTwo, true);

        vm.prank(owner);
        wallet.setGuardian(guardianThree, true);
    }

    function _fundWallet(uint256 amount) private {
        (bool success,) = address(wallet).call{ value: amount }("");
        assertTrue(success);
    }

    function assertTrue(bool condition) private pure {
        require(condition, "expected true");
    }

    function assertFalse(bool condition) private pure {
        require(!condition, "expected false");
    }

    function assertEq(address actual, address expected) private pure {
        require(actual == expected, "address mismatch");
    }

    function assertEq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "uint256 mismatch");
    }
}

contract RevertingRecipient {
    receive() external payable {
        revert("rejecting funds");
    }
}

contract PayloadRecipient {
    uint256 public lastValue;

    function recordPayment(uint256 value) external payable returns (uint256) {
        lastValue = value;
        return value * 2;
    }
}
