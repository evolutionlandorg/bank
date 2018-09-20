var GringottsBank = artifacts.require("./GringottsBank.sol");
var SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
var StandardERC223 = artifacts.require("./StandardERC223.sol");
var DeployAndTest = artifacts.require("./DeployAndTest.sol");

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
    deployer.deploy([
        SettingsRegistry,
        DeployAndTest
    ]).then(function() {
        DeployAndTest.deployed().then(function(instance) {
           var ring  =  instance.testRING.call(accounts[0]);
           var kton  =  instance.testKTON.call(accounts[0]);
           deployer.deploy(GringottsBank, ring, kton, SettingsRegistry.address);
        });

        // ring.mint(accounts[0], 10000, {from: accounts[0]});


        //var bank = deployer.deploy(GringottsBank, ring, kton, instances[0].address);
        //console.log(bank);
        // bank.loadDefaultSettings(SettingsRegistry.address);

       // return bank;
    });
}
