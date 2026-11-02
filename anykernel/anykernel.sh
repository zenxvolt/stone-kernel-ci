### AnyKernel3 Ramdisk Mod Script - Redmi Note 12 5G / POCO X5 5G, crDroid "stone"
### Berbasis template osm0sis AnyKernel3

### AnyKernel setup
# global properties
properties() { '
kernel.string=stone custom kernel (modular: BakaSU / Droidspaces / systemd / Anland)
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=stone
device.name2=moonstone
device.name3=sunstone
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
# stone = perangkat A/B: AnyKernel3 menentukan slot aktif sendiri (is_slot_device=auto).
BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: hanya ganti kernel (file Image), ramdisk yang ada dipertahankan.
# DTB ada di vendor_boot pada header boot v3/v4, jadi tidak ikut di zip ini.
split_boot;
flash_boot;
## end boot install
