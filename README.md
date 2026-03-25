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

- Secure - the bot secures your private key on the very first run (___it is your responsibility to **back it up**___)
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
- Pseudo tri-hop (bridged) via USD1 and USDC stable coins

Current execution paths include:
- RPC fanout
- Jito
- Helius
- Helius SWQoS
- Flashblock
- Temporal / Nozomi
- Astra
- HelloMoon

**_Unprofitable_** transactions are **_failed_**, hence no tip ever gets wasted.

Support may evolve between releases.

***_It is important to mention that some providers strongly discourage failing of even unprofitable transactions._**

## Fee Model

Money Printer is not distributed through a traditional upfront license.

Instead:
- you run the bot on your own machine
- you control your own wallet, network, and operating environment
- compensation is taken only from profitable executions
- the fee is 5% of net profit after direct execution costs

Direct execution costs may include transaction fees, priority fees, tips, flash-loan fees, and other route-related expenses.

## System Requirements

Minimum recommended environment:
- Linux 64-bit
- CPU with at least 8 cores
- RAM: >256MB
- Disk: just enough for the binary itself
- stable and fast network connection

Actual performance depends heavily on hardware quality, network quality, market selection, and operating conditions.

## Quick Start

1. Download the latest release.
2. Extract the release package.
3. Review the example configuration.
4. Prepare your Linux host and wallet environment.
5. Launch the bot.

## Key Protection

On first run, Money Printer automatically protects the configured Solana keypair file on disk and continues operating with the protected key as usual.

This is intended to reduce the risk of casual key exposure on the host machine. However, operators should not treat it as a substitute for proper system security, access control, and backups.

**Important:** back up your original keypair file before the first launch. Once the file has been protected by the bot, you will not be able to decrypt it yourself outside Money Printer.

## Important Notes

- Money Printer is intended for experienced operators.
- Trading is risky and profits are not guaranteed.
- You are responsible for your infrastructure, wallet security, and compliance in your jurisdiction.

[//]: # (## Support)

[//]: # (For onboarding, release questions, or support:)

[//]: # (**[add contact here]**)
