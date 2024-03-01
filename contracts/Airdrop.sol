// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;
import {VRFCoordinatorV2Interface} from "@chainlink/contracts@0.8.0/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts@0.8.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./ERC20Token.sol";

contract Airdrop is VRFConsumerBaseV2 {
    uint256 private constant ROLL_IN_PROGRESS = 42;
    VRFCoordinatorV2Interface COORDINATOR;
    Token token;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Sepolia coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 s_keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 40,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 40000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;
    address s_owner;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // map rollers to requestIds
    // mapping(uint256 => address) public s_rollers;
    // // map vrf results to rollers
    // mapping(address => uint256) public s_results;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    event DiceRolled(uint256 indexed requestId, address indexed roller);
    event DiceLanded(uint256 indexed requestId, uint256 indexed result);

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;

        token = new Token(1000000000000 * 10e18, "PYDE", "PYD");
    }

    struct User {
        address id;
        string name;
    }

    struct Registry {
        address userId;
        uint256 tries;
        uint256 wins;
        bool fulfilled;
    }

    mapping(address => Registry) public registries;
    mapping(address => User) users;

    function signUp(string calldata _name) external {
        require(users[msg.sender].id == address(0), "User already exist");

        User storage _newUser = users[msg.sender];
        _newUser.id = msg.sender;
        _newUser.name = _name;
    }

    // function createUserEntry() private {
    //     Registry storage _newRegistry = registries[msg.sender];

    //     // _newEntry.guess =
    // }

    // uint[]  random = [1,2,3,4,5,6,7];

    function rollDice() public IsValidUser returns (uint256 requestId) {
        Registry storage _newRegistry = registries[msg.sender];
        require(!_newRegistry.fulfilled, "ALREADY RECEIVED ALLOCATIONS");

        if (_newRegistry.tries >= 3) {
            revert();
        }
        // require(s_results[roller] == 0, "Already rolled");
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        // s_rollers[requestId] = roller;
        // s_results[roller] = ROLL_IN_PROGRESS;

        // emit DiceRolled(requestId, roller);

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        // rawFulfillRandomWords(requestId, random);
        //   (bool fulfilled,uint[]memory _randao) =   getRequestStatus(requestId);
        //   if(!fulfilled){
        //     revert();
        //   }

        //     _newRegistry.tries += 1;
        //     _newRegistry.wins += divideToLowestUnit(_randao[0]);
        //     _newRegistry.fulfilled = false;
    }

    function divideToLowestUnit(uint256 _number) public pure returns (uint8) {
        while (_number > type(uint8).max) {
            _number /= 256;
        }
        return uint8(_number);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        // emit RequestFulfilled(_requestId, _randomWords);
    }

    function verify(uint _requestId) external {
        (bool fulfilled, uint[] memory _randao) = getRequestStatus(_requestId);
        if (!fulfilled) {
            revert();
        }
        Registry storage _newRegistry = registries[msg.sender];

        _newRegistry.tries += 1;
        _newRegistry.wins += divideToLowestUnit(_randao[0]);
        _newRegistry.fulfilled = false;
    }

    function getRequestStatus(
        uint256 _requestId
    ) public view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function claimReward() external IsValidUser {
        Registry storage _registry = registries[msg.sender];
        require(!_registry.fulfilled, "ALREADY RECEIVED ALLOCATIONS");
        require(_registry.wins > 0, "NO ALLOCATIONS");
        token.transfer(msg.sender, registries[msg.sender].wins);
        _registry.wins = 0;
        _registry.fulfilled = true;
    }

    modifier IsValidUser() {
        require(users[msg.sender].id != address(0), "UNAUTHORIZED_ACCESS");
        _;
    }
}
