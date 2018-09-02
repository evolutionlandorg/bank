pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import "evolutionlandcommon/contracts/interfaces/ISettingsRegistry.sol";
import "./BankSettingIds.sol";
import './interfaces/IBurnableERC20.sol';


contract  GringottsBank is Ownable, BankSettingIds {
    /*
     *  Events
     */
    event ClaimedTokens(address indexed _token, address indexed _owner, uint _amount);

    event NewDeposit(address indexed _depositor, uint256 indexed _depositID);

    /*
     *  Constants
     */
    uint public constant MONTH = 30 * 1 days;

    /*
     *  Storage
     */
    ERC20 public ring_; // token contract

    ERC20 public kryptonite_;   // bounty contract

    ISettingsRegistry registry_;

    // Deposit
    struct Deposit {
        address depositor;
        uint128 value;  // amount of ring
        uint128 months; // Length of time from the deposit's beginning to end (in months), For now, months must >= 1 and <= 36
        uint256 startAt;   // when player deposit, timestamp in seconds
        uint256 unitInterest;
        bool claimed;
    }

    mapping (uint256 => Deposit) deposits_;

    uint public depositCount_;

    mapping (address => uint[]) playerDeposits_;

    // player => totalDepositRing
    // total number of ring that the player has deposited
    mapping (address => uint256) public playerTotalDeposit_;


    /*
     *  Modifiers
     */

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }

    /**
    * @dev Bank's constructor which set the token address and unitInterest_
    * @param _ring - address of ring
    * @param _kton - address of kton
    */
    constructor (address _ring, address _kton) public {
        ring_ = ERC20(_ring);
        kryptonite_ = ERC20(_kton);
    }

    /*
     *  Functions
     */

    // for deposit ring
    function tokenFallback(address _from, uint256 _amount, bytes _data) public {
        // deposit entrance
        if(address(ring_) == msg.sender) {
            uint months = bytesToUint256(_data);
            _deposit(_from, _amount, months);
        }
        //  Early Redemption entrance
        if (address(kryptonite_) == msg.sender) {
            uint depositID = bytesToUint256(_data);
            require(_amount >= _computePenalty(depositID));

            claimDeposit(_from, depositID, true);

            // burn the KTON transferred in
            IBurnableERC20(kryptonite_).burn(_amount);
        }
    }

    function claimDeposit(uint _depositID) public {
        claimDeposit(msg.sender, _depositID, false);
    }

    // normal Redemption, withdraw at maturity
    function claimDeposit(address _depositor, uint _depositID, bool isPenalty) internal {
        require(deposits_[_depositID].claimed == false, "Already claimed");
        require(deposits_[_depositID].depositor == _depositor);

        if (!isPenalty) {
            uint months = deposits_[_depositID].months;
            uint startAt = deposits_[_depositID].startAt;
            uint duration = now - startAt;
        
            require (duration >= (months * MONTH));
        }

        deposits_[_depositID].claimed = true;
        playerTotalDeposit_[_depositor] -= deposits_[_depositID].value;

        require(ring_.transfer(_depositor, deposits_[_depositID].value));
    }

    /**
       * @dev deposit actions
       * @param _depositor - person who deposits
       * @param _value - depositor wants to deposit how many tokens
       * @param _month - Length of time from the deposit's beginning to end (in months).
    */
    function _deposit(address _depositor, uint _value, uint _month) canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) internal returns (uint depositId) {
        require( _value > 0 );
        require( _month <= 36 && _month >= 1 );

        depositId = depositCount_;


        uint _unitInterest = registry_.uintOf(BankSettingIds.UINT_BANK_UNIT_INTEREST);

        deposits_[depositId] = Deposit({
            depositor: _depositor,
            value: uint128(_value),
            months: uint128(_month),
            startAt: now,
            unitInterest: _unitInterest,
            claimed: false
        });

        depositCount_ += 1;

        playerDeposits_[_depositor].push(depositId);

        playerTotalDeposit_[_depositor] += _value;

        // give the player interest immediately
        uint interest = _computeInterest(_value, _month, _unitInterest);
        require(kryptonite_.transfer(_depositor, interest));
        
        emit NewDeposit(_depositor, depositId);
    }

    /**
        * @dev compute interst based on deposit amount and deposit time
        * @param _value - Amount of ring  (in deceimal units)
        * @param _month - Length of time from the deposit's beginning to end (in months).
    */
    function _computeInterest(uint _value, uint _month, uint _unitInterest) internal canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) pure returns (uint) {
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
        return (30 * _unitInterest * uint128(_value) / 11) * ((quotient - 1) * 10**18 + remainder * 10**18 / denominator) / (10**36);
    }


    function _computePenalty(uint _depositID) internal returns (uint) {
        uint startAt = deposits_[_depositID].startAt;
        uint duration = now - startAt;
        uint depositMonth = duration / MONTH;

        uint penalty = registry_.uintOf(BankSettingIds.UINT_BANK_PENALTY_MULTIPLIER) * (_computeInterest(deposits_[_depositID].value, deposits_[_depositID].months, deposits_[_depositID].unitInterest) - _computeInterest(deposits_[_depositID].value, depositMonth, deposits_[_depositID].unitInterest));


        return penalty;
    }

    function bytesToUint256(bytes b) public pure returns (uint256) {
        bytes32 out;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[i] & 0xFF) >> (i * 8);
        }
        return uint256(out);
    }

    /// @notice This method can be used by the owner to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyOwner {
        if (_token == 0x0) {
            owner.transfer(address(this).balance);
            return;
        }
        ERC20 token = ERC20(_token);
        uint balance = token.balanceOf(address(this));
        token.transfer(owner, balance);

        emit ClaimedTokens(_token, owner, balance);
    }
}
