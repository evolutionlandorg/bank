pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';


contract BankBase {

    /*==============
     |   variables  |
     ===============*/

    // token contract
    ERC20 public ring_;

    // bounty contract
    ERC20 public kryptonite_;

    // deposit
    struct Deposit {
        // amount of ring
        uint128 value;
        // Length of time from the deposit's beginning to end (in months)
        // For now, months must >= 1 and <= 36
        uint128 months;
        // when player deposit, timestamp in seconds
        uint startAt;
    }

    uint public constant MONTH = 4 * 1 weeks;

    // amount of kryptonite after depositing 1 ring for 1 month
    uint public unitInterest_;

    // penalty multiplier
    uint public penaltyMultiplier_; // 3;

    // player => depositID => Deposit
    mapping (address => mapping (uint256 => Deposit)) public playerDepositInfo_;

    // player => number of deposit
    mapping (address => uint256) public playerDepositNumber_;

    // player => depositID => isOpen
    //  true for isopen, false for withdrawed or does not exist
    mapping (address => mapping (uint256 => bool)) public palyerDepositIsOpen_;

    // player => totalDepositRing
    // total number of ring that the player has deposited
    mapping (address => uint256) public playerTotalDeposit_;

    // claimedToken event
    event ClaimedTokens(address indexed _token, address indexed _owner, uint _amount);




    /*==============
     |   modifier   |
     ===============*/

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }


    /*==============
     |  functions  |
     ===============*/

    /**
       * @dev deposit actions
       * @param _depositor - person who deposits
       * @param _value - depositor wants to deposit how many tokens
       * @param _month - Length of time from the deposit's beginning to end (in months).
    */
    function _deposit(address _depositor, uint _value, uint _month) canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) internal {
        require(_month <= 36 && _month >= 1);
        Deposit memory depositEntity = Deposit(uint128(_value), uint128(_month), now);
        // use current number of deposit from the _depositor as depositID
        uint depositID = playerDepositNumber_[_depositor] + 1;
        require(palyerDepositIsOpen_[_depositor][depositID] == false);

        playerDepositInfo_[_depositor][depositID] = depositEntity;
        palyerDepositIsOpen_[_depositor][depositID] = true;
        playerDepositNumber_[_depositor] = depositID;
        playerTotalDeposit_[_depositor] += _value;

        // give the player interest immediately
        uint interest = _computeInterest(_value, _month);
        require(kryptonite_.transfer(_depositor,interest));
    }

    function _claimBack(address _depositor,uint _value, uint _depositID) internal {

        require(palyerDepositIsOpen_[_depositor][_depositID] == true);
        // prevent re-entrency attack
        palyerDepositIsOpen_[_depositor][_depositID] = false;

        playerTotalDeposit_[_depositor] -= _value;
        require(ring_.transfer(_depositor,_value));
    }



    /**
        * @dev compute interst based on deposit amount and deposit time
        * @param _value - Amount of ring  (in deceimal units)
        * @param _month - Length of time from the deposit's beginning to end (in months).
    */
    function _computeInterest(uint _value, uint _month) internal canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) returns (uint) {
        // these two actually mean the multiplier is 1.006
        uint numerator = 1006 ** uint128(_month);
        uint denominator = 1000 ** uint128(_month);

        uint quotient;
        uint remainder;

        assembly {
            quotient := div(numerator, denominator)
            remainder := mod(numerator, denominator)
        }
        // depositing 1 ring for 12 months, interest is about 1.015 KTON
        // and the multiplier is about 2.72
        uint interest = (30 * unitInterest_ * uint128(_value) / 11) * ((quotient - 1) * 10**18 + remainder * 10**18 / denominator) / (10**36);
        return interest;
    }


    function _computePenaltyWithID(address _depositor, uint _depositID) internal returns (uint){
        Deposit memory depositEntity = playerDepositInfo_[_depositor][_depositID];

        uint value = depositEntity.value;
        uint months = depositEntity.months;
        uint startAt = depositEntity.startAt;
        uint duration = now - startAt;
        uint depositMonth = duration / MONTH;

        return _computePenalty(depositMonth, months, value);
    }


    function _computePenalty(uint _depositMonth, uint _predeterminedMonth, uint _value) internal returns (uint) {
        uint penalty = penaltyMultiplier_ * (_computeInterest(_value, _predeterminedMonth) - _computeInterest(_value, _depositMonth));
        return penalty;
    }


    // @dev set UNIT_INTEREST;
    function _setUnitInterest(uint _unitInterest) internal {
        unitInterest_ = _unitInterest;
    }

    // @dev set UNIT_INTEREST;
    function _setPenaltyMultiplier(uint _penaltyMultiplier) internal {
        penaltyMultiplier_ = _penaltyMultiplier;
    }

    // @dev set ring_
    function _setRING(address _ring) internal {
        ring_ = ERC20(_ring);
    }

    // @dev set KTON
    function _setKton(address _kton) internal {
        kryptonite_ = ERC20(_kton);
    }


    function bytesToUint256(bytes b) public pure returns (uint256) {
        bytes32 out;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[i] & 0xFF) >> (i * 8);
        }
        return uint256(out);
    }






}
