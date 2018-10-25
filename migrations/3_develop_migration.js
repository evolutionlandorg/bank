const GringottsBank = artifacts.require("./GringottsBank.sol");
const SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
const StandardERC223 = artifacts.require("./StandardERC223.sol");
const DeployAndTest = artifacts.require("./DeployAndTest.sol");
const KTONAuthority = artifacts.require("./KTONAuthority.sol");
const GringottsBankProxy = artifacts.require("OwnedUpgradeabilityProxy")

const conf = {
    bank_unit_interest: 1000,
    bank_penalty_multiplier: 3
}

module.exports = function(deployer, network, accounts) {
    if (network == "develop")
    {
        deployOnLocal(deployer, network, accounts);
    }
};

function deployOnLocal(deployer, network, accounts) {
    console.log(network);

    deployer.deploy([
        SettingsRegistry,
        DeployAndTest,
        GringottsBankProxy
    ]).then(async () => {
        return deployer.deploy(GringottsBank);
    }).then(async () => {
        console.log("Loging: proxy... " + GringottsBankProxy.address);
        console.log("Loging: bank... " + GringottsBank.address);
        let bank = await GringottsBank.deployed();
        let proxy = await GringottsBankProxy.deployed();
        await proxy.upgradeTo(GringottsBank.address);

        let bankProxy = await GringottsBank.at(GringottsBankProxy.address);

        let instance = await DeployAndTest.deployed();

        let ring  =  await instance.testRING.call();
        let kton  =  await instance.testKTON.call();
        console.log("Loging: ring..." + ring);
        await bankProxy.initializeContract(SettingsRegistry.address);

        return deployer.deploy(KTONAuthority, GringottsBankProxy.address);
    }).then(async () => {
        console.log("Loging: set bank authority.");
        
        let deployAndTest = await DeployAndTest.deployed();

        let ring  =  await deployAndTest.testRING.call();
        let kton  =  await deployAndTest.testKTON.call();

        let bank = await GringottsBank.at(GringottsBankProxy.address); // await GringottsBankProxy.deployed();

        let registry = await SettingsRegistry.deployed();

        // default settings
        // interest is about 1.015 KTON
        let bank_unit_interest = await bank.UINT_BANK_UNIT_INTEREST.call();
        await registry.setUintProperty(bank_unit_interest, conf.bank_unit_interest);

        let bank_penalty_multiplier = await bank.UINT_BANK_PENALTY_MULTIPLIER.call();
        await registry.setUintProperty(bank_penalty_multiplier, conf.bank_penalty_multiplier);

        let ring_settings = await bank.CONTRACT_RING_ERC20_TOKEN.call();
        await registry.setAddressProperty(ring_settings, ring);

        let kton_settings = await bank.CONTRACT_KTON_ERC20_TOKEN.call();
        await registry.setAddressProperty(kton_settings, kton);

        console.log("Loging: set bank authority.");
        // await StandardERC223.at(kton).setOwner(GringottsBank.address);
        await StandardERC223.at(kton).setAuthority(KTONAuthority.address);

        let interest = await bank.computeInterest.call(10000, 12, conf.bank_unit_interest);
        console.log("Current annual interest for 10000 RING is: ... " + interest + " KTON");
    });
}
