// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint256 choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
        address addr;
    }
    mapping(uint256 => Player) public player; // only player id = 0 and player id = 1 only
    uint256 public numPlayer = 0;
    uint256 public numInput = 0;
    uint256 public numShow = 0;
    uint256 public reward = 0;

    uint256 public constant TIME_IDLE_DURATION = 1 minutes;
    uint256 public lastActionTime = block.timestamp;

    function getHashedChoiceWithSalt(uint256 choice, string memory salt)
        external
        pure
        returns (bytes32)
    {
        bytes32 encodedSalt = bytes32(abi.encodePacked(salt));
        return keccak256(abi.encodePacked(choice, encodedSalt));
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "maximum player limit exceed");
        require(msg.value == 1 ether, "incorrect value");
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
        emit PlayerAdded(numPlayer, msg.sender);
        numPlayer++;
        lastActionTime = block.timestamp;
    }

    event PlayerAdded(uint256 id, address addr);

    function inputHashedChoice(bytes32 hashedChoiceWithSalt, uint256 idx)
        public
    {
        require(numPlayer == 2, "not enough player");
        require(msg.sender == player[idx].addr, "invelid address");
        commit(getHash(hashedChoiceWithSalt));
        numInput++;
        lastActionTime = block.timestamp;
    }

    function showChoice(
        uint256 choice,
        string memory salt,
        uint256 idx
    ) public {
        require(numPlayer == 2);
        require(numInput == 2);
        require(msg.sender == player[idx].addr);
        require(choice == 0 || choice == 1 || choice == 2);
        bytes32 encodedSalt = bytes32(abi.encodePacked(salt));
        reveal(keccak256(abi.encodePacked(choice, encodedSalt)));
        player[idx].choice = choice;
        numShow++;
        emit ChoiceRevealed(idx, choice);
        lastActionTime = block.timestamp;
        if (numShow == 2) {
            _checkWinnerAndPay();
        }
    }

    event ChoiceRevealed(uint256 id, uint256 choice);

    function _checkWinnerAndPay() private {
        uint256 p0Choice = player[0].choice;
        uint256 p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);
        } else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        _resetGame();
    }

    function _resetGame() private {
        numPlayer = 0;
        numInput = 0;
        numShow = 0;
        reward = 0;
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

        // return money if both players not input their choice or not revealed their choice in time
        if (numPlayer == 2 && numShow == 0) {
            address payable account0 = payable(player[0].addr);
            address payable account1 = payable(player[1].addr);
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
            _resetGame();
        }

        // punish player who not revealed their choice in time
        if (numPlayer == 2 && numShow == 1) {
            if (player[0].choice == 3) {
                // player 0 has not revealed their choice
                address payable account = payable(player[1].addr);
                account.transfer(reward);
            } else if (player[1].choice == 3) {
                // player 1 has not revealed their choice
                address payable account = payable(player[0].addr);
                account.transfer(reward);
            }
            _resetGame();
        }
    }
}
