### AnyKernel3 Ramdisk Mod Script - POCO X5 5G (moonstone) on stock HyperOS
### dare-devil-ex "dinosaur" base + BakaSU + Droidspaces.
### Same install steps as the dinosaur zip: kernel to boot, dtbo erased,
### LineageOS dtb into vendor_boot (vendor ramdisk and its modules untouched).

### AnyKernel setup
properties() { '
kernel.string=dino-bakasu (BakaSU + Droidspaces) for stock HyperOS
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=moonstone
device.name2=sunstone
device.name3=stone
device.name4=gemstone
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=auto;
NO_BLOCK_DISPLAY=1;
RAMDISK_COMPRESSION=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

ui_print " " "Installing kernel to boot...";
# boot install: only the kernel changes; the ramdisk (and OrangeFox / root
# already in it) stays.
split_boot;
flash_boot;
## end boot install

ui_print "Erasing dtbo (as the dinosaur zip does)...";
dtbo_blk=/dev/block/by-name/dtbo$SLOT;
if [ -b "$dtbo_blk" ]; then
  dd if=/dev/zero of=$dtbo_blk conv=fsync count=1 bs=$(blockdev --getsize64 $dtbo_blk);
else
  ui_print "  dtbo$SLOT not found, skipped";
fi;

ui_print "Installing dtb to vendor_boot...";
BLOCK=vendor_boot;

# reset for vendor_boot patching
reset_ak;

# IR blaster: same rule as the dinosaur zip. If the vendor ships the
# consumerir HAL, use the dtb whose irled node says "ir-spi".
grep -q "/vendor " /proc/mounts || mount /vendor 2>/dev/null;
if [ -e /vendor/lib64/hw/consumerir.default.so -o -e /vendor/lib64/hw/consumerir.holi.so ]; then
  if [ -f $AKHOME/alt/dtb-ir-spi ]; then
    cp -f $AKHOME/alt/dtb-ir-spi $AKHOME/dtb;
    ui_print "  consumerir HAL found: irled compatible = ir-spi";
  fi;
fi;

# vendor_boot install: only the dtb changes
split_boot;
flash_boot;
## end vendor_boot install

ui_print " " "Done. Reboot to system.";
