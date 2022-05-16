const assert = require("chai").assert;
const truffleAssert = require('truffle-assertions');
var BigNumber = require('bignumber.js');
const web3Abi = require('web3-eth-abi');

const _ = require('./utils.js');
const math = require('./math.js');
const help = require('./helper.js');

var DAO = artifacts.require("./Dao.sol");
var SPARTA = artifacts.require("./Sparta.sol");
var UTILS = artifacts.require("./Utils.sol");
var TOKEN = artifacts.require("./Token1.sol");
var RESERVE = artifacts.require("./Reserve.sol");
var DAOVAULT = artifacts.require("./DaoVault.sol");
var POOL = artifacts.require("./Pool.sol");
var POOLFACTORY = artifacts.require("./PoolFactory.sol");
var ROUTER = artifacts.require("./Router.sol");
var WBNB = artifacts.require("./WBNB");

var SYNTH = artifacts.require("./Synth.sol");
var SYNTHFACTORY = artifacts.require("./SynthFactory.sol");
var SYNTHVAULT = artifacts.require("./SynthVault.sol");

var sparta; var token1;  var token2; var wbnb;
var utils; var utils2; var router; var router2; var Dao; var Dao2;
var poolWBNB; var poolTKN1; var synthTNK2; var synthBNB;var reserve;
var acc0; var acc1; var acc2; var acc3;
var allocation = 2500000;
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
contract('SWAP + ZAP + MINT + BURN', function (accounts) {
    constructor(accounts)
    createPoolBNB(acc0, 10000, 30)
    // createPoolBUSD(acc0, 10000, 10000)
    // addLiquidityBNB(acc1, 9)
    // addLiquidityBUSD(acc1, 100)
    BNBPoolBalanceCheck()
    safetyCheck();
    swapBNBForSparta(acc2, 3)
    safetyCheck();
    // swapSPARTAForBUSD(acc1, 500)
    // swapBUSDForSparta(acc1, 300)
    // swapBNBForBUSD(acc2, 2)
    // swapBUSDForBNB(acc1, 500)
    swapBNBForSparta(acc2, 3)
    safetyCheck();
    swapBNBForSparta(acc2, 1)
    safetyCheck();
    swapSPARTAForBNB(acc1, 500)
    safetyCheck();
    // swapSPARTAForBNB(acc1, 500)
    // safetyCheck();
    // swapSPARTAForBNB(acc1, 500)
    // safetyCheck();
    // swapSPARTAForBNB(acc1, 500)
    // safetyCheck();
    // swapSPARTAForBNB(acc1, 500)
    // swapSPARTAForBNB(acc1, 500)
    // swapSPARTAForBNB(acc1, 500)
    // swapSPARTAForBNB(acc1, 500)
    // swapSPARTAForBNB(acc1, 500)
    safetyCheck();
    // curatePools()
    // swapBNBForBUSD(acc2, 2)
    // swapBUSDForBNB(acc1, 500)
    // swapSPARTA(acc1, 1000)
    // swapBNB(acc2, 1)
    // BNBPoolBalanceCheck()
    // zapLiquidity(acc1, 20)
    // createSyntheticBNB()
    // createSyntheticBUSD()
    // removeSynths()
    // addSynths()
    // swapSpartaToSynth(acc1, 200)
    // swapBNBToSynthBNB(acc2, 1)
    //  TokenPoolBalanceCheck()
    //  swapBUSDToSynthBUSD(acc1, 10)
    //  removeCuratePools()
    // swapSynthBNBToSparta(acc1, 0.1)
    // swapSynthBUSDToBUSD(acc1, 1)
     

})


//################################################################
// CONSTRUCTION
function constructor(accounts) {
    acc0 = accounts[0]; acc1 = accounts[1]; acc2 = accounts[2]; acc3 = accounts[3]
    it("constructor events", async () => {
        sparta = await SPARTA.new(acc0)         // deploy sparta v2
        Dao = await DAO.new(sparta.address)     // deploy daoV2
        wbnb = await WBNB.new()                 // deploy wBNB 
        utils = await UTILS.new(sparta.address) // deploy utilsV2
        token1 = await TOKEN.new()   
        reserve = await RESERVE.new(sparta.address) // deploy reserve 
        daoVault = await DAOVAULT.new(sparta.address); // deploy daoVault
        synthVault = await SYNTHVAULT.new(sparta.address); // deploy daoVault
        router = await ROUTER.new(sparta.address, wbnb.address,); // deploy router
        poolFactory = await POOLFACTORY.new(sparta.address,  wbnb.address) // deploy poolfactory
        synthFactory = await SYNTHFACTORY.new(sparta.address,  wbnb.address) // deploy poolfactory
        await Dao.setGenesisAddresses(router.address,utils.address,reserve.address, utils.address);
        await Dao.setVaultAddresses(daoVault.address,synthVault.address, synthVault.address);
        await Dao.setFactoryAddresses(poolFactory.address,synthFactory.address);
        await sparta.changeDAO(Dao.address)
        
     
        //   await reserve.flipEmissions();    
        // await sparta.flipEmissions();  
        await router.flipSynthMinting();

        await sparta.transfer(acc1, _.getBN(_.BN2Str(100000 * _.one)))
        await sparta.transfer(reserve.address, _.getBN(_.BN2Str(100000 * _.one)))
        await sparta.transfer(acc2, _.getBN(_.BN2Str(100000 * _.one)))

        await token1.transfer(acc1, _.getBN(_.BN2Str(100000 * _.one)))
        await token1.transfer(acc2, _.getBN(_.BN2Str(100000 * _.one)))

        await token1.approve(router.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await token1.approve(router.address, _.BN2Str(500000 * _.one), { from: acc1 })
        await token1.approve(router.address, _.BN2Str(500000 * _.one), { from: acc2 })

        await sparta.approve(router.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await sparta.approve(router.address, _.BN2Str(500000 * _.one), { from: acc1 })
        await sparta.approve(router.address, _.BN2Str(500000 * _.one), { from: acc2 })

        await sparta.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await sparta.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc1 })
        await sparta.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc2 })

        await token1.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await token1.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc1 })
        await token1.approve(poolFactory.address, _.BN2Str(500000 * _.one), { from: acc2 })


    });
}
async function createPoolBNB(acc, inputB, inputT) {
    it("It should deploy BNB Pool", async () => {
        let inputBase = _.getBN(inputB * _.one)
        let inputToken = _.getBN(inputT * _.one)
        let token = _.BNB
        var _pool = await poolFactory.createPoolADD.call(inputBase, inputToken, token, {value: inputToken})
        await poolFactory.createPoolADD(inputBase, inputToken, token, {value: inputToken})
        poolBNB = await POOL.at(_pool)
        //console.log(`Pools: ${poolBNB.address}`)
        // const baseAddr = await poolBNB.BASE()
        // assert.equal(baseAddr, sparta.address, "address is correct")
        let supply = await sparta.totalSupply()
        await sparta.approve(router.address, supply, { from: acc0 })
        await sparta.approve(router.address, supply, { from: acc1 })

        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(inputToken), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(inputBase), 'sparta balance')
        assert.equal(_.BN2Str(await poolBNB.balanceOf(acc0)), _.BN2Str(inputBase.minus(100*10**18)), 'Correct LPS')

    })
}
async function createPoolBUSD(acc, inputB, inputT) {
    it("It should deploy BUSD Pool", async () => {
        let inputBase = _.getBN(inputB * _.one)
        let inputToken = _.getBN(inputT * _.one)
        let token = token1.address
        var _pool = await poolFactory.createPoolADD.call(inputBase, inputToken, token,{from:acc})
        await poolFactory.createPoolADD(inputBase, inputToken, token,{from:acc})
        poolBUSD = await POOL.at(_pool)

        const baseAddr = await poolBUSD.BASE()
        assert.equal(baseAddr, sparta.address, "address is correct")

        let supply = await sparta.totalSupply()
        await sparta.approve(poolBUSD.address, supply, { from: acc0 })
        await sparta.approve(poolBUSD.address, supply, { from: acc1 })

        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(inputToken), 'BUSD balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(inputBase), 'sparta balance')
        assert.equal(_.BN2Str(await poolBUSD.balanceOf(acc)), _.BN2Str(inputBase.minus(100*10**18)), 'Correct LPS')

    })
}
async function curatePools() {
    it("Curate POOls", async () => {
        await poolFactory.addCuratedPool(_.BNB);
        await poolFactory.addCuratedPool(token1.address);
    })
}
async function addLiquidityBNB(acc, t) {
    it(`It should addLiquidity BNB`, async () => {
        let token = _.BNB
        let inputToken = _.getBN(t * _.one)
        let poolData = await utils.getPoolData(token);
        var B = _.getBN(poolData.baseAmount)
        var T = _.getBN(poolData.tokenAmount)
        let b = inputToken.times(B).div(T);
        poolUnits = _.getBN((await poolBNB.totalSupply()))
        let before = _.getBN(await poolBNB.balanceOf(acc))
        let units = math.calcLiquidityUnits(b, B, inputToken, T, poolUnits)
        let tx = await router.addLiquidity(inputToken,b, token, {from: acc, value:inputToken})
         poolData = await utils.getPoolData(token);
         assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(B.plus(b)))
         assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(T.plus(inputToken)))
         assert.equal(_.BN2Str((await poolBNB.totalSupply())), _.BN2Str(poolUnits.plus(units)), 'poolUnits')
         assert.equal(_.BN2Str(await poolBNB.balanceOf(acc)), _.BN2Str(before.plus(units)), 'units')
         assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(B.plus(b)), 'sparta balance')
         assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(T.plus(inputToken)), 'wbnb balance')
    })
}
async function addLiquidityBUSD(acc, t) {
    it(`It should addLiquidity BUSD `, async () => {
        let token = token1.address
        let inputToken = _.getBN(t * _.one)
        let poolData = await utils.getPoolData(token);
        var B = _.getBN(poolData.baseAmount)
        var T = _.getBN(poolData.tokenAmount)
        let b = inputToken.times(B).div(T);
        poolUnits = _.getBN((await poolBUSD.totalSupply()))
        let before = _.getBN(await poolBUSD.balanceOf(acc))
        let units = math.calcLiquidityUnits(b, B, inputToken, T, poolUnits)
        let tx = await router.addLiquidity(inputToken,b, token, {from: acc})
         poolData = await utils.getPoolData(token);
         assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(B.plus(b)))
         assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(T.plus(inputToken)))
         assert.equal(_.BN2Str((await poolBUSD.totalSupply())), _.BN2Str(poolUnits.plus(units)), 'poolUnits')
         assert.equal(_.BN2Str(await poolBUSD.balanceOf(acc)), _.BN2Str(before.plus(units)), 'units')
         assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(B.plus(b)), 'sparta balance')
         assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(T.plus(inputToken)), 'wbnb balance')
    })
}
async function swapSPARTAForBNB(acc, xx){
    it(`It should swap sparta for BNB`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = _.BNB
        let fromToken = sparta.address
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(toToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, X, Y)
        let fee = math.calcSwapOutput(x, X, Y)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc})
        poolData = await utils.getPoolData(toToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.plus(x)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.minus(y)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X.plus(x)), 'sparta balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y.minus(y)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.minus(x)), 'sparta balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.plus(y)), 'wbnb balance')
       
    })
}
async function swapSPARTAForBUSD(acc, xx){
    it(`It should swap sparta for BUSD`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = token1.address
        let fromToken = sparta.address
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await token1.balanceOf(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(toToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, X, Y)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc})
        poolData = await utils.getPoolData(toToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.plus(x)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.minus(y)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(X.plus(x)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(Y.minus(y)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.minus(x)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(tokenStart.plus(y)), 'wbnb balance')
       
    })
}
async function swapBNBForSparta(acc, xx){
    it(`It should swap BNB for sparta`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = sparta.address
        let fromToken = _.BNB
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(fromToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, Y, X)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc, value:x})
        poolData = await utils.getPoolData(fromToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.minus(y)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.plus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X.minus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y.plus(x)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.plus(y)), 'sparta balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.minus(x)), 'wbnb balance')
       
    })
}
async function swapBUSDForSparta(acc, xx){
    it(`It should swap BUSD for Sparta`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = sparta.address
        let fromToken = token1.address
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await token1.balanceOf(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(fromToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, Y, X)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc})
        poolData = await utils.getPoolData(fromToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.minus(y)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.plus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(X.minus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(Y.plus(x)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.plus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(tokenStart.minus(x)), 'wbnb balance')
       
    })
}
async function swapBNBForBUSD(acc, xx) {
    it(`It should swap BNB for BUSD`, async () => {
        let x = _.getBN(xx * _.oneBN)
        let toToken = token1.address
        let fromToken = _.BNB
        let busdStart = _.getBN(await token1.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let poolDataBNB = await utils.getPoolData(fromToken);
        let poolDataBUSD = await utils.getPoolData(toToken);
        const X = _.getBN(poolDataBNB.tokenAmount)
        const Y = _.getBN(poolDataBNB.baseAmount)
        const B = _.getBN(poolDataBUSD.baseAmount)
        const Z = _.getBN(poolDataBUSD.tokenAmount)
        let y = math.calcSwapOutput(x, X, Y)
        let feey = math.calcSwapFee(x, X, Y)
        let z = math.calcSwapOutput(y, B, Z)
        let feez = math.calcSwapFee(y, B, Z)
        let minAmount = _.getBN(1*_.oneBN)
        let fee = math.calcValueIn(feey, B.plus(y), Z.minus(z)).plus(feez)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc, value:x})
        poolDataBNB = await utils.getPoolData(fromToken);
        poolDataBUSD = await utils.getPoolData(toToken);
        assert.equal(_.BN2Str(poolDataBNB.tokenAmount), _.BN2Str(X.plus(x)))
        assert.equal(_.BN2Str(poolDataBNB.baseAmount), _.BN2Str(Y.minus(y)))
        assert.equal(_.BN2Str(poolDataBUSD.baseAmount), _.BN2Str(B.plus(y)))
        assert.equal(_.BN2Str(poolDataBUSD.tokenAmount), _.BN2Str(Z.minus(z)))
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(X.plus(x)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(Y.minus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(B.plus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(Z.minus(z)), 'token1 balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.minus(x)), 'bnb balance')
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(busdStart.plus(z)), 'token1 balance')
    })
}
async function swapBUSDForBNB(acc, xx) {
    it(`It should swap BUSD for BNB`, async () => {
        let x = _.getBN(xx * _.oneBN)
        let fromToken = token1.address 
        let toToken = _.BNB
        let busdStart = _.getBN(await token1.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let poolDataBUSD = await utils.getPoolData(fromToken);
        let poolDataBNB = await utils.getPoolData(toToken);
        const X = _.getBN(poolDataBNB.tokenAmount)
        const Y = _.getBN(poolDataBNB.baseAmount)
        const B = _.getBN(poolDataBUSD.baseAmount)
        const Z = _.getBN(poolDataBUSD.tokenAmount)
        let y = math.calcSwapOutput(x, Z, B)
        let z = math.calcSwapOutput(y, Y, X)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc})
        poolDataBNB = await utils.getPoolData(toToken);
        poolDataBUSD = await utils.getPoolData(fromToken);
        assert.equal(_.BN2Str(poolDataBNB.tokenAmount), _.BN2Str(X.minus(z)))
        assert.equal(_.BN2Str(poolDataBNB.baseAmount), _.BN2Str(Y.plus(y)))
        assert.equal(_.BN2Str(poolDataBUSD.baseAmount), _.BN2Str(B.minus(y)))
        assert.equal(_.BN2Str(poolDataBUSD.tokenAmount), _.BN2Str(Z.plus(x)))
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(X.minus(z)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(Y.plus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(B.minus(y)), 'sparta balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(Z.plus(x)), 'token1 balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.plus(z)), 'bnb balance')
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(busdStart.minus(x)), 'token1 balance')
    })
}
async function swapSPARTA(acc, xx){
    it(`It should swap sparta for BNB gets Dividend`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = _.BNB
        let fromToken = sparta.address
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(toToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, X, Y)
        let fe = math.calcSwapFee(x, X, Y)
        let fee = fe.times(X).div(Y)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc})
        poolData = await utils.getPoolData(toToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.plus(x).plus(fee)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.minus(y)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X.plus(x).plus(fee)), 'sparta balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y.minus(y)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.minus(x)), 'sparta balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.plus(y)), 'wbnb balance')
       
    })
}
async function swapBNB(acc, xx){
    it(`It should swap BNB for sparta gets dividend`, async () =>{
        let x = _.getBN(xx * _.oneBN)
        let toToken = sparta.address
        let fromToken = _.BNB
        let baseStart = _.getBN(await sparta.balanceOf(acc))
        let tokenStart = _.getBN(await web3.eth.getBalance(acc))
        let feeOnTransfer = _.getBN(await sparta.feeOnTransfer())
        let totalSupply = _.BN2Str(await sparta.totalSupply())
        let poolData = await utils.getPoolData(fromToken);
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let y = math.calcSwapOutput(x, Y, X)
        let fee = math.calcSwapFee(x, Y, X)
        let minAmount = _.getBN(1*_.oneBN)
        let tx = await router.swap(x, fromToken, toToken, minAmount,{from:acc, value:x})
        poolData = await utils.getPoolData(fromToken);
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.minus(y).plus(fee)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.plus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X.minus(y).plus(fee)), 'sparta balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y.plus(x)), 'wbnb balance')
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(baseStart.plus(y)), 'sparta balance')
        assert.isAtMost(_.BN2Int(await web3.eth.getBalance(acc)), _.BN2Int(tokenStart.minus(x)), 'wbnb balance')
       
    })
}
async function zapLiquidity(acc, xx) {
    it("It should zap liquidity from BNB to BUSD pool", async () => {
        let x = _.getBN(xx * _.oneBN)
        let fromTOKEN = poolBNB.address
        let toTOKEN = poolBUSD.address
        let BUSDP = _.BN2Str(await poolBUSD.balanceOf(acc))
        let baseP = _.BN2Str(await sparta.balanceOf(poolBNB.address))
        let wbnbb = _.BN2Str(await wbnb.balanceOf(poolBNB.address))
        let TOKENN = _.BN2Str(await token1.balanceOf(poolBUSD.address))
         let baset = _.BN2Str(await sparta.balanceOf(poolBUSD.address))
         let BNBp = _.BN2Str(await poolBNB.balanceOf(acc))
        // console.log("BUSDP bal",BUSDP/_.one )
        // console.log("BNBP bal",BNBp/_.one )
        // console.log("BASE poolBNB",baseP/_.one )
        // console.log("BNB poolBNB", wbnbb/_.one)
        // console.log("BASE poolBUSD", baset/_.one)
        // console.log("TOKEN poolBUSD", TOKENN/_.one)
        await poolBNB.approve(router.address, _.BN2Str(100000*10**18),{from:acc})
        await poolBUSD.approve(router.address, _.BN2Str(100000*10**18),{from:acc})
        let tx = await router.zapLiquidity(x, fromTOKEN, toTOKEN, {from:acc})
        let basePA = _.BN2Str(await sparta.balanceOf(poolBNB.address))
        let wbnbbA = _.BN2Str(await wbnb.balanceOf(poolBNB.address))
        let TOKENNA = _.BN2Str(await token1.balanceOf(poolBUSD.address))
         let basetA = _.BN2Str(await sparta.balanceOf(poolBUSD.address))
        let BNBP = _.BN2Str(await poolBNB.balanceOf(acc))
        let BUSDPa = _.BN2Str(await poolBUSD.balanceOf(acc))
        // console.log("BNBP bal",BNBP/_.one )
        // console.log("BUSDP bal",BUSDPa/_.one )
        // console.log("BASE poolBNB",basePA/_.one )
        // console.log("BNB poolBNB", wbnbbA/_.one)
        // console.log("BASE poolBUSD", basetA/_.one)
        // console.log("TOKEN poolBUSD", TOKENNA/_.one)
       
    })
}
async function createSyntheticBNB() {
    it("It should Create Synthetic BNB ", async () => {
        let token = _.BNB
        var _synth =  await synthFactory.createSynth.call(token);
        await synthFactory.createSynth(token);
        synthBNB = await SYNTH.at(_synth)
        await synthBNB.approve(router.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await synthBNB.approve(router.address, _.BN2Str(500000 * _.one), { from: acc1 });
        await synthBNB.approve(router.address, _.BN2Str(500000 * _.one), { from: acc2 })
        assert.equal(_.BN2Str(await synthFactory.synthCount()), 1, 'length')
        // console.log("Symbol: ",await synthBNB.symbol());
        //  console.log("Name: ",await synthBNB.name());
    })
}
async function createSyntheticBUSD() {
    it("It should Create Synthetic BUSD ", async () => {
        let token = token1.address
        var _synth =  await synthFactory.createSynth.call(token);
        await synthFactory.createSynth(token);
        synthBUSD = await SYNTH.at(_synth)
        await synthBUSD.approve(router.address, _.BN2Str(500000 * _.one), { from: acc0 })
        await synthBUSD.approve(router.address, _.BN2Str(500000 * _.one), { from: acc1 });
        await synthBUSD.approve(router.address, _.BN2Str(500000 * _.one), { from: acc2 })
        assert.equal(_.BN2Str(await synthFactory.synthCount()), 2, 'length')
        // console.log("Symbol: ",await synthBUSD.symbol());
        //  console.log("Name: ",await synthBUSD.name());
    })
}
async function removeSynths() {
    it("Remove Synths ", async () => {
        await synthFactory.removeSynth(_.BNB);
        await synthFactory.removeSynth(token1.address);
        assert.equal(await synthFactory.isSynth(synthBNB.address), false, 'Removed')
        assert.equal(await synthFactory.isSynth(synthBUSD.address), false, 'Removed')
        assert.equal(await synthFactory.getSynth(_.BNB), synthBNB.address, 'Remains In Mapping')
        assert.equal(await synthFactory.getSynth(token1.address), synthBUSD.address, 'Remains In Mapping')
        assert.equal(_.BN2Str(await synthFactory.synthCount()), 0, 'length')
    })
}
async function addSynths() {
    it("Add Synths ", async () => {
        await synthFactory._addSynth(synthBNB.address);
        await synthFactory._addSynth(synthBUSD.address);
        assert.equal(await synthFactory.isSynth(synthBNB.address), true, 'Added')
        assert.equal(await synthFactory.isSynth(synthBUSD.address), true, 'Added')
        assert.equal(_.BN2Str(await synthFactory.synthCount()), 2, 'length')
    })
}
async function removeCuratePools() {
    it("Remove Curated POOls", async () => {
        await poolFactory.removeCuratedPool(_.BNB);
        await poolFactory.removeCuratedPool(token1.address);
        assert.equal(await poolFactory.isCuratedPool(poolBNB.address), false, 'Removed')
        assert.equal(await poolFactory.isCuratedPool(poolBUSD.address), false, 'Removed')
        assert.equal(_.BN2Str(await poolFactory.curatedPoolCount()), 0, 'Removed')
        assert.equal(_.BN2Str(await poolFactory.vaultAssetsLength()), 0, 'Removed')

        assert.equal(await synthFactory.isSynth(synthBUSD.address), false, 'Removed')
        assert.equal(await synthFactory.isSynth(synthBNB.address), false, 'Removed')
        assert.equal(await synthFactory.getSynth(_.BNB), synthBNB.address, 'Remains In Mapping')
        assert.equal(await synthFactory.getSynth(token1.address), synthBUSD.address, 'Remains In Mapping')
        assert.equal(_.BN2Str(await synthFactory.synthCount()), 0, 'length')

    })
}
async function swapSpartaToSynth(acc, xx) {
    it("Swap BASE to Synthetic BNB", async () => {
        let x = _.getBN(xx * _.oneBN)
        let fromToken = sparta.address
        let toSynth = synthBNB.address
        let token = _.BNB;
        let synBal = _.getBN(await synthBNB.balanceOf(synthVault.address));
        let basBal = _.getBN(await sparta.balanceOf(acc));
        let basBalPool = _.getBN(await sparta.balanceOf(poolBNB.address));
        let bAA =_.getBN( await poolBNB.baseAmount());
        let poolData = await utils.getPoolData(token);
        let lpBalance = _.getBN(await synthBNB.collateral());
        let lpDebt =_.getBN( await synthBNB.totalSupply());
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let asymAdd = _.getBN(await utils.calcLiquidityUnitsAsym(x, poolBNB.address))
        let poolSynBal = _.getBN(await poolBNB.balanceOf(synthBNB.address));
        let totalSynths = _.getBN(await synthBNB.totalSupply());
        await router.swapAssetToSynth(x, fromToken, toSynth, {from:acc});
        let synthMint = math.calcSwapOutput(x, (X), (Y))
        poolData = await utils.getPoolData(token);
        let lpBalanceA = _.getBN(await synthBNB.collateral());
        let lpDebtA =_.getBN( await synthBNB.totalSupply());
        let bA =_.getBN( await poolBNB.baseAmount());
        let basBalPooll = _.getBN(await sparta.balanceOf(poolBNB.address));
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X.plus(x)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y))
        assert.equal(_.BN2Str(lpBalanceA), _.BN2Str(lpBalance.plus(asymAdd)))
        assert.equal(_.BN2Str(lpDebtA), _.BN2Str(lpDebt.plus(synthMint)))
        assert.equal(_.BN2Str(await poolBNB.balanceOf(synthBNB.address)), _.BN2Str(poolSynBal.plus(asymAdd)))
        assert.equal(_.BN2Str(await synthBNB.totalSupply()), _.BN2Str(totalSynths.plus(synthMint)))
        assert.equal(_.BN2Str(await synthBNB.balanceOf(synthVault.address)), _.BN2Str(synBal.plus(synthMint)))
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(basBal.minus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X.plus(x)), 'bnb balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y), 'sparta balance')
        
    })
}
async function swapBNBToSynthBNB(acc, xx) {
    it("Swap BNB to Synthetic BNB", async () => {
        let x = _.getBN(xx * _.oneBN)
        let fromToken = _.BNB;
        let toSynth = synthBNB.address
        let token = _.BNB;
        let synBal = _.getBN(await synthBNB.balanceOf(acc));
        let basBal = _.getBN(await sparta.balanceOf(acc));
        let basBalPool = _.getBN(await sparta.balanceOf(poolBNB.address));
        let bAA =_.getBN( await poolBNB.baseAmount());
        let poolData = await utils.getPoolData(token);
        let lpBalance = _.getBN(await synthBNB.collateral());
        let lpDebt =_.getBN( await synthBNB.totalSupply());
        let totalS = _.getBN(await poolBNB.totalSupply())
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let baseIN = math.calcSwapOutput(x, Y, X)
        let asymAdd = totalS.times(baseIN).div((X).times("2"))
        let poolSynBal = _.getBN(await poolBNB.balanceOf(synthBNB.address));
        let totalSynth = _.getBN(await synthBNB.totalSupply());
        let totalSynths = _.getBN(await synthBNB.totalSupply());
        await sleep(8000)
        await router.swapAssetToSynth(x, fromToken, toSynth, {from:acc, value:x});
        let synthMint = math.calcSwapOutput(baseIN, X.minus(baseIN), Y.plus(x))
        poolData = await utils.getPoolData(token);
        poolData = await utils.getPoolData(token);
        let lpBalanceA = _.getBN(await synthBNB.collateral());
        let lpDebtA =_.getBN( await synthBNB.totalSupply());
        let bA =_.getBN( await poolBNB.baseAmount());
        let basBalPooll = _.getBN(await sparta.balanceOf(poolBNB.address));
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.plus(x)))
        assert.equal(_.BN2Str(lpBalanceA), _.BN2Str(lpBalance.plus(asymAdd)))
        assert.equal(_.BN2Str(lpDebtA), _.BN2Str(lpDebt.plus(synthMint)))
        assert.equal(_.BN2Str(await poolBNB.balanceOf(synthBNB.address)), _.BN2Str(poolSynBal.plus(asymAdd)))
        assert.equal(_.BN2Str(await synthBNB.totalSupply()), _.BN2Str(totalSynths.plus(synthMint)))
        // assert.equal(_.BN2Str(await synthBNB.balanceOf(acc)), _.BN2Str(synBal.plus(synthMint)))
        // assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(basBal.minus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(X), 'bnb balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(Y.plus(x)), 'sparta balance')
        
    })
}
async function swapSynthBNBToSparta(acc, xx) {
    it("Swap Synthetic BNB To Sparta", async () => {
        let x = _.getBN(xx * _.oneBN)
        let toToken = sparta.address 
        let fromSynth = synthBNB.address
        let token = _.BNB;
        let input = _.BN2Str(await synthBNB.balanceOf(acc));
        let synBal = _.getBN(await synthBNB.balanceOf(acc));
        let basBal = _.getBN(await sparta.balanceOf(acc));
        let lpBalance = _.getBN(await synthBNB.collateral());
        let lpDebt =_.getBN( await synthBNB.totalSupply());
        let poolData = await utils.getPoolData(token);
        const X = _.getBN(poolData.tokenAmount)
        const Y = _.getBN(poolData.baseAmount)
        let poolSynBal = _.getBN(await poolBNB.balanceOf(synthBNB.address));
        let totalSynth = _.getBN(await synthBNB.totalSupply())
        let totalSynths = _.getBN(await synthBNB.totalSupply())
        let lpShare = _.BN2Str((_.getBN(x).times(lpBalance)).div(lpDebt));
        let baseSwapped = math.calcSwapOutput(x, X, Y)
        baseSwapped = baseSwapped.times(9500).div(10000); 
        await router.swapSynthToAsset(x,fromSynth,toToken,{from:acc})
        poolData = await utils.getPoolData(token);
        let lpBalanceA = _.getBN(await synthBNB.collateral());
        let lpDebtA =_.getBN( await synthBNB.totalSupply());
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(Y.minus(baseSwapped)))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(X))
        assert.equal(_.BN2Str(lpBalanceA), _.BN2Str(lpBalance.minus(lpShare)))
        assert.equal(_.BN2Str(lpDebtA), _.BN2Str(lpDebt.minus(x)))
        assert.equal(_.BN2Str(await poolBNB.balanceOf(synthBNB.address)), _.BN2Str(poolSynBal.minus(lpShare)))
        assert.equal(_.BN2Str(await synthBNB.totalSupply()), _.BN2Str(totalSynths.minus(x)))
        // assert.equal(_.BN2Str(await synthBNB.balanceOf(acc)), _.BN2Str(synBal.minus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(basBal.plus(baseSwapped)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBNB.address)), _.BN2Str(Y.minus(baseSwapped)), 'wbnb balance')
        assert.equal(_.BN2Str(await wbnb.balanceOf(poolBNB.address)), _.BN2Str(X), 'sparta balance')
        
    })
}
async function swapBUSDToSynthBUSD(acc, xx) {
    it("Swap BUSD to Synthetic BUSD", async () => {
        let x = _.getBN(xx * _.oneBN)
        let fromToken = token1.address;
        let toSynth = synthBUSD.address
        let token = token1.address;
        let synBal = _.getBN(await synthBUSD.balanceOf(acc));
        let basBal = _.getBN(await token1.balanceOf(acc));
        let basBalPool = _.getBN(await sparta.balanceOf(poolBUSD.address));
        let bAA =_.getBN( await poolBUSD.baseAmount());
        let poolData = await utils.getPoolData(token);
        let lpBalance = _.getBN(await synthBUSD.collateral());
        let lpDebt =_.getBN( await synthBUSD.totalSupply());
        let totalS = _.getBN(await poolBUSD.totalSupply())
        const X = _.getBN(poolData.baseAmount)
        const Y = _.getBN(poolData.tokenAmount)
        let baseIN = math.calcSwapOutput(x, Y, X)
        let asymAdd = totalS.times(baseIN).div((X).times("2"))
        let poolSynBal = _.getBN(await poolBUSD.balanceOf(synthBUSD.address));
        let totalSynth = _.getBN(await synthBUSD.totalSupply());
        let totalSynths = _.getBN(await synthBUSD.totalSupply());
        await router.swapAssetToSynth(x, fromToken, toSynth, {from:acc});
        let synthMint = math.calcSwapOutput(baseIN, X.minus(baseIN), Y.plus(x))
        poolData = await utils.getPoolData(token);
        let lpBalanceA = _.getBN(await synthBUSD.collateral());
        let lpDebtA =_.getBN( await synthBUSD.totalSupply());
        let bA =_.getBN( await poolBUSD.baseAmount());
        let basBalPooll = _.getBN(await sparta.balanceOf(poolBUSD.address));
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(X))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(Y.plus(x)))
        assert.equal(_.BN2Str(lpBalanceA), _.BN2Str(lpBalance.plus(asymAdd)))
        assert.equal(_.BN2Str(lpDebtA), _.BN2Str(lpDebt.plus(synthMint)))
        assert.equal(_.BN2Str(await poolBUSD.balanceOf(synthBUSD.address)), _.BN2Str(poolSynBal.plus(asymAdd)))
        assert.equal(_.BN2Str(await synthBUSD.totalSupply()), _.BN2Str(totalSynths.plus(synthMint)))
        // assert.equal(_.BN2Str(await synthBUSD.balanceOf(acc)), _.BN2Str(synBal.plus(synthMint)))
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(basBal.minus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(X), 'bnb balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(Y.plus(x)), 'sparta balance')
    })
}
async function swapSynthBUSDToBUSD(acc, xx) {
    it("Swap Synthetic BUSD To BUSD", async () => {
        let x = _.getBN(xx * _.oneBN)
        let toToken = token1.address 
        let fromSynth = synthBUSD.address
        let token = token1.address;
        let input = _.getBN(await token1.balanceOf(acc));
        let synBal = _.getBN(await synthBUSD.balanceOf(acc));
        let basBal = _.getBN(await sparta.balanceOf(acc));
        let lpBalance = _.getBN(await synthBUSD.collateral());
        let lpDebt =_.getBN( await synthBUSD.totalSupply());
        let poolData = await utils.getPoolData(token);
        const X = _.getBN(poolData.tokenAmount)
        const Y = _.getBN(poolData.baseAmount)
        let poolSynBal = _.getBN(await poolBUSD.balanceOf(synthBUSD.address));
        let totalSynth = _.getBN(await synthBUSD.totalSupply())
        let totalSynths = _.getBN(await synthBUSD.totalSupply())
        let lpShare = _.BN2Str((_.getBN(x).times(lpBalance)).div(lpDebt));
        let baseSwapped = math.calcSwapOutput(x, X, Y)
        baseSwapped = baseSwapped.times(9500).div(10000); 
        let tokenOut = math.calcSwapOutput(baseSwapped,Y.minus(baseSwapped), X)
       
        await router.swapSynthToAsset(x,fromSynth,toToken,{from:acc})
        poolData = await utils.getPoolData(token);
        let lpBalanceA = _.getBN(await synthBUSD.collateral());
        let lpDebtA =_.getBN( await synthBUSD.totalSupply());
        assert.equal(_.BN2Str(poolData.baseAmount), _.BN2Str(Y))
        assert.equal(_.BN2Str(poolData.tokenAmount), _.BN2Str(X.minus(tokenOut)))
        assert.equal(_.BN2Str(lpBalanceA), _.BN2Str(lpBalance.minus(lpShare)))
        assert.equal(_.BN2Str(lpDebtA), _.BN2Str(lpDebt.minus(x)))
        assert.equal(_.BN2Str(await poolBUSD.balanceOf(synthBUSD.address)), _.BN2Str(poolSynBal.minus(lpShare)))
        assert.equal(_.BN2Str(await synthBUSD.totalSupply()), _.BN2Str(totalSynths.minus(x)))
        // assert.equal(_.BN2Str(await synthBUSD.balanceOf(acc)), _.BN2Str(synBal.minus(x)))
        assert.equal(_.BN2Str(await sparta.balanceOf(acc)), _.BN2Str(basBal))
        assert.equal(_.BN2Str(await token1.balanceOf(acc)), _.BN2Str(input.plus(tokenOut)))
        assert.equal(_.BN2Str(await sparta.balanceOf(poolBUSD.address)), _.BN2Str(Y), 'wbnb balance')
        assert.equal(_.BN2Str(await token1.balanceOf(poolBUSD.address)), _.BN2Str(X.minus(tokenOut)), 'sparta balance')
        assert.equal(_.BN2Str(await synthBUSD.collateral()), _.BN2Str(await poolBUSD.balanceOf(synthBUSD.address)))
        
    })
}
async function BNBPoolBalanceCheck() {
    it("", async () => {
        let poolSB = _.BN2Str(await sparta.balanceOf(poolBNB.address))
        let poolTB = _.BN2Str(await wbnb.balanceOf(poolBNB.address))
        let supply = _.BN2Str(await poolBNB.totalSupply())
        console.log("Address?", poolBNB.address)
        console.log("GlobalFreeze?", await reserve.globalFreeze())
        console.log("Frozen?", await poolBNB.freeze())
        console.log("BNB POOL Sparta Bal:", poolSB/10**18);
        console.log("BNB POOL Token Bal:", poolTB/10**18);
        console.log("BNB POOL TotalSupply:", supply/10**18);
    })
}
async function TokenPoolBalanceCheck() {
    it("", async () => {
        let poolSB = _.BN2Str(await sparta.balanceOf(poolBUSD.address))
        let poolTB = _.BN2Str(await token1.balanceOf(poolBUSD.address))
        let supply = _.BN2Str(await poolBUSD.totalSupply())
        console.log("Address? ", poolBNB.address)
        console.log("GlobalFreeze? ", await reserve.globalFreeze())
        console.log("Frozen? ", await poolBNB.freeze())
        console.log("BUSD POOL Sparta Bal: ", poolSB/10**18);
        console.log("BUSD POOL Token Bal: ", poolTB/10**18);
        console.log("BUSD POOL TotalSupply ", supply/10**18);
    })
}

async function safetyCheck() {
    it('test Ratio', async () =>{
        let token = _.BNB
        let poolData = await utils.getPoolData(token);
        let oldRate = _.getBN(await poolBNB.oldRate());
        var B = _.getBN(poolData.baseAmount)
        var T = _.getBN(poolData.tokenAmount)
        let currentRate = _.oneBN.times(B).div(T); // Get current rate
        let rateDiff;
        let freeze = false;
        let rateDiffBP;
        if (currentRate.isGreaterThan(oldRate)) {
            rateDiff = currentRate.minus(oldRate); // Get absolute rate diff
            rateDiffBP = rateDiff.times(10000).div(currentRate); // Get basispoints difference
        } else {
            rateDiff = oldRate.minus(currentRate); // Get absolute rate diff
            rateDiffBP = rateDiff.times(10000).div(oldRate); // Get basispoints difference
        }
        if (rateDiffBP.isGreaterThan(3000)) {
            freeze = true; // If exceeding; flip freeze to true
        } 

        console.log("CurrentRate",_.BN2Str(currentRate));
        console.log("OldRate",_.BN2Str(oldRate));
        console.log("RateDiff",_.BN2Str(rateDiff));
        console.log("RateDiffBP",_.BN2Str(rateDiffBP) )
        console.log("Freeze",freeze);
    })
}






