const GringottsBank = artifacts.require("./GringottsBank.sol");
const SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
const StandardERC223 = artifacts.require("./StandardERC223.sol");
const DeployAndTest = artifacts.require("./DeployAndTest.sol");
const KTONAuthority = artifacts.require("./MintAndBurnAuthority.sol");
const GringottsBankProxy = artifacts.require("OwnedUpgradeabilityProxy")
const conf = {
    bank_unit_interest: 1000,
    bank_penalty_multiplier: 3
}

module.exports = async function(deployer, network, accounts) {
    if (network == "development")
    {
        await deployOnLocal(deployer, network, accounts);
    }
};

async function deployOnLocal(deployer, network, accounts) {
    console.log('CONFIG',network, accounts);

    await deployer.deploy(SettingsRegistry);
    await  deployer.deploy(DeployAndTest);
    await deployer.deploy(GringottsBankProxy);
    await deployer.deploy(GringottsBank);

    console.log("Loging: proxy... " + GringottsBankProxy.address);
    console.log("Loging: bank... " + GringottsBank.address);
    let bank1 = await GringottsBank.deployed();
    let proxy = await GringottsBankProxy.deployed();
    await proxy.upgradeTo(GringottsBank.address);

    let bankProxy = await GringottsBank.at(GringottsBankProxy.address);

    let instance = await DeployAndTest.deployed();

    let ring  =  await instance.testRING.call();
    let kton  =  await instance.testKTON.call();
    console.log("Loging: ring..." + ring);
    await bankProxy.initializeContract(SettingsRegistry.address);

    await deployer.deploy(KTONAuthority, [GringottsBankProxy.address]);


    console.log("Loging: set bank authority.");

    let deployAndTest = await DeployAndTest.deployed();


    console.log('kton', kton)
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
    const standardERC223 = await StandardERC223.at(kton)
    standardERC223.setAuthority(KTONAuthority.address);
    let interest = await bank.computeInterest.call(10000, 12, conf.bank_unit_interest);
    console.log("Current annual interest for 10000 RING is: ... " + interest + " KTON");

}
