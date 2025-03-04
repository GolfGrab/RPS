// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";
contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public reward = 0;

    // 0 - Scissors, 1 - Paper, 2 - Rock, 3 - Lizard, 4 - Spock
    enum Choice {
        Scissors,
        Paper,
        Rock,
        Lizard,
        Spock
    }

    mapping(address => bytes32) public player_hashedChoice;
    mapping(address => Choice) public player_choice;
    mapping(address => bool) public player_not_played;
    mapping(address => bool) public player_not_revealed;
    address[] public players;
    address[] public allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    uint public numInput = 0;
    uint public numReveal = 0;
    uint public constant TIME_LIMIT = 10 minutes;

    function addPlayer() public payable {
        require(numPlayer < 2);

        bool isPlayerAllowed = false;
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (msg.sender == allowedPlayers[i]) {
                isPlayerAllowed = true;
                break;
            }
        }
        require(isPlayerAllowed);

        if (numPlayer == 0) {
            _setStartTime();
        }

        if (numPlayer > 0) {
            // not allow player to play with themselves
            require(msg.sender != players[0]);

            // not allow player to play after time limit
            require(elapsedSeconds() < TIME_LIMIT);
        }
        require(msg.value == 1 ether);
        reward += msg.value;
        player_not_played[msg.sender] = true;
        player_not_revealed[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function getHashedChoice(
        Choice choice,
        string memory secret
    ) public pure returns (bytes32) {
        return getHash(bytes32(abi.encodePacked(choice, secret)));
    }

    function inputHashedChoice(bytes32 hashedChoice) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        require(elapsedSeconds() < TIME_LIMIT);

        _commit(hashedChoice);
        player_not_played[msg.sender] = false;
        player_hashedChoice[msg.sender] = hashedChoice;
        numInput++;
    }

    function revealChoice(Choice choice, string memory secret) public {
        require(numPlayer == 2);
        require(!player_not_played[msg.sender]);
        require(player_not_revealed[msg.sender]);
        require(elapsedSeconds() < TIME_LIMIT);
        require(
            choice == Choice.Scissors ||
                choice == Choice.Paper ||
                choice == Choice.Rock ||
                choice == Choice.Lizard ||
                choice == Choice.Spock
        );

        _reveal(bytes32(abi.encodePacked(choice, secret)));
        player_not_revealed[msg.sender] = false;
        player_choice[msg.sender] = choice;
        numReveal++;
        if (numReveal == 2) {
            _checkWinnerAndPay();
            _resetGame();
        }
    }

    function _checkWinnerAndPay() private {
        Choice p0Choice = player_choice[players[0]];
        Choice p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        if (
            (uint(p0Choice) + 1) % 5 == uint(p1Choice) ||
            (uint(p0Choice) + 3) % 5 == uint(p1Choice)
        ) {
            // pay player[1]
            account1.transfer(reward);
        } else if (
            (uint(p1Choice) + 1) % 5 == uint(p0Choice) ||
            (uint(p1Choice) + 3) % 5 == uint(p0Choice)
        ) {
            // pay player[0]
            account0.transfer(reward);
        } else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }

    function withdraw() public {
        require(elapsedSeconds() >= TIME_LIMIT);
        require(numPlayer > 0);

        if (numPlayer == 1) {
            // withdraw reward if another player not join
            address payable account0 = payable(players[0]);
            account0.transfer(reward);
        } else if (numPlayer == 2) {
            address payable account0 = payable(players[0]);
            address payable account1 = payable(players[1]);

            // penalty for player who not play
            if (
                player_not_played[players[0]] && player_not_played[players[1]]
            ) {
                // split reward if both player not play
                account0.transfer(reward / 2);
                account1.transfer(reward / 2);
            } else if (player_not_played[players[0]]) {
                account1.transfer(reward);
            } else if (player_not_played[players[1]]) {
                account0.transfer(reward);
            }
            // penalty for player who not reveal
            else if (
                player_not_revealed[players[0]] &&
                player_not_revealed[players[1]]
            ) {
                // split reward if both player not reveal
                account0.transfer(reward / 2);
                account1.transfer(reward / 2);
            } else if (player_not_revealed[players[0]]) {
                account1.transfer(reward);
            } else if (player_not_revealed[players[1]]) {
                account0.transfer(reward);
            }
        }

        _resetGame();
    }

    function _resetGame() private {
        for (uint i = 0; i < players.length; i++) {
            player_not_played[players[i]] = true;
            player_choice[players[i]] = Choice.Scissors;
            player_hashedChoice[players[i]] = getHashedChoice(
                Choice.Scissors,
                ""
            );
        }
        numInput = 0;
        numReveal = 0;
        numPlayer = 0;
        reward = 0;
        players = new address[](0);
    }
}
