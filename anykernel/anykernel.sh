### AnyKernel3 Ramdisk Mod Script
## stone-kernel-ci: replaces only the kernel Image in boot (boot header v3/v4 devices
## keep ramdisk + dtb in vendor_boot, so nothing else is touched)

properties() { '
kernel.string=__KERNEL_STRING__
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;

split_boot;
flash_boot;
