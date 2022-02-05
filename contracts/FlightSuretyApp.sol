pragma solidity >=0.4.24 <0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "./FlightSuretyData.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    bool private sc_operational = true;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    mapping(address => address[]) public registrationAirline;

    FlightSuretyData dataPart;

    event AirlineRegistered(address account);
    event Pay(address account, uint256 balance);

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address flightSuretyDataAddress) public
    {
        contractOwner = msg.sender;
        dataPart = FlightSuretyData(flightSuretyDataAddress);
        dataPart.registerAirline(contractOwner, true);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view
                            returns(bool) 
    {
        return sc_operational;  // Modify to call data contract's status
    }

    function getStatusCodes()
                            public 
                            pure
                            returns(uint8[6] memory)
    {
        return [STATUS_CODE_UNKNOWN, STATUS_CODE_ON_TIME, STATUS_CODE_LATE_AIRLINE, 
        STATUS_CODE_LATE_WEATHER, STATUS_CODE_LATE_TECHNICAL, STATUS_CODE_LATE_OTHER];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            ( 
                                address airline  
                            )
                            external
                            requireIsOperational
                            returns(bool success, uint256 votes)
    {
        require(
           !dataPart.getAirlineRegisteryStatus(airline),
           "Airline is already registered"
        );
        require(
            dataPart.getAirlineOperationStatus(msg.sender),
           "Request Airline isn't operational in reality"
        );
        

        if(dataPart.getAirlineCount() <= 3){
            success = dataPart.registerAirline(airline, false);

            emit AirlineRegistered(airline);
            return (success, 0);
        } else {
            uint256 currVotes = registrationAirline[airline].length;
            if(currVotes==0){
                registrationAirline[airline] = new address[](0);
                registrationAirline[airline].push(msg.sender);
                success = false;
                votes = 1;
            } else {
                uint256 counter = 0;
                for(;counter<currVotes;counter++){
                    if(registrationAirline[airline][counter]==msg.sender){
                        break;
                    }
                }
                if(counter==currVotes){
                    registrationAirline[airline].push(msg.sender);
                }
                votes = registrationAirline[airline].length;
                if(votes.mul(2) >= dataPart.getAirlineCount()){
                    success = dataPart.registerAirline(airline, false);
                    emit AirlineRegistered(airline);
                } else {
                    success = false;
                }
            }
        }

        return (success, votes);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                )
                                external
                                pure
    {

    }

    /**
    * @dev Purchase insurance for a flight
    *
    */  
    function purchaseInsurance(address airline, string calldata flight, uint256 timestamp) external payable requireIsOperational {
        dataPart.purchase(airline, flight, timestamp, msg.sender, msg.value);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        
        oracleResponses[key] = ResponseInfo({requester: msg.sender, isOpen: true});

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    function pay(address payable customer) external requireIsOperational{
        uint256 balance = dataPart.pay(customer);

        customer.transfer(balance);

        emit Pay(customer, balance);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

     /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string calldata flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                external
    {
        address customer;
        uint256 price;
        (customer, price) = dataPart.getCustomerInsuranceDetails(airline, flight, timestamp);

        uint256 requiredPayout = price.mul(3).div(2);

        require(requiredPayout > 0, "Please provide required payout amount");
        if((statusCode==STATUS_CODE_LATE_AIRLINE)||(statusCode==STATUS_CODE_LATE_TECHNICAL)){
            dataPart.creditInsurees(airline,flight,timestamp,customer,requiredPayout);
        }
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            this.processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    /**
    * @dev Function for funding smart contract.
    *
    */
    function fund() 
                            public 
                            payable
                            requireIsOperational 
    {
        require(msg.value == 10 ether, "Should only be 10 ether");

        dataPart.setFundForAirline(msg.sender, msg.value);
        dataPart.setOperatingStatusForAirline(msg.sender, true);
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function () external payable {
        fund();
    }

// endregion

}   
