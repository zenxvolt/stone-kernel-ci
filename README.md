# moonstone-hyperos-kernel-ci

Kernel untuk POCO X5 5G (moonstone) di **HyperOS stock**, dibangun dari kernel
"dinosaur" dare-devil-ex yang sudah terbukti boot di HyperOS, dengan:

- **BakaSU** (root) menggantikan KernelSU-Next
- **semua syarat Droidspaces** (wajib, recommended, dan opsional), kecuali
  cpu limit (`CFS_BANDWIDTH`) dan process limit (`CGROUP_PIDS`)
- **backport kernel untuk systemd 258–262**

## Cara kerja
- Config awal = config kernel dinosaur persis (`configs/dino_base.config`, diambil
  dari `Image` dinosaur via IKCONFIG). Fitur yang membuat build sebelumnya gagal boot
  (LTO, CFI, Shadow Call Stack, kprobes, vgem) tetap mati (`keep-dino-safe.config`).
- Compiler sama dengan dinosaur: AOSP clang r596125 (clang 22).
- Cara pasang sama dengan zip dinosaur: kernel ke `boot` (ramdisk/OrangeFox tetap),
  `dtbo` dikosongkan, dtb LineageOS ke `vendor_boot` (ramdisk vendor dan modulnya
  tidak disentuh), termasuk tambalan IR blaster.

## Build
Actions → *Build kernel* → **Run workflow**. Semua pilihan default sudah benar.
Hasil: artifact `moonstone-kernel-zip` (zip AnyKernel3).

Kalau hasil build tidak boot, matikan satu kelompok, build lagi, lalu tes:
`ds_network` → `ds_cgroup` → `ds_misc` → `systemd` → `bakasu`.
Dengan semua kelompok mati, isinya sama dengan dinosaur non-KSU yang sudah terbukti jalan.

## Flash
1. Backup `boot`, `vendor_boot`, `dtbo` (slot aktif) dan salin ke PC.
2. Flash zip lewat OrangeFox.
3. Kalau gagal boot: OrangeFox ikut tidak bisa dibuka (memakai kernel di `boot`).
   Pulihkan dari PC:
   ```
   fastboot getvar current-slot
   fastboot flash boot_a boot.emmc.win
   fastboot flash vendor_boot_a vendor_boot.emmc.win
   fastboot flash dtbo_a dtbo.emmc.win
   fastboot reboot
   ```

## Cek setelah boot
```
su -c "uname -r"            # 5.4.302-dino-bakasu
su -c "droidspaces check"
```
Dialog "There's an internal problem with your device" bisa muncul seperti di
dinosaur: config kernel tidak cocok dengan daftar syarat kernel (VINTF) di HyperOS.
Tekan OK, tidak berbahaya.

## Isi
- `patches/0001-remove-ksu-next-hooks.patch`: membuang hook KernelSU-Next dinosaur.
- `patches/0002-droidspaces-cgroup-prefix.patch`: patch cgroup Droidspaces.
- `patches/0003-bakasu-manual-hooks.patch`: hook manual BakaSU untuk 5.4.
- `patches/systemd/`: droidspaces-backports seri 5.4, patch 0001–0004.
- `configs/`: base dinosaur + fragment per kelompok.
- `anykernel/anykernel.sh`: skrip flash.
