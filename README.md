# Switchroot Android R Scripted Builder
One script to rule them all

Automates the steps of the Rene-Guide (https://gitlab.com/makinbacon17/rene-guide/)

DISCLAIMER: Switchroot Android R is in VERY EARLY development and may harm your device--a public image release will come soon, but this script builds the early-stage product for testing purposes. The current public release (Switchroot Android 10) is available using this guide: https://forum.xda-developers.com/t/rom-unofficial-switchroot-android-10.4229761/

# Features
Supports Android (`icosa_sr`) and Android TV (`icosa_tv_sr`)

Clean build and updates

OC coreboot (memory overclock)

COMING SOON: OC patch (CPU)

Joycon patch (snapshot button takes screenshots)

GApps download

Option to preroot with magisk

# Requirements
Ubuntu 20.04+ (WSL2 works now on NTFS or ext4 filesystems, but NTFS is kinda slow and not recommended)

16GB RAM (or smaller amounts with a sizeable swapfile)

~300 GBs of available storage (sources + ccache)

Decent CPU (better CPU --> faster build)

Unpatched Erista-codenamed Nintendo Switch (https://ismyswitchpatched.com/) with RCM jig to trigger exploit

# Building
Syntax: `./Q_Builder.sh [-v | --verbose] [-n | --nosync] [-c | --clean]`

- `-v | --verbose`: Enables verbose mode (`set -x`) for debugging
- `-n | --nosync`: Runs build without `git reset` or `repo sync` (keeps source tree from last build intact)
- `-c | --clean`: Forces clean build (removes source tree and builds from scratch)
- `-e | --noccache`: Disables CCache for building (NOT RECOMMENDED--MOSTLY FOR TESTING PURPOSES)
- `-h | --help`: Long-winded help message

First `chmod +x R_Builder.sh` to make it executable, thne run the script with `./R_Builder.sh` and any arguments, and answer any prompts you get. Once stuff starts happening, there shouldn't be any more prompts unless you screwed something up

# Credits
@Dajokeisonu for his direct contributions

@PabloZaiden for his work on the Dockerized build and the disgusting URL magic that has been performed to get GApps to work properly

@ZachyCatGames for his work on the original Q building instructions (Q-Tips Guide)

@Andrebraga for assisting PabloZaiden getting everything working in the Dockerized build.

@Biff627 for providing patches
