#!/bin/bash
cp ~/android/lineage/out/target/product/foster_tab/boot.img ~/switchroot-script-builder/magisk
./boot_patch.sh boot.img
mv new-boot.img boot_patched.img && cp boot_patched.img ../../../../android/output/switchroot/install/boot.img
rm -rf boot.img boot_patched.img
./cleanup.sh
