pragma solidity ^0.5.10;

contract EsportsBettingNetwork {
    
    // A struct representing a match, currently only implemented for equal wager two person bets.
    struct Match {
        //Required fields
        string matchID;             // In format A_vs_B_MatchDate eg. Soma_vs_ZerO_15-11-2020.
        string playerA;             // PlayerA
        string playerB;             // PlayerB
        uint256 startDate;          // Start date in unix timestamp
        //address organiser;          // Address of organiser
        //address charity;            // Address of charity

        // Nullable fields
        string winner;              // Winner of the match, 
        uint betAmount;             // Amount the maker has placed the bet for.
        address accountBetA;        // Account which is betting on A to win.
        address accountBetB;        // Account which is betting on B to win.
    }

    // Temporary coordinator to ensure funds are not stuck in the contract,
    // Should be removed eventually and run in a decentralised manner.
    address public coordinator;

    // Mapping from matchID to Match structs, contains a list of all matches.
    mapping(string => Match) public matches;


    // Initializes the contract, setting the `coordinator` to the address of the contract creator.
    constructor() public {
        coordinator = msg.sender;
    }

    // Places a bet on an existing match, using the value sent in the message as the bet amount eg.
    // Soma_vs_ZerO_15-11-2020, Soma
    // Soma_vs_ZerO_15-11-2020, ZerO
    // Checks if the match exists, then checks if bet amount is valid, calls taker/maker or reverts if unable to process.
    function bet(string memory matchID, string memory player) public payable {
        // TODO require(matchExists); if matchID == 0 returns false when match not found this is unnecessary, RESEARCH!

        if (matches[matchID].betAmount == 0) {
            maker(matchID, player);
        } else if (matches[matchID].betAmount == msg.value) {
            taker(matchID, player);
        } else {
            revert("amount differs");   // Can other things cause this? More general error message?
        }
    }

    

    // Places a bet on a found match, acting as the bet maker.
    // Checks which player the user bet on by comparing hashes using the keccak256(SHA-3) hashing function.
    // Sets betAmount using the message value. Reverts if hashes of players do not match. 
    //
    // TODO rewrite using require instead of if statements?
    function maker(string memory matchID, string memory player) private {
        // Currently comparing hashes of strings instead of a util function, INEFFICIENT?
        if (keccak256(abi.encodePacked(player)) == keccak256(abi.encodePacked(matches[matchID].playerA))) {
            matches[matchID].accountBetA = msg.sender;
        } else if (keccak256(abi.encodePacked(player)) == keccak256(abi.encodePacked(matches[matchID].playerB))) {
            matches[matchID].accountBetB = msg.sender;
        } else {
            revert("maker error");
        }
        matches[matchID].betAmount = msg.value;
    }

    // Places a bet on a found match, acting as the bet taker.
    // Checks which player the user bet on by comparing hashes using the keccak256(SHA-3) hashing function.
    // Ensures that the player has not already bet on, Checks that the message value matches the betAmount, revert if any problems.
    //
    // TODO rewrite using require instead of if statements?
    function taker(string memory matchID, string memory player) private {
        // Currently comparing hashes of strings instead of a util function, INEFFICIENT?
        if (keccak256(abi.encodePacked(player)) == keccak256(abi.encodePacked(matches[matchID].playerA)) 
                && keccak256(abi.encodePacked(matches[matchID].accountBetA)) == keccak256(abi.encodePacked(address(0x0)))) {
            matches[matchID].accountBetA = msg.sender;
        } else if (keccak256(abi.encodePacked(player)) == keccak256(abi.encodePacked(matches[matchID].playerB))
                    && keccak256(abi.encodePacked(matches[matchID].accountBetB)) == keccak256(abi.encodePacked(address(0x0)))) {
            matches[matchID].accountBetB = msg.sender;
        } else {
            revert("taker error");
        }
        matches[matchID].betAmount = msg.value;
    }

    // Creates a new match and adds it to matches eg.
    // Soma_vs_ZerO_15-11-2020, Soma, ZerO, 15112020
    function createMatch(string memory matchID, string memory playerA, string memory playerB, uint256 startDate) public {
        require(msg.sender == coordinator, "You are not the coordinator.");
        // TODO require(!matchExists); will overwrite existing matches, feature?, DANGEROUS!

        matches[matchID] = Match(matchID, playerA, playerB, startDate, string(""), uint(0), address(0), address(0));
    }

    // Assigns a winner for a match and automatically pays out bets.
    // Soma_vs_ZerO_15-11-2020, ZerO
    function assignWinner(string memory matchID, string memory winningPlayer) public {
        require(msg.sender == coordinator, "You are not the coordinator.");
        //TODO require winner not set already

        if (keccak256(abi.encodePacked(winningPlayer)) == keccak256(abi.encodePacked(matches[matchID].playerA))) {
            payoutWinner(matchID, matches[matchID].accountBetA);
        } else if (keccak256(abi.encodePacked(winningPlayer)) == keccak256(abi.encodePacked(matches[matchID].playerB))) {
            payoutWinner(matchID, matches[matchID].accountBetB);
        } else {
            revert("winner must be one of the participants");
        }

        matches[matchID].winner = winningPlayer;            // Set winning player
    }

    // Pays out the winning address the amount bet in full
    // TODO implement cut for event organiser and charity orginisation
    function payoutWinner(string memory matchID, address winnerAddress) private {
        address payable payoutAddress = address(uint160(winnerAddress));    // Conversion to payable address
        uint payoutAmount = matches[matchID].betAmount;                     // Get amount to payout winner
        
        payoutAddress.transfer(payoutAmount);                               // Payout the winner
    }
}
