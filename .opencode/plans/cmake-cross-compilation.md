# CMake Cross-Compilation Build System

**Status:** COMPLETE
**Goal:** Build the entire Meridian 59 project on Linux using CMake. The Windows client and modules cross-compile via MinGW-w64 (producing .exe/.dll for Wine). The server, compiler, and kod compile natively for Linux.

## Overview

Currently, building on Linux requires per-component `make -f makefile.linux` invocations for server, compiler, and kod only. The Windows client has no Linux build support at all.

This plan introduces a **single CMake-based build system** that:
1. Cross-compiles the client (`meridian.exe`) and 6 module DLLs using MinGW-w64
2. Natively compiles the server (`blakserv`), compiler (`bc`), and utilities for Linux
3. Compiles all Blakod scripts (`.kod` -> `.bof`) using the native `bc` compiler
4. Can be invoked with a single `cmake --build build` command

### Target Outputs

| Component | Toolchain | Output | Destination |
|-----------|-----------|--------|-------------|
| `meridian.exe` | MinGW-w64 | Windows PE executable | `run/localclient/` |
| `merintr.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `char.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `admin.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `dm.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `mailnews.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `chess.dll` | MinGW-w64 | Windows DLL (client module) | `run/localclient/resource/` |
| `blakserv` | Native g++ | Linux ELF executable | `run/server/` |
| `bc` | Native g++ | Linux ELF executable | `bin/` |
| `rscmerge` | Native g++ | Linux ELF executable | `bin/` |
| `rscprint` | Native g++ | Linux ELF executable | `bin/` |
| `*.bof` | `bc` (native) | Blakod bytecode | `run/server/loadkod/` |

### Prerequisites

- `x86_64-w64-mingw32-g++` (MinGW-w64 cross-compiler)
- `g++` with C++20 support (native compiler)
- `cmake` >= 3.20
- `flex`, `bison`
- DirectX 9 headers (shipped with MinGW-w64)

Install on Debian/Ubuntu:
```bash
sudo apt install cmake g++ mingw-w64 flex bison
```

---

## Phase 1: CMake Infrastructure & Toolchain Files [sonnet] ✅

**Goal:** Create the top-level CMake project structure and MinGW toolchain file.

### Files to Create

1. **`CMakeLists.txt`** (top-level) -- Master project file
   - `cmake_minimum_required(VERSION 3.20)`
   - `project(Meridian59)`
   - Common settings: C++20 standard, compile `.c` files as C++
   - Option: `CROSS_COMPILE_CLIENT` (ON by default)
   - Uses `ExternalProject_Add` or `add_subdirectory` with toolchain switching
   - Since CMake doesn't natively support two toolchains in one build, use the **superbuild pattern**: the top-level CMake configures native targets directly, and invokes a separate CMake configure/build for the MinGW cross-compiled targets via `ExternalProject_Add`

2. **`cmake/mingw-w64-x86_64.cmake`** -- CMake toolchain file for MinGW
   ```cmake
   set(CMAKE_SYSTEM_NAME Windows)
   set(CMAKE_SYSTEM_PROCESSOR x86_64)
   set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
   set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
   set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
   set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
   set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
   set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
   set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
   ```

3. **`cmake/CompileAsCC.cmake`** -- Helper module to compile .c files as C++20
   - Sets `LANGUAGE CXX` property on all `.c` source files
   - Or uses `CMAKE_C_FLAGS` with `-x c++` globally

### Architecture: Superbuild Pattern

```
CMakeLists.txt  (top-level, native toolchain)
├── blakserv/CMakeLists.txt      (native: Linux server)
├── blakcomp/CMakeLists.txt      (native: Blakod compiler)
├── util/CMakeLists.txt          (native: rscmerge, rscprint)
├── kod/CMakeLists.txt           (native: custom target invoking bc)
└── ExternalProject_Add(client_win32,
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/client-win32
        CMAKE_TOOLCHAIN_FILE cmake/mingw-w64-x86_64.cmake)
    └── client-win32/CMakeLists.txt  (cross-compiled subtree)
        ├── external/zlib           (static lib, compiled as C)
        ├── external/libpng         (static lib)
        ├── external/libarchive     (static lib, compiled as C)
        ├── util/ (rscload only)    (static lib)
        ├── clientd3d/              (EXE with .def exports)
        └── module/                 (6 DLLs linking against meridian.exe)
```

**Why superbuild?** CMake can only use one toolchain per configure. We need native g++ for server/compiler and MinGW for the client. The superbuild pattern launches a nested CMake invocation with a different toolchain.

### Verification
- `cmake -B build` succeeds with the superbuild structure
- No actual targets build yet -- just the infrastructure

---

## Phase 2: Native Linux Targets (Server, Compiler, Utilities) [sonnet] ✅

**Goal:** Port the existing `makefile.linux` builds to CMake.

### 2a. Blakod Compiler (`blakcomp/CMakeLists.txt`)

**Source files:** `actions.c`, `table.c`, `kodbase.c`, `codegen.c`, `codeutil.c`, `function.c`, `util.c`, `sort.c`, `optimize.c`, `resource.c` + generated `lexyy.c`, `blakcomp.tab.c`

**Steps:**
- Use `find_package(FLEX)` and `find_package(BISON)` for code generation
- `FLEX_TARGET(Scanner blakcomp.l ${CMAKE_CURRENT_BINARY_DIR}/lexyy.c)`
- `BISON_TARGET(Parser blakcomp.y ${CMAKE_CURRENT_BINARY_DIR}/blakcomp.tab.c)`
- `ADD_FLEX_BISON_DEPENDENCY(Scanner Parser)`
- Include `../include` for shared headers
- Compile all `.c` as C++20
- Output: `bc` binary, copied to `${PROJECT_SOURCE_DIR}/bin/`

### 2b. Server (`blakserv/CMakeLists.txt`)

**Source files:** 66 `.c` files (see makefile.linux), plus `rscload.c`, `crc.c`, `md5.c` from `../util/`

**Platform sources:**
- Linux: `osd_linux.c` + `osd_epoll.c`
- macOS: `osd_linux.c` + `osd_kqueue.c`

**Steps:**
- Include `../include` and `../external/fmtlib`
- Compile all `.c` as C++20
- Define `BLAK_PLATFORM_LINUX`
- Platform detection for epoll vs kqueue
- Custom command to recompile `version.c` before link (embed timestamp)
- Output: `blakserv` binary, copied to `${PROJECT_SOURCE_DIR}/run/server/`

### 2c. Utilities (`util/CMakeLists.txt`)

- `rscmerge`: `rscmerge.c` + `rscload.c`
- `rscprint`: `rscprint.c` + `rscload.c`
- Include `../include`
- Output: both copied to `${PROJECT_SOURCE_DIR}/bin/`

### 2d. Blakod Scripts (`kod/CMakeLists.txt`)

This is NOT a C compilation. It invokes the `bc` compiler on `.kod` files.

**Approach:**
- Custom target that depends on the `bc` executable
- Glob all `.kod` files (or replicate the explicit list from the existing makefiles)
- Custom commands: `bc -d -I <include_dir> -K kodbase.txt <file>.kod`
- Copy `.bof` to `run/server/loadkod/`, `.rsc` to `run/server/rsc/`
- This is the trickiest part -- the existing makefile system has a complex recursive structure with dependency ordering (util.bof and object.bof must compile first to generate kodbase.txt, then all other .kod files use that)

**Implementation detail:** The Blakod compilation has a strict ordering requirement -- `kodbase.txt` is built incrementally as each `.bof` is compiled, and later `.kod` files depend on earlier ones via inheritance. The CMake target must preserve the exact compilation order from the existing makefiles (BOFS, BOFS2..BOFS8 groups).

### Verification
- `cmake -B build && cmake --build build` produces working `blakserv`, `bc`, `rscmerge`, `rscprint`
- `bc` can compile `.kod` files
- `blakserv` starts and loads compiled `.bof` files
- Compare against existing `make -f makefile.linux` builds

---

## Phase 3: Cross-Compiled External Libraries [sonnet] ✅

**Goal:** Build zlib, libpng, and libarchive as static Windows libraries using MinGW.

These live inside the cross-compiled subtree (`client-win32/CMakeLists.txt` or equivalent).

### 3a. zlib

**Source files:** 15 `.c` files (adler32, compress, crc32, deflate, gzclose, gzlib, gzread, gzwrite, infback, inffast, inflate, inftrees, trees, uncompr, zutil)

**Key:** Must compile as **plain C** (not C++). The existing Windows makefile uses `-TC` to override the global `-TP`. In CMake: `set_target_properties(zlib PROPERTIES LINKER_LANGUAGE C)` and ensure no C++ flags apply.

**Output:** `libzlib.a` (static library)

### 3b. libpng

**Source files:** 15 `.c` files
**Depends on:** zlib (include path)
**Output:** `liblibpng.a` (static library)
**Can compile as C++** (the existing Windows build does this)

### 3c. libarchive

**Source files:** 122 `.c` files (large library)
**Key:** Must compile as **plain C** (existing Windows makefile uses `-TC`)
**Defines:** `-DHAVE_CONFIG_H` (uses vendored `config.h`)
**Depends on:** zlib
**Output:** `liblibarchive.a` (static library)

### Verification
- All three libraries compile cleanly with MinGW
- `.a` files are produced and have the expected symbols

---

## Phase 4: Cross-Compiled Client Utilities & Code Generators [sonnet] ✅

**Goal:** Build helper executables and the rscload library for the Windows client.

### 4a. rscload (static library)

**Source files:** `util/rscload.c`, `util/memmap.c`
**Output:** `librscload.a` (MinGW static library)
**Include:** `include/`

### 4b. Code generators: `maketrig.exe` and `makepal.exe`

**Source files:** `clientd3d/maketrig.c`, `clientd3d/makepal.c`
**These are Windows executables** that run during the build to generate lookup tables.

**Problem:** These run at build time to generate `trig.c`, `trig.h`, and `pal.c`. When cross-compiling, we can't run Windows executables directly.

**Solutions (pick one):**
1. **Run under Wine at build time:** `wine maketrig.exe` -- works but adds Wine as a build dependency
2. **Build native versions too:** Compile `maketrig.c` and `makepal.c` with the native compiler just for code generation, then use the generated files in the cross-compiled client. This is cleaner.
3. **Pre-generate the files:** Run once, commit the generated files. Fragile if inputs change.

**Recommended: Option 2.** Use `add_executable(maketrig_native ...)` with the native compiler, then add custom commands that run the native executables to produce the `.c`/`.h` files used by the cross build.

**Implementation:** The superbuild pattern already gives us both toolchains. The native build produces `maketrig` and `makepal` as host tools. The cross-compile build consumes their generated output via a shared directory.

### Verification
- `maketrig` generates `trig.c` and `trig.h` with trigonometric lookup tables
- `makepal` generates `pal.c` from `blakston.pal`
- Both generated files compile cleanly with MinGW

---

## Phase 5: Cross-Compiled Client (`meridian.exe`) [sonnet] ✅

**Goal:** Cross-compile the main game client executable with MinGW-w64.

### Source Files (109 .c files)

All from `clientd3d/`:
`client.c`, `list.c`, `modules.c`, `map.c`, `msgfiltr.c`, `loadrsc.c`, `protocol.c`, `com.c`, `palette.c`, `tooltip.c`, `annotate.c`, `idlist.c`, `roomanim.c`, `statconn.c`, `memmap.c`, `mapfile.c`, `boverlay.c`, `web.c`, `about.c`, `login.c`, `srvrstr.c`, `effect.c`, `bitmap.c`, `download.c`, `select.c`, `logoff.c`, `transfer.c`, `statoffl.c`, `cursor.c`, `xlat.c`, `rops.c`, `profane.c`, `object.c`, `graphics.c`, `winmsg.c`, `server.c`, `dialog.c`, `draw.c`, `graphctl.c`, `animate.c`, `config.c`, `projectile.c`, `uselist.c`, `move.c`, `startup.c`, `keyhook.c`, `toolbar.c`, `game.c`, `intrface.c`, `ownerdrw.c`, `util.c`, `table.c`, `statterm.c`, `statgame.c`, `font.c`, `textin.c`, `msgbox.c`, `editbox.c`, `gameuser.c`, `offer.c`, `maindlg.c`, `lookdlg.c`, `color.c`, `say.c`, `sound.c`, `music.c`, `key.c`, `buy.c`, `statstrt.c`, `dibutil.c`, `parse.c`, `drawbmp.c`, `winmenu.c`, `cache.c`, `ping.c`, `objdraw.c`, `lagbox.c`, `regexpr.c`, `fixed.c`, `signup.c`, `preferences.c`

**3D rendering files:**
`draw3d.c`, `object3d.c`, `overlay.c`, `moveobj.c`, `client3d.c`, `drawbsp.c`, `bspload.c`, `d3dcache.c`, `d3ddriver.c`, `d3dparticle.c`, `d3drender.c`, `d3drender_bgoverlays.c`, `d3drender_fx.c`, `d3drender_lights.c`, `d3drender_materials.c`, `d3drender_objects.c`, `d3drender_skybox.c`, `d3drender_textures.c`, `d3drender_world.c`, `matrix.c`, `xform.c`

**Audio:**
`audio_openal.c`, plus `external/stb/stb_vorbis.c`

**Shared utility sources:**
`util/md5.c`, `util/crc.c`

**Generated sources (from Phase 4):**
`trig.c`, `pal.c`

### Resource Compilation

**File:** `clientd3d/client.rc`

Compile with `x86_64-w64-mingw32-windres`:
```
x86_64-w64-mingw32-windres -I clientd3d -I include client.rc -o client.res.o
```

**Required fix:** Wrap `AFX_DIALOG_LAYOUT` blocks (lines 3090-3098) in `#ifdef _MSC_VER` or `#ifdef APSTUDIO_INVOKED` since `windres` doesn't recognize this resource type. This is the only incompatibility.

### Compiler Flags

```cmake
target_compile_definitions(meridian PRIVATE
    BLAK_PLATFORM_WINDOWS
    WIN32
    BLAKCLIENT
    STB_VORBIS_NO_PUSHDATA_API
    FMT_UNICODE=0
)
```

**C++20 compilation:** All `.c` files must compile as C++20.
```cmake
set_source_files_properties(${CLIENT_SOURCES} PROPERTIES LANGUAGE CXX)
# Or use: target_compile_options(meridian PRIVATE -x c++ -std=c++20)
```

**Warning suppression:** The 3 `#pragma warning(disable: ...)` in client.h and bsp.h are MSVC-specific. Wrap them:
```c
#ifdef _MSC_VER
#pragma warning(disable: 4244)
#endif
```

MinGW equivalents if needed:
- 4244 (double-to-float): `-Wno-conversion` or leave as-is (GCC may not warn by default)
- 4201 (nameless struct/union): `-fms-extensions` (MinGW supports this)

### Linker Configuration

```cmake
target_link_libraries(meridian PRIVATE
    zlib libpng libarchive rscload
    user32 gdi32 comdlg32 shell32
    ws2_32 comctl32 advapi32 winmm
    wininet ole32 OpenAL32 d3d9
)
```

**DEF file for exports:**
```cmake
set_target_properties(meridian PROPERTIES
    LINK_FLAGS "-Wl,--output-def,meridian.def"
    # Or use the existing client.def:
    # LINK_FLAGS "-Wl,--def,${CMAKE_CURRENT_SOURCE_DIR}/client.def"
)
```

MinGW supports `.def` files directly in the linker. Using the existing `client.def` to export the 171 symbols that module DLLs need.

**Generate import library for modules:**
The MinGW linker automatically generates an import library (`libmeridian.dll.a` or `meridian.lib`) when building an executable with exports. Alternatively:
```bash
x86_64-w64-mingw32-dlltool --def client.def --dllname meridian.exe --output-lib libmeridian.a
```

**Subsystem:**
```cmake
target_link_options(meridian PRIVATE -mwindows)  # Windows subsystem (no console)
```

### OpenAL Soft

The vendored `external/openal-soft/` only contains pre-built Windows binaries and import libraries. For MinGW cross-compilation:
- Use the existing `libs/Win64/OpenAL32.lib` as the import library (MinGW can link against MSVC `.lib` import libraries in many cases)
- Or generate a MinGW import library from the DLL: `x86_64-w64-mingw32-dlltool --def openal32.def --dllname soft_oal.dll --output-lib libOpenAL32.a`
- Ship `soft_oal.dll` (renamed to `OpenAL32.dll`) alongside the client for Wine

### Known Compilation Issues to Fix

1. **`#pragma warning` directives** (3 occurrences) -- Wrap in `#ifdef _MSC_VER`
2. **`<sys\stat.h>` backslash** -- Change to `<sys/stat.h>` (or it may work as-is with MinGW)
3. **`AFX_DIALOG_LAYOUT` in client.rc** -- Wrap in `#ifdef APSTUDIO_INVOKED`
4. **MinGW `-Werror` compatibility** -- MinGW's g++ may produce different warnings than MSVC. May need additional `-Wno-*` flags. Address iteratively.
5. **`-fms-extensions`** -- May be needed for nameless struct/union usage in D3D types
6. **`NODEFAULTLIB:libc`** -- Replace with MinGW equivalent (`-nostdlib` not needed; MinGW doesn't have this conflict)

### Verification
- `meridian.exe` compiles and links cleanly
- File type check: `file meridian.exe` shows "PE32+ executable (GUI) x86-64, for MS Windows"
- `wine meridian.exe` launches (may not fully work yet without modules, but should start)

---

## Phase 6: Cross-Compiled Module DLLs [sonnet] ✅

**Goal:** Build all 6 module DLLs that plug into the client.

### Module Build Pattern

Each module:
1. Compiles its `.c` sources as C++20
2. Compiles its `.rc` resource file with `windres`
3. Links as a DLL against `libmeridian.a` (import library for the client EXE) plus Win32 libs
4. Uses its `.def` file for ordinal exports

### Modules

| Module | Sources | DEF exports |
|--------|---------|-------------|
| merintr | 26 `.c` files + `merintr.rc` | 19 ordinals |
| char | 8 `.c` files + `char.rc` | 3 ordinals |
| admin | 3 `.c` files + `admin.rc` | 6 ordinals |
| dm | 4 `.c` files + `dm.rc` | 5 ordinals |
| mailnews | 6 `.c` files + `mailnews.rc` | 6 ordinals |
| chess | 3 `.c` files + `chess.rc` | 4 ordinals |

### CMake Pattern for Each Module

```cmake
add_library(merintr SHARED ${MERINTR_SOURCES} ${MERINTR_RC})
target_include_directories(merintr PRIVATE
    ${CMAKE_SOURCE_DIR}/clientd3d
    ${CMAKE_SOURCE_DIR}/include
    ${CLIENT_GENERATED_DIR}  # For trig.h, pal.c
)
target_link_libraries(merintr PRIVATE meridian user32 gdi32 comctl32)
set_target_properties(merintr PROPERTIES
    PREFIX ""  # No "lib" prefix
    LINK_FLAGS "-Wl,--def,${CMAKE_CURRENT_SOURCE_DIR}/merintr.def"
)
```

### Module Resource Files

Each module has its own `.rc` file (merintr.rc, char.rc, etc.) defining dialog resources. Compile with `windres` same as the client.

### Verification
- All 6 DLLs compile and link cleanly
- `file merintr.dll` shows "PE32+ executable (DLL) x86-64, for MS Windows"
- DLLs export the correct ordinals (check with `x86_64-w64-mingw32-objdump -p merintr.dll | grep Export`)

---

## Phase 7: Build Integration & Testing [sonnet] ✅

**Goal:** Wire everything together, add install targets, and test under Wine.

### 7a. CMake Install Targets

```cmake
# Native binaries
install(TARGETS blakserv DESTINATION run/server/)
install(TARGETS bc rscmerge rscprint DESTINATION bin/)

# Cross-compiled client
install(FILES ${CLIENT_BUILD}/meridian.exe DESTINATION run/localclient/)
install(FILES ${CLIENT_BUILD}/merintr.dll DESTINATION run/localclient/resource/)
install(FILES ${CLIENT_BUILD}/char.dll DESTINATION run/localclient/resource/)
# ... etc for all modules
install(FILES external/openal-soft/.../soft_oal.dll
        DESTINATION run/localclient/ RENAME OpenAL32.dll)
```

### 7b. Blakod Compilation Integration

Add a custom target `kod` that:
1. Depends on the `bc` native executable
2. Invokes `bc` for each `.kod` file in dependency order
3. Copies `.bof` files to `run/server/loadkod/`

### 7c. Wine Testing

Create a convenience script `run-client.sh`:
```bash
#!/bin/bash
cd run/localclient
wine meridian.exe "$@"
```

### 7d. CI Integration

Add a GitHub Actions job for the CMake Linux cross-compile build:
```yaml
build-linux-cmake:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install dependencies
      run: sudo apt-get install -y cmake g++ mingw-w64 flex bison
    - name: Configure
      run: cmake -B build
    - name: Build
      run: cmake --build build -j$(nproc)
```

### Verification
- `cmake -B build && cmake --build build` builds everything from scratch
- Native: `blakserv` starts on Linux
- Native: `bc` compiles `.kod` files
- Cross: `wine run/localclient/meridian.exe` launches the client
- Cross: Module DLLs load correctly under Wine

---

## Phase 8: 32-bit Support (Optional) [sonnet]

**Goal:** Add support for building as 32-bit Windows binaries (x86).

The original Windows builds target both x86 and x64. Some Wine compatibility may be better with 32-bit builds. This phase adds a `cmake/mingw-w64-i686.cmake` toolchain file using `i686-w64-mingw32-g++`.

**Requires:** `sudo apt install gcc-mingw-w64-i686 g++-mingw-w64-i686`

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MinGW C++20 warnings differ from MSVC | High | Low | Add `-Wno-*` flags iteratively |
| `windres` rejects parts of `.rc` files | Medium | Low | Only `AFX_DIALOG_LAYOUT` is known issue; wrap in ifdef |
| D3D9 headers incomplete in MinGW-w64 | Low | Medium | MinGW-w64 ships comprehensive D3D9 headers; test early |
| OpenAL import library incompatibility | Low | Low | Generate MinGW import lib with `dlltool` |
| Module DLL loading fails under Wine | Low | Medium | Wine has excellent PE loader; test ordinal exports |
| Kod compilation order breaks in CMake | Medium | Medium | Must preserve exact BOFS ordering from existing makefiles |
| Code generators need native+cross setup | Expected | Low | Superbuild pattern handles this cleanly |

## Estimated Effort

| Phase | Effort | Description |
|-------|--------|-------------|
| Phase 1 | 2-3 hours | CMake infrastructure, toolchain files |
| Phase 2 | 3-4 hours | Native targets (server, compiler, utils, kod) |
| Phase 3 | 1-2 hours | Cross-compiled external libraries |
| Phase 4 | 1-2 hours | Code generators and rscload |
| Phase 5 | 4-6 hours | Client cross-compilation (bulk of the work) |
| Phase 6 | 2-3 hours | Module DLLs |
| Phase 7 | 2-3 hours | Integration, install targets, testing |
| **Total** | **~15-23 hours** | |

The main uncertainty is Phase 5 -- the client has 109 source files and may surface MinGW-specific compilation issues that need individual attention.
