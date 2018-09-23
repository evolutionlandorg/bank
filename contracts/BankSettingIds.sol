pragma solidity ^0.4.24;

import '@evolutionland/common/contracts/SettingIds.sol';
import '@evolutionland/common/contracts/interfaces/ISettingsRegistry.sol';

contract BankSettingIds is SettingIds {

    // amount of kryptonite after depositing 1 ring for 1 month
    // default: 10000 RING for 1 year is 1 KTON.
    // uint public unitInterest_;
    // interst of per ring per month, 0.0005 ring recommended
    bytes32 public constant UINT_BANK_UNIT_INTEREST = "UINT_BANK_UNIT_INTEREST";

    // penalty multiplier
    // default: 3
    // uint public penaltyMultiplier_;
    bytes32 public constant UINT_BANK_PENALTY_MULTIPLIER = "UINT_BANK_PENALTY_MULTIPLIER";
}