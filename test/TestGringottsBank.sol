pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/GringottsBank.sol";
import "evolutionlandcommon/contracts/StandardERC223.sol";
import "evolutionlandcommon/contracts/SettingsRegistry.sol";

contract TestGringottsBank {
    function testInitialBalanceUsingDeployedContract() {
        GringottsBank bank = GringottsBank(DeployedAddresses.GringottsBank());

        uint expected = 10000;

        //Assert.equal(bank.deposits_[0].value, expected, "Owner should have 10000 MetaCoin initially");
    }

    function testInitialBalanceWithNewMetaCoin() {
        SettingsRegistry registry = new SettingsRegistry();
        StandardERC223 ring = new StandardERC223("RING");

        ring.mint(address(this), 10000);

        StandardERC223 kton = new StandardERC223("KTON");
        GringottsBank bank = new GringottsBank(ring, kton, registry);
        // kton.setOwner(bank);
        // bank.loadDefaultSettings(registry);

        // this._deposit()
        //ring.transferFrom(address(this), bank, 0x0);

        uint expected = 10000;
        var (,value,,,,) = bank.getDeposit(0);
      
        Assert.equal(value, expected, "Owner should have 10000 MetaCoin initially");
    }
}