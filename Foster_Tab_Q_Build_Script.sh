#!/bin/bash

# get threads for tasks
JOBS=$(($(nproc) + 1))

# prompt for root and install necessary packages
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf 
> imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev 
> libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc 
> zip zlib1g-dev

# rom type?
read -p "Do ya want android (t) or android tv (f)? " FOSTERTYPE

# check to see if git is configured, if not prompt user
if ["$(git config --list)" != *"user.email"*] 
then
	read -p "Enter your git email address: " GITEMAIL
	read -p "Enter your name: " GITNAME
	git config --global user.email $GITEMAIL
	git config --global user.name $GITNAME
fi

# clean build?
if [ ! -d ./android ]; 
then
	# download and unzip latest platform tools
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
	unzip platform-tools-latest-linux.zip -d ~
	cd ../

	# check for platform tools in PATH, add if missing
	if ! grep -q "PATH=\"$HOME/platform-tools:$PATH\"" "~/.profile" ; 
    then
		echo "if [ -d \"$HOME/platform-tools\" ] ; then" >> ~/.profile
		echo "    PATH=\"$HOME/platform-tools:$PATH\"" >> ~/.profile
		echo "fi" >> ~/.profile
	fi
	
	# create directories and get repo
	mkdir -p ~/bin
	mkdir -p ~/android/lineage
	curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
	chmod a+x ~/bin/repo
	
	# check for bin in PATH, add if missing
	if ! grep -q "PATH=\"$HOME/bin:$PATH\"" "~/.profile" ; 
    then
		echo "if [ -d \"$HOME/bin\" ] ; then" >> ~/.profile
		echo "    PATH=\"$HOME/bin:$PATH\"" >> ~/.profile
		echo "fi" >> ~/.profile
	fi

	# initialize repo, sync
	cd ~/android/lineage
	repo init -u https://github.com/LineageOS/android.git -b lineage-17.1
	repo sync --force-sync -j${JOBS}
	git clone https://gitlab.com/switchroot/android/manifest.git -b lineage-17.1 .repo/local_manifests
fi

# update stuff (used for clean too but kinda unnecessary)
cd ~/android/lineage
repo forall -c 'git reset --hard'
repo forall -c 'git clean -fdd'
cd .repo/local_manifests
git pull
cd ../../
repo sync --force-sync -j${JOBS}
./build/envsetup.sh

# repopicks
repopick -t nvidia-enhancements-q
repopick -t nvidia-nvgpu-q
repopick -t nvidia-shieldtech-q
repopick -t icosa-bt-lineage-17.1
repopick 287339
repopick 284553

# patch bionic_intrinsics, nvcpl, oc, joycond, and foster
cd bionic
patch -p1 < ../.repo/local_manifests/patches/bionic_intrinsics.patch
cd ../frameworks/base
patch -p1 < ../../.repo/local_manifests/patches/frameworks_base_nvcpl.patch
cd ../../kernel/nvidia/linux-4.9/kernel/kernel-4.9
patch -p1 < ../../../../../.repo/local_manifests/patches/oc-android10.patch
cd ~/android/lineage/hardware/nintendo/joycond
patch -p1 < ../../../.repo/local_manifests/patches/joycond10.patch
wget -O .repo/android_device_nvidia_foster.patch https://gitlab.com/ZachyCatGames/q-tips-guide/-/raw/master/res/android_device_nvidia_foster.patch
cd ~/android/lineage/device/nvidia/foster
rm patch -p1 < ../../../.repo/android_device_nvidia_foster.patch
patch -p1 < ../../../.repo/android_device_nvidia_foster.patch
cd ../../../

# ccache
export USE_CCACHE=1
export CCACHE_EXEC="/usr/bin/ccache"
export WITHOUT_CHECK_API=true
ccache -M 50G

### Rebuild (clean)
mkdir -p ./out/target/product/$OUTPUTFILE/vendor/lib/modules
sh ./build/envsetup.sh

# check rom type and assign gapps type and rom type
if [$FOSTERTYPE == "t"];
then
	TYPE = "tvstock"
	OUTPUTFILE = "foster"
	lunch lineage_foster-userdebug
else
	TYPE = "pico"
	OUTPUTFILE = "foster_tab"
	lunch lineage_foster_tab-userdebug
fi
make -j${JOBS} bacon

## This script copies the build output to the output dir
## so it can be used by hekate

cd ${BUILDBASE}

ZIP_FILE=$(ls -rt ~/android/lineage/out/target/product/$OUTPUTFILE/lineage-17.1-*-UNOFFICIAL-$OUTPUTFILE.zip | tail -1)

## Copy to output
echo "Creating switchroot install dir..."
mkdir -p ./android/output/switchroot/install
echo "Creating switchroot android dir..."
mkdir -p ./android/output/switchroot/android
echo "Downloading hekate..."
LATEST_HEKATE=$(curl -sL https://github.com/CTCaer/hekate/releases/latest | grep -o '/CTCaer/hekate/releases/download/.*/hekate_ctcaer.*zip')
curl -L -o ./hekate.zip https://github.com/$LATEST_HEKATE
unzip -u ./hekate.zip -d ./android/output/
echo "Creating bootloader config dir..."
mkdir -p ./android/output/bootloader/ini
echo "Copying build zip to SD Card..."
cp $ZIP_FILE ~/android/output/
echo "Copying build combined kernel and ramdisk..."
cp ~/android/lineage/out/target/product/$OUTPUTFILE/boot.img ./android/output/switchroot/install/
echo "Copying build dtb..."
cp ~/android/lineage/out/target/product/$OUTPUTFILE/obj/KERNEL_OBJ/arch/arm64/boot/dts/tegra210-icosa.dtb ./android/output/switchroot/install/
echo "Downloading twrp..."
curl -L -o ~/android/output/switchroot/install/twrp.img https://github.com/PabloZaiden/switchroot-android-build/raw/master/external/twrp.img
echo "Downloading coreboot.rom..."
curl -L -o ~/android/output/switchroot/android/coreboot.rom https://github.com/PabloZaiden/switchroot-android-build/raw/master/external/coreboot.rom
echo "Downloading 00-android.ini..."
curl -L -o ~/android/output/bootloader/ini/00-android.ini https://gitlab.com/ZachyCatGames/shitty-pie-guide/-/raw/master/res/00-android.ini?inline=false
echo "Downloading boot scripts..."
curl -L -o ~/android/output/switchroot/android/common.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/common.scr?job=build
curl -L -o ~/android/output/switchroot/android/boot.scr https://gitlab.com/switchroot/bootstack/switch-uboot-scripts/-/jobs/artifacts/master/raw/sd.scr?job=build
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
curl -L -o ./android/output/opengapps_${TYPE}.zip $FULL_GAPPS_URL

## Patch zip file to accept any bootloader version
OUTPUT_ZIP_FILE=$(ls -rt ~/android/output/lineage-17.1-*-UNOFFICIAL-${OUTPUTFILE}.zip | tail -1)

mkdir -p ./META-INF/com/google/android/
unzip -p $OUTPUT_ZIP_FILE META-INF/com/google/android/updater-script > ./META-INF/com/google/android/updater-script.original
sed -E 's/getprop\(\"ro\.bootloader\"\)/true || getprop\(\"ro\.bootloader\"\)/g' < ./META-INF/com/google/android/updater-script.original > ./META-INF/com/google/android/updater-script
rm ./META-INF/com/google/android/updater-script.original
zip -u $OUTPUT_ZIP_FILE META-INF/com/google/android/updater-script
rm -rf ./META-INF/com/google/android/

