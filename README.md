# Money Printer

**Money Printer is a self-hosted high-frequency arbitrage bot for Solana. Fast, reliable, and highly configurable, it is built for operators who compete on execution quality.**

Money Printer is designed for real mainnet conditions. It runs on your own Linux machine, monitors configured markets, builds execution-ready transactions, and submits them through multiple low-latency delivery paths.

## This Repository

This repository is the public release home for Money Printer.

Releases may include:
- the `money-printer` binary
- example configuration files
- release notes
- operator documentation

## Why Use It

- Built for Solana HFT arbitrage
- Fast transaction delivery
- Reliable multi-path execution
- Flexible runtime configuration
- Self-hosted on your own infrastructure
- Incentives aligned through performance-based compensation

## Current Integrations

Current venue support includes:
- Meteora DLMM
- Meteora DAMM2
- Raydium CPMM
- Pump AMM
- Pseudo tri-hop/quad-hop via USD1 and USDC stable coins

Current execution paths include:
- RPC fanout
- Jito
- Helius
- Helius SWQoS
- Flashblock
- Temporal / Nozomi
- Astra
- HelloMoon

Support may evolve between releases.

## Fee Model

Money Printer is not distributed through a traditional upfront license.

Instead:
- you run the bot on your own machine
- you control your own wallet, network, and operating environment
- compensation is taken only from profitable executions
- the fee is calculated as a percentage of net profit after direct execution costs

Direct execution costs may include transaction fees, priority fees, tips, flash-loan fees, and other route-related expenses.

## System Requirements

Minimum recommended environment:
- Linux
- stable network connection
- at least 8 CPU cores

Actual performance depends heavily on hardware quality, network quality, market selection, and operating conditions.

## Quick Start

1. Download the latest release.
2. Extract the release package.
3. Review the example configuration.
4. Prepare your Linux host and wallet environment.
5. Launch the bot.

## Important Notes

- Money Printer is intended for experienced operators.
- Trading is risky and profits are not guaranteed.
- You are responsible for your infrastructure, wallet security, and compliance in your jurisdiction.

## Support

For onboarding, release questions, or support:

**[add contact here]**
