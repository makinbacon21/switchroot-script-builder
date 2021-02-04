#!/bin/bash

# get current working directory
CWD=$(pwd)
if [ -z "$BUILDBASE" ];
then
	BUILDBASE=~
fi

# get json object
PATCHJSON=$(curl -s https://raw.githubusercontent.com/makinbacon21/resources/main/script-builder/patchdefs.json)

# detect WSL
if [ -d /run/WSL ];
then
	WSL=true
fi

# arguments
for arg in "$@"
do
    if [ "$arg" == "--verbose" ] || [ "$arg" == "-v" ];
    then
        echo "Verbose mode enabled."
		VERBOSE=true
		set -x
    fi
	if [ "$arg" == "--nosync" ] || [ "$arg" == "-n" ];
    then
        echo "No-Sync mode enabled."
		NOSYNC=true
    fi
	if [ "$arg" == "--clean" ] || [ "$arg" == "-c" ];
    then
        echo "Clean mode enabled."
		if [ $NOSYNC ];
		then
			echo "Clean and No-Sync modes are incompatible...assuming Clean."
			NOSYNC=false
		fi
		CLEAN=true
  	fi
  	if [ "$arg" == "--update" ] || [ "$arg" == "-u" ];
    then
    	echo "Update mode enabled."
		UPDATE=true
    fi
	if [ "$arg" == "--noccache" ] || [ "$arg" == "-e" ];
    then
        echo "CCache disabled."
		NOCCACHE=true
    fi
	if [ "$arg" == "--help" ] || [ "$arg" == "-h" ];
    then
		# long-winded help message
    	printf "\nWelcome to Switchroot Script Builder!\nThe current version of Switchroot Android is Q (10), based on LineageOS 17.1.\n\n"
		printf "USAGE: ./Q_Builder.sh [-v | --verbose] [-n | --nosync] [-c | --clean] [-e | --noccache] [-h | --help]\n"
		printf -- "-v | --verbose\t\tActivates verbose mode\n"
		printf -- "-n | --nosync\t\tDisables repo syncing and git cleaning and just forces a direct rebuild\n"
		printf -- "-c | --clean\t\tForces a clean build--deletes BUILDBASE/android and redownloads sources\n"
		printf -- "-u | --update\t\tForces an update build--only keeps the boot.img, DTB file, and LineageOS flashable zip\n"
		printf -- "-e | --noccache\t\tNOT RECOMMENDED--disables using CCache for building, which reduces storage consumption but can have unintended consequences\n\n"
		printf "MORE INFO:\n\nExport the BUILDBASE environment variable as the directory you want to build in\nEXAMPLE: export BUILDBASE=/home/tmakin\n"
		printf "WSL2 users should note that NTFS sucks and ext4 is recommended, and mounting an external NTFS drive is supported in newer Insider Dev Channel builds\nFor more info, see https://docs.microsoft.com/en-us/windows/wsl/wsl2-mount-disk\n\n"
		
		# force exit on fail
		exit -1
    fi
done

# backup files based on patch file. usage e.g.) backup_original /location/to/patch/patchname.patch
backup_original() {
	for UNPATCHEDFILES in $(cat $1 | grep -o -P '(?<=diff --git a/).*(?= b/)') ; do
    	cp $UNPATCHEDFILES $UNPATCHEDFILES.bak
	done
}

# restore backuped files based on patch file. usage e.g.) restore_original /location/to/patch/patchname.patch
restore_original() {
	for PATCHEDFILES in $(cat $1 | grep -o -P '(?<=diff --git a/).*(?= b/)') ; do
    	[ -f $(echo $PATCHEDFILES).bak ] && rm -Rf $PATCHEDFILES && mv $PATCHEDFILES.bak $PATCHEDFILES
	done
}

# apply optional patches based on json in repo
apply_patches() {
	# Create a nested function that will be reused multiple time during main function
	do_patching() {

		# Create a counter to avoid exceeding array length
		PATCH_COUNT=0

		# Iterate over patches
		for PATCH in ${PATCHES[@]}; do

			# Go to patch directory
			cd "$BUILDBASE/android/lineage/$(jq -r '.patches[].'$key'['$PATCH_COUNT'].path' $PATCHJSON)"

			# Increment counter
			PATCH_COUNT=$((PATCH_COUNT++))

			# If patch begins with https then curl the patch otherwise apply
			if [[ "${PATCH}" =~ "^https.*" ]]; then
				curl -s ${PATCH} | patch -p1
			else
				patch -p1 < $BUILDBASE/android/lineage/${PATCH}
			fi
		done
	}

 	for key in $(jq -r '.patches[]' $PATCHJSON | jq -r 'keys[]'); do

		# Create our prompt
		PS3="Do you want to apply the $key patch (y|n)? :"

		select answer in yes no; do
			if [[ $answer == "yes" ]]; then
				# Store patches into an array
				PATCHES=($((jq -r '.patches[].'$key'[].patch | @sh' $PATCHJSON) | tr -d \'\")) # Store patches into an array
				do_patching
			else
				echo -e "\nYou chose not to apply $key patch !"
			fi
			break
		done
	done
}

# repopick commits based on json in repo
repopick_commits() {

	# Create a counter to keep track of picks
	PICK_COUNT=0

	# Iterate over patches
	for key in $(jq -r '.repopicks[]' $PATCHJSON | jq -r 'keys[]'); do

		# Increment counter
		if [[ $(jq -r '.repopicks[PICK_COUNT].isNamed | @sh' $PATCHJSON) == "\"y\"" ]]; then
			${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t ${key}
		else
			${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py ${key}
		fi
		PICK_COUNT=$((PICK_COUNT++))
	done
}

cd $BUILDBASE

# get threads for tasks
JOBS=$(($(nproc) + 1))

# rom type?
while true; do
    read -p "Do ya want icosa (i) or foster_tab (m) or android tv (t)?" imt
    case $imt in
        [Ii]* ) FOSTERTYPE=i; break;;
        [Mm]* ) FOSTERTYPE=m; break;;
        [Tt]* ) FOSTERTYPE=t; break;;
        * ) echo "Please answer y or n.";;
    esac
done

# download gapps?
while true; do
    read -p "Do ya want to download OpenGApps (y/n)?" yn
    case $yn in
        [Yy]* ) GAPPS=y; break;;
        [Nn]* ) GAPPS=n; break;;
        * ) echo "Please answer y or n.";;
    esac
done

# download hekate?
while true; do
    read -p "Do ya want download and set up hekate (y/n)?" yn
    case $yn in
        [Yy]* ) HEKATE=y; break;;
        [Nn]* ) HEKATE=n; break;;
        * ) echo "Please answer y or n.";;
    esac
done

# root?
while true; do
    read -p "Do ya want your device rooted (patch for Magisk) (y/n)?" yn
    case $yn in
        [Yy]* ) MAGISK=y; break;;
        [Nn]* ) MAGISK=n; break;;
        * ) echo "Please answer y or n.";;
    esac
done

# prompt for root and install necessary packages
sudo apt update
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf 
> imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev 
> libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc 
> zip zlib1g-dev python python3 binfmt-support qemu qemu-user-static repo qemu-user qemu-user-static 
> gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu binutils-aarch64-linux-gnu-dbg build-essential jq
sudo apt -y upgrade

# check to see if git is configured, if not prompt user
if [[ "$(git config --list)" != *"user.email"* ]];
then
	read -p "Enter your git email address: " GITEMAIL
	read -p "Enter your name: " GITNAME
	git config --global user.email $GITEMAIL
	git config --global user.name $GITNAME
fi

# clean build?
if [ ! -z $CLEAN ];
then
	echo "Cleaning android folder..."
	rm -rf $BUILDBASE/android
fi

# check for android
if [ ! -d $BUILDBASE/android ]; 
then
	# clean, download, and unzip latest platform tools
	rm -rf platform-tools-latest-linux.zip
	rm -rf platform-tools-latest-linux.zip.*
	rm -rf platform-tools
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
	unzip platform-tools-latest-linux.zip
	cd $BUILDBASE

	# check for platform tools in PATH, add if missing
	if ! grep -q "PATH=\"\$HOME/platform-tools:\$PATH\"" ~/.profile ; 
    then
		echo "if [ -d \"\$HOME/platform-tools\" ] ; then" >> ~/.profile
		echo "    PATH=\"\$HOME/platform-tools:\$PATH\"" >> ~/.profile
		echo "fi" >> ~/.profile
	fi
	
	# create directories and get repo
	mkdir -p ~/bin
	mkdir -p $BUILDBASE/android/lineage

	# check for missing case sensitivity (assume WSL) and fix if not
	if [ ! -z $WSL ];
	then
		cd $CWD
		powershell.exe -File "./wsl_cs.ps1" -Buildbase "$BUILDBASE"
	fi

	curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
	chmod a+x ~/bin/repo
	
	# check for bin in PATH, add if missing
	if ! grep -q "PATH=\"\$HOME/bin:\$PATH\"" ~/.profile ; 
    then
		echo "if [ -d \"\$HOME/bin\" ] ; then" >> ~/.profile
		echo "    PATH=\"\$HOME/bin:\$PATH\"" >> ~/.profile
		echo "fi" >> ~/.profile
	fi

	# initialize repo, sync
	cd $BUILDBASE/android/lineage
	repo init -u https://github.com/LineageOS/android.git -b lineage-17.1
	repo sync --force-sync -j${JOBS}
	cd ./.repo
	git clone https://gitlab.com/switchroot/android/manifest.git -b lineage-17.1 local_manifests
	repo sync --force-sync -j${JOBS}

	# repopick and apply patches
	apply_patches

# check if syncing
elif [ -z $NOSYNC ];
then
	cd $BUILDBASE/android/lineage
	repo forall -c 'git reset --hard'
	repo forall -c 'git clean -fdd'
	cd .repo/local_manifests
	git pull
	cd $BUILDBASE/android/lineage
	repo sync --force-sync -j${JOBS}

	# restore backuped files
    cd $BUILDBASE/android/lineage/kernel/nvidia/linux-4.9/kernel/kernel-4.9
	restore_original $CWD/patches/oc-android10.patch

    cd $BUILDBASE/android/lineage/device/nvidia/foster
	restore_original $CWD/patches/oc_profiles.patch

    cd $BUILDBASE/android/lineage/hardware/nintendo/joycond
	restore_original $CWD/patches/joycond10.patch

    cd $BUILDBASE

	# repopick and apply patches
	apply_patches
fi

# reset back to lineage directory
cd $BUILDBASE/android/lineage

# ccache
if [ -z $NOCCACHE ];
then
	export USE_CCACHE=1
	export CCACHE_EXEC="/usr/bin/ccache"
	export WITHOUT_CHECK_API=true
	ccache -M 50G
else
	export USE_CCACHE=0
fi

### Rebuild (clean)
mkdir -p $BUILDBASE/android/lineage/out/target/product/$OUTPUTFILE/vendor/lib/modules
source build/envsetup.sh

# check rom type and assign gapps type and rom type
if [ $FOSTERTYPE = "i" ];
then
	TYPE="pico"
	OUTPUTFILE="icosa"
	lunch lineage_icosa-userdebug
elif [ $FOSTERTYPE = "m" ];
then
	TYPE="pico"
	OUTPUTFILE="foster_tab"
	lunch lineage_foster_tab-userdebug
else
	TYPE="tvmini"
	OUTPUTFILE="foster"
	lunch lineage_foster-userdebug	
fi

make -j${JOBS} bacon

## This script copies the build output to the output dir
## so it can be used by hekate

cd ${BUILDBASE}

ZIP_FILE=$(ls -rt ${BUILDBASE}/android/lineage/out/target/product/$OUTPUTFILE/lineage-17.1-*-UNOFFICIAL-$OUTPUTFILE.zip | tail -1)

## Copy to output
echo "Creating switchroot install dir..."
mkdir -p $BUILDBASE/android/output/switchroot/install

if [ -z $UPDATE ]; then
	echo "Creating switchroot android dir..."
	mkdir -p $BUILDBASE/android/output/switchroot/android
fi

if [ $HEKATE = "y" ];
	then
	echo "Downloading hekate..."
	LATEST_HEKATE=$(curl -sL https://github.com/CTCaer/hekate/releases/latest | grep -o '/CTCaer/hekate/releases/download/.*/hekate_ctcaer.*zip')
	curl -L -o ./hekate.zip https://github.com/$LATEST_HEKATE
	unzip -u ./hekate.zip -d $BUILDBASE/android/output/
	echo "Creating bootloader config dir..."
	mkdir -p $BUILDBASE/android/output/bootloader/ini
	echo "Downloading 00-android.ini..."
	curl -L -o $BUILDBASE/android/output/bootloader/ini/00-android.ini https://gitlab.com/ZachyCatGames/shitty-pie-guide/-/raw/master/res/00-android.ini?inline=false
fi

echo "Copying build zip to SD Card..."
cp $ZIP_FILE $BUILDBASE/android/output/
echo "Copying build combined kernel and ramdisk..."
cp $BUILDBASE/android/lineage/out/target/product/$OUTPUTFILE/boot.img $BUILDBASE/android/output/switchroot/install/
echo "Copying build dtb..."
cp $BUILDBASE/android/lineage/out/target/product/$OUTPUTFILE/obj/KERNEL_OBJ/arch/arm64/boot/dts/tegra210-icosa.dtb $BUILDBASE/android/output/switchroot/install/

if [ -z $UPDATE ]; then
	echo "Downloading twrp..."
	curl -L -o $BUILDBASE/android/output/switchroot/install/twrp.img https://github.com/PabloZaiden/switchroot-android-build/raw/master/external/twrp.img
	echo "Downloading coreboot.rom..."
	# oc coreboot check
	if [ $MEMOC = "y" ];
	then
		curl -L -o $BUILDBASE/android/output/switchroot/android/coreboot.rom https://github.com/PabloZaiden/switchroot-android-build/raw/5591127dc4b9ef3ed1afb0bb677d05108705caa5/external/coreboot-oc.rom
		zip -u $BUILDBASE/android/output/switchroot/android/coreboot.rom $OUTPUT_ZIP_FILE firmware-update/coreboot.rom
	else
		curl -L -o $BUILDBASE/android/output/switchroot/android/coreboot.rom https://github.com/PabloZaiden/switchroot-android-build/raw/5591127dc4b9ef3ed1afb0bb677d05108705caa5/external/coreboot.rom
	fi
fi

if [ $UPDATE = "false" ]; then
	echo "Downloading boot scripts..."
	curl -L -o $BUILDBASE/android/output/switchroot/android/common.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/common.scr?job=build
	curl -L -o $BUILDBASE/android/output/switchroot/android/boot.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/sd.scr?job=build
fi

if [ $GAPPS = "y" ];
then
	echo "Downloading Pico Open GApps..."

	# get base URL for pico gapps	
	BASE_GAPPS_URL=$(curl -L https://sourceforge.net/projects/opengapps/rss?path=/arm64 \
			| grep -Po "https:\/\/.*10\.0-${TYPE}.*zip\/download" \
			| head -n 1 \
			| sed "s/\/download//" \
			| sed "s/files\///" \
			| sed "s/projects/project/" \
			| sed "s/sourceforge/downloads\.sourceforge/")

	TIMESTAMP=$(echo $(( $(date '+%s%N') / 1000000000)))
	FULL_GAPPS_URL=$(echo $BASE_GAPPS_URL"?use_mirror=autoselect&ts="$TIMESTAMP)
	curl -L -o $BUILDBASE/android/output/opengapps_${TYPE}.zip $FULL_GAPPS_URL
fi

## Patch zip file to accept any bootloader version
OUTPUT_ZIP_FILE=$(ls -rt ${BUILDBASE}/android/output/lineage-17.1-*-UNOFFICIAL-${OUTPUTFILE}.zip | tail -1)

mkdir -p ./META-INF/com/google/android/
unzip -p $OUTPUT_ZIP_FILE META-INF/com/google/android/updater-script > ./META-INF/com/google/android/updater-script.original
sed -E 's/getprop\(\"ro\.bootloader\"\)/true || getprop\(\"ro\.bootloader\"\)/g' < ./META-INF/com/google/android/updater-script.original > ./META-INF/com/google/android/updater-script
rm ./META-INF/com/google/android/updater-script.original
zip -u $OUTPUT_ZIP_FILE META-INF/com/google/android/updater-script
rm -rf ./META-INF/com/google/android/

# Magisk pre-rooting
if [ $MAGISK = "y" ];
then	
	cd $BUILDBASE
	
	# get magisk
	LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/topjohnwu/Magisk/releases/latest)
	LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
	if [[ "$LATEST_VERSON" == "manager"* ]];
	then
		LATEST_VERSION=v21.4
	fi
	MAGISK_URL="https://github.com/topjohnwu/Magisk/releases/download/${LATEST_VERSION}/Magisk-${LATEST_VERSION}.zip"
	wget $MAGISK_URL

	# clean folder, unpack magisk zip, and move all required files to arm folder
	rm -rf $BUILDBASE/magisk
	mkdir $BUILDBASE/magisk
	unzip Magisk-$LATEST_VERSION.zip -d $BUILDBASE/magisk
	cd $BUILDBASE/magisk
	cp common/* arm/
	mv $BUILDBASE/android/output/switchroot/install/boot.img $BUILDBASE/magisk/arm/boot.img
	cd $BUILDBASE/magisk/arm
	mv magiskinit magiskinit32
	mv magiskinit64 magiskinit

	# patch and replace boot.img
	bash ./boot_patch.sh boot.img
	mv new-boot.img $BUILDBASE/android/output/switchroot/install/boot.img

	# zip patched boot.img into lineage zip
	cd $BUILDBASE/android/output/switchroot/install/
	zip -u $OUTPUT_ZIP_FILE boot.img
fi

if [ ! -z $WSL ]; then
	mv $BUILDBASE/android/output $CWD
fi
