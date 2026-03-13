# Config Files

This directory contains example external configuration files used by Money Printer.

The main config file, `mpconfig.example.toml`, can reference these files through the `[external_config]` section. In a typical setup, you copy these examples, adjust them for your environment, and rename them to the paths used by your final `mpconfig.toml`.

These files also exist to fit more easily into operators' existing workflows, automation, and deployment habits, especially for users who already manage external market, LUT, and runtime tuning files for other bots.

When external config is enabled, Money Printer checks these files at runtime and reloads updated contents without requiring a full restart.

In addition, `mpconfig.toml` may reference values from `gas.json` by placeholder name instead of embedding literal values directly. For example, a setting in `mpconfig.toml` may use a value like `{enable_cu_limit}`, which is then resolved from the JSON file at runtime.

## Files

### `gas.example.json`

Runtime tuning and execution parameters.

This file contains hot-reloadable values such as:
- compute unit limit
- priority fee ranges
- sender enable or disable flags
- cooldown values
- tip ranges for supported delivery paths

Use this file to tune execution behavior without rewriting the main config.

### `markets.example.toml`

Market universe definition.

This file tells the bot which pools or markets to monitor and use for route construction. Markets are grouped in TOML format under `[[group]]`.

Use this file to control the set of venues and pairs the bot will operate on.

### `lut.example.txt`

Address Lookup Table list.

This file contains one LUT address per line. LUTs are used to reduce transaction size and allow larger account sets to fit into Solana transactions.

Use this file to provide the lookup tables the bot should load and consider during transaction building.

## Typical Usage

A common setup is to copy these files and rename them to:

- `gas.json`
- `markets.toml`
- `lut.txt`

Then point your `mpconfig.toml` to those paths under `[external_config]`.

## Notes

- These files are examples, not universal defaults.
- Values should be reviewed and adjusted for your own environment.
- Runtime-reload behavior depends on using external config through `[external_config]`.
- Performance depends heavily on market selection, fee settings, and infrastructure quality.
