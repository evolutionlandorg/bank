var abi = require('ethereumjs-abi')

const StandardERC223 = artifacts.require('StandardERC223');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const GringottsBank = artifacts.require('GringottsBank');

const gasPrice = 22000000000;
const COIN = 10 ** 18;

contract('Gringotts Bank Test', async(accounts) => {
    let deployer = accounts[0];
    let investor = accounts[1];
    let bank;
    let registry;
    let ring;
    let kton;

    before('deploy and configure', async() => {
        // get contract from deployed version
        bank     = await GringottsBank.deployed();
        registry = await SettingsRegistry.deployed();

        ring = StandardERC223.at(await bank.ring_.call())
        kton = StandardERC223.at(await bank.kryptonite_.call())

        console.log('Bank address: ', bank.address);
        console.log('registry address: ', registry.address);
        console.log('RING address: ', ring.address);
        console.log('KTON address: ', kton.address);

        // give some ring to investor
        await ring.mint(investor, 100000 * COIN, { from:deployer } );
    })

    it('bank setting should be same as registry initialization', async() => {
        let bank_unit_interest = await registry.uintOf(await bank.UINT_BANK_UNIT_INTEREST.call());
        let bank_penalty_multiplier = await registry.uintOf(await bank.UINT_BANK_PENALTY_MULTIPLIER.call());

        assert.equal(bank_unit_interest, 1000)
        assert.equal(bank_penalty_multiplier, 3)
    })

    it('should return correct amount of KTON', async() => {
        // deposit 100 RING for 1 year
        await ring.contract.transfer['address,uint256,bytes']( bank.address, 10000 * COIN, '0x' + abi.rawEncode(['uint256'], [12]).toString('hex'), { from: investor, gas: 300000 });
        let ktonAmount = await kton.balanceOf(investor);
        
        assert.equal(ktonAmount.toNumber(), 1 * COIN);
        // using the way to call overloaded functions.
        //let tx = ring.contract.transfer['address,uint256,bytes'](bank.address, 100 * 10**18, "0x1", {from:deployer});
        //console.log(tx);
        //await tx;

        //let balance = await kton.balanceOf.call(deployer);
        //console.log(balance.toNumber());
        //assert.equal(balance.toNumber(), 100 , "returned unexpected kton");
    })

    it('should deduct correct amount of penalty', async() => {
    })

    // need help with timecop
    it('should be able to redeem back all ring when due', async() => {
    })

    it('test bytesToUint256', async() => {
        console.log('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));
        let x = await bank.bytesToUint256.call('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));

        assert.equal(x, 12);
    })

})