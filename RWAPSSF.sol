// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "CommitReveal.sol";

contract RPS is CommitReveal {
    /* 
    Rules:

    # choices
    0 - Rock
    1 - Water
    2 - Air
    3 - Paper
    4 - Sponge
    5 - Scissors
    6 - Fire

    # winning condition
    ROCK POUNDS OUT FIRE, CRUSHES SCISSORS & SPONGE. 0 > 6, 0 > 5, 0 > 4
    FIRE MELTS SCISSORS, BURNS PAPER & SPONGE. 6 > 5, 6 > 3, 6 > 4
    SCISSORS SWISH THROUGH AIR, CUT PAPER & SPONGE. 5 > 2, 5 > 3, 5 > 4
    SPONGE SOAKS PAPER, USES AIR POCKETS, ABSORBS WATER. 4 > 3, 4 > 2, 4 > 1
    PAPER FANS AIR, COVERS ROCK, FLOATS ON WATER. 3 > 2, 3 > 0, 3 > 1
    AIR BLOWS OUT FIRE, ERODES ROCK, EVAPORATES WATER. 2 > 6, 2 > 0, 2 > 1
    WATER ERODES ROCK, PUTS OUT FIRE, RUSTS SCISSORS. 1 > 0, 1 > 6, 1 > 5

    # winning logic
    if ( left choice - right choice ) % 7 <= 3 and not equal to 0, left win
    if ( left choice - right choice ) % 7 > 3 and not equal to 0, right win
    if ( left choice - right choice ) % 7 == 0, draw
    */

    struct Player {
        uint64 choice1; // 0-Rock 1-Water 2-Air 3-Paper 4-Sponge 5-Scissors 6-Fire 7-Unrevealed
        uint64 choice2; // 0-Rock 1-Water 2-Air 3-Paper 4-Sponge 5-Scissors 6-Fire 7-Unrevealed
        bool isCommitted;
        address addr;
    }

    mapping(uint256 => Player) public player; // only player id = 0 and player id = 1 only
    uint256 public numPlayer = 0;
    uint256 public numInput = 0;
    uint256 public numShow = 0;
    uint256 public reward = 0;

    uint256 public constant TIME_IDLE_DURATION = 1 minutes;
    uint256 public lastActionTime = block.timestamp;

    function getHashedChoiceWithSalt(
        uint64 choice1,
        uint64 choice2,
        string memory salt
    ) external pure returns (bytes32) {
        bytes32 encodedSalt = bytes32(abi.encodePacked(salt));
        return keccak256(abi.encodePacked(choice1, choice2, encodedSalt));
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "maximum player limit exceed");
        require(msg.value == 1 ether, "incorrect value");
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice1 = 7; // 7 means unrevealed choice
        player[numPlayer].choice2 = 7; // 7 means unrevealed choice
        emit PlayerAdded(numPlayer, msg.sender);
        numPlayer++;
        lastActionTime = block.timestamp;
    }

    event PlayerAdded(uint256 id, address addr);

    function inputHashedChoice(
        bytes32 hashedChoiceWithSalt,
        uint256 idx
    ) public {
        require(numPlayer == 2, "not enough player");
        require(msg.sender == player[idx].addr, "invelid address");
        require(player[idx].isCommitted == false, "already committed");
        commit(getHash(hashedChoiceWithSalt));
        numInput++;
        lastActionTime = block.timestamp;
    }

    function showChoice(
        uint64 choice1,
        uint64 choice2,
        string memory salt,
        uint256 idx
    ) public {
        require(numPlayer == 2, "not enough player");
        require(numInput == 2, "not enough input");
        require(msg.sender == player[idx].addr, "invelid address");
        require(choice1 >= 0 && choice1 <= 6, "invalid choice1");
        require(choice2 >= 0 && choice2 <= 6, "invalid choice2");
        bytes32 encodedSalt = bytes32(abi.encodePacked(salt));
        reveal(keccak256(abi.encodePacked(choice1, choice2, encodedSalt)));
        player[idx].choice1 = choice1;
        player[idx].choice2 = choice2;
        numShow++;
        emit ChoiceRevealed(idx, choice1, choice2);
        lastActionTime = block.timestamp;
        if (numShow == 2) {
            _checkWinnerAndPay();
        }
    }

    event ChoiceRevealed(uint256 id, uint64 choice1, uint64 choice2);

    function _checkWinnerAndPay() private {
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        uint256 winner; // 0 - player 0 , 1 - player 1 , 2 - draw

        uint64 p0Score = 0;
        uint64 p0Choice1 = player[0].choice1;
        uint64 p0Choice2 = player[0].choice2;

        uint64 p1Score = 0;
        uint64 p1Choice1 = player[1].choice1;
        uint64 p1Choice2 = player[1].choice2;

        // round 1
        uint64 diff1 = (p0Choice1 + 7 - p1Choice1) % 7;
        if (diff1 == 0) {
            // draw
            p0Score += 1;
            p1Score += 1;
        } else if (diff1 <= 3 && diff1 != 0) {
            // player 0 win
            p0Score += 2;
        } else if (diff1 > 3 && diff1 != 0) {
            // player 1 win
            p1Score += 2;
        }

        // round 2
        uint64 diff2 = (p0Choice2 + 7 - p1Choice2) % 7;
        if (diff2 == 0) {
            // draw
            p0Score += 1;
            p1Score += 1;
        } else if (diff2 <= 3 && diff2 != 0) {
            // player 0 win
            p0Score += 2;
        } else if (diff2 > 3 && diff2 != 0) {
            // player 1 win
            p1Score += 2;
        }

        if (p0Score > p1Score) {
            winner = 0;
            account0.transfer(reward);
        } else if (p0Score < p1Score) {
            winner = 1;
            account1.transfer(reward);
        } else {
            winner = 2;
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        emit Winner(winner, p0Choice1, p1Choice1, p0Choice2, p1Choice2);
        _resetGame();
    }

    event Winner(
        uint256 winner,
        uint64 p0Choice,
        uint64 p1Choice,
        uint64 p0Choice2,
        uint64 p1Choice2
    );

    function _resetGame() private {
        numPlayer = 0;
        numInput = 0;
        numShow = 0;
        reward = 0;
        delete player[0];
        delete player[1];
    }

    function returnMoney() public {
        require(
            block.timestamp - lastActionTime > TIME_IDLE_DURATION,
            "not enough time"
        );
        require(numPlayer > 0, "no player");

        // return money if only one player has joined
        if (numPlayer == 1) {
            address payable account = payable(player[0].addr);
            account.transfer(reward);
            _resetGame();
        }
        // return money if both players not input their choice in time
        else if (numPlayer == 2 && numInput == 0) {
            address payable account0 = payable(player[0].addr);
            address payable account1 = payable(player[1].addr);
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
            _resetGame();
        }
        // return money if both players not revealed their choice in time
        else if (numPlayer == 2 && numInput == 2 && numShow == 0) {
            address payable account0 = payable(player[0].addr);
            address payable account1 = payable(player[1].addr);
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
            _resetGame();
        }
        // punish player who not input their choice in time
        else if (numPlayer == 2 && numInput == 1) {
            if (player[0].isCommitted == false) {
                // player 0 has not input their choice
                address payable account = payable(player[1].addr);
                account.transfer(reward);
            } else if (player[1].isCommitted == false) {
                // player 1 has not input their choice
                address payable account = payable(player[0].addr);
                account.transfer(reward);
            }
            _resetGame();
        }
        // punish player who not revealed their choice in time
        else if (numPlayer == 2 && numShow == 1) {
            if (player[0].choice1 == 7 || player[0].choice2 == 7) {
                // player 0 has not revealed their choice
                address payable account = payable(player[1].addr);
                account.transfer(reward);
            } else if (player[1].choice1 == 7 || player[1].choice2 == 7) {
                // player 1 has not revealed their choice
                address payable account = payable(player[0].addr);
                account.transfer(reward);
            }
            _resetGame();
        }
    }
}
