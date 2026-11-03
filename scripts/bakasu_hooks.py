#!/usr/bin/env python3
"""Insert the BakaSU *manual hooks* into a 5.4 kernel tree.

Hooks required by BakaSU's tools/manual_hook_check.mk when the three AUTO_*
options (setuid / init.rc / input) stay on, which is the default on 5.4:

    fs/exec.c         ksu_handle_execveat
    fs/open.c         ksu_handle_faccessat
    fs/stat.c         ksu_handle_stat, ksu_handle_newfstat_ret, ksu_handle_fstat64_ret
    kernel/reboot.c   ksu_handle_sys_reboot

Anchor based and idempotent: every edit must match exactly once, otherwise the
script exits non-zero and the CI run fails with a readable message.

Usage: bakasu_hooks.py <kernel-tree>
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
failed = False


def edit(rel, steps):
    """steps = list of (description, regex, replacement)."""
    global failed
    p = root / rel
    txt = p.read_text()
    if "ksu_handle_" in txt:
        print(f"[=] {rel}: already hooked, skipping")
        return
    for desc, rx, repl in steps:
        txt, n = re.subn(rx, repl, txt, flags=re.M)
        if n != 1:
            print(f"[!] {rel}: '{desc}' matched {n} times (expected 1)")
            failed = True
            return
    p.write_text(txt)
    print(f"[+] {rel}: hooked")


# ---- fs/exec.c ---------------------------------------------------------------
edit("fs/exec.c", [
    ("extern + call in do_execveat_common",
     r"^(static int do_execveat_common\(int fd, struct filename \*filename,\n"
     r"\s+struct user_arg_ptr argv,\n\s+struct user_arg_ptr envp,\n\s+int flags\)\n\{\n)",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\n"
     "\t\t\t       void *envp, int *flags);\n"
     "#endif\n\n"
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return value intentionally ignored: the hook returns -EINVAL for\n"
     "\t * unprivileged processes, which must not fail execve(). */\n"
     "\tksu_handle_execveat(&fd, &filename, (void *)&argv, (void *)&envp, &flags);\n"
     "#endif\n"),
])

# ---- fs/open.c ---------------------------------------------------------------
edit("fs/open.c", [
    ("extern before do_faccessat",
     r"^((?:static )?long do_faccessat\()",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n"
     "\t\t\t\tint *__unused_flags);\n"
     "#endif\n\n"
     r"\1"),
    ("call after retry: in do_faccessat",
     r"(old_cred = override_creds\(override_cred\);\nretry:\n)"
     r"(\tres = user_path_at\(dfd, filename, lookup_flags, &path\);)",
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return value intentionally ignored (notification only). */\n"
     "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n"
     "#endif\n"
     r"\2"),
])

# ---- fs/stat.c ---------------------------------------------------------------
edit("fs/stat.c", [
    ("extern ksu_handle_stat",
     r"^(/\*\*\n \* vfs_statx - Get basic and extra attributes by filename)",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n"
     "#endif\n\n"
     r"\1"),
    ("call in vfs_statx",
     r"(\nretry:\n)(\terror = user_path_at\(dfd, filename, lookup_flags, &path\);)",
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return value intentionally ignored (notification only). */\n"
     "\tksu_handle_stat(&dfd, &filename, &flags);\n"
     "#endif\n"
     r"\2"),
    ("newfstat return hook",
     r"^(SYSCALL_DEFINE2\(newfstat, unsigned int, fd, struct stat __user \*, statbuf\)\n\{\n"
     r"\tstruct kstat stat;\n\tint error = vfs_fstat\(fd, &stat\);\n\n"
     r"\tif \(!error\)\n\t\terror = cp_new_stat\(&stat, statbuf\);\n)",
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return-value hook: patches st_size in the user buffer, success only. */\n"
     "\tif (!error)\n\t\tksu_handle_newfstat_ret(&fd, &statbuf);\n"
     "#endif\n"),
    ("extern newfstat_ret",
     r"^(SYSCALL_DEFINE2\(newfstat, unsigned int, fd,)",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);\n"
     "#endif\n\n"
     r"\1"),
    ("fstat64 return hook",
     r"^(SYSCALL_DEFINE2\(fstat64, unsigned long, fd, struct stat64 __user \*, statbuf\)\n\{\n"
     r"\tstruct kstat stat;\n\tint error = vfs_fstat\(fd, &stat\);\n\n"
     r"\tif \(!error\)\n\t\terror = cp_new_stat64\(&stat, statbuf\);\n)",
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return-value hook: patches st_size in the user buffer, success only. */\n"
     "\tif (!error)\n\t\tksu_handle_fstat64_ret(&fd, &statbuf);\n"
     "#endif\n"),
    ("extern fstat64_ret",
     r"^(SYSCALL_DEFINE2\(fstat64, unsigned long, fd,)",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern void ksu_handle_fstat64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);\n"
     "#endif\n\n"
     r"\1"),
])

# ---- kernel/reboot.c ---------------------------------------------------------
edit("kernel/reboot.c", [
    ("extern before reboot syscall",
     r"^(/\*\n \* Reboot system call: for obvious reasons only root may call it,)",
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd,\n"
     "\t\t\t\t void __user **arg);\n"
     "#endif\n\n"
     r"\1"),
    ("call at top of reboot syscall",
     r"(SYSCALL_DEFINE4\(reboot, int, magic1, int, magic2, unsigned int, cmd,\n"
     r"\t\tvoid __user \*, arg\)\n\{\n\tstruct pid_namespace \*pid_ns = task_active_pid_ns\(current\);\n"
     r"\tchar buffer\[256\];\n\tint ret = 0;\n\n)",
     r"\1"
     "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
     "\t/* Return value intentionally ignored: only KSU magic pairs are acted on. */\n"
     "\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n"
     "#endif\n\n"),
])

sys.exit(1 if failed else 0)
