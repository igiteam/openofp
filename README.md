# Operation Flashpoint: Cold War Assault

This repository holds the engine and game source code (codename *Poseidon*) - the game first released in 2001 as *Operation Flashpoint: Cold War Crisis*. The code has been modernized to C++20, built with CMake and Clang, with cross-platform support for Windows x64 and Linux x64.


## Quick Start

```sh
cmake --preset win-x64-clang-rwdi
cmake --build build/win-x64-clang-rwdi
```

On GNU/Linux, use the matching `linux-x64-clang-rwdi` preset.

## Layout

- [Apps](apps/README.md) - executable targets
- [Engine](engine/README.md) - engine libraries and Rust Trident tooling
- [Master server tools](mserver/README.md) - Rust service and CLI crates
- [Tests](tests/README.md) - test source trees; CI currently compiles them only
- `cmake/` - presets, toolchains, vcpkg triplets, and overlay ports
- `docker/` - container support for service and runtime environments
- `packages/` - ignored local game data staging area
- `resources/` - application icon resources
- `thirdparty/` - vendored third-party headers and sources


