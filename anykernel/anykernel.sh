### AnyKernel3 Ramdisk Mod Script - Redmi Note 12 5G / POCO X5 5G (stone, moonstone, sunstone)
### Based on osm0sis' AnyKernel3 template

### AnyKernel setup
# global properties
properties() { '
kernel.string=stone custom kernel (@FEATURES@)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=moonstone
device.name2=sunstone
device.name3=stone
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
# Perangkat A/B dengan boot header v3: kernel ada di boot, DTB di vendor_boot.
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: hanya ganti kernel (Image), ramdisk dibiarkan
split_boot;
flash_boot;
## end boot install
