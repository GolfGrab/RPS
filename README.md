# Rock Paper Scissors Lizard Spock Smart Contract

This Solidity smart contract implements a decentralized version of the game "Rock Paper Scissors Lizard Spock" with commit-reveal scheme to ensure fairness. The contract allows two players to participate, commit their choices, reveal them, and determine the winner based on the game rules. The contract also includes a time limit to prevent funds from being locked indefinitely and allows players to withdraw their funds if the game is not completed within the specified time limit, or if both players have not played or revealed their choices.

## Game Rules

The game "Rock Paper Scissors Lizard Spock" is an extension of the classic game "Rock Paper Scissors" with two additional choices. The rules are as follows:

- **Rock** crushes **Scissors** and crushes **Lizard**
- **Paper** covers **Rock** and disproves **Spock**
- **Scissors** cuts **Paper** and decapitates **Lizard**
- **Lizard** poisons **Spock** and eats **Paper**
- **Spock** smashes **Scissors** and vaporizes **Rock**

```solidity
// 0 - Scissors, 1 - Paper, 2 - Rock, 3 - Lizard, 4 - Spock
enum Choice {
    Scissors,
    Paper,
    Rock,
    Lizard,
    Spock
}
```

## Game Flow

1. **Join Game:** Players can join the game by sending 1 ether.
2. **Commit Choice:** Players commit their choice by hashing it with a secret string.
3. **Reveal Choice:** Players reveal their choice by providing the original choice and secret string.
4. **Determine Winner:** The contract compares the choices of both players and determines the winner based on the game rules.
5. **Reward Winner:** The winner receives the reward, and in case of a tie, the reward is split between the players.
6. **Reset Game:** The game state is reset for a new round.
7. **Withdraw Funds (Special Case):** If the game is not completed within the time limit, players can withdraw their funds with penalty for the player who did not take action.

## Contract Overview

### Allowed Players

The contract allows only two players to participate in the game and only the allowed players can join the game.

```solidity
address[] public allowedPlayers = [
    0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
    0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
    0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
    0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
];
```

### Preventing Funds from Being Locked

The contract ensures that funds are not locked indefinitely by implementing a time limit for each game. If the time limit is exceeded, players can withdraw their funds.

- **Function:** `withdraw()`
- **Condition:** `require(elapsedSeconds() >= TIME_LIMIT);`
- **Description:** Allows players to withdraw their funds if the game is not completed within the specified time limit.

### Commit and Reveal Scheme

The commit-reveal scheme is used to prevent players from cheating by selecting their choices after seeing the opponent's choice.

- **Function:** `getHashedChoice(Choice choice, string memory secret)`
- **Description:** Generates a hashed choice using the player's choice and a secret string. (View function, can be called externally)
- **Function:** `inputHashedChoice(bytes32 hashedChoice)`
- **Description:** Allows players to commit their hashed choice.
- **Function:** `revealChoice(Choice choice, string memory secret)`
- **Description:** Allows players to reveal their choice by providing the original choice and secret.

### Handling Delays and Incomplete Games

The contract handles scenarios where players do not complete their actions within the time limit.

- **Function:** `withdraw()`
- **Description:** Allows players to withdraw their funds if the game is not completed within the specified time limit.
- **Condition:** Checks if some players have not played or revealed their choices within the time limit and allow players to withdraw their funds with a penalty for the player who did not take action.

```solidity
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
```

### Revealing Choices and Determining the Winner

Once both players reveal their choices, the contract determines the winner and distributes the reward.

- **Function:** `_checkWinnerAndPay()`
- **Description:** Compares the choices of both players and transfers the reward to the winner or splits it in case of a tie.

```solidity
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
```

- **Function:** `_resetGame()`
- **Description:** Resets the game state for a new round.

```solidity
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
```

## Usage

1. **Add Player:** Players can join the game by calling `addPlayer()` and sending 1 ether.
2. **Commit Choice:** Players commit their hashed choice using `inputHashedChoice(bytes32 hashedChoice)`.
3. **Reveal Choice:** Players reveal their choice using `revealChoice(Choice choice, string memory secret)`.
4. **Withdraw Funds:** If the game is not completed within the time limit, players can withdraw their funds using `withdraw()`.

## Example

```solidity
// Player 1 joins the game
addPlayer();

// Player 2 joins the game
addPlayer();

// Player 1 commits their choice
inputHashedChoice(getHashedChoice(Choice.Rock, "secret1"));

// Player 2 commits their choice
inputHashedChoice(getHashedChoice(Choice.Paper, "secret2"));

// Player 1 reveals their choice
revealChoice(Choice.Rock, "secret1");

// Player 2 reveals their choice
revealChoice(Choice.Paper, "secret2");
```
