#!/usr/bin/env bash
# Di-source oleh script lain dan workflow. Menyediakan kmake() untuk dijalankan
# dari root tree kernel.
#   KCFLAGS       default -Wno-error (clang baru lebih cerewet daripada toolchain Qualcomm)
#   KMAKE_EXTRA   argumen make tambahan, mis. "CLANG_TRIPLE=aarch64-linux-gnu-"

kmake() {
	make O=out ARCH=arm64 LLVM=1 CC=clang \
		CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
		KCFLAGS="${KCFLAGS:--Wno-error}" ${KMAKE_EXTRA:-} "$@"
}
