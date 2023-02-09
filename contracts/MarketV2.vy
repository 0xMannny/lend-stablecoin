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
    borrowAmount: uint256
    collateralValue: uint256
    collateralAmount: uint256
    principleBorrowAmount: uint256
    snapshotInterestVariable: uint256

users: public(HashMap[address, Loan])
activeUsers: public(HashMap[address, bool])

struct SpecialLoanParams:
    specialMaxLTVRatio: uint256
    specialMaxBorrowAmount: uint256
    specialInterestVariable: uint256

specialUsers: public(HashMap[address, SpecialLoanParams])
isSpecialUser: public(HashMap[address, bool])

totalLoans: public(uint256)
totalInterestAmount: public(uint256)
totalCollateralAmount: public(uint256)

defaultMaxLTVRatio: public(uint256)
defaultMaxBorrowAmount: public(uint256)
defaultInterestVariable: public(uint256)
defaultMinCollateralValue: public(immutable(uint256))

approvedWhitelist: public(HashMap[address, bool])
whitelistEnabled: public(immutable(bool))
totalWhitelistBorrowers: public(uint256)

isPaused: public(bool)
isShutdown: public(bool)

MAX_BPS: constant(uint256) = 10000

burner: public(address)
controller: public(address)


@external
def __init__(_collateralAddress: address,
             _stablecoinAddress: address,
             _defaultMaxLTVRatio: uint256,
             _defaultMaxBorrowAmount: uint256,
             _defaultInterestVariable: uint256,
             _defaultMinCollateralValue: uint256,
             _whitelistEnabled: bool,
             _burnerAddress: address):
    self.collateralERC4626 = ERC4626(_collateralAddress)
    self.collateralERC20 = ERC20(_collateralAddress)
    self.stablecoin = ERC20(_stablecoinAddress)
    self.defaultMaxLTVRatio = _defaultMaxLTVRatio
    self.defaultMaxBorrowAmount = _defaultMaxBorrowAmount
    self.defaultInterestVariable = _defaultInterestVariable
    defaultMinCollateralValue = _defaultMinCollateralValue
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
                       _borrowAmount: uint256,
                       _interestVariable: uint256) -> uint256:
    return (_newCollateralValue - _oldCollateralValue) * self.calcLoanLTVRatio(_oldCollateralValue, _borrowAmount) * _interestVariable / 10 ** 8


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
    newLoan: Loan = Loan({borrowAmount: _withdrawborrowAmount,
                        collateralValue: collateralValue,
                        collateralAmount: _depositCollateralAmount,
                        principleBorrowAmount: _withdrawborrowAmount,
                        snapshotInterestVariable: 0})
    ### Run Checks
    if self.isSpecialUser[msg.sender] == True:
        newLoan.snapshotInterestVariable = self.specialUsers[msg.sender].specialInterestVariable
        assert _withdrawborrowAmount <= self.specialUsers[msg.sender].specialMaxBorrowAmount
        assert self.calcLoanLTVRatio(collateralValue, _withdrawborrowAmount) <= self.specialUsers[msg.sender].specialMaxLTVRatio
    else:
        newLoan.snapshotInterestVariable = self.defaultInterestVariable
        assert _withdrawborrowAmount <= self.defaultMaxBorrowAmount
        assert self.calcLoanLTVRatio(collateralValue, _withdrawborrowAmount) <= self.defaultMaxLTVRatio
    assert self.activeUsers[msg.sender] == False
    assert self.isShutdown == False
    assert self.isPaused == False
    if whitelistEnabled == True:
        assert self.approvedWhitelist[msg.sender] == True
    assert self.collateralERC20.balanceOf(msg.sender) >= _depositCollateralAmount
    assert self.collateralERC20.allowance(msg.sender, self) >= _depositCollateralAmount
    assert collateralValue >= defaultMinCollateralValue
    assert _withdrawborrowAmount > 0
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
                                                 self.users[msg.sender].borrowAmount,
                                                 self.users[msg.sender].snapshotInterestVariable)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest
    newLoan: Loan = Loan({borrowAmount: 0,
                          collateralValue: 0,
                          collateralAmount: 0,
                          principleBorrowAmount: 0,
                          snapshotInterestVariable: 0})
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
              _withdrawBorrowAmount: uint256):
    """
    @notice Adds collateral or stablecoin debt on an active loan
    @param _depositCollateralAmount The amount of collateral to deposit
    @param _withdrawBorrowAmount The amount of stablecoins to borrow
    """
    ### Math
    newCollateralAmount: uint256 = self.users[msg.sender].collateralAmount + _depositCollateralAmount
    oldCollateralValue: uint256 = self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount)
    newCollateralValue: uint256 = self.collateralERC4626.convertToAssets(newCollateralAmount)
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                 oldCollateralValue,
                                                 self.users[msg.sender].borrowAmount,
                                                 self.users[msg.sender].snapshotInterestVariable)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest + _withdrawBorrowAmount
    newLoan: Loan = Loan({borrowAmount: newBorrowAmount,
                        collateralValue: newCollateralValue,
                        collateralAmount: newCollateralAmount,
                        principleBorrowAmount: self.users[msg.sender].principleBorrowAmount + _withdrawBorrowAmount,
                        snapshotInterestVariable: 0})
    ### Run Checks
    if self.isSpecialUser[msg.sender] == True:
        newLoan.snapshotInterestVariable = self.specialUsers[msg.sender].specialInterestVariable
        assert self.users[msg.sender].principleBorrowAmount + _withdrawBorrowAmount <= self.specialUsers[msg.sender].specialMaxBorrowAmount
        assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.specialUsers[msg.sender].specialMaxLTVRatio
    else:
        newLoan.snapshotInterestVariable = self.defaultInterestVariable
        assert self.users[msg.sender].principleBorrowAmount + _withdrawBorrowAmount <= self.defaultMaxBorrowAmount
        assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.defaultMaxLTVRatio
    assert self.activeUsers[msg.sender] == True
    assert self.isShutdown == False
    assert self.isPaused == False
    if whitelistEnabled == True:
        assert self.approvedWhitelist[msg.sender] == True
    assert _depositCollateralAmount + _withdrawBorrowAmount > 0
    assert self.collateralERC20.balanceOf(msg.sender) >= _depositCollateralAmount
    assert self.collateralERC20.allowance(msg.sender, self) >= _depositCollateralAmount
    ### Transfer Collateral
    if _depositCollateralAmount > 0:
        self.collateralERC20.transferFrom(msg.sender, self, _depositCollateralAmount)
        self.totalCollateralAmount += _depositCollateralAmount
    ### Mint Stablecoin
    if _withdrawBorrowAmount > 0:
        self.stablecoin.transfer(msg.sender, _withdrawBorrowAmount)
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
                                                 self.users[msg.sender].borrowAmount,
                                                 self.users[msg.sender].snapshotInterestVariable)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest - _depositBorrowAmount
    newLoan: Loan = Loan({borrowAmount: newBorrowAmount,
                        collateralValue: newCollateralValue,
                        collateralAmount: newCollateralAmount,
                        principleBorrowAmount: self.users[msg.sender].principleBorrowAmount - _depositBorrowAmount,
                        snapshotInterestVariable: 0})
    ### Run Checks
    if self.isSpecialUser[msg.sender] == True:
        newLoan.snapshotInterestVariable = self.specialUsers[msg.sender].specialInterestVariable
        assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.specialUsers[msg.sender].specialMaxLTVRatio
    else:
        newLoan.snapshotInterestVariable = self.defaultInterestVariable
        assert self.calcLoanLTVRatio(newCollateralValue, newBorrowAmount) <= self.defaultMaxLTVRatio
    assert self.activeUsers[msg.sender] == True
    assert _withdrawCollateralAmount + _depositBorrowAmount > 0
    assert self.stablecoin.balanceOf(msg.sender) >= _depositBorrowAmount
    assert self.stablecoin.allowance(msg.sender, self) >= _depositBorrowAmount
    assert newCollateralValue >= defaultMinCollateralValue
    assert self.users[msg.sender].principleBorrowAmount - _depositBorrowAmount >= 0
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


@internal
def _updateInterest(_user: address):
    """
    @notice Updates interest owed of a borrower
    @param _user The address to update interest
    """
    ### Math
    gainedInterest: uint256 = self.calcGainedInterest(self.users[msg.sender].collateralValue,
                                                          self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount),
                                                          self.users[msg.sender].borrowAmount,
                                                          self.users[msg.sender].snapshotInterestVariable)
    newBorrowAmount: uint256 = self.users[msg.sender].borrowAmount + gainedInterest
    newLoan: Loan = Loan({borrowAmount: newBorrowAmount,
                        collateralValue: self.collateralERC4626.convertToAssets(self.users[msg.sender].collateralAmount),
                        collateralAmount: self.users[msg.sender].collateralAmount,
                        principleBorrowAmount: self.users[msg.sender].principleBorrowAmount,
                        snapshotInterestVariable: 0})
    if self.isSpecialUser[msg.sender] == True:
        newLoan.snapshotInterestVariable = self.specialUsers[msg.sender].specialInterestVariable
    else:
        newLoan.snapshotInterestVariable = self.defaultInterestVariable
    ### Run Checks
    assert msg.sender == self.controller
    assert self.activeUsers[_user] == True
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
    self._updateInterest(_user)


@external
def updateSpecialUser(_user: address, _maxLTVRatio: uint256, _maxBorrowAmount: uint256, _interestVariable: uint256, _minCollateralValue: uint256, _removeSpecialUser: bool):
    assert msg.sender == self.controller
    if _removeSpecialUser == False:
        assert _maxLTVRatio < MAX_BPS
        assert _maxBorrowAmount > 0
        assert _interestVariable < MAX_BPS
        assert _minCollateralValue > 0
        newParams: SpecialLoanParams = SpecialLoanParams({specialMaxLTVRatio: _maxLTVRatio,
                                                          specialMaxBorrowAmount: _maxBorrowAmount,
                                                          specialInterestVariable: _interestVariable})
        self._updateInterest(_user)
        self.specialUsers[_user] = newParams
        self.isSpecialUser[_user] = True
    else:
        assert self.isSpecialUser[_user] == True
        newParams: SpecialLoanParams = SpecialLoanParams({specialMaxLTVRatio: 0,
                                                          specialMaxBorrowAmount: 0,
                                                          specialInterestVariable: 0})
        self.isSpecialUser[_user] = False
        self._updateInterest(_user)
        self.specialUsers[_user] = newParams


@external
def setDefaultMaxBorrowAmount(_defaultMaxBorrowAmount: uint256) -> bool:
    """
    @notice Sets the max borrow amount to a new value
    @param _defaultMaxBorrowAmount The amount to set the max borrow amount to
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert _defaultMaxBorrowAmount > 0
    self.defaultMaxBorrowAmount = _defaultMaxBorrowAmount
    return True


@external
def setDefaultMaxLTVRatio(_defaultMaxLTVRatio: uint256) -> bool:
    """
    @notice Sets the max ltv ratio to a new value
    @param _defaultMaxLTVRatio The amount to set the max ltv ratio to
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert _defaultMaxLTVRatio < MAX_BPS
    self.defaultMaxLTVRatio = _defaultMaxLTVRatio
    return True


@external
def setDefaultInterestVariable(_defaultInterestVariable: uint256) -> bool:
    """
    @notice Sets the interest variable to a new value
    @param _defaultInterestVariable The amount to set the interest variable to
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert _defaultInterestVariable < MAX_BPS
    self.defaultInterestVariable = _defaultInterestVariable
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


@external
def shutdownMarket(_currentTotalLoans: uint256) -> bool:
    """
    @notice Disable new borrowing and depositing of the market
    @param _currentTotalLoans The amount of the current loans, asks as a confirmation to actually shutdown
    @return Success boolean
    """
    assert msg.sender == self.controller
    assert self.isShutdown == False
    self.isShutdown = True
    return True