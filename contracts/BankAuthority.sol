pragma solidity ^0.4.24;

import "@evolutionland/common/contracts/interfaces/IAuthority.sol";

contract BankAuthority is IAuthority {
    address public bank;

    constructor(address _bank) public
    {
        bank = _bank;
    }

    function canCall(
        address _src, address _dst, bytes4 _sig
    ) public view returns (bool) {
        return ( _src == bank && _sig == bytes4(keccak256("mint(address,uint256)")) ) || 
            ( _src == bank && _sig == bytes4(keccak256("burn(address,uint256)")) );
    }
}