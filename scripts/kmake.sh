#!/usr/bin/env bash
# kmake.sh <make args...>   (run from the kernel source dir, toolchain on PATH)
# One place for the toolchain variables. Every make call must use the SAME set,
# otherwise Kconfig's compiler probe silently drops LTO/CFI/SCS.
exec make O=out ARCH=arm64 \
  CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip \
  HOSTCC=gcc HOSTCXX=g++ HOSTLD=ld HOSTAR=ar \
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  CLANG_TRIPLE=aarch64-linux-gnu- KCFLAGS=-fno-temp-file "$@"
