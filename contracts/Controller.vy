# @version ^0.3.7

from vyper.interfaces import ERC20
from vyper.interfaces import ERC4626

interface Market:
    def openLoan(_depositCollateralAmount: uint256, _withdrawborrowAmount: uint256): nonpayable
    def closeLoan(): nonpayable
    def addToLoan(_depositCollateralAmount: uint256, _withdrawborrowAmount: uint256): nonpayable
    def removeFromLoan(_withdrawCollateralAmount: uint256, _depositBorrowAmount: uint256): nonpayable
    def updateInterest(_user: address): nonpayable
    def setMaxBorrowAmount(_maxBorrowAmount: uint256) -> bool: nonpayable
    def setMaxLTVRatio(_maxLTVRatio: uint256) -> bool: nonpayable
    def addWhitelistBorrower(_borrower: address) -> bool: nonpayable
    def removeWhitelistBorrower(_borrower: address) -> bool: nonpayable
    def togglePause() -> bool: nonpayable

interface Token:
    def balanceOf(_owner: address) -> uint256: nonpayable
    def mintTo(_to: address, _value: uint256) -> bool: nonpayable
    def burnFrom(_from: address, _value: uint256) -> bool: nonpayable


struct Loan:
    collateralAmount: uint256
    collateralValue: uint256
    borrowAmount: uint256
    principleBorrowAmount: uint256

markets: public(DynArray[address, 10000])
totalMarkets: public(uint256)
marketsInterestCollected: public(HashMap[address, uint256])

burner: public(immutable(address))
blueprint: public(immutable(address))
stablecoinAddress: public(immutable(address))

MAX_BPS: public(constant(uint256)) = 10000

stablecoin: public(immutable(Token))

totalIssuedDebt: public(uint256)

deployer: public(address)


@external
def __init__(_stablecoinAddress: address, _burnerAddress: address, _blueprintAddress: address):
    assert _blueprintAddress != empty(address)
    assert _stablecoinAddress != empty(address)
    assert _burnerAddress != empty(address)
    stablecoinAddress = _stablecoinAddress
    burner = _burnerAddress
    blueprint = _blueprintAddress
    stablecoin = Token(_stablecoinAddress)
    self.deployer = msg.sender


@external
def addMarket(_collateralAddress: address, _maxLTVRatio: uint256, _maxBorrowAmount: uint256, _interestVariable: uint256, _minCollateralValue: uint256, _whitelistEnabled: bool) -> address:
    assert msg.sender == self.deployer
    assert _maxLTVRatio <= MAX_BPS
    assert _maxBorrowAmount > 0
    assert _interestVariable <= MAX_BPS
    assert _minCollateralValue > 0
    arg1: address = _collateralAddress
    arg2: address = stablecoinAddress
    arg3: uint256 = _maxLTVRatio
    arg4: uint256 = _maxBorrowAmount
    arg5: uint256 = _interestVariable
    arg6: uint256 = _minCollateralValue
    arg7: bool = _whitelistEnabled
    arg8: address = burner
    # if arg7 == False:
    #     for market in self.markets:
    #         if Market(market).whitelistEnabled() == False:
    #             assert Market(market).collateralERC20() != _collateralAddress
    newMarket: address = create_from_blueprint(blueprint, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, code_offset=3)
    self.markets.append(newMarket)
    self.totalMarkets += 1
    return newMarket


@external
def raiseDebtCeiling(_market: address, _amount: uint256) -> bool:
    assert msg.sender == self.deployer
    assert _market in self.markets
    assert _amount > 0
    stablecoin.mintTo(_market, _amount)
    self.totalIssuedDebt += _amount
    return True


@external
def lowerDebtCeiling(_market: address, _amount: uint256) -> bool:
    assert msg.sender == self.deployer
    assert _market in self.markets
    assert stablecoin.balanceOf(_market) >= _amount
    assert _amount > 0
    stablecoin.burnFrom(_market, _amount)
    self.totalIssuedDebt -= _amount
    return True


@external
def collectInterest(_market: address) -> uint256:
    assert msg.sender == self.deployer
    assert _market in self.markets
    # assert Market(_market).totalInterestAmount() - self.marketsInterestCollected[_market] > 0
    # unclaimedInterest: uint256 = Market(_market).totalInterestAmount() - self.marketsInterestCollected[_market]
    # stablecoin.mintTo(msg.sender, unclaimedInterest)
    # self.marketsInterestCollected[_market] += unclaimedInterest
    # return unclaimedInterest
    return 1


@external
def setMaxBorrowAmount(_market: address, _maxBorrowAmount: uint256) -> bool:
    """
    @notice Sets the max borrow amount to a new value
    @param _market The address of market to update
    @param _maxBorrowAmount The amount to set the max borrow amount to
    @return Success boolean
    """
    assert msg.sender == self.deployer
    assert _market in self.markets
    return Market(_market).setMaxBorrowAmount(_maxBorrowAmount)


@external
def setMaxLTVRatio(_market: address, _maxLTVRatio: uint256) -> bool:
    """
    @notice Sets the max ltv ratio to a new value
    @param _market The address of market to update
    @param _maxLTVRatio The amount to set the max ltv ratio to
    @return Success boolean
    """
    assert msg.sender == self.deployer
    assert _market in self.markets
    return Market(_market).setMaxLTVRatio(_maxLTVRatio)


@external
def addWhitelistBorrower(_market: address, _borrower: address) -> bool:
    """
    @notice Adds a user to the borrower whitelist
    @param _market The address of market to update
    @param _borrower The address to add to the whitelist
    @return Success boolean
    """
    assert msg.sender == self.deployer
    assert _market in self.markets
    return Market(_market).addWhitelistBorrower(_borrower)


@external
def removeWhitelistBorrower(_market: address, _borrower: address) -> bool:
    """
    @notice Removes a user from the borrower whitelist
    @param _market The address of market to update
    @param _borrower The address to remove from whitelist
    @return Success boolean
    """
    assert msg.sender == self.deployer
    assert _market in self.markets
    return Market(_market).removeWhitelistBorrower(_borrower)


@external
def togglePause(_market: address) -> bool:
    """
    @notice Toggles whether borrowing is paused or not
    @param _market The address of market to update
    @return The new state of isPaused
    """
    assert msg.sender == self.deployer
    assert _market in self.markets
    return Market(_market).togglePause()