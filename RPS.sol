// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// ทำการปรับปรุง contract นี้ตามที่ได้ทำในปฏิบัติการที่ 5 แต่มีเงื่อนไขเพิ่มเติมต่อไปนี้
// ยกเลิกข้อจำกัดที่ให้เฉพาะต้องเป็นผู้เล่นจาก 4 account แต่ให้ผู้เล่นมาจาก account ใดๆก็ได้
// แทนที่จะให้ผู้เล่นส่งเงินมาที่ contract นี้ ให้ผู้เล่น approve ให้ contract นี้สามารถถอนเงิน 0.000001 ether จาก wallet หรือ account ของผู้เล่นได้
// Contract จะต้องเช็คว่าผู้เล่นทั้งสองได้ approve การถอนเงิน โดยการเช็คที่ตัวแปร allowance (ดูตัวอย่างจาก TokenSwap contract ที่ได้คุยกันในชั้นเรียน) 
// เมื่อ player ทั้งสองได้ commit แล้ว จะต้องมีการโอนเงินจาก account ของ player ทั้งสองมาไว้ที่ contract ทันที
// ถ้า player คนใดคนหนึ่งไม่ reveal ตามกำหนดเวลา player อีกคนสามารถถอนเงินทั้งหมดออกจาก contract เข้ากระเป๋าตัวเองได้
// ถ้า player ทั้งสองไม่ reveal ตามกำหนดเวลา ให้ account ใดๆก็ได้มีสิทธิมาถอนเงินจาก contract นี้เข้ากระเป่าตัวเองทั้งหมด


import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "./IERC20.sol";
contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public constant FEE = 0.000001 ether; // 1 * 10^12 wei


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

    // ERC20 token contract
    IERC20 public token = IERC20(0xa5A6701E17A6c1204F49500D601dcC26D573Cd5F);

    uint public numInput = 0;
    uint public numReveal = 0;
    uint public constant TIME_LIMIT = 10 minutes;

    function addPlayer() public payable {
        require(numPlayer < 2);

        if (numPlayer == 0) {
            _setStartTime();
        }

        if (numPlayer > 0) {
            // not allow player to play with themselves
            require(msg.sender != players[0]);

            // not allow player to play after time limit
            require(elapsedSeconds() < TIME_LIMIT);
        }
        // Check token allowance
        require(token.allowance(msg.sender, address(this)) >= FEE, "Insufficient token allowance");

        reward += FEE;
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

        if (numInput == 2) {
            // transfer fee from players to contract
            token.transferFrom(players[0], address(this), FEE);
            token.transferFrom(players[1], address(this), FEE);
        }
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
            // pay player[0]
            account0.transfer(reward);
        } else if (
            (uint(p1Choice) + 1) % 5 == uint(p0Choice) ||
            (uint(p1Choice) + 3) % 5 == uint(p0Choice)
        ) {
            // pay player[1]
            account1.transfer(reward);
        } else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }

    function withdraw() public {
        require(elapsedSeconds() >= TIME_LIMIT);
        require(numPlayer > 0);
        address payable sender = payable(msg.sender);

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
                // who trigger withdraw get reward
                require(msg.sender == account0 || msg.sender == account1);
                sender.transfer(reward);
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
                // who trigger withdraw get reward
                require(msg.sender == account0 || msg.sender == account1);
                sender.transfer(reward);
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
            player_not_revealed[players[i]] = true;
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
