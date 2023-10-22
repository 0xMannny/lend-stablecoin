# lend-stablecoin
A stablecoin for borrowers to borrow against collateral without the need for a lender. The markets are controlled by governance, which can decide changes to markets using proposals. These proposals can change interest rates, and loan-to-value ratios, implement new markets, get rid of unused markets, etc. Almost every part of the market is customizable depending on what governance decides is necessary. The protocol is set up in a way where although governance has control over various markets, it doesn't have control over user assets. This ensures proper decentralization and protects against potential damage from governance attacks.

To fork this, you must be using Brownie and Titanoboa to compile and test Vyper.

Terminology:

Stablecoin - An asset that attempts to maintain the same price as another asset.
Fork - A copy of someone's code
Vyper - A programming language similar to Python that focuses on Ethereum
Brownie - A software that allows for developing and testing using the Vyper language.
Titanoboa - An addon to Vyper and Brownie that allows for easier testing of the code
