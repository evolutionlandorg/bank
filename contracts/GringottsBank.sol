pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "@evolutionland/common/contracts/interfaces/ISettingsRegistry.sol";
import "@evolutionland/common/contracts/interfaces/IBurnableERC20.sol";
import "@evolutionland/common/contracts/interfaces/IMintableERC20.sol";
import "./BankSettingIds.sol";

contract  GringottsBank is Ownable, BankSettingIds {
    /*
     *  Events
     */
    event ClaimedTokens(address indexed _token, address indexed _owner, uint _amount);

    event NewDeposit(uint256 indexed _depositID, address indexed _depositor, uint _value, uint _month);

    event ClaimedDeposit(uint256 indexed _depositID, address indexed _depositor, uint _value, bool isPenalty);

    /*
     *  Constants
     */
    uint public constant MONTH = 30 * 1 days;

    /*
     *  Structs
     */
    struct Deposit {
        address depositor;
        uint128 value;  // amount of ring
        uint128 months; // Length of time from the deposit's beginning to end (in months), For now, months must >= 1 and <= 36
        uint256 startAt;   // when player deposit, timestamp in seconds
        uint256 unitInterest;
        bool claimed;
    }

    /*
     *  Storages
     */
    ERC20 public ring; // token contract

    ERC20 public kryptonite;   // bounty contract

    ISettingsRegistry public registry;

    mapping (uint256 => Deposit) public deposits;

    uint public depositCount;

    mapping (address => uint[]) public userDeposits;

    // player => totalDepositRING, total number of ring that the player has deposited
    mapping (address => uint256) public userTotalDeposit;

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
     * @param _registry - address of SettingsRegistry
     */
    constructor (address _ring, address _kton, address _registry) public {
        ring = ERC20(_ring);
        kryptonite = ERC20(_kton);

        registry = ISettingsRegistry(_registry);
    }

    function getDeposit(uint _id) public view returns (address, uint128, uint128, uint256, uint256, bool ) {
        return (deposits[_id].depositor, deposits[_id].value, deposits[_id].months, 
            deposits[_id].startAt, deposits[_id].unitInterest, deposits[_id].claimed);
    }

    /**
     * @dev ERC223 fallback function, make sure to check the msg.sender is from target token contracts
     * @param _from - person who transfer token in for deposits or claim deposit with penalty KTON.
     * @param _amount - amount of token.
     * @param _data - data which indicate the operations.
     */
    function tokenFallback(address _from, uint256 _amount, bytes _data) public {
        // deposit entrance
        if(address(ring) == msg.sender) {
            uint months = bytesToUint256(_data);
            _deposit(_from, _amount, months);
        }
        //  Early Redemption entrance
        if (address(kryptonite) == msg.sender) {
            uint _depositID = bytesToUint256(_data);

            require(_amount >= computePenalty(_depositID), "No enough amount of KTON penalty.");

            _claimDeposit(_from, _depositID, true);

            // burn the KTON transferred in
            IBurnableERC20(kryptonite).burn(address(this), _amount);
        }
    }

    /**
     * @dev Deposit for msg sender, require the token approvement ahead.
     * @param _amount - amount of token.
     * @param _months - the amount of months that the token will be locked in the deposit.
     */
    function deposit(uint256 _amount, uint256 _months) public {
        deposit(msg.sender, _amount, _months);
    }

    /**
     * @dev Deposit for benificiary, require the token approvement ahead.
     * @param _benificiary - benificiary of the deposit, which will get the KTON and RINGs after deposit being claimed.
     * @param _amount - amount of token.
     * @param _months - the amount of months that the token will be locked in the deposit.
     */
    function deposit(address _benificiary, uint256 _amount, uint256 _months) public {
        require(ring.transferFrom(msg.sender, address(this), _amount), "RING token tranfer failed.");

        _deposit(_benificiary, _amount, _months);
    }

    function claimDeposit(uint _depositID) public {
        _claimDeposit(msg.sender, _depositID, false);
    }

    function claimDepositWithPenalty(uint _depositID) public {
        uint256 _penalty = computePenalty(_depositID);

        require(kryptonite.transferFrom(msg.sender, address(this), _penalty));

        _claimDeposit(msg.sender, _depositID, true);

        IBurnableERC20(kryptonite).burn(address(this), _penalty);

    }

    // normal Redemption, withdraw at maturity
    function _claimDeposit(address _depositor, uint _depositID, bool isPenalty) internal {
        require(deposits[_depositID].startAt > 0, "Deposit not created.");
        require(deposits[_depositID].claimed == false, "Already claimed");
        require(deposits[_depositID].depositor == _depositor);

        if (isPenalty) {
            require(now - deposits[_depositID].startAt < deposits[_depositID].months * MONTH );
        } else {
            require(now - deposits[_depositID].startAt >= deposits[_depositID].months * MONTH );
        }

        deposits[_depositID].claimed = true;
        userTotalDeposit[_depositor] -= deposits[_depositID].value;

        require(ring.transfer(_depositor, deposits[_depositID].value));

        emit ClaimedDeposit(_depositID, _depositor, deposits[_depositID].value, isPenalty);
    }

    /**
     * @dev deposit actions
     * @param _depositor - person who deposits
     * @param _value - depositor wants to deposit how many tokens
     * @param _month - Length of time from the deposit's beginning to end (in months).
     */
    function _deposit(address _depositor, uint _value, uint _month) 
        canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) internal returns (uint _depositId) {
        require( _value > 0 );
        require( _month <= 36 && _month >= 1 );

        _depositId = depositCount;

        uint _unitInterest = registry.uintOf(BankSettingIds.UINT_BANK_UNIT_INTEREST);

        deposits[_depositId] = Deposit({
            depositor: _depositor,
            value: uint128(_value),
            months: uint128(_month),
            startAt: now,
            unitInterest: _unitInterest,
            claimed: false
        });
        
        depositCount += 1;

        userDeposits[_depositor].push(_depositId);

        userTotalDeposit[_depositor] += _value;

        // give the player interest immediately
        uint interest = computeInterest(_value, _month, _unitInterest);
        IMintableERC20(kryptonite).mint(_depositor, interest);
        
        emit NewDeposit(_depositId, _depositor, _value, _month);
    }

    /**
     * @dev compute interst based on deposit amount and deposit time
     * @param _value - Amount of ring  (in deceimal units)
     * @param _month - Length of time from the deposit's beginning to end (in months).
     * @param _unitInterest - Parameter of basic interest for deposited RING.(default value is 1000, returns _unitInterest/ 10**7 for one year)
     */
    function computeInterest(uint _value, uint _month, uint _unitInterest) 
        public canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) pure returns (uint) {
        // these two actually mean the multiplier is 1.015
        uint numerator = 67 ** _month;
        uint denominator = 66 ** _month;
        uint quotient;
        uint remainder;

        assembly {
            quotient := div(numerator, denominator)
            remainder := mod(numerator, denominator)
        }
        // depositing X RING for 12 months, interest is about (1 * _unitInterest * X / 10**7) KTON
        // and the multiplier is about 3
        // ((quotient - 1) * 1000 + remainder * 1000 / denominator) is 197 when _month is 12.
        return (_unitInterest * uint128(_value)) * ((quotient - 1) * 1000 + remainder * 1000 / denominator) / (197 * 10**7);
    }

    function isClaimRequirePenalty(uint _depositID) public view returns (bool) {
        return (deposits[_depositID].startAt > 0 && 
                !deposits[_depositID].claimed && 
                (now - deposits[_depositID].startAt < deposits[_depositID].months * MONTH ));
    }

    function computePenalty(uint _depositID) public view returns (uint256) {
        require(isClaimRequirePenalty(_depositID), "Claim do not need Penalty.");

        uint256 monthsDuration = (now - deposits[_depositID].startAt) / MONTH;

        uint256 penalty = registry.uintOf(BankSettingIds.UINT_BANK_PENALTY_MULTIPLIER) * 
            (computeInterest(deposits[_depositID].value, deposits[_depositID].months, deposits[_depositID].unitInterest) - computeInterest(deposits[_depositID].value, monthsDuration, deposits[_depositID].unitInterest));


        return penalty;
    }

    function getDepositIds(address _user) public view returns(uint256[]) {
        return userDeposits[_user];
    }

    function bytesToUint256(bytes _encodedParam) public pure returns (uint256 a) {
        /* solium-disable-next-line security/no-inline-assembly */
        assembly {
            a := mload(add(_encodedParam, /*BYTES_HEADER_SIZE*/32))
        }
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
