import 'babel-polyfill';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

var cors = require('cors');

let eIndex = null;

const flights = [
  { "id": 0, "title": "INDGO001" },
	{ "id": 1, "title": "GOFIR002" },
	{ "id": 2, "title": "ARIND003" },
	{ "id": 3, "title": "JTAIR004" },
]

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

let oracle_address = [];

function setUpOracles() {
  web3.eth.getAccounts()
    .then(UserAccounts => {
      flightSuretyApp.methods.REGISTRATION_FEE().call()
              .then(registrationFee => {
                for(let index = 0; index < UserAccounts.length; index++) {
                  flightSuretyApp.methods.registerOracle().send({
                    "from": UserAccounts[index],
                    "value": registrationFee,
                    "gas": 5000000
                  }).then(() => {
                    flightSuretyApp.methods.getMyIndexes().call({from: UserAccounts[index]})
                            .then(result => {
                              oracle_address.push({
                                indexes: result,
                                address: UserAccounts[index]
                              });
                              console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]} at ${UserAccounts[index]}`);
                        })
                  })
                }
              })
    })
}

setUpOracles();


flightSuretyApp.events.OracleRequest({
    fromBlock: "latest"
  }, function (error, event) {
    if (error) console.log(error)

    eIndex = event.returnValues.index;
    console.log(event);
});

flightSuretyApp.events.AirlineRegistered({
  fromBlock: "latest"
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});

flightSuretyApp.events.Pay({
  fromBlock: "latest"
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});

const app = express();
app.use(cors());

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})
app.get('/flights/list', (req, res) => {
  res.send({
    flights: flights
  })
})
app.get('/eIndex/list', (req, res) => {
  res.send({
    eIndex: eIndex
  })
})

export default app;


