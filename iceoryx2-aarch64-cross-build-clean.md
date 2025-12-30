# Iceoryx2 Cross-Compilation (AArch64, SD-card Sysroot)

This guide describes a **reproducible, best-practice workflow** to cross-compile the Iceoryx2 stack for **AArch64** using a **physically mounted Raspberry Pi SD-card sysroot**, with **all target artifacts installed into a single prefix**.

**Target install prefix (single-prefix best practice)**

```
external/iceoryx2/target/ff/cc/aarch64-install
```

---

## 1) Mount the Raspberry Pi SD Card (Sysroot)

> Adjust `/dev/sda1` and `/dev/sda2` to match your SD card device.

```bash
sudo mkdir -p /mnt/rpi/{bootfs,rootfs}

sudo mount -o ro /dev/sda2 /mnt/rpi/rootfs
sudo mount -o ro /dev/sda1 /mnt/rpi/bootfs
```

Verify the sysroot is AArch64:

```bash
file /mnt/rpi/rootfs/bin/ls
```

Expected (example):

```
ELF 64-bit LSB pie executable, ARM aarch64, ...
```

---

## 2) Canonical Environment

Run all build commands from:

```
external/iceoryx2
```

```bash
export SYSROOT=/mnt/rpi/rootfs
export TOOLCHAIN_FILE="$(pwd)/../toolchain/toolchain-aarch64-armgnu.cmake"

# Single authoritative AArch64 install prefix
export AARCH64_PREFIX="$(pwd)/target/ff/cc/aarch64-install"
mkdir -p "$AARCH64_PREFIX"
```

---

## 3) Build Rust FFI (AArch64)

```bash
cargo build --release \
  --target aarch64-unknown-linux-gnu \
  --package iceoryx2-ffi-c
```

---

## 4) Build and Install `iceoryx2-cmake-modules` (host tools)

These are CMake helper modules; build on the host and install into the **same target prefix** (single-prefix best practice).

```bash
cmake -S iceoryx2-cmake-modules \
  -B target/ff/cmake-modules/build \
  -DCMAKE_BUILD_TYPE=Release

cmake --build target/ff/cmake-modules/build -j"$(nproc)"
cmake --install target/ff/cmake-modules/build --prefix "$AARCH64_PREFIX"
```

---

## 5) Cross-Compile and Install `iceoryx2-bb-cxx` (AArch64)

`iceoryx2-cxx` depends on this package.

```bash
rm -rf target/ff/bb-cxx/build

cmake -S iceoryx2-bb-cxx \
  -B target/ff/bb-cxx/build \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$AARCH64_PREFIX" \
  -DCMAKE_PREFIX_PATH="$AARCH64_PREFIX" \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++

cmake --build target/ff/bb-cxx/build -j"$(nproc)"
cmake --install target/ff/bb-cxx/build
```

---

## 6) Cross-Compile and Install `iceoryx2-c` (AArch64)

```bash
rm -rf target/ff/c/build

cmake -S iceoryx2-c \
  -B target/ff/c/build \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$AARCH64_PREFIX" \
  -DRUST_BUILD_ARTIFACT_PATH="$(pwd)/target/aarch64-unknown-linux-gnu/release" \
  -DCMAKE_PREFIX_PATH="$AARCH64_PREFIX" \
  -Diceoryx2-cmake-modules_DIR="$AARCH64_PREFIX/lib/cmake/iceoryx2-cmake-modules" \
  -DCMAKE_FIND_ROOT_PATH="$SYSROOT" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER

cmake --build target/ff/c/build -j"$(nproc)"
cmake --install target/ff/c/build
```

---

## 7) Cross-Compile and Install `iceoryx_platform` (AArch64)

This comes from your separate iceoryx (classic) repository located at `../iceoryx`.

```bash
rm -rf target/ff/iceoryx/build/platform

cmake -S ../iceoryx/iceoryx_platform \
  -B target/ff/iceoryx/build/platform \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF \
  -DCMAKE_INSTALL_PREFIX="$AARCH64_PREFIX" \
  -DCMAKE_PREFIX_PATH="$AARCH64_PREFIX" \
  -DCMAKE_FIND_ROOT_PATH="$SYSROOT" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER

cmake --build target/ff/iceoryx/build/platform -j"$(nproc)"
cmake --install target/ff/iceoryx/build/platform
```

---

## 8) Cross-Compile and Install `iceoryx_hoofs` (AArch64)

```bash
export iceoryx_platform_DIR="$AARCH64_PREFIX/lib/cmake/iceoryx_platform"

rm -rf target/ff/iceoryx/build/hoofs

cmake -S ../iceoryx/iceoryx_hoofs \
  -B target/ff/iceoryx/build/hoofs \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$AARCH64_PREFIX" \
  -Diceoryx_platform_DIR="$iceoryx_platform_DIR" \
  -DCMAKE_PREFIX_PATH="$AARCH64_PREFIX" \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++

cmake --build target/ff/iceoryx/build/hoofs -j"$(nproc)"
cmake --install target/ff/iceoryx/build/hoofs
```

---

## 9) Cross-Compile and Install `iceoryx2-cxx` (AArch64)

```bash
export iceoryx2_c_DIR="$AARCH64_PREFIX/lib/cmake/iceoryx2-c"

rm -rf target/ff/cxx/build

cmake -S iceoryx2-cxx \
  -B target/ff/cxx/build \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$AARCH64_PREFIX" \
  -DCMAKE_PREFIX_PATH="$AARCH64_PREFIX" \
  -Diceoryx2-c_DIR="$iceoryx2_c_DIR" \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++

cmake --build target/ff/cxx/build -j"$(nproc)"
cmake --install target/ff/cxx/build
```

---

## 10) Verification

List a few installed artifacts:

```bash
find "$AARCH64_PREFIX" -maxdepth 3 -type f \( -name "*.so*" -o -name "*.a" -o -name "*Config.cmake" \) | head -50
```

Verify architecture of shared libraries (if any):

```bash
aarch64-linux-gnu-readelf -h "$AARCH64_PREFIX"/lib/*.so* 2>/dev/null | grep -E "Machine|Class" || true
```

Expected (example):

```
Machine:                           AArch64
```

---

## Result

All target artifacts are installed under:

```
target/ff/cc/aarch64-install
```

This layout is deterministic, CI-friendly, and avoids host/target contamination.
