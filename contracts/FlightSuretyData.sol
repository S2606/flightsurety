pragma solidity >=0.4.24 <0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;

    address[] airlineCalls;
                                      
    struct Airline{
        bool isOperational;
        bool isRegistered;
    }

    mapping(address => Airline) airlines;

    struct Insurance{
        address customer;
        uint256 price;
        bool claimed;
    }

    mapping(address => uint256) airlineFunds;
    mapping(address => uint256) customerBalances;

    mapping(bytes32 => Insurance) insurances;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public
    {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is currently not operational");
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
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }

    function getAirlineRegisteryStatus(address airline) external view returns (bool) {
        return airlines[airline].isRegistered;
    }

    function getAirlineOperationStatus(address airline) external view returns (bool) {
        return airlines[airline].isOperational;
    }

    function getAirlineFundingStatus(address airline) external view returns (bool) {
        return airlineFunds[airline] > 0;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function setOperatingStatusForAirline(address airlineAccount,
                                bool _isOperational)
        external
        requireIsOperational
    {
        airlines[airlineAccount].isOperational = _isOperational;
    }

    /********************************************************************************************/
    /*                                     GETTER SETTER FUNCTIONS                             */
    /********************************************************************************************/

    function setEligibleCalls(address airlineAccount) private
    {
        airlineCalls.push(airlineAccount);
    }

    function getAirlineCount() external view returns (uint256){
        return airlineCalls.length;
    }

    function getEligibleAirlines() 
                            public 
                            view
                            returns(address[] memory)
    {
        return airlineCalls;
    }

    function getCustomerInsuranceDetails(address airline, string calldata flight, uint256 timestamp)
        external
        view
        requireIsOperational
        returns (address, uint256)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        return (insurances[key].customer, insurances[key].price);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Check if an airline is registered
     *
     * @return A bool that indicates if the airline is registered
     */

    function isAirline(address airlineAccount) external view returns (bool) {
        require(airlineAccount != address(0), "Must be a valid address.");

        return airlines[airlineAccount].isRegistered;
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airlineAccount,
                                bool _isOperational
                            )
                            external
                            returns (bool)
    {
        airlines[airlineAccount] = Airline({
            isRegistered: true,
            isOperational: _isOperational
        });
        setEligibleCalls(airlineAccount);
        return airlines[airlineAccount].isRegistered;
    }


   /**
    * @dev Purchase insurance for a flight
    *
    */   
    function purchase
                            (
                                address airline,
                                string calldata flight,
                                uint256 timestamp,
                                address customer,
                                uint256 amount                         
                            )
                            external
                            payable
                            requireIsOperational
    {

        bytes32 key = getFlightKey(airline, flight, timestamp);

        require(airlines[airline].isOperational, "Airline is not operational");

        require(
            (amount > 0 ether) && (amount <= 1 ether),
            "Insurance price limit is between 0-1(inclusive) ether "
        );

        require(
            insurances[key].price == 0,
             "Insurance can only pe purchased once"
        );

        insurances[key] = Insurance({customer: customer, price: amount, claimed: false});
        uint256 currentFund = airlineFunds[airline];
        airlineFunds[airline] = currentFund.add(amount);

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                  address airline, 
                                  string calldata flight,
                                  uint256 timestamp,
                                  address customer,
                                  uint256 amount  
                                )
                                external
                                requireIsOperational
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        uint256 requiredPayout = insurances[key].price.mul(3).div(2);

        require(
            (customer != address(0)) && (airline != address(0)),
            "They are not valid address"
        );

        require(
            insurances[key].customer == customer,
            "Not the customer to whom insurance was provided"
        );

        require(
            amount == requiredPayout,
            "Not the amount to be credit based on calculation"
        );

        require(
            insurances[key].claimed == false,
            "Cannot claim an already claimed insurance"
        );

        uint256 currentBalance = customerBalances[customer];
        currentBalance += requiredPayout;
        customerBalances[customer] = currentBalance;
        insurances[key].claimed = true;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address payable customer) external requireIsOperational returns (uint256) {
        require(
            customerBalances[customer] > 0,
            "No outstanding balance left"
        );

        uint256 withdraw_value = customerBalances[customer];

        delete customerBalances[customer];

        return withdraw_value;
    }

    /**
     *  @dev Get Customer Payable Amount
     *
    */
    function getCustomerPayoutAmount(address customer)
        external
        view
        requireIsOperational
        returns (uint256)
    {
        return  customerBalances[customer];
    }


   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function setFundForAirline
                            (
                                address airline, 
                                uint256 amount   
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(airlines[airline].isRegistered, "Airline is not registered");
        uint256 currentFund = airlineFunds[airline];
        airlineFunds[airline] = currentFund.add(amount);
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


}

