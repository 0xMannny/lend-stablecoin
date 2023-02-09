#!/usr/bin/python3

import pytest
import boa

# . This runs before ALL tests


# Admin


@pytest.fixture
def admin():
    return boa.env.generate_address()


# Tokens


@pytest.fixture
def collat_token(TestYearnToken, accounts):
    return TestYearnToken.deploy("Test Yearn ETH", "yETH", 18, 1e24, {"from": accounts[0]})


@pytest.fixture
def token(Token, accounts):
    return Token.deploy("Test ETH", "tETH", 18, 1e24, {"from": accounts[0]})


# Minter


@pytest.fixture
def minter(Minter, token, accounts):
    minter = Minter.deploy(token, {"from": accounts[0]})
    token.setMinter(minter, {"from": token.minter()})
    return minter


# Burner


@pytest.fixture
def burner(Burner, token, accounts):
    burner = Burner.deploy(token, {"from": accounts[0]})
    token.setBurner(burner, {"from": token.burner()})
    return burner


# Market For Blueprint


@pytest.fixture
def market(Market, collat_token, token, burner, accounts):
    market = Market.deploy(collat_token, token, 9000, 1e21, 10000, 1e18, False, burner, {'from': accounts[0]})
    token.mintTo(market, 1e24, {"from": token.controller()})
    return market


@pytest.fixture
def wl_market(Market, collat_token, token, burner, accounts):
    market = Market.deploy(collat_token, token, 9000, 1e21, 10000, 1e18, True, burner, {'from': accounts[0]})
    token.mintTo(market, 1e21, {"from": token.controller()})
    return market


# Controller


@pytest.fixture
def controller(token, burner):
    s = boa.load_partial('contracts/Market.vy')
    r = s.deploy_as_blueprint()
    controller = boa.load("contracts/Controller.vy", token.address, burner.address, r)
    token.setController(controller.address, {'from': token.controller()})
    return controller