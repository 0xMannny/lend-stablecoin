# @version ^0.3.7

"""
@title Governance for Market and Factory
"""

interface Market:
    def openLoan(_depositCollateralAmount: uint256, _withdrawborrowAmount: uint256): nonpayable
    def closeLoan(): nonpayable
    def addToLoan(_depositCollateralAmount: uint256, _withdrawborrowAmount: uint256): nonpayable
    def removeFromLoan(_withdrawCollateralAmount: uint256, _depositBorrowAmount: uint256): nonpayable
    def updateInterest(_user: address): nonpayable
    def updateSpecialUser(_user: address, _maxLTVRatio: uint256, _maxBorrowAmount: uint256, _interestVariable: uint256,
                          _removeSpecialUser: bool) -> bool: nonpayable
    def setDefaultMaxBorrowAmount(_maxBorrowAmount: uint256) -> bool: nonpayable
    def setDefaultMaxLTVRatio(_maxLTVRatio: uint256) -> bool: nonpayable
    def setDefaultInterestVariable(_defaultInterestVariable: uint256) -> bool: nonpayable
    def addWhitelistBorrower(_borrower: address) -> bool: nonpayable
    def removeWhitelistBorrower(_borrower: address) -> bool: nonpayable
    def togglePause() -> bool: nonpayable

interface Factory:
    def isApprovedCollateral(_collateralAddress: address) -> bool: nonpayable
    def addCollateral(_collateralAddress: address): nonpayable
    def removeCollateral(_collateralAddress: address): nonpayable
    def isAddressAMarket(_address: address) -> bool: nonpayable
    def addMarket(_collateralAddress: address, _maxLTVRatio: uint256, _maxBorrowAmount: uint256, _interestVariable: uint256, _minCollateralValue: uint256, _whitelistEnabled: bool) -> address: nonpayable
    def raiseDebtCeiling(_market: address, _amount: uint256) -> bool: nonpayable
    def lowerDebtCeiling(_market: address, _amount: uint256) -> bool: nonpayable

factory: public(Factory)

# Has all possible parameters for any function, but only uses what is needed to call the function
struct Proposal:
    functionID: uint256
    startTime: uint256
    endTime: uint256
    agreeVotes: uint256
    disagreeVotes: uint256
    collateralAddress: address
    maxLTVRatio: uint256
    maxBorrowAmount: uint256
    interestVariable: uint256
    minCollateralValue: uint256
    whitelistEnabled: bool
    removeSpecialUser: bool
    user: address

marketProposals: public(HashMap[address, Proposal])
numbers: public(HashMap[address, uint256])
activeMarketProposal: public(HashMap[address, bool])
marketProposalsVoteSnapshot: public(HashMap[address, HashMap[address, uint256]])

weekInSeconds: public(constant(uint256)) = 604800
MAX_BPS: constant(uint256) = 10000


@external
def __init__(_factoryAddress: address):
    self.factory = Factory(_factoryAddress)


@external
def getProposal(_market: address) -> Proposal:
    assert self.factory.isAddressAMarket(_market)
    return self.marketProposals[_market]


@external
def isVotePassed(_market: address) -> bool:
    assert self.factory.isAddressAMarket(_market)
    assert self.activeMarketProposal[_market] == True
    assert block.timestamp >= self.marketProposals[_market].endTime
    return self.marketProposals[_market].agreeVotes > self.marketProposals[_market].disagreeVotes


@external
def vote(_market: address, _agree: bool) -> uint256:
    assert self.factory.isAddressAMarket(_market)
    assert self.activeMarketProposal[_market] == True
    assert block.timestamp >= self.marketProposals[_market].endTime
    amount: uint256 = 1
    if _agree:
        self.marketProposals[_market].agreeVotes += amount
    else:
        self.marketProposals[_market].disagreeVotes += amount
    return amount


@external
def newProposal(_functionID: uint256,
                _market: address,
                _collateralAddress: address,
                _maxLTVRatio: uint256,
                _maxBorrowAmount: uint256,
                _interestVariable: uint256,
                _minCollateralValue: uint256,
                _whitelistEnabled: bool,
                _removeSpecialUser: bool,
                _user: address):
    assert self.factory.isAddressAMarket(_market)
    assert self.activeMarketProposal[_market] == False
    assert _functionID <= 9
    assert self.factory.isApprovedCollateral(_collateralAddress)
    assert _maxLTVRatio <= MAX_BPS
    assert _maxLTVRatio >= 1000
    assert _maxBorrowAmount > 0
    assert _interestVariable <= MAX_BPS
    assert _minCollateralValue > 0
    newProposal: Proposal = Proposal({functionID: _functionID,
                                      startTime: block.timestamp,
                                      endTime: block.timestamp + weekInSeconds,
                                      agreeVotes: 0,
                                      disagreeVotes: 0,
                                      collateralAddress: _collateralAddress,
                                      maxLTVRatio: _maxLTVRatio,
                                      maxBorrowAmount: _maxBorrowAmount,
                                      interestVariable: _interestVariable,
                                      minCollateralValue: _minCollateralValue,
                                      whitelistEnabled: _whitelistEnabled,
                                      removeSpecialUser: _removeSpecialUser,
                                      user: _user})
    self.marketProposals[_market] = newProposal
    self.activeMarketProposal[_market] = True


@external
def useProposal(_market: address):
    assert self.factory.isAddressAMarket(_market)
    assert self.activeMarketProposal[_market] == True
    proposal: Proposal = self.marketProposals[_market]
    assert block.timestamp >= proposal.endTime
    assert proposal.agreeVotes > proposal.disagreeVotes
    if proposal.functionID == 0:
        self.factory.addCollateral(proposal.collateralAddress)
    elif proposal.functionID == 1:
        self.factory.removeCollateral(proposal.collateralAddress)
    elif proposal.functionID == 2:
        self.factory.addMarket(proposal.collateralAddress, proposal.maxLTVRatio, proposal.maxBorrowAmount,proposal.interestVariable,
                               proposal.minCollateralValue, proposal.whitelistEnabled)
    elif proposal.functionID == 3:
        assert Market(_market).updateSpecialUser(proposal.user, proposal.maxLTVRatio, proposal.maxBorrowAmount,
                                                 proposal.interestVariable, proposal.removeSpecialUser)
    elif proposal.functionID == 4:
        assert Market(_market).setDefaultMaxBorrowAmount(proposal.maxBorrowAmount)
    elif proposal.functionID == 5:
        assert Market(_market).setDefaultMaxLTVRatio(proposal.maxLTVRatio)
    elif proposal.functionID == 6:
        assert Market(_market).setDefaultInterestVariable(proposal.interestVariable)
    elif proposal.functionID == 7:
        assert Market(_market).addWhitelistBorrower(proposal.user)
    elif proposal.functionID == 8:
        assert Market(_market).removeWhitelistBorrower(proposal.user)
    elif proposal.functionID == 9:
        assert Market(_market).togglePause()
    newProposal: Proposal = Proposal({functionID: 0,
                                      startTime: 0,
                                      endTime: 0,
                                      agreeVotes: 0,
                                      disagreeVotes: 0,
                                      collateralAddress: empty(address),
                                      maxLTVRatio: 0,
                                      maxBorrowAmount: 0,
                                      interestVariable: 0,
                                      minCollateralValue: 0,
                                      whitelistEnabled: False,
                                      removeSpecialUser: False,
                                      user: empty(address)})
    self.marketProposals[_market] = newProposal
    self.activeMarketProposal[_market] = False
    


@external
def endProposal(_market: address):
    assert self.factory.isAddressAMarket(_market)
    assert self.activeMarketProposal[_market] == True
    assert block.timestamp >= self.marketProposals[_market].endTime
    assert self.marketProposals[_market].disagreeVotes > self.marketProposals[_market].agreeVotes
    newProposal: Proposal = Proposal({functionID: 0,
                                      startTime: 0,
                                      endTime: 0,
                                      agreeVotes: 0,
                                      disagreeVotes: 0,
                                      collateralAddress: empty(address),
                                      maxLTVRatio: 0,
                                      maxBorrowAmount: 0,
                                      interestVariable: 0,
                                      minCollateralValue: 0,
                                      whitelistEnabled: False,
                                      removeSpecialUser: False,
                                      user: empty(address)})
    self.marketProposals[_market] = newProposal
    self.activeMarketProposal[_market] = False
