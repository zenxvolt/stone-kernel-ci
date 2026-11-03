# stone-kernel-ci

Build kernel Poco X5 5G (`moonstone_defconfig`, Linux 5.4 QGKI) di GitHub Actions dengan fitur modular:

| Fitur (input workflow) | Isi |
|---|---|
| `enable_bakasu` | BakaSU root, mode **manual hook** (tracepoint hook hanya untuk GKI 5.10+). 6 hook disisipkan otomatis oleh `scripts/bakasu_hooks.py`. |
| `enable_droidspaces` | Opsi kernel Droidspaces + patch kABI (SYSVIPC/mqueue dipindah ke padding `ANDROID_KABI_*`) supaya CRC symbol tidak berubah. |
| `enable_network` | `MACVLAN`, `IP6_NF_NAT`, `IP6_NF_TARGET_MASQUERADE` (+ guard IPv6 dan driver USB-Ethernet yang sudah aktif). |
| `enable_systemd` | Backport untuk systemd 258+ (statx mnt_id/mount_root, utimensat, faccessat2) + `FHANDLE`. `close_range` sudah ada di tree stone, jadi hanya patch 1 sampai 4. |
| `enable_firewall` | Opsi UFW / Fail2Ban (opsional). |
| `abi_check` | Build ulang defconfig polos dan bandingkan CRC symbol export. Dua kali waktu build. |

## Cara pakai

1. Buat repo `stone-kernel-ci`, push isi folder ini.
2. Actions → **Build stone kernel** → Run workflow.
3. Isi `kernel_ref` dengan branch yang sama dengan kernel ROM kamu sekarang.
4. Isi `expected_release` dengan output `uname -r` dari HP (build gagal lebih awal kalau beda).
5. Unduh artifact `stone-kernel-zip`, flash lewat Kernel Flasher / recovery.
6. Pasang manager BakaSU dari **commit yang sama** (commit tercetak di `notes.txt`).

## Kalau HP stuck di logo

Penyebab paling umum di kernel QGKI: modul vendor ditolak karena CRC symbol atau `uname -r` berubah.

1. Jalankan sekali dengan `abi_check` aktif dan baca `abi-report`. Kalau ada CRC berubah, coba `kabi_variant` lain (`3_4_5` lalu `1_2_3`) atau matikan fitur yang menggeser struct.
2. Pastikan `kernel_ref` sama dengan sumber kernel ROM, dan `expected_release` terisi.
3. Simpan `boot.img` asli. Pulihkan dengan `fastboot flash boot boot.img`.

## Catatan

- Tidak diuji di perangkat. Yang sudah diuji: semua patch dan script apply bersih di crdroidandroid/android_kernel_xiaomi_stone (5.4.302, branch 16.0), dan seluruh opsi config lolos `olddefconfig` + verifikasi dengan toolchain host. Kompilasi penuh dengan clang belum dijalankan.
- `clang_url` default adalah AOSP clang-r383902b (clang 11). LTO + CFI di 5.4 butuh clang AOSP, bukan clang distro.
- `CONFIG_CFS_BANDWIDTH` dan `CONFIG_CGROUP_PIDS` sengaja tidak diaktifkan (merusak kABI). `--cpus` dan `--pids-limit` Droidspaces tidak akan tersedia.
- SUSFS tidak disertakan: patch SUSFS 5.4 berhenti di v1.5.5, sedangkan BakaSU main butuh API v2.
- `path_umount` tidak ada di 5.4, jadi fitur unmount modul BakaSU tidak aktif. Root dan modul tetap jalan.
- AnyKernel3 hanya mengganti `Image` di partisi boot dan mengatur flag vbmeta otomatis.
