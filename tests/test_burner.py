import brownie
from brownie import *


def test_burner_deployed(burner):
    assert hasattr(burner, "burn")


# burn Function


def test_nothing_to_burn(burner, accounts):
    with brownie.reverts():
        burner.burn({"from": accounts[0]})


def test_balance_updates_on_burn(burner, token, accounts):
    amount = 10 ** 18

    token.transfer(burner, amount, {"from": accounts[0]})
    burner.burn({"from": accounts[0]})
    assert token.balanceOf(burner) == 0