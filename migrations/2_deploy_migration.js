const GringottsBank = artifacts.require("./GringottsBank.sol");
const SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
const StandardERC223 = artifacts.require("./StandardERC223.sol");
const Proxy = artifacts.require("OwnedUpgradeabilityProxy")
const BankSettingIds = artifacts.require('BankSettingIds');

const conf = {
    bank_unit_interest: 1000,
    bank_penalty_multiplier: 3,
    registry_address: '0xf21930682df28044d88623e0707facf419477041',
    ring_address: '0xf8720eb6ad4a530cccb696043a0d10831e2ff60e'
}

module.exports = function(deployer, network){
    if(network == 'kovan') {
        console.log(network);

        deployer.deploy(BankSettingIds);
        deployer.deploy(StandardERC223, 'KTON');
        deployer.deploy(Proxy);
        deployer.deploy(GringottsBank).then(async () => {

            let registry = await SettingsRegistry.at(conf.registry_address);
            let settingIds = await BankSettingIds.deployed();
            let kton  =  await StandardERC223.deployed();

            // register in registry
            let ktonId = await settingIds.CONTRACT_KTON_ERC20_TOKEN.call();
            await registry.setAddressProperty(ktonId, kton.address);

            let bank_unit_interest = await bank.UINT_BANK_UNIT_INTEREST.call();
            await registry.setUintProperty(bank_unit_interest, conf.bank_unit_interest);

            let bank_penalty_multiplier = await bank.UINT_BANK_PENALTY_MULTIPLIER.call();
            await registry.setUintProperty(bank_penalty_multiplier, conf.bank_penalty_multiplier);
            console.log("REGISTRATION DONE! ");

            // upgrade
            let proxy = await Proxy.deployed();
            await proxy.upgradeTo(GringottsBank.address);
            console.log("UPGRADE DONE! ");

            // initialize
            let bankProxy = await GringottsBank.at(Proxy.address);
            await bankProxy.initializeContract(conf.registry_address);
            console.log("INITIALIZATION DONE! ");

            // kton.setAuthority will be done in market's migration
            let interest = await bankProxy.computeInterest.call(10000, 12, conf.bank_unit_interest);
            console.log("Current annual interest for 10000 RING is: ... " + interest + " KTON");
        });
    }
}

