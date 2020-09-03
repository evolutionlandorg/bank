pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "@evolutionland/common/contracts/interfaces/ISettingsRegistry.sol";
import "@evolutionland/common/contracts/interfaces/IBurnableERC20.sol";
import "@evolutionland/common/contracts/interfaces/IMintableERC20.sol";
import "@evolutionland/common/contracts/DSAuth.sol";
import "./BankSettingIds.sol";

contract  GringottsBank is DSAuth, BankSettingIds {
    /*
     *  Events
     */
    event ClaimedTokens(address indexed _token, address indexed _owner, uint _amount);

    event NewDeposit(uint256 indexed _depositID, address indexed _depositor, uint _value, uint _month, uint _interest);

    event ClaimedDeposit(uint256 indexed _depositID, address indexed _depositor, uint _value, bool isPenalty, uint penaltyAmount);

    event TransferDeposit(uint256 indexed _depositID, address indexed _oldDepositor, address indexed _newDepositor);

    event BurnAndRedeem(uint256 indexed _depositID,  address _depositor, uint48 _months, uint48 _startAt, uint64 _unitInterest, uint128 _value, bytes _data);

    /*
     *  Constants
     */
    uint public constant MONTH = 30 * 1 days;

    /*
     *  Structs
     */
    struct Deposit {
        address depositor;
        uint48 months; // Length of time from the deposit's beginning to end (in months), For now, months must >= 1 and <= 36
        uint48 startAt;   // when player deposit, timestamp in seconds
        uint128 value;  // amount of ring
        uint64 unitInterest;
        bool claimed;
    }


    /*
     *  Storages
     */

    bool private singletonLock = false;


    ISettingsRegistry public registry;

    mapping (uint256 => Deposit) public deposits;

    uint public depositCount;

    mapping (address => uint[]) public userDeposits;

    // player => totalDepositRING, total number of ring that the player has deposited
    mapping (address => uint256) public userTotalDeposit;

    /*
     *  Modifiers
     */
    modifier singletonLockCall() {
        require(!singletonLock, "Only can call once");
        _;
        singletonLock = true;
    }

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }

    modifier canBeStoredWith48Bits(uint256 _value) {
        require(_value < 281474976710656);
        _;
    }


    /**
     * @dev Bank's constructor which set the token address and unitInterest_
     */
    constructor () public {
        // initializeContract(_registry);
    }

    /**
     * @dev Same with constructor, but is used and called by storage proxy as logic contract.
     * @param _registry - address of SettingsRegistry
     */
    function initializeContract(address _registry) public singletonLockCall {
        // call Ownable's constructor
        owner = msg.sender;

        emit LogSetOwner(msg.sender);

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
        address ring = registry.addressOf(SettingIds.CONTRACT_RING_ERC20_TOKEN);
        address kryptonite = registry.addressOf(SettingIds.CONTRACT_KTON_ERC20_TOKEN);

        // deposit entrance
        if(ring == msg.sender) {
            uint months = bytesToUint256(_data);
            _deposit(_from, _amount, months);
        }
        //  Early Redemption entrance

        if (kryptonite == msg.sender) {
            uint _depositID = bytesToUint256(_data);

            require(_amount >= computePenalty(_depositID), "No enough amount of KTON penalty.");

            _claimDeposit(_from, _depositID, true, _amount);

            // burn the KTON transferred in
            IBurnableERC20(kryptonite).burn(address(this), _amount);
        }
    }

    /**
     * @dev transfer of deposit from  Ethereum network to Darwinia Network, params can be obtained by the function 'getDeposit'
     * @param _depositID - ID of deposit.
     * @param _data - receiving address of darwinia network.

     */
    function burnAndRedeem(uint256 _depositID, bytes _data) public {
        bytes32 darwiniaAddress;

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            darwiniaAddress := mload(add(ptr, 100))
        }

        // Check the validity of the deposit
        require(deposits[_depositID].claimed == false, "Already claimed");
        require(deposits[_depositID].startAt > 0, "Deposit not created.");
        require(deposits[_depositID].depositor == msg.sender, "Permission denied");

        require(_data.length == 32, "The address (Darwinia Network) must be in a 32 bytes hexadecimal format");
        require(darwiniaAddress != bytes32(0x0), "Darwinia Network Address can't be empty");

        deposits[_depositID].claimed = true;
        removeUserDepositsByID(_depositID, msg.sender);

        require(deposits[_depositID].value <= userTotalDeposit[msg.sender], "Subtraction overflow");
        userTotalDeposit[msg.sender] -= deposits[_depositID].value;

        address ring = registry.addressOf(SettingIds.CONTRACT_RING_ERC20_TOKEN);
        IBurnableERC20(ring).burn(address(this), deposits[_depositID].value);
        
        emit BurnAndRedeem(
            _depositID, 
            deposits[_depositID].depositor, 
            deposits[_depositID].months, 
            deposits[_depositID].startAt, 
            deposits[_depositID].unitInterest, 
            deposits[_depositID].value, 
            _data
        );
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

        address ring = registry.addressOf(SettingIds.CONTRACT_RING_ERC20_TOKEN);
        require(ERC20(ring).transferFrom(msg.sender, address(this), _amount), "RING token tranfer failed.");


        _deposit(_benificiary, _amount, _months);
    }

    function claimDeposit(uint _depositID) public {
        _claimDeposit(msg.sender, _depositID, false, 0);
    }

    function claimDepositWithPenalty(uint _depositID) public {
        address kryptonite = ERC20(registry.addressOf(SettingIds.CONTRACT_KTON_ERC20_TOKEN));
        uint256 _penalty = computePenalty(_depositID);

        require(ERC20(kryptonite).transferFrom(msg.sender, address(this), _penalty));

        _claimDeposit(msg.sender, _depositID, true, _penalty);

        IBurnableERC20(kryptonite).burn(address(this), _penalty);
    }

    function transferDeposit(address _benificiary, uint _depositID) public {
        require(deposits[_depositID].depositor == msg.sender, "Depositor must be the msg.sender");
        require(_benificiary != 0x0, "Benificiary can not be zero");
        require(deposits[_depositID].claimed == false, "Already claimed, can not transfer.");

        // update the depositor of the deposit.
        deposits[_depositID].depositor = _benificiary;

        // update the deposit ids of the original user and new user.
        removeUserDepositsByID(_depositID, msg.sender);
        userDeposits[_benificiary].push(_depositID);

        // update the balance of the original depositor and new depositor.
        require(deposits[_depositID].value <= userTotalDeposit[msg.sender], "Subtraction overflow");
        userTotalDeposit[msg.sender] -= deposits[_depositID].value;

        userTotalDeposit[_benificiary] += deposits[_depositID].value;
        require(userTotalDeposit[_benificiary] >= deposits[_depositID].value, "Addition overflow");

        emit TransferDeposit(_depositID, msg.sender, _benificiary);
    }

    // normal Redemption, withdraw at maturity
    function _claimDeposit(address _depositor, uint _depositID, bool isPenalty, uint _penaltyAmount) internal {

        address ring = registry.addressOf(SettingIds.CONTRACT_RING_ERC20_TOKEN);

        require(deposits[_depositID].startAt > 0, "Deposit not created.");
        require(deposits[_depositID].claimed == false, "Already claimed");
        require(deposits[_depositID].depositor == _depositor, "Depositor must match.");

        if (isPenalty) {
            require(now - deposits[_depositID].startAt < deposits[_depositID].months * MONTH );
        } else {
            require(now - deposits[_depositID].startAt >= deposits[_depositID].months * MONTH );
        }

        deposits[_depositID].claimed = true;
        userTotalDeposit[_depositor] -= deposits[_depositID].value;

        require(ERC20(ring).transfer(_depositor, deposits[_depositID].value));


        emit ClaimedDeposit(_depositID, _depositor, deposits[_depositID].value, isPenalty, _penaltyAmount);
    }

    /**
     * @dev deposit actions
     * @param _depositor - person who deposits
     * @param _value - depositor wants to deposit how many tokens
     * @param _month - Length of time from the deposit's beginning to end (in months).
     */

    function _deposit(address _depositor, uint _value, uint _month)
        canBeStoredWith128Bits(_value) canBeStoredWith128Bits(_month) internal returns (uint _depositId) {

        address kryptonite = ERC20(registry.addressOf(SettingIds.CONTRACT_KTON_ERC20_TOKEN));

        require( _value > 0 );  // because the _value is pass in from token transfer, token transfer will help check, so there should not be overflow issues.
        require( _month <= 36 && _month >= 1 );

        _depositId = depositCount;

        uint64 _unitInterest = uint64(registry.uintOf(BankSettingIds.UINT_BANK_UNIT_INTEREST));

        deposits[_depositId] = Deposit({
            depositor: _depositor,
            value: uint128(_value),
            months: uint48(_month),
            startAt: uint48(now),
            unitInterest: uint48(_unitInterest),
            claimed: false
        });

        depositCount += 1;

        userDeposits[_depositor].push(_depositId);

        userTotalDeposit[_depositor] += _value;
        require(userTotalDeposit[_depositor] >= _value, "Addition overflow");

        // give the player interest immediately
        uint interest = computeInterest(_value, _month, _unitInterest);
        IMintableERC20(kryptonite).mint(_depositor, interest);

        emit NewDeposit(_depositId, _depositor, _value, _month, interest);
    }

    /**
     * @dev compute interst based on deposit amount and deposit time
     * @param _value - Amount of ring  (in deceimal units)
     * @param _month - Length of time from the deposit's beginning to end (in months).
     * @param _unitInterest - Parameter of basic interest for deposited RING.(default value is 1000, returns _unitInterest/ 10**7 for one year)
     */
    function computeInterest(uint _value, uint _month, uint _unitInterest)
        public canBeStoredWith128Bits(_value) canBeStoredWith48Bits(_month) pure returns (uint) {
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

    function setRegistry(address _registry) public onlyOwner {
        registry = ISettingsRegistry(_registry);
    }

    function removeUserDepositsByID(uint _depositID, address _depositor) private{
        // update the deposit ids of the original user and new user.
        bool found = false;
        for(uint i = 0 ; i < userDeposits[_depositor].length; i++)
        {
            if (!found && userDeposits[_depositor][i] == _depositID){
                found = true;
                delete userDeposits[_depositor][i];
            }

            if (found && i < userDeposits[_depositor].length - 1)
            {
                // shifts value to left
                userDeposits[_depositor][i] =  userDeposits[_depositor][i+1];
            }
        }

        delete userDeposits[_depositor][userDeposits[_depositor].length-1];
        //reducing the length
        userDeposits[_depositor].length--;
    }

}
