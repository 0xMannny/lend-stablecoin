import brownie
from brownie import *


def test_market_deployed(market):
    assert hasattr(market, "openLoan")


# openLoan Function


def test_open_loan_with_active_loan(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_with_paused_market(market, collat_token, accounts):
    amount = 1e18

    market.togglePause({"from": market.controller()})
    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_without_whitelist(wl_market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(wl_market, amount, {"from": accounts[0]})
    with brownie.reverts():
        wl_market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_with_insufficient_balance(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    collat_token.burnFrom(accounts[0], collat_token.balanceOf(accounts[0]), {"from": collat_token.deployer()})
    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_with_insufficient_allowance(market, collat_token, accounts):
    amount = 1e18

    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_below_min_collateral(market, collat_token, accounts):
    amount = 1e15

    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_with_0_borrow(market, collat_token, accounts):
    amount = 1e15

    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 0, {"from": accounts[0]})


def test_open_loan_above_max_borrow(market, collat_token, accounts):
    amount = 1e24

    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1e22, {"from": accounts[0]})


def test_open_loan_above_max_ltv_ratio(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1e18, {"from": accounts[0]})


def test_open_loan_updates_total_collateral(market, collat_token, accounts):
    amount = 1e18
    init_amount = market.totalCollateralAmount()

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    assert market.totalCollateralAmount() == init_amount + amount


def test_open_loan_updates_active_user(market, collat_token, accounts):
    amount = 1e18
    init_amount = market.totalCollateralAmount()

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.openLoan(amount, 1, {"from": accounts[0]})


def test_open_loan_updates_total_loans(market, collat_token, accounts):
    amount = 1e18
    init_amount = market.totalLoans()

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    assert market.totalLoans() == init_amount + 1


# closeLoan Function


def test_close_loan_with_no_loan(market, accounts):
    with brownie.reverts():
        market.closeLoan({"from": accounts[0]})


def test_close_loan_with_insufficent_balance(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    token.approve(market, 1, {"from": accounts[0]})
    token.burnFrom(accounts[0], token.balanceOf(accounts[0]), {"from": token.controller()})
    with brownie.reverts():
        market.closeLoan({"from": accounts[0]})



def test_close_loan_with_insufficent_allowance(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.closeLoan({"from": accounts[0]})


def test_close_loan_updates_total_collateral(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    init_amount = market.totalCollateralAmount()
    token.approve(market, 1, {"from": accounts[0]})
    market.closeLoan({"from": accounts[0]})
    assert market.totalCollateralAmount() == init_amount - amount


def test_close_loan_updates_total_interest(market, collat_token, token, accounts):
    pass


def test_close_loan_updates_active_user(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    token.approve(market, 1, {"from": accounts[0]})
    market.closeLoan({"from": accounts[0]})
    with brownie.reverts():
        market.closeLoan({"from": accounts[0]})


def test_close_loan_updates_total_loans(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    init_amount = market.totalLoans()
    token.approve(market, 1, {"from": accounts[0]})
    market.closeLoan({"from": accounts[0]})
    assert market.totalLoans() == init_amount - 1


# addToLoan Function


def test_add_to_loan_with_no_loan(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    with brownie.reverts():
        market.addToLoan(amount, 1, {"from": accounts[0]})


def test_add_to_loan_with_paused_market(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    market.togglePause({"from": market.controller()})
    with brownie.reverts():
        market.addToLoan(amount, 1, {"from": accounts[0]})


def test_add_to_loan_without_whitelist(wl_market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(wl_market, amount * 2, {"from": accounts[0]})
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    wl_market.openLoan(amount, 1, {"from": accounts[0]})
    wl_market.removeWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    wl_market.togglePause({"from": wl_market.controller()})
    with brownie.reverts():
        wl_market.addToLoan(amount, 1, {"from": accounts[0]})


def test_add_to_loan_with_0_deposit_and_borrow(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.addToLoan(0, 0, {"from": accounts[0]})


def test_add_to_loan_with_insufficient_balance(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    collat_token.burnFrom(accounts[0], collat_token.balanceOf(accounts[0]), {"from": collat_token.deployer()})
    with brownie.reverts():
        market.addToLoan(amount, 1, {"from": accounts[0]})


def test_add_to_loan_with_insufficient_approval(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.addToLoan(amount, 1, {"from": accounts[0]})


def test_add_to_loan_above_max_borrow(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.addToLoan(amount, 1e22, {"from": accounts[0]})


def test_add_to_loan_above_max_ltv_ratio(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.addToLoan(0, 1e19, {"from": accounts[0]})


def test_add_to_loan_updates_total_collateral(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    init_amount = market.totalCollateralAmount()
    market.addToLoan(amount, 1, {"from": accounts[0]})
    assert market.totalCollateralAmount() == init_amount + amount


def test_add_to_loan_updates_total_interest(market, collat_token, accounts):
    pass


# removeFromLoan Function


def test_remove_from_loan_below_0_collateral_amount(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(amount * 2, 0, {"from": accounts[0]})


def test_remove_from_loan_below_0_principal_amount(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    token.approve(market, 2, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(0, 2, {"from": accounts[0]})


def test_remove_from_loan_with_no_loan(market, token, accounts):
    amount = 1e18

    token.approve(market, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(0, 1, {"from": accounts[0]})


def test_remove_from_loan_with_0_withdraw_and_repay(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(0, 0, {"from": accounts[0]})


def test_remove_from_loan_with_insufficient_balance(market, collat_token, token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    token.approve(market, 1, {"from": accounts[0]})
    token.burnFrom(accounts[0], token.balanceOf(accounts[0]), {"from": token.controller()})
    with brownie.reverts():
        market.removeFromLoan(0, 1, {"from": accounts[0]})


def test_remove_from_loan_with_insufficient_approval(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(0, 1, {"from": accounts[0]})


def test_remove_from_loan_below_min_collateral(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(1e18, 0, {"from": accounts[0]})


def test_remove_from_loan_repay_above_principal():
    pass


def test_remove_from_loan_above_max_ltv_ratio(market, collat_token, accounts):
    amount = 2e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1e18, {"from": accounts[0]})
    with brownie.reverts():
        market.removeFromLoan(1e18, 0, {"from": accounts[0]})


def test_remove_from_loan_updates_total_collateral(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount * 2, {"from": accounts[0]})
    market.openLoan(amount * 2, 1, {"from": accounts[0]})
    init_amount = market.totalCollateralAmount()
    market.removeFromLoan(amount, 0, {"from": accounts[0]})
    assert market.totalCollateralAmount() == init_amount - amount


def test_remove_from_loan_updates_total_interest():
    pass


# updateInterest Function


def test_update_interest_from_hacker(market, collat_token, accounts):
    amount = 1e18

    collat_token.approve(market, amount, {"from": accounts[0]})
    market.openLoan(amount, 1, {"from": accounts[0]})
    with brownie.reverts():
        market.updateInterest(accounts[0], {"from": accounts[1]})


def test_update_interest_with_no_loan(market, accounts):
    with brownie.reverts():
        market.updateInterest(accounts[0], {"from": market.controller()})


def test_update_interest_updates_total_interest():
    pass


# setMaxBorrowAmount Function


def test_set_max_borrow_amount_from_hacker(market, accounts):
    with brownie.reverts():
        market.setMaxBorrowAmount(1e21, {"from": accounts[1]})


def test_set_max_borrow_amount_with_0_amount(market):
    with brownie.reverts():
        market.setMaxBorrowAmount(0, {"from": market.controller()})


def test_set_max_borrow_amount_updates_max_borrow_amount(market):
    amount = 1

    market.setMaxBorrowAmount(amount, {"from": market.controller()})
    assert market.maxBorrowAmount() == amount



# setMaxLTVRatio Function


def test_set_max_ltv_ratio_from_hacker(market, accounts):
    with brownie.reverts():
        market.setMaxLTVRatio(9000, {"from": accounts[1]})


def test_set_max_ltv_ratio_above_max_amount(market):
    with brownie.reverts():
        market.setMaxLTVRatio(15000, {"from": market.controller()})


def test_set_max_ltv_ratio_updates_max_ltv_ratio(market):
    amount = 1
    
    market.setMaxLTVRatio(amount, {"from": market.controller()})
    assert market.maxLTVRatio() == amount


# addWhitelistBorrower Function


def test_add_whitelist_borrower_from_hacker(wl_market, accounts):
    with brownie.reverts():
        wl_market.addWhitelistBorrower(accounts[0], {"from": accounts[1]})


def test_add_whitelist_borrower_without_whitelist(market, accounts):
    with brownie.reverts():
        market.addWhitelistBorrower(accounts[0], {"from": market.controller()})


def test_add_whitelist_borrower_with_whitelist_borrower(wl_market, accounts):
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    with brownie.reverts():
        wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})


def test_add_whitelist_borrower_updates_borrower(wl_market, accounts):
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    assert wl_market.approvedWhitelist(accounts[0]) == True


def test_add_whitelist_borrower_updates_total_whitelist_borrowers(wl_market, accounts):
    amount = wl_market.totalWhitelistBorrowers()
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    assert wl_market.totalWhitelistBorrowers() == amount + 1


# removeWhitelistBorrower Function


def test_remove_whitelist_borrower_from_hacker(wl_market, accounts):
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    with brownie.reverts():
        wl_market.removeWhitelistBorrower(accounts[0], {"from": accounts[1]})


def test_remove_whitelist_borrower_without_whitelist(market, accounts):
    with brownie.reverts():
        market.removeWhitelistBorrower(accounts[0], {"from": market.controller()})


def test_remove_whitelist_borrower_without_whitelist_borrower(wl_market, accounts):
    with brownie.reverts():
        wl_market.removeWhitelistBorrower(accounts[0], {"from": wl_market.controller()})


def test_remove_whitelist_borrower_updates_borrower(wl_market, accounts):
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    wl_market.removeWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    assert wl_market.approvedWhitelist(accounts[0]) == False


def test_remove_whitelist_borrower_updates_total_whitelist_borrowers(wl_market, accounts):
    wl_market.addWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    amount = wl_market.totalWhitelistBorrowers()
    wl_market.removeWhitelistBorrower(accounts[0], {"from": wl_market.controller()})
    assert wl_market.totalWhitelistBorrowers() == amount - 1


# togglePause Function


def test_toggle_pause_from_hacker(market, accounts):
    with brownie.reverts():
        market.togglePause({"from": accounts[1]})


def test_toggle_pause_updates_paused(market):
    state = market.isPaused()
    market.togglePause({"from": market.controller()})
    assert market.isPaused() != state