const GringottsBank = artifacts.require("./GringottsBank.sol");
const SettingsRegistry = artifacts.require("./SettingsRegistry.sol");
const StandardERC223 = artifacts.require("./StandardERC223.sol");
const Proxy = artifacts.require("OwnedUpgradeabilityProxy");
const BankSettingIds = artifacts.require('BankSettingIds');
const MintAndBurnAuthority = artifacts.require('MintAndBurnAuthority');




const conf = {
    bank_unit_interest: 1000,
    bank_penalty_multiplier: 3,
    registry_address: '0xd8b7a3f6076872c2c37fb4d5cbfeb5bf45826ed7',
}


module.exports = function(deployer, network){
    if(network != 'kovan') {
        return
    }
        deployer.deploy(BankSettingIds);
        deployer.deploy(StandardERC223, 'KTON');
        deployer.deploy(Proxy);
        deployer.deploy(GringottsBank).then(async () => {
            return deployer.deploy(MintAndBurnAuthority, [Proxy.address]);

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

            // setAuthority to kton
            await kton.setAuthority(MintAndBurnAuthority.address);

            console.log('MIGRATION SUCCESS!');


            // kton.setAuthority will be done in market's migration
            let interest = await bankProxy.computeInterest.call(10000, 12, conf.bank_unit_interest);
            console.log("Current annual interest for 10000 RING is: ... " + interest + " KTON");
        });


}

