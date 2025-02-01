# EcoVault

A decentralized savings app that rounds up purchases to fund eco-friendly initiatives. Users can connect their wallets, and when they make purchases, the amount is rounded up to the nearest dollar with the difference being stored in the vault. These funds can then be allocated to verified eco-friendly projects.

## Features
- Deposit rounded up amounts into vault
- Withdraw funds (with timelock)
- View total contributions 
- Allocate funds to eco initiatives
- View initiative funding metrics
- Earn rewards for significant initiative contributions
- Track contributor metrics per initiative

## Architecture
The smart contract handles:
- User vault management
- Fund allocation logic
- Initiative registration and verification
- Time-locked withdrawals
- Rewards distribution for large contributions
- Contributor tracking per initiative

## Rewards System
Users who contribute above the rewards threshold (1000 microSTX) to initiatives receive:
- 5% rewards on their contribution
- Rewards are tracked per user vault
- Total rewards distribution is monitored contract-wide
- Initiative contributor counts are tracked
