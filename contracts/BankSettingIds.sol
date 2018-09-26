pragma solidity ^0.4.24;

import "@evolutionland/common/contracts/SettingIds.sol";
import "@evolutionland/common/contracts/interfaces/ISettingsRegistry.sol";

contract BankSettingIds is SettingIds {

    // depositing X RING for 12 months, interest is about (1 * _unitInterest * X / 10**7) KTON
    // default: 1000
    bytes32 public constant UINT_BANK_UNIT_INTEREST = "UINT_BANK_UNIT_INTEREST";

    // penalty multiplier
    // default: 3
    bytes32 public constant UINT_BANK_PENALTY_MULTIPLIER = "UINT_BANK_PENALTY_MULTIPLIER";
}