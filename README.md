# stone-kernel-ci

CI untuk membangun kernel crDroid `stone` (Redmi Note 12 5G / POCO X5 5G, SM6375, Linux 5.4.302)
dengan fitur custom yang **bisa dipilih satu per satu**: root BakaSU, opsi kernel Droidspaces,
backport systemd, dan kompatibilitas Anland.

Repo ini tidak berisi kode kernel. Workflow mengambil kernel dari repo lain (upstream atau fork
kamu), menerapkan modul yang dicentang, membangun `Image`, lalu membuat zip AnyKernel3.
Turunan dari `rova-kernel-ci`, disesuaikan untuk kernel 5.4.

## Pakai
1. Tab **Actions** -> *Build kernel (stone, modular)* -> **Run workflow**.
2. Isi `kernel_repo` dan `kernel_branch`. Upstream stone saat ini hanya punya branch `16.0`
   (tidak ada `15.0`); kalau kamu punya fork dengan branch Android 15, isi di sini.
3. Centang modul yang mau dipakai (semua aktif secara default).
4. Unduh artifact `stone-kernel-zip`, backup boot, lalu flash lewat recovery.
   Isi zip juga memuat `build-info.txt` (modul, commit, clang).

Fork privat: tambahkan secret `KERNEL_REPO_TOKEN` (PAT dengan akses baca).

## Modul
| Modul | Isi | Catatan |
|---|---|---|
| `bakasu` | patch hook manual BakaSU (`exec`, `faccessat`, `stat`, `newfstat`, `fstat64`, `reboot`) + setup BakaSU + `CONFIG_KSU*` | stone tidak punya KernelSU bawaan, jadi patch hook ditulis ulang untuk 5.4 (rova hanya mengubah hook statis yang sudah ada) |
| `droidspaces` | opsi namespace, cgroup, veth/bridge, NAT, macvlan, IPv6/NAT66 + patch link cgroup NOPREFIX | patch cgroup di-port ke 5.4 (`legacy_name`) |
| `systemd` | backport VFS untuk guest systemd 260+ dan `FHANDLE`, `AUTOFS_FS`, `CRYPTO_USER_API_HASH` | hanya patch yang belum ada di tree; stone sudah punya `close_range`, jadi 0005 dan 0006 otomatis dilewati |
| `anland` | `DRM_VGEM` + `CHECKPOINT_RESTORE` (kcmp) | tidak butuh patch: `vgem` 5.4 dan driver msm sudah punya `DRIVER_RENDER` |

Perbedaan dari rova: patch `focaltech`, `mdss-pll`, dan `vgem render node` **tidak dipakai**.
Ketiganya khusus tree 4.19 msm8937 dan tidak relevan di stone.

Urutan penerapan ada di `modules/order.txt`. Opsi kustom milikmu sendiri taruh di
`configs/extra.config` (selalu di-merge paling akhir).

## Menambah modul
1. Buat `modules/<nama>/` berisi:
   - `module.conf` (`DESC`, `REQUIRES`, `CONFLICTS`, `WANT`, `WANT_NOT`)
   - `patches/*.patch` (opsional)
   - `<nama>.config` (opsional, fragment config)
   - `pre.sh` (opsional, dijalankan di root tree kernel sebelum patch)
   - `skip-if.txt` (opsional; `namapatch|file|regex`, patch dilewati bila regex sudah ada di file)
2. Tambahkan `<nama>` di `modules/order.txt`.
3. Tambahkan satu input boolean dan satu baris `add` di `.github/workflows/build-kernel.yml`.

Patch yang sudah ada di tree (dan tidak punya `skip-if`) dideteksi lewat `git apply -R --check`
dan dilewati tanpa membuat build gagal.

## Build lokal
```
export CI_META_DIR=$PWD/.build-meta BAKASU_REF=main
scripts/apply-modules.sh ~/kernel/stone bakasu,droidspaces,systemd,anland   # atau all / none
scripts/configure.sh ~/kernel/stone moonstone_defconfig configs/no-lto.config
scripts/verify-config.sh ~/kernel/stone/out/.config
cd ~/kernel/stone && . ~/stone-kernel-ci/scripts/env.sh && kmake -j"$(nproc)" Image
```

## Toolchain
Default memakai clang apt (Ubuntu 24.04, clang 18) dengan LTO, CFI, dan ShadowCallStack dimatikan
(`disable_lto`). Clang Ubuntu tidak punya CFI ignore list dan full LTO berat di runner GitHub.
Kalau kamu ingin LTO/CFI seperti defconfig aslinya, isi `clang_url` dengan tarball toolchain
AOSP/Neutron dan matikan `disable_lto`.

## Verifikasi di perangkat
```
su -c "droidspaces check"
su -c "zcat /proc/config.gz | grep -E 'KSU|MACVLAN|IP6_NF_NAT|FHANDLE|DRM_VGEM'"
ls -l /sys/class/drm /dev/dri
```
Syarat runtime systemd: Droidspaces harus lebih baru dari 7.1.0 (lihat `droidspaces-backports`).
Macvlan hanya berguna pada jaringan kabel (mis. Ethernet USB OTG), bukan Wi-Fi.

## Asumsi yang perlu kamu cek
- **Branch**: upstream hanya punya `16.0`. Kernel-nya sama-sama 5.4.302, tapi isi driver bisa beda
  dari build Android 15 yang kamu pakai sekarang.
- **Flash**: `anykernel.sh` mengganti kernel saja (`Image`), A/B otomatis, DTB dianggap ada di
  `vendor_boot` (boot header v3/v4). Kalau ROM kamu memakai boot image dengan DTB tergabung,
  ubah target build dan nama file di workflow.
- **Teruji di sandbox**: semua modul aktif, build penuh `Image` dengan clang 18.1.3 (sama dengan
  runner `ubuntu-24.04`) selesai tanpa error, 39 menit di 2 core. Cek hook BakaSU lolos.
- **Belum diuji di perangkat**: boot, root, dan container belum dites di hardware.
