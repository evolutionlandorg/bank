const StandardERC223 = artifacts.require('StandardERC223');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const GringottsBank = artifacts.require('GringottsBank');

const gasPrice = 22000000000;

var registry;
var ring;
var kton;
var bank;


contract('Gringotts Bank test', async(accounts) => {
    let contractFeaturesId;
    let gasPriceLimitId;
    let formulaId;
    let bancorNetworkId;

    before('deploy and configure', async() => {
        registry = await SettingsRegistry.new({from: accounts[0]});
        console.log('registry address: ', registry.address);

        ring = await StandardERC223.new("RING", {from: accounts[0]});
        console.log('RING address: ', ring.address);

        await ring.mint(accounts[0], 10000 * 10**18, {from:accounts[0]});

        kton = await StandardERC223.new("KTON", {from: accounts[0]});
        console.log('KTON address: ', kton.address);

        bank = await GringottsBank.new(ring.address, kton.address, registry.address, {from: accounts[0]});
        console.log('Bank address: ', bank.address);

        await kton.setOwner(bank.address, {from: accounts[0]});

        // default settings
        let bank_unit_interest = await bank.UINT_BANK_UNIT_INTEREST.call();
        await registry.setUintProperty(bank_unit_interest, 10000);

        let bank_penalty_multiplier = await bank.UINT_BANK_PENALTY_MULTIPLIER.call();
        await registry.setUintProperty(bank_penalty_multiplier, 10000);
    })

    it('should return correct amount of kton', async() => {
        // using the way to call overloaded functions.
        await ring.contract.transfer['address,uint256,bytes'](bank.address, 100 * 10**18, "0x1", {from:accounts[0]});

        let balance = await kton.balanceOf.call(accounts[0]);
        console.log(balance.toNumber());
        assert.equal(balance.toNumber(), 100 , "returned unexpected kton");
    })


})