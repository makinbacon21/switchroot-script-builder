#!/bin/bash

# get current working directory
CWD=$(pwd)
if [ -z "$BUILDBASE" ];
then
	BUILDBASE=~
fi

cd $BUILDBASE

# get threads for tasks
JOBS=$(($(nproc) + 1))

# prompt for root and install necessary packages
sudo apt update
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf 
> imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev 
> libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc 
> zip zlib1g-dev python python3 binfmt-support qemu qemu-user-static repo

# rom type?
while true; do
    read -p "Do ya want icosa (i) or foster_tab (m) or android tv (t)?" imt
    case $imt in
        [Ii]* ) FOSTERTYPE=i; break;;
        [Mm]* ) FOSTERTYPE=m; break;;
        [Tt]* ) FOSTERTYPE=t; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# oc coreboot?
while true; do
    read -p "Do ya want an 1862 MHz memory OC (y/n)?" yn
    case $yn in
        [Yy]* ) MEMOC=y; break;;
        [Nn]* ) MEMOC=n; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# oc patch?
while true; do
    read -p "Do ya want a 2091 MHz CPU OC (y/n)?" yn
    case $yn in
        [Yy]* ) CPUOC=y; break;;
        [Nn]* ) CPUOC=n; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# joycon-swap?
while true; do
    read -p "Do ya want the joycon trigger patch (y/n)?" yn
    case $yn in
        [Yy]* ) JCPATCH=y; break;;
        [Nn]* ) JCPATCH=n; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# root?
while true; do
    read -p "Do ya want your device rooted (patch for Magisk) (y/n)?" yn
    case $yn in
        [Yy]* ) MAGISK=y; break;;
        [Nn]* ) MAGISK=n; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# check to see if git is configured, if not prompt user
if [[ "$(git config --list)" != *"user.email"* ]];
then
	read -p "Enter your git email address: " GITEMAIL
	read -p "Enter your name: " GITNAME
	git config --global user.email $GITEMAIL
	git config --global user.name $GITNAME
fi

# clean build?
if [ ! -d $BUILDBASE/android ]; 
then
	# download and unzip latest platform tools
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
	unzip platform-tools-latest-linux.zip -d ~
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
	if [ -d ~/Bin ];
	then
		cd $CWD
		powershell.exe -File "./wsl_cs.ps1" -Buildbase "~"
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
else
	cd $BUILDBASE/android/lineage
	repo forall -c 'git reset --hard'
	repo forall -c 'git clean -fdd'
	cd .repo/local_manifests
	git pull
	cd $BUILDBASE/android/lineage
	repo sync --force-sync -j${JOBS}
fi

# update stuff (used for clean too but kinda unnecessary)
cd $BUILDBASE/android/lineage
source build/envsetup.sh

# repopicks
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t nvidia-enhancements-q
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t icosa-bt-lineage-17.1
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t nvidia-nvgpu-q
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t nvidia-shieldtech-q
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py -t nvidia-beyonder-q
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py 287339
${BUILDBASE}/android/lineage/vendor/lineage/build/tools/repopick.py 284553

# bionic intrinsics patch
cd $BUILDBASE/android/lineage/bionic
patch -p1 < $BUILDBASE/android/lineage/.repo/local_manifests/patches/bionic_intrinsics.patch

# beyonder fix patch
cd $BUILDBASE/android/lineage/device/nvidia/foster_tab
patch -p1 < $BUILDBASE/android/lineage/.repo/local_manifests/patches/device_nvidia_foster_tab-beyonder.patch

# mouse patch
cd $BUILDBASE/android/lineage/frameworks/native
patch -p1 < $BUILDBASE/android/lineage/.repo/local_manifests/patches/frameworks_native-mouse.patch

# cpu oc patch
if [ $CPUOC = "y" ];
then
	cd $BUILDBASE/android/lineage/kernel/nvidia/linux-4.9/kernel/kernel-4.9
	patch -p1 < $CWD/patches/oc-android10.patch
	cd $BUILDBASE/android/lineage/device/nvidia/foster
        patch -p1 < $CWD/patches/oc_profiles.patch
fi

# joycon patch
if [ $JCPATCH = "y" ];
then
	cd $BUILDBASE/android/lineage/hardware/nintendo/joycond
	patch -p1 < $CWD/patches/joycond10.patch
fi

# patch to support old TWRP
cd $BUILDBASE/android/lineage/device/nvidia/foster
git revert 0e1c660d -n

# reset back to lineage directory
cd $BUILDBASE/android/lineage

# ccache
export USE_CCACHE=1
export CCACHE_EXEC="/usr/bin/ccache"
export WITHOUT_CHECK_API=true
ccache -M 50G

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
echo "Creating switchroot android dir..."
mkdir -p $BUILDBASE/android/output/switchroot/android
echo "Downloading hekate..."
LATEST_HEKATE=$(curl -sL https://github.com/CTCaer/hekate/releases/latest | grep -o '/CTCaer/hekate/releases/download/.*/hekate_ctcaer.*zip')
curl -L -o ./hekate.zip https://github.com/$LATEST_HEKATE
unzip -u ./hekate.zip -d $BUILDBASE/android/output/
echo "Creating bootloader config dir..."
mkdir -p $BUILDBASE/android/output/bootloader/ini
echo "Copying build zip to SD Card..."
cp $ZIP_FILE $BUILDBASE/android/output/
echo "Copying build combined kernel and ramdisk..."
cp $BUILDBASE/android/lineage/out/target/product/$OUTPUTFILE/boot.img $BUILDBASE/android/output/switchroot/install/
echo "Copying build dtb..."
cp $BUILDBASE/android/lineage/out/target/product/$OUTPUTFILE/obj/KERNEL_OBJ/arch/arm64/boot/dts/tegra210-icosa.dtb $BUILDBASE/android/output/switchroot/install/
echo "Downloading twrp..."
curl -L -o $BUILDBASE/android/output/switchroot/install/twrp.img https://github.com/PabloZaiden/switchroot-android-build/raw/master/external/twrp.img
echo "Downloading coreboot.rom..."

# oc coreboot check
if [ $MEMOC == "y" ];
then
	curl -L -o $BUILDBASE/android/output/switchroot/android/coreboot.rom https://github.com/PabloZaiden/switchroot-android-build/raw/5591127dc4b9ef3ed1afb0bb677d05108705caa5/external/coreboot-oc.rom
else
	curl -L -o $BUILDBASE/android/output/switchroot/android/coreboot.rom https://github.com/PabloZaiden/switchroot-android-build/raw/5591127dc4b9ef3ed1afb0bb677d05108705caa5/external/coreboot.rom
fi

echo "Downloading 00-android.ini..."
curl -L -o $BUILDBASE/android/output/bootloader/ini/00-android.ini https://gitlab.com/ZachyCatGames/shitty-pie-guide/-/raw/master/res/00-android.ini?inline=false
echo "Downloading boot scripts..."
curl -L -o $BUILDBASE/android/output/switchroot/android/common.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/common.scr?job=build
curl -L -o $BUILDBASE/android/output/switchroot/android/boot.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/sd.scr?job=build
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

	# patch and replace boot.img
	bash $CWD/magisk/boot_patch.sh $BUILDBASE/android/output/switchroot/install/boot.img
	cd $BUILDBASE/android/output/switchroot/install/
	rm boot.img
	mv $CWD/magisk/new-boot.img $BUILDBASE/android/output/switchroot/install/boot.img

	zip -u $OUTPUT_ZIP_FILE boot.img # zip patched boot.img into lineage zip
fi
