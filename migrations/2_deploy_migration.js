var GringottsBank = artifacts.require("./GringottsBank.sol");
var SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
var StandardERC223 = artifacts.require("./StandardERC223.sol");

module.exports = function(deployer, network, accounts) {
    if (network == "developement")
    {
        deployOnLocal(deployer, network, accounts);
    } else {
        deployOnLocal(deployer, network, accounts);
    }
};

function deployOnLocal(deployer, network, accounts) {
    console.log(network);
    deployer.then(function() {
        return SettingsRegistry.new();
    }).then(function(registry) {
        // console.log(registry);
        var ring = StandardERC223.new("RING");
        var kton = StandardERC223.new("KTON");
        // ring.mint(accounts[0], 10000, {from: accounts[0]});

        var bank = deployer.deploy(GringottsBank, ring.address, kton.address, registry.address);
        console.log(bank);
        // bank.loadDefaultSettings(SettingsRegistry.address);
        
        return bank;
    });
}
