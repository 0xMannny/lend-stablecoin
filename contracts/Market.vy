# @version ^0.3.7

"""
@title Leverage Borrow Minter for IB ETH Tokens
"""

from vyper.interfaces import ERC4626
from vyper.interfaces import ERC20

collateralERC4626: public(ERC4626)
collateralERC20: public(ERC20)
stablecoin: public(ERC20)

struct Loan:
    collateralAmount: uint256
    collateralValue: uint256
    borrowAmount: uint256
    principleBorrowAmount: uint256

totalLoans: public(uint256)
maxLTVRatio: public(uint256)
maxBorrowAmount: public(uint256)
totalInterestAmount: public(uint256)
totalCollateralAmount: public(uint256)
interestVariable: public(immutable(uint256))
minCollateralValue: public(immutable(uint256))

approvedWhitelist: public(HashMap[address, bool])
whitelistEnabled: public(immutable(bool))
totalWhitelistBorrowers: public(uint256)

isPaused: public(bool)

MAX_BPS: constant(uint256) = 10000

users: public(HashMap[address, Loan])
activeUsers: public(HashMap[address, bool])

burner: public(address)
controller: public(address)


@external
def __init__(_collateralAddress: address,
             _stablecoinAddress: address,
             _maxLTVRatio: uint256,
             _maxBorrowAmount: uint256,
             _interestVariable: uint256,
             _minCollateralValue: uint256,
             _whitelistEnabled: bool,
             _burnerAddress: address):
    self.collateralERC4626 = ERC4626(_collateralAddress)
    self.collateralERC20 = ERC20(_collateralAddress)
    self.stablecoin = ERC20(_stablecoinAddress)
    self.maxLTVRatio = _maxLTVRatio
    self.maxBorrowAmount = _maxBorrowAmount
    interestVariable = _interestVariable
    minCollateralValue = _minCollateralValue
    whitelistEnabled = _whitelistEnabled
    self.burner = _burnerAddress
    self.controller = msg.sender


@internal
def calcLoanLTVRatio(_collateralValue: uint256,
                     _borrowAmount: uint256) -> uint256:
    return 10000 * _borrowAmount / _collateralValue

@internal
def calcGainedInterest(_oldCollateralValue: uint256,
                       _newCollateralValue: uint256,
                       _borrowAmount: uint256) -> uint256:
    return (_newCollateralValue - _oldCollateralValue) * self.calcLoanLTVRatio(_oldCollateralValue, _borrowAmount) * interestVariable / 10 ** 8


@external
def openLoan(_depositCollateralAmount: uint256,
             _withdrawborrowAmount: uint256):
    """
    @notice Opens an approved loan with collateral and stablecoins borrowed
    @param _depositCollateralAmount The amount of collateral to deposit
    @param _withdrawborrowAmount The amount of stablecoins to borrow
    """
    ### Math
    collateralValue: uint256 = self.collateralERC4626.convertToAssets(_depositCollateralAmount)
    newLoan: Loan = Loan({collateralAmount: _depositCollateralAmount,
                          collateralValue: collateralValue,
                          borrowAmount: _withdrawborrowAmount,
                          principleBorrowAmount: _withdrawborrowAmount})
    ### Run Checks
    assert self.activeUsers[msg.sender] == False
    assert self.isPaused == False
    if whitelistEnabled == True:
        assert self.approvedWhitelist[msg.sender] == True
    assert self.collateralERC20.balanceOf(msg.sender) >= _depositCollateralAmount
    assert self.collateralERC20.allowance(msg.sender, self) >= _depositCollateralAmount
    assert collateralValue >= minCollateralValue
    assert _withdrawborrowAmount > 0
    assert _withdrawborrowAmount <= self.maxBorrowAmount
    assert self.calcLoanLTVRatio(collateralValue, _withdrawborrowAmount) <= self.maxLTVRatio
    ### Transfer Collateral
    self.collateralERC20.transferFrom(msg.sender, self, _depositCollateralAmount)
    self.totalCollateralAmount += _depositCollateralAmount
    ### Mint Stablecoin
    self.stablecoin.transfer(msg.sender, _withdrawborrowAmount)
    ### Set Up User Loan
    self.users[msg.sender] = newLoan
    ### Activate Positon
    self.activeUsers[msg.sender] = True
    self.totalLoans += 1


@external
def closeLoan():
    """
    @notice Closes an loan by repaying debt and transfering back collateral
    """
    ### Math
    oldCollateralValue: uint256 = self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount)
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                      oldCollateralValue,
                                                      self.users[msg.sender].borrowAmount)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest
    newLoan: Loan = Loan({collateralAmount: 0,
                          collateralValue: 0,
                          borrowAmount: 0,
                          principleBorrowAmount: 0})
    ### Run Checks
    assert self.activeUsers[msg.sender] == True
    assert self.stablecoin.balanceOf(msg.sender) >= newBorrowAmount
    assert self.stablecoin.allowance(msg.sender, self) >= newBorrowAmount
    ### Transfer Collateral
    self.collateralERC20.transfer(msg.sender, self.users[msg.sender].collateralAmount)
    self.totalCollateralAmount -= self.users[msg.sender].collateralAmount
    ### Mint/Burn Stablecoin
    self.stablecoin.transferFrom(msg.sender, self, self.users[msg.sender].principleBorrowAmount)
    self.stablecoin.transferFrom(msg.sender, self.burner, newBorrowAmount - self.users[msg.sender].principleBorrowAmount)
    ### Update Interest
    self.totalInterestAmount += gainedInterest
    ### Close User Loan
    self.users[msg.sender] = newLoan
    ### Deactivate Positon
    self.activeUsers[msg.sender] = False
    self.totalLoans -= 1


@external
def addToLoan(_depositCollateralAmount: uint256,
              _withdrawborrowAmount: uint256):
    """
    @notice Adds collateral or stablecoin debt on an active loan
    @param _depositCollateralAmount The amount of collateral to deposit
    @param _withdrawborrowAmount The amount of stablecoins to borrow
    """
    ### Math
    newCollateralAmount: uint256 = self.users[msg.sender].collateralAmount + _depositCollateralAmount
    oldCollateralValue: uint256 = self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount)
    newCollateralValue: uint256 = self.collateralERC4626.convertToAssets(newCollateralAmount)
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                      oldCollateralValue,
                                                      self.users[msg.sender].borrowAmount)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + _withdrawborrowAmount + gainedInterest
    newLoan: Loan = Loan({collateralAmount: newCollateralAmount, 
                          collateralValue: newCollateralValue,
                          borrowAmount: newBorrowAmount,
                          principleBorrowAmount: self.users[msg.sender].principleBorrowAmount + _withdrawborrowAmount})
    ### Run Checks
    assert self.activeUsers[msg.sender] == True
    assert self.isPaused == False
    if whitelistEnabled == True:
        assert self.approvedWhitelist[msg.sender] == True
    assert _depositCollateralAmount + _withdrawborrowAmount > 0
    assert self.collateralERC20.balanceOf(msg.sender) >= _depositCollateralAmount
    assert self.collateralERC20.allowance(msg.sender, self) >= _depositCollateralAmount
    assert newBorrowAmount <= self.maxBorrowAmount
    assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.maxLTVRatio
    ### Transfer Collateral
    if _depositCollateralAmount > 0:
        self.collateralERC20.transferFrom(msg.sender, self, _depositCollateralAmount)
        self.totalCollateralAmount += _depositCollateralAmount
    ### Mint Stablecoin
    if _withdrawborrowAmount > 0:
        self.stablecoin.transfer(msg.sender, _withdrawborrowAmount)
    ### Update Interest
    self.totalInterestAmount += gainedInterest
    ### Update User Loan
    self.users[msg.sender] = newLoan


@external
def removeFromLoan(_withdrawCollateralAmount: uint256,
                   _depositBorrowAmount: uint256):
    """
    @notice Removes collateral or stablecoin debt from an active loan
    @param _withdrawCollateralAmount The amount of collateral to withdraw
    @param _depositBorrowAmount The amount of stablecoins to repay
    """
    ### Run Checks For Non-Negative Math
    assert self.users[msg.sender].collateralAmount - _withdrawCollateralAmount >= 0
    assert self.users[msg.sender].principleBorrowAmount - _depositBorrowAmount >= 0
    ### Math
    newCollateralAmount: uint256 = self.users[msg.sender].collateralAmount - _withdrawCollateralAmount
    oldCollateralValue: uint256 = self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount)
    newCollateralValue: uint256 = self.collateralERC4626.convertToAssets(newCollateralAmount)
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                      oldCollateralValue,
                                                      self.users[msg.sender].borrowAmount)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest - _depositBorrowAmount 
    newLoan: Loan = Loan({collateralAmount: newCollateralAmount,
                          collateralValue: newCollateralValue,
                          borrowAmount: newBorrowAmount,
                          principleBorrowAmount: self.users[msg.sender].principleBorrowAmount - _depositBorrowAmount})
    ### Run Checks
    assert self.activeUsers[msg.sender] == True
    assert _withdrawCollateralAmount + _depositBorrowAmount > 0
    assert self.stablecoin.balanceOf(msg.sender) >= _depositBorrowAmount
    assert self.stablecoin.allowance(msg.sender, self) >= _depositBorrowAmount
    assert newCollateralValue >= minCollateralValue
    assert self.users[msg.sender].principleBorrowAmount - _depositBorrowAmount >= 0
    assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.maxLTVRatio
    ### Transfer Collateral
    if _withdrawCollateralAmount > 0:
        self.collateralERC20.transfer(msg.sender, _withdrawCollateralAmount)
        self.totalCollateralAmount -= _withdrawCollateralAmount
    ### Mint/Burn Stablecoin
    if _depositBorrowAmount > 0:
        self.stablecoin.transferFrom(msg.sender, self, _depositBorrowAmount)
    ### Update Interest
    self.totalInterestAmount += gainedInterest
    ### Update User Loan
    self.users[msg.sender] = newLoan


@external
def updateInterest(_user: address):
    """
    @notice Updates interest owed of a borrower
    @param _user The address to update interest
    """
    ### Math
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                      self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount),
                                                      self.users[msg.sender].borrowAmount)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest
    newLoan: Loan = Loan({collateralAmount: self.users[msg.sender].collateralAmount,
                          collateralValue: self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount),
                          borrowAmount: newBorrowAmount,
                          principleBorrowAmount: self.users[msg.sender].principleBorrowAmount})
    ### Run Checks
    assert msg.sender == self.controller
    assert self.activeUsers[_user] == True
    ### Update Interest
    self.totalInterestAmount += gainedInterest
    ### Update User Loan
    self.users[msg.sender] = newLoan


@external
def setMaxBorrowAmount(_maxBorrowAmount: uint256) -> bool:
    """
    @notice Sets the max borrow amount to a new value
    @param _maxBorrowAmount The amount to set the max borrow amount to
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert _maxBorrowAmount > 0
    self.maxBorrowAmount = _maxBorrowAmount
    return True


@external
def setMaxLTVRatio(_maxLTVRatio: uint256) -> bool:
    """
    @notice Sets the max ltv ratio to a new value
    @param _maxLTVRatio The amount to set the max ltv ratio to
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert _maxLTVRatio <= MAX_BPS
    self.maxLTVRatio = _maxLTVRatio
    return True


@external
def addWhitelistBorrower(_borrower: address) -> bool:
    """
    @notice Adds a user to the borrower whitelist
    @param _borrower The address to add to the whitelist
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert whitelistEnabled == True
    assert self.approvedWhitelist[_borrower] == False
    self.approvedWhitelist[_borrower] = True
    self.totalWhitelistBorrowers += 1
    return True


@external
def removeWhitelistBorrower(_borrower: address) -> bool:
    """
    @notice Removes a user from the borrower whitelist
    @param _borrower The address to remove from whitelist
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert whitelistEnabled == True
    assert self.approvedWhitelist[_borrower] == True
    self.approvedWhitelist[_borrower] = False
    self.totalWhitelistBorrowers -= 1
    return True


@external
def togglePause() -> bool:
    """
    @notice Toggles whether borrowing is paused or not
    @return The new state of isPaused
    """
    assert msg.sender == self.controller
    if self.isPaused == True:
        self.isPaused = False
    else:
        self.isPaused = True
    return self.isPaused