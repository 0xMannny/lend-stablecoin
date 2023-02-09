# @version ^0.3.7

"""
@title Safe Burner of Stablecoins
"""

import Token as Token

event Burn:
    burner: indexed(address)
    value: uint256

stablecoin: immutable(Token)


@external
def __init__(_stablecoinAddress: address):
    stablecoin = Token(_stablecoinAddress)


@external
def burn():
    value: uint256 = stablecoin.balanceOf(self)
    assert value > 0
    stablecoin.burnFrom(self, value)
    log Burn(msg.sender, value)