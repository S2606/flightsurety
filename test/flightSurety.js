
var Test = require('../config/testConfig.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    let newAirline = accounts[2];

    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) calls register when multi-party is reached', async() => {
    let airline2 = accounts[2];
    await config.flightSuretyApp.registerAirline(airline2, {from: config.owner});
    let result2 = await config.flightSuretyData.isAirline.call(airline2);
    assert.equal(result2, true, "Airline 2 was not registered, weird!");

    let airline3 = accounts[3];
    await config.flightSuretyApp.registerAirline(airline3, {from: config.owner});
    let result3 = await config.flightSuretyData.isAirline.call(airline3);
    assert.equal(result3, true, "Airline 3 was not registered, weird!");

    let airline4 = accounts[4];
    await config.flightSuretyApp.registerAirline(airline4, {from: config.owner});
    let result4 = await config.flightSuretyData.isAirline.call(airline4);
    assert.equal(result4, true, "Airline 4 was not registered, weird!");

    let airline5 = accounts[5];
    await config.flightSuretyApp.registerAirline(airline5, {from: config.owner});
    let result5 = await config.flightSuretyData.isAirline.call(airline5);
    assert.equal(result5, false, "Multi-party call passed, weird!");

  });
 
  it('(airline) check if it`s operational on a condition that 10 ether funding is submitted', async() => {
    let price = web3.utils.toWei("10", "ether");

    let airline2 = accounts[2];
    await config.flightSuretyApp.fund({ from: airline2, value: price });
    let result2 = await config.flightSuretyData.getAirlineOperationStatus.call(airline2);
	assert.equal(result2, true, "Airline 2 is not operational, weird!");

    let airline3 = accounts[3];
    await config.flightSuretyApp.fund({ from: airline3, value: price });
    let result3 = await config.flightSuretyData.getAirlineOperationStatus.call(airline3);
    assert.equal(result3, true, "Airline 3 is not operational, weird!");
    
    let airline4 = accounts[4];
    await config.flightSuretyApp.fund({ from: airline4, value: price });
    let result4 = await config.flightSuretyData.getAirlineOperationStatus.call(airline4);
    assert.equal(result4, true, "Airline 4 is not operational, weird!");

  });

  it('(multi-party) check on reaching multi-party limit, voting is made or not', async() => {

    let airline6 = accounts[6];
    await config.flightSuretyApp.registerAirline(airline6, {from:accounts[3]});
    let oneVoteStatus = await config.flightSuretyData.getAirlineRegisteryStatus.call(airline6);
    await config.flightSuretyApp.registerAirline(airline6, {from:accounts[4]});
    let twoVoteStatus = await config.flightSuretyData.getAirlineRegisteryStatus.call(airline6);

    assert.equal(oneVoteStatus, false, "Airline cannot be registered with just one vote");
    assert.equal(twoVoteStatus, true, "Airline should ideally be registered with two votes");

  });
  
});
