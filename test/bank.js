var abi = require('ethereumjs-abi')

const StandardERC223 = artifacts.require('StandardERC223');
const SettingsRegistry = artifacts.require('SettingsRegistry');
const GringottsBank = artifacts.require('GringottsBank');

const gasPrice = 22000000000;
const COIN = 10 ** 18;

const increaseTime = function(duration) {
    const id = Date.now()
  
    return new Promise((resolve, reject) => {
      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [duration],
        id: id,
      }, err1 => {
        if (err1) return reject(err1)
  
        web3.currentProvider.sendAsync({
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: id+1,
        }, (err2, res) => {
          return err2 ? reject(err2) : resolve(res)
        })
      })
    })
  }

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

        ring = StandardERC223.at(await bank.ring.call())
        kton = StandardERC223.at(await bank.kryptonite.call())

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
        let ktonAmount1 = await kton.balanceOf(investor);
        
        assert.equal(ktonAmount1.toNumber(), 1 * COIN);


        await ring.contract.transfer['address,uint256,bytes']( bank.address, 30000 * COIN, '0x' + abi.rawEncode(['uint256'], [12]).toString('hex'), { from: investor, gas: 300000 });

        let ktonAmount = await kton.balanceOf(investor);

        let userTotal = await bank.userTotalDeposit.call(investor);

        let depositId = await bank.userDeposits.call(investor, 1);

        let deposit = await bank.getDeposit.call(depositId);

        // console.log(deposit);

        assert.equal(userTotal.toNumber(), 40000 * COIN);

        assert.equal(depositId.toNumber(), 1);

        assert.equal(deposit[0], investor);
        assert.equal(deposit[1].toNumber(), 30000 * COIN);
        assert.equal(deposit[2].toNumber(), 12);
        assert.equal(deposit[4].toNumber(), 1000);
        assert.equal(deposit[5], false);

        assert.equal(ktonAmount.toNumber(), 4 * COIN);
    })

    it('should deduct correct amount of penalty', async() => {
        let penalty = await bank.computePenalty.call(0);

        console.log("Penalty is ... " + penalty.toNumber());
        assert.equal(penalty.toNumber(), 3 * COIN);
        

        await kton.contract.transfer['address,uint256,bytes']( bank.address, 3 * COIN, '0x' + abi.rawEncode(['uint256'], [0]).toString('hex'), { from: investor, gas: 300000 });

        let userTotal2 = await bank.userTotalDeposit.call(investor);

        let depositId2 = await bank.userDeposits.call(investor, 0);

        let deposit2 = await bank.getDeposit.call(depositId2);
        let ktonAmount2 = await kton.balanceOf(investor);

        assert.equal(userTotal2.toNumber(), 30000 * COIN);

        assert.equal(depositId2.toNumber(), 0);
        assert.equal(deposit2[5], true);
        
        assert.equal(ktonAmount2.toNumber(), 1 * COIN);

    })

    // need help with timecop
    it('should be able to redeem back all ring when due', async() => {
        // time flies, 13 months passed
        increaseTime(60 * 60 * 24 * 30 * 13);

        let ringAmount1 = await ring.balanceOf(investor);

        console.log("RING amount 1 ... " + ringAmount1.toNumber());

        await bank.claimDeposit( 1, { from: investor, gas: 300000 } );

        let ktonAmount = await kton.balanceOf(investor);

        let userTotal = await bank.userTotalDeposit.call(investor);

        let depositId = await bank.userDeposits.call(investor, 1);
        let deposit = await bank.getDeposit.call(depositId);

        assert.equal(deposit[5], true);

        let ringAmount2 = await ring.balanceOf(investor);

        console.log("RING amount 2 ... " + ringAmount2.toNumber());

        assert.equal(ringAmount2.minus(ringAmount1).toNumber(), 30000 * COIN);
    })

    it('test bytesToUint256', async() => {
        console.log('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));
        let x = await bank.bytesToUint256.call('0x' + abi.rawEncode(['uint256'], [12]).toString('hex'));

        assert.equal(x, 12);
    })

})