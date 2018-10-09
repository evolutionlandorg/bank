var abi = require('ethereumjs-abi')

const StandardERC223 = artifacts.require('StandardERC223');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const GringottsBank = artifacts.require('GringottsBank');

const gasPrice = 22000000000;
const COIN = 10 ** 18;

contract('Gringotts Bank Interest Calculating Test', async(accounts) => {
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

        ring = StandardERC223.at(await bank.ring.call())
        kton = StandardERC223.at(await bank.kryptonite.call())

        console.log('Bank address: ', bank.address);
        console.log('registry address: ', registry.address);
        console.log('RING address: ', ring.address);
        console.log('KTON address: ', kton.address);
    })

    it('test computeInterest', async() => {
        for (var x = 0; x <=36; x++)
        {
            console.log("Interest of " + x + " months for 10000 RING is " + (await bank.computeInterest.call(10000000, x, 1000)).toNumber()/1000.0 + " KTON");
        }
    })

})