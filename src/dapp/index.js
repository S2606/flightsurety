
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

let baseUrl = "http://localhost:3000";

(async() => {

	let airlines = null;
	let flightDetails = null;
    let traveltime = null;
    let statusCodeMapping = {
		0: "UNKNOWN",
		10: "ON_TIME",
		20: "LATE_AIRLINE",
		30: "LATE_WEATHER",
		40: "LATE_TECHNICAL",
		50: "LATE_OTHER"
	}


    let contract = new Contract('localhost', () => {

        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { error: error, value: result} ]);
        });

        let flightDropdown = document.getElementById("flightList");
        flightDropdown.length = 0;

        let listUrl = baseUrl+"/flights/list";

        fetch(listUrl)
                    .then(
                        (resp) => {
                            resp.json().then(
                                (payload) => {
                                    let flightOption;
                                    payload = payload.flights;
                                    for(let i=0; i<payload.length; i++){
                                        flightOption = document.createElement('option');
                                        flightOption.text = payload[i].title;
                                        flightOption.value = payload[i].title;
                                        flightDropdown.add(flightOption);
                                    }
                                }
                            )
                        }
                    )
                    .catch((err) => {
                        console.log(err);
                    });
    

        DOM.elid('submitOracle').addEventListener('click', () => {
            let inputFlight = DOM.elid('flightList').value;
            contract.getFlightStatus(inputFlight, (error, result) => {
                airlines = result.airline;
				traveltime = result.timestamp;
                flightDetails = result.flight;

                display('Insurance Portal', 'Current Flight Details', [ { 
                    error: error, 
                    value: `Flight Name: ${flightDetails} - Departure Timestamp: ${traveltime}`,
                    flightName: flightDetails,
                    depttime: traveltime
                    }], "", "showFlight");
            });
        })

        DOM.elid('purchase').addEventListener('click', () => {
            let departure = DOM.elid('departure').innerHTML;
            let price = DOM.elid('insurePremium').value;
            let flgname = DOM.elid('flgname').innerHTML;

            DOM.elid("flightForm").style.display = "none";

            contract.purchase(flgname, price, departure, (error, result) => {
                display('Insurance Portal', 'Final Details', [{ 
                    error: error, 
                    value: `Flight Name: ${flgname} - Departure Timestamp: ${departure} - Premium: ${price} ether - Payout on Delay: ${price * 1.5} ether`
                    }], 
                    "showDetail", "showFlight");
            })
        })

        DOM.elid('getFunds').addEventListener('click', () => {
            contract.pay((error, result) => {

                DOM.elid('getFunds').style.display = "none";
                DOM.elid("flightReport").style.display = "none";

				DOM.elid("remittedAmount").innerHTML = DOM.elid("delayPremium").innerHTML;
				DOM.elid("payout").style.display = "block";
			});
        })

        DOM.elid('insurePremium').addEventListener('change', () => {
            let price = DOM.elid('insurePremium').value;
            let payoutPremium = DOM.elid('payoutPremium');
            let delayPremium = DOM.elid('delayPremium');

            payoutPremium.innerHTML = price;
			delayPremium.innerHTML = (price * 1.5);
        })

        DOM.elid('oracleResult').addEventListener('click', () => {
            getOracleIdx();

            setTimeout(() => {
                let airline = airlines;
                let flight = flightDetails;
                let departure = traveltime;
                let showIndex = document.getElementById('showIndex').innerHTML;
                
                contract.submitOracleResponse(parseInt(showIndex), airline, flight, departure, (error, result) => {
                    
                    DOM.elid("oracleResult").style.display = "none";

                    let status = statusCodeMapping[result.status];

                    DOM.elid('status').innerHTML = status;
                    DOM.elid('name').innerHTML = result.flight;
                    DOM.elid('timestamp').innerHTML = result.timestamp;

                    if (status == statusCodeMapping[20] || status == statusCodeMapping[40] 
                        || status == statusCodeMapping[50]) {
                        DOM.elid("flightReport").style.display = "block";
                        DOM.elid("getFunds").style.display = "block";
                        DOM.elid('amount').innerHTML = `${DOM.elid('delayPremium').innerHTML}`;
					} else {
                        DOM.elid("flightOnTime").style.display = "block";
                    }


                })
            }, 600)

        })
    
    });
    

})();


function display(title, description, results, className, id) {
    let displayDiv = DOM.elid("displayDetails");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    if (description != ''){
        section.appendChild(DOM.h5(description));
    }
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        let col_details = 'col-sm-8';
        if (className == "showDetail") {
            DOM.elid("oracleResult").style.display = "block";
		}

        if (col_details != ''){
            if(result.error){
                row.appendChild(DOM.div({ className: `${col_details}` }, String(result.error)));
            } else if(result.value!=null && typeof(result.value)=='string') {
                let result_str = result.value.split('-');
                result_str.forEach(element => {
                    row.appendChild(DOM.div({ className: `${col_details}` }, String(element)));
                    row.appendChild(DOM.br());
                });
            } else {
                row.appendChild(DOM.div({ className: `${col_details}` }, String(result.value)));
            }
        }

        if (id == "showFlight" && className == "") {
            let button = DOM.button({ className: 'col-sm-3 field btn btn-primary purchInsurance'}, "Buy Insurance");
            button.addEventListener('click', () => {
                DOM.elid("flightForm").style.display = "block";
            })
            button.style.textAlign = "center";
            row.appendChild(button);

            let name = DOM.elid("flgname");
            let departure = DOM.elid("departure");
            name.innerHTML = result.flightName;
			departure.innerHTML = result.depttime;
        }
        section.appendChild(row);
    })
    displayDiv.removeChild(displayDiv.firstChild);
    displayDiv.append(section);

}

function getOracleIdx(){
    let listUrl = baseUrl+"/eIndex/list";

    fetch(listUrl)
                    .then(
                        (resp) => {
                            resp.json().then(
                                (payload) => {
                                    let ele = document.getElementById('showIndex');
                                    payload = payload.eIndex;
                                    ele.innerHTML = parseInt(payload);
                                }
                            )
                        }
                    )
                    .catch((err) => {
                        console.log(err);
                    });
}







