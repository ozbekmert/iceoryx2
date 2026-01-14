# Iceoryx2 Native Build Script (x86_64, Single Prefix)

This repository provides a Bash script to **build Iceoryx2 natively on x86_64 Linux** using a **single, self-contained install prefix**.

The script is derived from earlier cross-compilation tooling, but all cross-related residue has been removed. It is intended for local development, debugging, and CI use without touching system directories such as `/usr/local`.

---

## What This Script Builds

The script builds and installs the following components in order:

1. `iceoryx2-ffi-c` (Rust / Cargo)
2. `iceoryx2-cmake-modules`
3. `iceoryx2-bb-cxx`
4. `iceoryx2-c`
5. `iceoryx_platform` (classic Iceoryx repository)
6. `iceoryx_hoofs` (classic Iceoryx repository)
7. `iceoryx2-cxx`

All artifacts are installed into a **single prefix directory**.

---

## Default Directory Layout

```
build-iceoryx2-x86_64/
├── cargo-target/
│   ├── debug/
│   └── release/
├── cmake/
│   ├── iceoryx2-cmake-modules/
│   ├── iceoryx2-bb-cxx/
│   ├── iceoryx2-c/
│   ├── iceoryx_platform/
│   ├── iceoryx_hoofs/
│   └── iceoryx2-cxx/
└── install/
    ├── bin/
    ├── lib/
    │   └── cmake/
    └── include/
```

Nothing is installed into `/usr/local`.

---

## Requirements

- Linux (x86_64)
- Bash 4+
- CMake
- Rust toolchain (`cargo`)
- C/C++ compiler toolchain
- `make` or `ninja`

---

## Usage

Run the script from the **`iceoryx2` repository root**:

```bash
chmod +x build-native.sh
./build-native.sh
```

---

## Configuration via Environment Variables

| Variable        | Description                         | Default                   |
|-----------------|-------------------------------------|---------------------------|
| `JOBS`          | Parallel build jobs                 | `nproc`                   |
| `BUILD_TYPE`    | CMake build type                    | `Debug`                   |
| `BUILD_ROOT`    | Root directory for build artifacts  | `./build-iceoryx2-x86_64` |
| `X86_64_PREFIX` | Installation prefix                | `${BUILD_ROOT}/install`   |

---

## Cleaning Up

```bash
rm -rf build-iceoryx2-x86_64
```

---

## Notes

- The classic Iceoryx repository is expected at `../iceoryx`
- This script performs **native builds only**
