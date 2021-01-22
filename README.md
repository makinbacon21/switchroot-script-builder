# Switchroot Android Q Script Builder
One script to rule them all

# Features
Supports Android (`icosa`) (`foster_tab`) and Android TV (`foster`)

Clean build and updates

OC coreboot (memory overclock)

OC patch (CPU)

Joycon patch (snapshot button takes screenshots)

GApps download

Option to preroot with magisk

# Requirements
Ubuntu 20.04+ (WSL2 works now on NTFS or ext4 filesystems)

16GB RAM (or smaller amounts with a sizeable swapfile)

~300 GBs of available storage

Decent CPU (better CPU --> faster build)

# Building
Syntax: `./Q_Builder.sh [-v | --verbose] [-n | --nosync] [-c | --clean]`

- `-v | --verbose`: Enables verbose mode (`set -x`) for debugging
- `-n | --nosync`: Runs build without `git reset` or `repo sync` (keeps source tree from last build intact)
- `-c | --clean`: Forces clean build (removes source tree and builds from scratch)
- `-e | --noccache`: Disables CCache for building (NOT RECOMMENDED--MOSTLY FOR TESTING PURPOSES)
- `-h | --help`: Long-winded help message

First `chmod +x Q_Builder.sh` to make it executable, thne run the script with `./Q_Builder.sh` and any arguments, and answer any prompts you get. Once stuff starts happening, there shouldn't be any more prompts unless you screwed something up

# Credits
@Dajokeisonu for his direct contributions

@PabloZaiden for his work on the Dockerized build and the disgusting URL magic that has been performed to get GApps to work properly

@ZachyCatGames for his work on the original Q building instructions (Q-Tips Guide)

@Andrebraga for assisting PabloZaiden getting everything working in the Dockerized build.

@Biff627 for providing patches
