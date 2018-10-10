const GringottsBank = artifacts.require('GringottsBank');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const StandardERC223 = artifacts.require('StandardERC223');
const BankAuthority = artifacts.require('BankAuthority');
const GringottsBankProxy = artifacts.require('OwnedUpgradeabilityProxy');
const BankSettingIds = artifacts.require('BankSettingIds');

var conf = {
    bank_unit_interest: 1000,
    bank_penalty_multiplier: 3,
    from: '0x4cc4c344eba849dc09ac9af4bff1977e44fc1d7e',
    registry_address: '0x31ff7a0106cae24756a62657660e3878dcec77dc',
    ring_address: '0x6df4e0da83e47e3f6cd7d725224bc73f0e198c4f'
}

module.exports = async(deployer) => {
    deployer.deploy(StandardERC223, 'KTON');
    deployer.deploy(GringottsBankProxy);
    deployer.deploy(GringottsBank)
    .then (async() => {
        await deployer.deploy(BankAuthority,  GringottsBankProxy.address)
        console.log("FIRST bankProxy: ", GringottsBankProxy.address);
        console.log('start configure')
        console.log("LOGGING kton address : ", StandardERC223.address);

        let bank = await GringottsBank.deployed();
        let proxy = await GringottsBankProxy.deployed();
        await proxy.upgradeTo(bank.address);

        let bankProxy = await GringottsBank.at(GringottsBankProxy.address);
        await bankProxy.initializeContract(conf.ring_address, StandardERC223.address, conf.registry_address);

        console.log("LOGGING initialization success!")

        // let bank_unit_interest = await bank.UINT_BANK_UNIT_INTEREST.call();
        // await SettingsRegistry.at(conf.registry_address).setUintProperty(bank_unit_interest, conf.bank_unit_interest);
        //
        // let bank_penalty_multiplier = await bank.UINT_BANK_PENALTY_MULTIPLIER.call();
        // await SettingsRegistry.at(conf.registry_address).setUintProperty(bank_penalty_multiplier, conf.bank_penalty_multiplier);

        console.log("Loging: set bank authority.");
        // await StandardERC223.at(kton).setOwner(GringottsBank.address);
        await StandardERC223.at(StandardERC223.address).setAuthority(BankAuthority.address);

        let interest = await bankProxy.computeInterest.call(10000, 12, conf.bank_unit_interest);
        console.log("Current annual interest for 10000 RING is: ... " + interest + " KTON");

        let bankInAuthority = await BankAuthority.at(BankAuthority.address).bank();
        console.log('BankProxy in authority: ', bankInAuthority);
        console.log('real BankProxy: ', bankProxy.address);
    })

}