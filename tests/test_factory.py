from brownie import *
import boa


def test_use_factory():
    s = boa.load_partial("contracts/tests/ERC20.vy")
    blueprint = s.deploy_as_blueprint()
    factory = boa.load("contracts/tests/Factory.vy", blueprint)
    s.at(factory.create_new_erc20("token", "TKN", 18, 10**18))