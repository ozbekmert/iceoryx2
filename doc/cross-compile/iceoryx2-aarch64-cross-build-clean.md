Run this script from main directory, not from under docs !


#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Iceoryx2 AArch64 cross-build using SD-card sysroot (single-prefix install)
#
# Run this script from: external/iceoryx2
#
# Requirements on host:
#   - aarch64-linux-gnu-gcc / aarch64-linux-gnu-g++
#   - cmake, make/ninja, cargo, rust target aarch64-unknown-linux-gnu
#
# Sysroot requirement:
#   - Raspberry Pi SD card mounted read-only at /mnt/rpi/rootfs
# =============================================================================

# ---- Configuration (override via environment if needed) ----------------------
SYSROOT="${SYSROOT:-/mnt/rpi/rootfs}"
TOOLCHAIN_FILE="${TOOLCHAIN_FILE:-$(pwd)/../toolchain/toolchain-aarch64-armgnu.cmake}"
AARCH64_PREFIX="${AARCH64_PREFIX:-$(pwd)/target/ff/cc/aarch64-install}"
JOBS="${JOBS:-$(nproc)}"

# ---- Safety checks -----------------------------------------------------------
if [[ ! -d "${SYSROOT}" ]]; then
  echo "[ERROR] SYSROOT not found: ${SYSROOT}"
  echo "        Mount the SD card rootfs at /mnt/rpi/rootfs (or set SYSROOT)."
  exit 1
fi

if [[ ! -f "${TOOLCHAIN_FILE}" ]]; then
  echo "[ERROR] TOOLCHAIN_FILE not found: ${TOOLCHAIN_FILE}"
  exit 1
fi

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "[ERROR] aarch64-linux-gnu-gcc not found on PATH."
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "[ERROR] cargo not found on PATH."
  exit 1
fi

# Verify sysroot looks like AArch64
if [[ -x "${SYSROOT}/bin/ls" ]]; then
  if ! file "${SYSROOT}/bin/ls" | grep -qi "ARM aarch64"; then
    echo "[ERROR] SYSROOT does not look like AArch64: ${SYSROOT}"
    file "${SYSROOT}/bin/ls" || true
    exit 1
  fi
else
  echo "[ERROR] SYSROOT seems incomplete: missing ${SYSROOT}/bin/ls"
  exit 1
fi

mkdir -p "${AARCH64_PREFIX}"

echo "[INFO] SYSROOT        = ${SYSROOT}"
echo "[INFO] TOOLCHAIN_FILE = ${TOOLCHAIN_FILE}"
echo "[INFO] AARCH64_PREFIX = ${AARCH64_PREFIX}"
echo "[INFO] JOBS           = ${JOBS}"

# ---- 1) Rust FFI -------------------------------------------------------------
echo "[STEP] cargo build iceoryx2-ffi-c (aarch64-unknown-linux-gnu)"
cargo build --release --target aarch64-unknown-linux-gnu --package iceoryx2-ffi-c

# ---- 2) iceoryx2-cmake-modules (host) ---------------------------------------
echo "[STEP] build+install iceoryx2-cmake-modules -> ${AARCH64_PREFIX}"
cmake -S iceoryx2-cmake-modules -B target/ff/cmake-modules/build -DCMAKE_BUILD_TYPE=Release
cmake --build target/ff/cmake-modules/build -j"${JOBS}"
cmake --install target/ff/cmake-modules/build --prefix "${AARCH64_PREFIX}"

# ---- Common CMake args for cross builds -------------------------------------
CROSS_ARGS=(
  "-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}"
  "-DCMAKE_SYSROOT=${SYSROOT}"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DCMAKE_INSTALL_PREFIX=${AARCH64_PREFIX}"
  "-DCMAKE_PREFIX_PATH=${AARCH64_PREFIX}"
  "-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc"
  "-DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
  "-DCMAKE_FIND_ROOT_PATH=${SYSROOT}"
  "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH"
  "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
  "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
  "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
  "-DCMAKE_FIND_ROOT_PATH=${AARCH64_PREFIX};${SYSROOT}"
)

# ---- 3) iceoryx2-bb-cxx ------------------------------------------------------
echo "[STEP] build+install iceoryx2-bb-cxx -> ${AARCH64_PREFIX}"
rm -rf target/ff/bb-cxx/build
cmake -S iceoryx2-bb/cxx -B target/ff/bb-cxx/build "${CROSS_ARGS[@]}"
cmake --build target/ff/bb-cxx/build -j"${JOBS}"
cmake --install target/ff/bb-cxx/build

# ---- 4) iceoryx2-c -----------------------------------------------------------
echo "[STEP] build+install iceoryx2-c -> ${AARCH64_PREFIX}"
rm -rf target/ff/c/build
cmake -S iceoryx2-c -B target/ff/c/build   "${CROSS_ARGS[@]}"   "-DRUST_BUILD_ARTIFACT_PATH=$(pwd)/target/aarch64-unknown-linux-gnu/release"   "-Diceoryx2-cmake-modules_DIR=${AARCH64_PREFIX}/lib/cmake/iceoryx2-cmake-modules"
cmake --build target/ff/c/build -j"${JOBS}"
cmake --install target/ff/c/build

# ---- 5) iceoryx_platform (classic iceoryx repo) ------------------------------
echo "[STEP] build+install ../iceoryx/iceoryx_platform -> ${AARCH64_PREFIX}"
rm -rf target/ff/iceoryx/build/platform
cmake -S ../iceoryx/iceoryx_platform -B target/ff/iceoryx/build/platform   "${CROSS_ARGS[@]}"   "-DBUILD_SHARED_LIBS=OFF"   "-DBUILD_TESTS=OFF"
cmake --build target/ff/iceoryx/build/platform -j"${JOBS}"
cmake --install target/ff/iceoryx/build/platform

# ---- 6) iceoryx_hoofs (classic iceoryx repo) ---------------------------------
echo "[STEP] build+install ../iceoryx/iceoryx_hoofs -> ${AARCH64_PREFIX}"
rm -rf target/ff/iceoryx/build/hoofs
cmake -S ../iceoryx/iceoryx_hoofs -B target/ff/iceoryx/build/hoofs   "${CROSS_ARGS[@]}"   "-Diceoryx_platform_DIR=${AARCH64_PREFIX}/lib/cmake/iceoryx_platform"
cmake --build target/ff/iceoryx/build/hoofs -j"${JOBS}"
cmake --install target/ff/iceoryx/build/hoofs

# ---- 7) iceoryx2-cxx ---------------------------------------------------------
echo "[STEP] build+install iceoryx2-cxx -> ${AARCH64_PREFIX}"
rm -rf target/ff/cxx/build
cmake -S iceoryx2-cxx -B target/ff/cxx/build   "${CROSS_ARGS[@]}"   "-Diceoryx2-c_DIR=${AARCH64_PREFIX}/lib/cmake/iceoryx2-c"
cmake --build target/ff/cxx/build -j"${JOBS}"
cmake --install target/ff/cxx/build

echo "[DONE] Installed AArch64 artifacts under: ${AARCH64_PREFIX}"
