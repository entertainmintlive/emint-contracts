// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IOwnable2Step {
    /// @notice Get address of pending owner.
    /// @return address of the pending owner.
    function pendingOwner() external view returns (address);

    /// @notice Start ownership transfer to a new account. Replaces the pending
    /// transfer if there is one active. Can only be called by the current owner.
    /// @param newOwner address of the new owner
    function transferOwnership(address newOwner) external;

    /// @notice Accept a proposed ownership transfer. Can only be called by the
    /// pending owner address.
    function acceptOwnership() external;
}
