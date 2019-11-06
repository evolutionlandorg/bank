var abi = require('ethereumjs-abi')

const StandardERC223 = artifacts.require('StandardERC223');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const GringottsBank = artifacts.require('GringottsBank');
const GringottsBankProxy = artifacts.require("./OwnedUpgradeabilityProxy.sol")

const gasPrice = 22000000000;
const COIN = 10 ** 18;

function toWei(ether) {
    return `${ether}000000000000000000`
}

const increaseTime = function (duration) {
    const id = Date.now()

    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [duration],
            id: id,
        }, err1 => {
            if (err1) return reject(err1)

            web3.currentProvider.send({
                jsonrpc: '2.0',
                method: 'evm_mine',
                id: id + 1,
            }, (err2, res) => {
                return err2 ? reject(err2) : resolve(res)
            })
        })
    })
}

contract('Gringotts Bank Test', async (accounts) => {
    let deployer = accounts[0];
    let investor = accounts[1];
    let investor2 = accounts[2];
    let bank;
    let registry;
    let ring;
    let kton;

    before('deploy and configure', async () => {
        // get contract from deployed version
        bank = await GringottsBank.at(GringottsBankProxy.address); //await GringottsBank.deployed();
        registry = await SettingsRegistry.deployed();

        let ring_settings = await bank.CONTRACT_RING_ERC20_TOKEN.call();
        let kton_settings = await bank.CONTRACT_KTON_ERC20_TOKEN.call();
        ring = await StandardERC223.at(await registry.addressOf.call(ring_settings))
        kton = await StandardERC223.at(await registry.addressOf.call(kton_settings))

        console.log('Bank address: ', bank.address);
        console.log('registry address: ', registry.address);
        console.log('RING address: ', ring.address);
        console.log('KTON address: ', kton.address);

        // give some ring to investor
        await ring.mint(investor, toWei(100000), {from: deployer});
    })

    it('bank setting should be same as registry initialization', async () => {
        let bank_unit_interest = await registry.uintOf(await bank.UINT_BANK_UNIT_INTEREST.call());
        let bank_penalty_multiplier = await registry.uintOf(await bank.UINT_BANK_PENALTY_MULTIPLIER.call());

        assert.equal(bank_unit_interest, 1000)
        assert.equal(bank_penalty_multiplier, 3)
    })

    it('should return correct amount of KTON', async () => {
        // deposit 100 RING for 1 year
        await ring.methods['transfer(address,uint256,bytes)'](bank.address, toWei(10000), '0x' + abi.rawEncode(['uint256'], [12]).toString('hex'), {
            from: investor,
            gas: 300000
        });

        let ktonAmount1 = await kton.balanceOf(investor);
        assert.equal(ktonAmount1.toString(), toWei(1));


        await ring.methods['transfer(address,uint256,bytes)'](bank.address, toWei(30000), '0x' + abi.rawEncode(['uint256'], [12]).toString('hex'), {
            from: investor,
            gas: 300000
        });

        let ktonAmount = await kton.balanceOf(investor);

        let userTotal = await bank.userTotalDeposit.call(investor);

        let depositId = await bank.userDeposits.call(investor, 1);

        let deposit = await bank.getDeposit.call(depositId);

        // console.log(deposit);

        assert.equal(userTotal.toString(), toWei(40000));

        assert.equal(depositId.toString(), '1');

        assert.equal(deposit[0], investor);
        assert.equal(deposit[1].toString(), toWei(30000));
        assert.equal(deposit[2].toString(), '12');
        assert.equal(deposit[4].toString(), '1000');
        assert.equal(deposit[5], false);

        assert.equal(ktonAmount.toString(), toWei(4));
    })

    it('should deduct correct amount of penalty', async () => {
        let penalty = await bank.computePenalty.call(0);

        console.log(`Penalty is ... ${penalty}`);
        assert.equal(penalty.toString(), toWei(3));


        await kton.methods['transfer(address,uint256,bytes)'](bank.address, toWei(3), '0x' + abi.rawEncode(['uint256'], [0]).toString('hex'), {
            from: investor,
            gas: 300000
        });

        let userTotal2 = await bank.userTotalDeposit.call(investor);

        let depositId2 = await bank.userDeposits.call(investor, 0);

        let deposit2 = await bank.getDeposit.call(depositId2);
        let ktonAmount2 = await kton.balanceOf(investor);

        assert.equal(userTotal2.toString(), toWei(30000));

        assert.equal(depositId2.toString(), '0');
        assert.equal(deposit2[5], true);

        assert.equal(ktonAmount2.toString(), toWei(1));
    })

    it('should transfer owner of deposit successful', async () => {
        await bank.transferDeposit(investor2, 1, {from: investor, gas: 300000});
        let deposit = await bank.getDeposit.call(1);

        let depositId = await bank.userDeposits.call(investor2, 0);

        assert.equal(deposit[0], investor2);
        assert.equal(depositId, 1);

        await bank.transferDeposit(investor, 1, {from: investor2, gas: 300000});
    })

    // need help with timecop
    it('should be able to redeem back all ring when due', async () => {
        // time flies, 13 months passed
        increaseTime(60 * 60 * 24 * 30 * 13);

        let ringAmount1 = await ring.balanceOf(investor);

        console.log(`RING amount 1 ... ${ringAmount1}`);

        await bank.claimDeposit(1, {from: investor, gas: 300000});

        let ktonAmount = await kton.balanceOf(investor);

        let userTotal = await bank.userTotalDeposit.call(investor);

        let depositId = await bank.userDeposits.call(investor, 1);
        let deposit = await bank.getDeposit.call(depositId);

        assert.equal(deposit[5], true);

        let ringAmount2 = await ring.balanceOf(investor);

        console.log(`RING amount 2 ... ${ringAmount2}`);

        assert.equal(ringAmount2.sub(ringAmount1).toString(), toWei(30000));
    })

    it('test bytesToUint256', async () => {
        console.log('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));
        let x = await bank.bytesToUint256.call('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));

        assert.equal(x, 12);
    })

    it('test burndrop', async () => {
        let userTotal0 = await bank.userTotalDeposit.call(investor);

        assert.equal(userTotal0.toString(), '0');

        await ring.methods['transfer(address,uint256,bytes)'](bank.address, toWei(10000), '0x' + abi.rawEncode(['uint256'], [12]).toString('hex'), {
            from: investor,
            gas: 300000
        });
        let depositId = await bank.userDeposits.call(investor, 2);
        let deposit = await bank.getDeposit.call(depositId);

        let userTotal = await bank.userTotalDeposit.call(investor);

        assert.equal(userTotal.toString(), toWei(10000));

        console.log('burndrop params: ', deposit, depositId, investor, deposit[1], deposit[2], deposit[3], deposit[4], '0x');

        await bank.burndrop(depositId, investor, deposit[2], deposit[3], deposit[4], deposit[1], '0x', {
            from: investor,
            gas: 300000
        })

        let userTotal1 = await bank.userTotalDeposit.call(investor);
        assert.equal(userTotal1.toString(), '0');
    })
})
