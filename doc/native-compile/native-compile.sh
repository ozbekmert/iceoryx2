#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Iceoryx2 native-build (single-prefix install)
# Run from: iceoryx2 (repo root)
# =============================================================================

JOBS="${JOBS:-$(nproc)}"

ROOT_DIR="$(pwd)"
BUILD_ROOT="${BUILD_ROOT:-${ROOT_DIR}/build-iceoryx2-x86_64}"
PREFIX="${X86_64_PREFIX:-${BUILD_ROOT}/install}"

BUILD_TYPE="${BUILD_TYPE:-Debug}"

# ---- Safety checks -----------------------------------------------------------
command -v cargo >/dev/null 2>&1 || { echo "[ERROR] cargo not found on PATH."; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "[ERROR] cmake not found on PATH."; exit 1; }

echo "[INFO] JOBS       = ${JOBS}"
echo "[INFO] BUILD_ROOT = ${BUILD_ROOT}"
echo "[INFO] PREFIX     = ${PREFIX}"
echo "[INFO] BUILD_TYPE = ${BUILD_TYPE}"

mkdir -p "${BUILD_ROOT}" "${PREFIX}"

# ---- 1) Rust FFI -------------------------------------------------------------
# Keep Cargo output separated from CMake trees
CARGO_TARGET_DIR="${BUILD_ROOT}/cargo-target"

echo "[STEP] cargo build iceoryx2-ffi-c (native)"
cargo build \
  --package iceoryx2-ffi-c \
  --target-dir "${CARGO_TARGET_DIR}"

# If iceoryx2-c expects a path to the built artifact(s), point it to the *native* cargo output
# Adjust Debug/Release directory based on BUILD_TYPE
RUST_PROFILE_DIR="debug"
if [[ "${BUILD_TYPE}" == "Release" || "${BUILD_TYPE}" == "RelWithDebInfo" || "${BUILD_TYPE}" == "MinSizeRel" ]]; then
  RUST_PROFILE_DIR="release"
fi
RUST_BUILD_ARTIFACT_PATH="${CARGO_TARGET_DIR}/${RUST_PROFILE_DIR}"

# ---- 2) iceoryx2-cmake-modules ----------------------------------------------
CMODULE_BUILD="${BUILD_ROOT}/cmake/iceoryx2-cmake-modules"

echo "[STEP] build+install iceoryx2-cmake-modules"
rm -rf "${CMODULE_BUILD}"
cmake -S iceoryx2-cmake-modules \
      -B "${CMODULE_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${CMODULE_BUILD}" -j"${JOBS}"
cmake --install "${CMODULE_BUILD}"

# ---- 3) iceoryx2-bb-cxx ------------------------------------------------------
BB_CXX_BUILD="${BUILD_ROOT}/cmake/iceoryx2-bb-cxx"

echo "[STEP] build+install iceoryx2-bb-cxx"
rm -rf "${BB_CXX_BUILD}"
cmake -S iceoryx2-bb/cxx \
      -B "${BB_CXX_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BB_CXX_BUILD}" -j"${JOBS}"
cmake --install "${BB_CXX_BUILD}"

# ---- 4) iceoryx2-c -----------------------------------------------------------
C_BUILD="${BUILD_ROOT}/cmake/iceoryx2-c"

echo "[STEP] build+install iceoryx2-c"
rm -rf "${C_BUILD}"
cmake -S iceoryx2-c \
      -B "${C_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
      -DRUST_BUILD_ARTIFACT_PATH="${RUST_BUILD_ARTIFACT_PATH}" \
      -Diceoryx2-cmake-modules_DIR="${PREFIX}/lib/cmake/iceoryx2-cmake-modules"
cmake --build "${C_BUILD}" -j"${JOBS}"
cmake --install "${C_BUILD}"

# ---- 5) classic iceoryx: iceoryx_platform -----------------------------------
IOX_PLATFORM_BUILD="${BUILD_ROOT}/cmake/iceoryx_platform"

echo "[STEP] build+install ../iceoryx/iceoryx_platform"
rm -rf "${IOX_PLATFORM_BUILD}"
cmake -S ../iceoryx/iceoryx_platform \
      -B "${IOX_PLATFORM_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_TESTS=OFF
cmake --build "${IOX_PLATFORM_BUILD}" -j"${JOBS}"
cmake --install "${IOX_PLATFORM_BUILD}"

# ---- 6) classic iceoryx: iceoryx_hoofs --------------------------------------
IOX_HOOFS_BUILD="${BUILD_ROOT}/cmake/iceoryx_hoofs"

echo "[STEP] build+install ../iceoryx/iceoryx_hoofs"
rm -rf "${IOX_HOOFS_BUILD}"
cmake -S ../iceoryx/iceoryx_hoofs \
      -B "${IOX_HOOFS_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
      -Diceoryx_platform_DIR="${PREFIX}/lib/cmake/iceoryx_platform"
cmake --build "${IOX_HOOFS_BUILD}" -j"${JOBS}"
cmake --install "${IOX_HOOFS_BUILD}"

# ---- 7) iceoryx2-cxx ---------------------------------------------------------
CXX_BUILD="${BUILD_ROOT}/cmake/iceoryx2-cxx"

echo "[STEP] build+install iceoryx2-cxx"
rm -rf "${CXX_BUILD}"
cmake -S iceoryx2-cxx \
      -B "${CXX_BUILD}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
      -Diceoryx2-c_DIR="${PREFIX}/lib/cmake/iceoryx2-c"
cmake --build "${CXX_BUILD}" -j"${JOBS}"
cmake --install "${CXX_BUILD}"

echo "[DONE] Installed native artifacts under: ${PREFIX}"
