# stone-kernel-ci

CI untuk membangun kernel crDroid `stone` (Redmi Note 12 5G / POCO X5 5G, SM6375,
Linux 5.4.302) dengan fitur custom yang bisa dipilih satu per satu:
BakaSU (root), Droidspaces, backport systemd modern, dan Anland.

Repo ini tidak berisi kode kernel. Workflow mengambil kernel dari repo lain
(upstream atau fork kamu), menerapkan fitur yang dicentang, membangun `Image`,
lalu membuat zip AnyKernel3 yang hanya mengganti kernel di partisi `boot`.

## Pakai
1. Tab **Actions** -> pilih *Build kernel (stone - modular)* -> **Run workflow**.
2. Centang fitur yang diinginkan (lihat tabel). Semua aktif secara default.
3. Tunggu selesai, unduh artifact `stone-kernel-zip`.
4. Backup `boot` dan `vendor_boot`, lalu flash zip lewat recovery. Slot aktif
   dideteksi otomatis.

Kernel fork privat: tambahkan secret `KERNEL_REPO_TOKEN` (PAT dengan akses baca).

## Fitur

| Fitur | Isi | Butuh |
|---|---|---|
| `bakasu` | BakaSU mode manual hook (tanpa SUSFS): setup, patch hook, opsi `KSU_*` | - |
| `droidspaces` | Namespace, cgroup, netfilter/NAT, macvlan, IPv6/NAT66; patch awalan file cgroup | - |
| `systemd` | Patch `statx` mount ID, `mount_root`, `utimensat` AT_EMPTY_PATH, `faccessat2` + `FHANDLE`, `AUTOFS_FS`, AF_ALG hash | `droidspaces` |
| `anland` | `DRM` dan `CHECKPOINT_RESTORE` (kcmp untuk Mesa) | `droidspaces` |

Fitur yang butuh fitur lain akan mengaktifkannya sendiri dan menampilkan peringatan di log.
Semua fitur dimatikan = build stok (hanya `configs/ci.config`).

Input lain di workflow:
- `lto`: `stock` (ThinLTO + CFI seperti defconfig stone) atau `off`. Pakai `off` kalau
  build gagal di tahap link, supaya penyebabnya terpisah. Build jadi jauh lebih cepat.
- `localversion`: akhiran `uname -r`. Default `-stone-ci`, hasilnya `5.4.302-qgki-stone-ci`.
- `extra_config`: opsi tambahan tanpa mengubah repo, contoh `DRM_VGEM=y CGROUP_NET_PRIO=y KSU_DEBUG=n`.
  Opsi yang tidak masuk ke `.config` akhir hanya menimbulkan peringatan.

## Struktur
```
.github/workflows/build-kernel.yml   urutan langkah, tanpa logika
scripts/        lib.sh  prepare-tree.sh  make-config.sh  verify-config.sh  build.sh  package.sh
configs/        ci.config (selalu), lto-off.config
features/<nama>/
    feature.conf      deskripsi, FEATURE_REQUIRES, FEATURE_ORDER
    kernel.config     opsi WAJIB: kalau tidak masuk ke .config akhir, build gagal
    optional.config   opsi opsional: tidak masuk -> hanya peringatan
    patches/*.patch   diterapkan berurutan (sudah ada = dilewati, gagal = error)
    setup.sh          dijalankan di folder kernel sebelum patch (opsional)
anykernel/anykernel.sh
```

### Menambah fitur baru
1. Buat `features/<nama>/feature.conf` (salin dari fitur lain) dan isi `kernel.config`,
   `optional.config`, `patches/`, `setup.sh` sesuai kebutuhan. Skrip menemukannya otomatis.
2. Di `build-kernel.yml` tambahkan satu input boolean dan satu baris di langkah
   *Resolve features*.

## Perbedaan dari rova-kernel-ci
- Kernel stone 5.4 monolitik (tanpa modul `.ko` vendor) dengan satu defconfig,
  `moonstone_defconfig`, bukan serpihan `vendor/*.config`. Fragmen digabung dengan
  `merge_config.sh` dari luar source, jadi tidak ada file yang disalin ke kernel.
- Source stone tidak membawa KernelSU/SUSFS. Tidak ada yang dihapus; hook BakaSU
  (`features/bakasu/patches/0001`) ditulis ulang sebagai patch baru untuk 5.4, bukan
  pengganti hook lama.
- Patch rova yang dibuang karena tidak berlaku di stone:
  `0003-drm-vgem` (vgem 5.4 sudah punya `DRIVER_RENDER`, dan driver display MSM sudah
  menyediakan render node), `0004-focaltech` dan `0005-mdss-pll` (khusus msm8937).
- Seri backport systemd memakai seri 5.4, bukan 4.19. Hanya patch 1-4 yang dipakai:
  `close_range` sudah ada di stone, dan patch 7 hanya untuk x86.
- Opsi Droidspaces memakai nama 5.4 (`NF_CT_NETLINK`, bukan `NF_CONNTRACK_NETLINK`;
  nama IPv4/IPv6 NAT lama dibuang). `CFS_BANDWIDTH` (`--cpus`) tidak bisa dipakai karena
  bergantung pada `!SCHED_WALT`.
- Hanya `Image` yang dibangun dan dikirim. DTB ada di `vendor_boot` dan tidak disentuh.
- Perangkat A/B, boot header v3: zip memakai `BLOCK=boot` dengan deteksi slot otomatis,
  dan memeriksa nama perangkat `moonstone`, `sunstone`, `stone`.

## Catatan
- Zip hanya cocok dengan `vendor_boot` dari build kernel yang sama (DTB harus sepadan).
  Kalau kamu memakai commit kernel yang mengubah device tree, flash juga `vendor_boot` dari ROM.
- Systemd 258 dan 259 sudah jalan di 5.4 tanpa patch. Patch `systemd` diperlukan untuk 260+.
  Di sisi runtime Droidspaces harus lebih baru dari 7.1.0 (`su -c "droidspaces check"`).
- SUSFS tidak disertakan. Mode manual hook BakaSU mewajibkan `KSU_SUSFS` mati.
- Tidak ada modul vendor yang dimuat (semua driver built-in), jadi opsi yang mengubah
  ukuran struct kernel (PID_NS, SYSVIPC, FAIR_GROUP_SCHED, dst.) aman di sini.
  Aturan kABI di dokumen Droidspaces untuk GKI tidak berlaku.

## Yang sudah diuji
Diuji pada 2026-11-02 terhadap `crdroidandroid/android_kernel_xiaomi_stone`, branch `16.0`,
commit `06497b244` (5.4.302), BakaSU `main` commit `516d3e87`:
- Build penuh `Image` dengan semua fitur aktif, ThinLTO + CFI seperti defconfig stone,
  clang 18.1.3 dari Ubuntu 24.04 (yang sama dengan runner). Berhasil, `Image` 48,6 MB,
  hanya peringatan. Di mesin 2 core: sekitar 80 menit kompilasi + 5 menit link.
- Di dalam `vmlinux`: semua simbol hook BakaSU, `sys_faccessat2`, `sys_close_range`,
  dan `.config` tertanam berisi `KSU`, `PID_NS`, `USER_NS`, `FHANDLE`, `MACVLAN`, dst.
- Tahap config + verifikasi untuk build stok, hanya Droidspaces, `lto=off`, dan `extra_config`.
- Skrip `prepare-tree.sh` dari nol menghasilkan source yang identik dengan tree yang dibangun.

Belum diuji: boot di perangkat, `lto=off` sampai tahap link (hanya sampai config),
dan alur lengkap di runner GitHub. Jangan flash tanpa backup `boot`.

## Verifikasi di perangkat
```
uname -r
su -c "droidspaces check"
su -c "zcat /proc/config.gz | grep -E 'CONFIG_(KSU|PID_NS|USER_NS|MACVLAN|IP6_NF_NAT|FHANDLE)='"
```
Macvlan hanya berguna pada jaringan kabel (misalnya adaptor Ethernet USB OTG), bukan Wi-Fi.
