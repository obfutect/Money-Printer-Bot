# Launcher

This folder contains the `mp.sh` launcher script for `money-printer`.

Use this script as the standard way to run the bot from a release package.

It can:
- download or update the `money-printer` binary from the latest GitHub release
- start the bot with your chosen command-line arguments
- stop the currently running bot instance

Typical usage:

```bash
./mp.sh start --server
./mp.sh stop
```

If the first argument starts with `-`, the script treats the call as `start` automatically:

```bash
./mp.sh --server
```

The launcher keeps the binary, PID file, version file, and log file in this folder.
