import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import BigNumber from 'bignumber.js';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.firstAirline = null;
        this.airlines = [];
        this.customers = [];
        this.oracles = [];
        this.fee = 10;
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.firstAirline = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.regAirline(accts[counter]);
                this.airlines.push(accts[counter]);
                counter++;
            }

            this.setAirlineFund(this.firstAirline);

            while(this.customers.length < 5) {
                this.customers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       this.flightSuretyApp.methods
            .isOperational()
            .call({ from: this.firstAirline}, callback);
    }

    regAirline(airlineAddress){
        this.flightSuretyApp.methods
            .registerAirline(airlineAddress)
            .call({from: this.firstAirline}, (error, result) => {
                //console.log(result);
            });
    }

    setAirlineFund(airlineAddress){
        let fee = (new BigNumber(10)).pow(18) * this.fee;
        this.flightSuretyApp.methods
            .fund()
            .call({from: airlineAddress, value: fee}, (error, result) => {
                //console.log(error);
            });
    }

    purchase(flight, price, timestamp, callback){
        let payload = {
            airline: this.firstAirline,
            flight: flight,
            timestamp: timestamp,
			customer: this.customers[1],
			price_wei: (new BigNumber(10)).pow(18) * Number(price),
        }
        this.flightSuretyApp.methods
            .purchaseInsurance(payload.airline, payload.flight, payload.timestamp)
            .call({from: payload.customer, value: payload.price_wei}, (error, result) => {
                callback(error, payload);
            });
    }

    pay(callback){
        let payload = {
			customer: this.customers[1],
        }
        this.flightSuretyApp.methods
            .pay(payload.customer)
            .call({}, (error, result) => {
                callback(error, payload);
            });
    }

    getFlightStatus(flight, callback) {
        let payload = {
            airline: this.firstAirline,
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        this.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: this.firstAirline}, (error, result) => {
                callback(error, payload);
            });
    }

    submitOracleResponse(indexes, airline, flight, timestamp, callback){

        this.flightSuretyApp.methods
            .getStatusCodes()
            .call({ from: this.firstAirline}, (error, result) => {
                let payload = {
                    indexes: indexes,
                    airline: airline,
                    flight: flight,
                    timestamp: timestamp,
                    status: result[Math.floor(Math.random() * result.length)]
                }
                this.flightSuretyApp.methods
                    .submitOracleResponse(payload.indexes, payload.airline, payload.flight, 
                        payload.timestamp, payload.status)
                            .send({ from: self.owner }, (error, result) => {
                                callback(error, payload);
                            });
            });
    }
}