# Meridian 59 Client — Linux Build System Port

## Status: PLANNING

## Goal

Get the Meridian 59 client codebase (`clientd3d` + modules + external deps) compiling on Linux using CMake, with stub implementations for all Win32/D3D9 APIs. Nothing needs to run yet — the goal is a clean compile and link.

## Current Build System

The existing build uses **NMAKE** (Microsoft's make) with MSVC (`cl.exe`, C++20 mode):

```
common.mak          — Shared compiler flags, paths, defines
rules.mak           — Pattern rules (.c → .obj)
makefile             — Top-level build orchestration
clientd3d/makefile   — Client executable (meridian.exe)
module/module.mak    — Shared module build config
module/*/makefile    — Per-module DLL builds (merintr, char, admin, dm, chess, mailnews)
external/*/makefile  — External library builds (zlib, libpng, libarchive)
util/makefile        — Utility library (rscload.lib)
```

### Key Build Characteristics

- **Compiler**: MSVC, `/TP` (force C++ mode for .c files), `-std:c++20`, `/WX` (warnings-as-errors), `/GR-` (no RTTI), `/MT` (static CRT)
- **Defines**: `BLAK_PLATFORM_WINDOWS`, `WIN32`, `BLAKCLIENT`, `FMT_UNICODE=0`, `STB_VORBIS_NO_PUSHDATA_API`
- **Generated files at build time**:
  - `trig.c` + `trig.h` — from `maketrig.c` (precomputed sin/cos lookup tables, 4096 entries)
  - `pal.c` — from `makepal.c` using `blakston.pal` (palette, lighting tables, blend tables)
- **Client output**: `meridian.exe` (Windows subsystem), also generates `meridian.lib` (import library for modules)
- **Module output**: `.dll` files loaded at runtime via `LoadLibrary`/`GetProcAddress` by ordinal
- **Module linkage**: Modules link against `meridian.lib` to call ~164 exported client functions

## Build Targets

### External Libraries (build from source)

| Library | Source Files | Current Build | Linux Strategy |
|---------|-------------|---------------|----------------|
| **zlib** | 15 .c files | `external/zlib/makefile` → `zlib.lib` | Use system `libz` via `find_package(ZLIB)` |
| **libpng** | 15 .c files | `external/libpng/makefile` → `libpng.lib` | Use system `libpng` via `find_package(PNG)` |
| **libarchive** | ~110 .c files | `external/libarchive/makefile` → `libarchive.lib` | Use system `libarchive` via `pkg_check_modules` |
| **OpenAL Soft** | Pre-built binary | Copies DLL from `external/openal-soft/openal-soft-1.24.3-bin/` | Use system `libopenal` via `find_package(OpenAL)` |
| **stb_vorbis** | 1 .c file (header-only style) | Compiled as part of clientd3d | Same — compile `external/stb/stb_vorbis.c` directly |
| **fmtlib** | Header-only | Include path only | Same — include path to `external/fmtlib/` |

On Linux, zlib, libpng, libarchive, and OpenAL are all available as system packages with pkg-config support. No need to build from source.

### Utility Library

| Library | Source Files | Notes |
|---------|-------------|-------|
| **rscload** | `util/rscload.c`, `util/memmap.c` | Resource file loader + memory-mapped I/O. Links as `rscload.lib`. |

`memmap.c` uses `CreateFileMapping`/`MapViewOfFile` — needs a Linux stub or mmap replacement. `rscload.c` may be more portable. For this phase, stubs are fine.

### Code Generators

| Tool | Source | Input | Output | Notes |
|------|--------|-------|--------|-------|
| `maketrig` | `clientd3d/maketrig.c` | Constants from `drawdefs.h`, `fixedpt.h` | `trig.c`, `trig.h` | Pure math, trivial to port. Uses `#include <process.h>` (Windows), backslash paths. |
| `makepal` | `clientd3d/makepal.c` | `blakston.pal` (256 RGB triplets) | `pal.c` | Palette + lighting tables + blend tables. Similar portability issues. |

**Strategy**: Port both generator tools to compile on Linux (minimal changes), run them at build time as custom commands, or pre-generate and commit the output files.

### Client Executable

**97 source files** (from `clientd3d/makefile`):

```
client.c      list.c        modules.c     map.c         msgfiltr.c
loadrsc.c     protocol.c    com.c         draw3d.c      object3d.c
overlay.c     moveobj.c     tooltip.c     annotate.c    idlist.c
roomanim.c    statconn.c    memmap.c      mapfile.c     boverlay.c
web.c         about.c       login.c       srvrstr.c     effect.c
bitmap.c      download.c    select.c      logoff.c      transfer.c
statoffl.c    cursor.c      client3d.c    xlat.c        rops.c
profane.c     object.c      graphics.c    winmsg.c      server.c
dialog.c      draw.c        graphctl.c    animate.c     config.c
projectile.c  uselist.c     move.c        startup.c     keyhook.c
toolbar.c     game.c        intrface.c    ownerdrw.c    util.c
table.c       statterm.c    statgame.c    font.c        textin.c
msgbox.c      editbox.c     gameuser.c    offer.c       maindlg.c
lookdlg.c     color.c       say.c         sound.c       music.c
audio_openal.c key.c        buy.c         statstrt.c    dibutil.c
drawbsp.c     bspload.c     parse.c       drawbmp.c     winmenu.c
cache.c       ping.c        objdraw.c     lagbox.c      regexpr.c
fixed.c       d3dcache.c    d3ddriver.c   d3dparticle.c d3drender.c
d3drender_bgoverlays.c      d3drender_fx.c
d3drender_lights.c          d3drender_materials.c
d3drender_objects.c         d3drender_skybox.c
d3drender_textures.c        d3drender_world.c
matrix.c      xform.c       signup.c      preferences.c
```

Plus from other dirs:
- `util/md5.c`, `util/crc.c` — compiled directly into client
- `external/stb/stb_vorbis.c` — compiled directly into client

Plus generated:
- `trig.c` (from maketrig)
- `pal.c` (from makepal)

Plus resource:
- `client.rc` → `client.res` (Win32 resource file — skip on Linux)

### Module Shared Libraries

| Module | Source Files | Notes |
|--------|-------------|-------|
| **merintr** | 29 .c files + merintr.rc | Main gameplay UI (inventory, spells, stats, guild, etc.) |
| **char** | 8 .c files + char.rc | Character creation/selection |
| **admin** | 3 .c files + admin.rc | Admin tools |
| **dm** | 4 .c files + dm.rc | DM (game master) tools |
| **chess** | 3 .c files + chess.rc | Chess minigame |
| **mailnews** | 6 .c files + mailnews.rc | In-game mail |

Modules export event handlers by **ordinal** (not by name) via .def files. On Linux, `dlsym` works by name, not ordinal. Options:
1. **Static linking**: Compile modules directly into the client (simplest, loses dynamic loading)
2. **Name-based dlsym**: Change to named exports, update module loader
3. **Function pointer table**: Module exports a single `GetModuleInterface()` that returns a struct of function pointers

## Implementation Plan

### Step 1: Create top-level CMakeLists.txt [sonnet]

Create a CMake project at the Meridian 59 repo root that builds:
1. External deps (find system packages or build from source)
2. Utility library (rscload)
3. Code generators (maketrig, makepal)
4. Client executable
5. Module shared libraries

Structure:
```
Meridian59/
  CMakeLists.txt                    ← NEW: top-level project
  cmake/
    FindDependencies.cmake          ← NEW: find_package wrappers
    Platform.cmake                  ← NEW: platform detection & flags
  clientd3d/
    CMakeLists.txt                  ← NEW: client build
    osd_linux.h                     ← NEW: Win32 type compatibility shim
    osd_linux.c                     ← NEW: Win32 function stubs
    d3d_stub.h                      ← NEW: D3D9 type/function stubs
  module/
    CMakeLists.txt                  ← NEW: module builds
  util/
    CMakeLists.txt                  ← NEW: rscload library
```

### Step 2: Platform compatibility header (osd_linux.h) [sonnet]

Following the server's `blakserv/osd_linux.h` pattern. Map Win32 types and functions to POSIX equivalents or stubs:

```c
// Types
typedef int SOCKET;
typedef unsigned int DWORD;
typedef int BOOL;
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef void* HANDLE;
typedef void* HWND;
typedef void* HINSTANCE;
typedef void* HDC;
typedef void* HBITMAP;
typedef void* HFONT;
typedef void* HBRUSH;
typedef void* HPEN;
typedef void* HPALETTE;
typedef void* HCURSOR;
typedef void* HMENU;
typedef void* HRGN;
typedef void* HMODULE;
typedef long LONG;
typedef long LRESULT;
typedef unsigned long WPARAM;
typedef long LPARAM;
// ... etc

// Socket compat
#define closesocket close
#define SOCKET_ERROR -1
#define INVALID_SOCKET -1
#define WSAEWOULDBLOCK EWOULDBLOCK

// String compat
#define stricmp strcasecmp
#define strnicmp strncasecmp
#define _stricmp strcasecmp

// Path compat
#define MAX_PATH PATH_MAX
#define O_BINARY 0

// Constants
#define TRUE 1
#define FALSE 0

// Win32 message constants (stub values)
#define WM_USER 0x0400
#define WM_PAINT 0x000F
#define WM_TIMER 0x0113
// ... etc

// Structures (minimal stubs)
typedef struct { int left, top, right, bottom; } RECT;
typedef struct { int x, y; } POINT;
typedef struct { int cx, cy; } SIZE;
typedef struct { int bmWidth, bmHeight; /* ... */ } BITMAP;
typedef struct tagMSG { HWND hwnd; unsigned int message; WPARAM wParam; LPARAM lParam; } MSG;
// ... etc
```

This will be large but mechanical. The server's version is ~80 lines; the client will need ~300-400 lines because of the much wider Win32 API surface.

### Step 3: D3D9 stub header (d3d_stub.h) [sonnet]

Stub out all Direct3D 9 types and interfaces so the D3D rendering code compiles but does nothing:

```c
// D3D types that appear in headers/structs throughout the codebase
typedef void* LPDIRECT3D9;
typedef void* LPDIRECT3DDEVICE9;
typedef void* LPDIRECT3DTEXTURE9;
typedef void* LPDIRECT3DVERTEXBUFFER9;
typedef void* LPDIRECT3DINDEXBUFFER9;
typedef void* LPDIRECT3DVERTEXDECLARATION9;
typedef void* LPDIRECT3DSURFACE9;

// D3D enums used in code
typedef int D3DFORMAT;
typedef int D3DDEVTYPE;
typedef int D3DPOOL;
typedef int D3DPRIMITIVETYPE;
typedef int D3DTRANSFORMSTATETYPE;
typedef int D3DRENDERSTATETYPE;
typedef int D3DTEXTURESTAGESTATETYPE;
typedef int D3DSAMPLERSTATETYPE;
// ... plus all D3DRS_*, D3DFMT_*, D3DPT_*, etc. as #defines

// D3D structures
typedef struct { float _11, _12, _13, _14; /* ... */ } D3DMATRIX;
typedef struct { float x, y, z; } D3DVECTOR;
typedef struct { int Width, Height, Format, Pool; } D3DSURFACE_DESC;
// ... etc

// D3D function stubs (macros that expand to no-ops or return S_OK)
#define IDirect3D9_CreateDevice(...) E_FAIL
#define IDirect3DDevice9_BeginScene(...) S_OK
#define IDirect3DDevice9_EndScene(...) S_OK
#define IDirect3DDevice9_Present(...) S_OK
#define IDirect3DDevice9_Clear(...) S_OK
// ... etc
```

### Step 4: Modify client.h for platform selection [sonnet]

Add `#ifdef BLAK_PLATFORM_LINUX` blocks to `client.h` (the master include header) to:
- Skip Windows headers (`windows.h`, `windowsx.h`, `commctrl.h`, `richedit.h`, `winsock.h`, `wininet.h`, `d3d9.h`, etc.)
- Include `osd_linux.h` and `d3d_stub.h` instead
- Keep all game logic headers unchanged

### Step 5: Port code generators [sonnet]

Port `maketrig.c` and `makepal.c` to compile on Linux:
- Remove `#include <process.h>` 
- Fix backslash path separators → forward slash
- Fix any MSVC-specific constructs
- Add as CMake custom commands that run at build time

Alternative: pre-generate `trig.c`, `trig.h`, `pal.c` and commit them.

### Step 6: Win32 function stubs (osd_linux.c) [sonnet]

Provide stub implementations for every Win32 function called from game code that isn't already handled by `osd_linux.h` macros. These stubs just need to compile and link — they don't need to do anything useful yet.

Categories of stubs needed:
- **Window management**: `CreateWindow`, `DestroyWindow`, `ShowWindow`, `UpdateWindow`, `SetWindowText`, `GetClientRect`, `MoveWindow`, `InvalidateRect`, `GetWindowRect`, etc.
- **Message loop**: `PeekMessage`, `GetMessage`, `TranslateMessage`, `DispatchMessage`, `PostMessage`, `SendMessage`, `DefWindowProc`
- **Dialog**: `DialogBoxParam`, `CreateDialogParam`, `EndDialog`, `GetDlgItem`, `SetDlgItemText`, `GetDlgItemText`, `SetDlgItemInt`, `CheckDlgButton`, etc.
- **GDI**: `GetDC`, `ReleaseDC`, `CreateCompatibleDC`, `DeleteDC`, `SelectObject`, `DeleteObject`, `BitBlt`, `StretchBlt`, `CreateCompatibleBitmap`, `CreateFont`, `TextOut`, `DrawText`, `SetTextColor`, `SetBkColor`, `FillRect`, `GetPixel`, `SetPixel`, etc.
- **Controls**: `CreateWindowEx` (for edit, listbox, combobox, toolbar, trackbar), `SendMessage` with control-specific messages (LB_ADDSTRING, CB_SETCURSEL, etc.)
- **Resources**: `LoadString`, `LoadIcon`, `LoadCursor`, `LoadBitmap`, `GetObject`
- **Config/INI**: `GetPrivateProfileString`, `GetPrivateProfileInt`, `WritePrivateProfileString`
- **File/Memory**: `CreateFileMapping`, `MapViewOfFile`, `UnmapViewOfFile`, `CloseHandle`
- **Timers**: `SetTimer`, `KillTimer`, `GetTickCount`, `QueryPerformanceCounter`, `QueryPerformanceFrequency`, `timeGetTime`
- **Misc**: `SetWindowsHookEx`, `UnhookWindowsHookEx`, `SetCapture`, `ReleaseCapture`, `ClipCursor`, `SetCursorPos`, `GetKeyboardState`, `GetAsyncKeyState`, `ShellExecute`, `GetModuleFileName`, `Sleep`

This is the most tedious step — there could be 100+ functions to stub. The approach:
1. Attempt to compile
2. Collect all unresolved symbols
3. Add stubs iteratively until it links

### Step 7: Fix compilation errors [sonnet]

Beyond missing functions, there will be:
- MSVC-specific constructs (`__declspec(dllexport)`, `__forceinline`, etc.)
- Windows-specific headers included transitively
- Win32 control macros from `<windowsx.h>` (e.g., `HANDLE_MSG`, `Button_GetCheck`, `ComboBox_SetCurSel`)
- `#pragma comment(lib, ...)` directives (ignored on Linux)
- Resource compilation (`client.rc`) — skip entirely on Linux
- `.def` file exports — handle via CMake `EXPORT` or visibility attributes

### Step 8: Validate clean build [sonnet]

- `cmake -B build -DBLAK_PLATFORM_LINUX=ON`
- `cmake --build build`
- All targets compile and link with zero errors
- The resulting binary can be executed and immediately exits (since everything is stubbed)

## Compiler Flag Mapping

| MSVC Flag | GCC/Clang Equivalent | Notes |
|-----------|---------------------|-------|
| `/TP` | `-x c++` | Force C++ compilation of .c files |
| `-std:c++20` | `-std=c++20` | C++20 standard |
| `/WX` | `-Werror` | Warnings as errors (maybe relax initially) |
| `/GR-` | `-fno-rtti` | No RTTI |
| `/EHsc-` | `-fno-exceptions` | No exceptions |
| `/MP` | `-j N` (make level) | Parallel compilation |
| `/MT` | N/A | Static CRT (not applicable on Linux) |
| `/W3` | `-Wall` | Warning level |
| `/wd4996` | `-Wno-deprecated-declarations` | Suppress deprecation warnings |
| `/NODEFAULTLIB:libc` | N/A | Not applicable |
| `/SUBSYSTEM:WINDOWS` | N/A | Not applicable |

## System Dependencies (Arch/CachyOS)

All required packages are already installed:

| Package | Version | pkg-config name |
|---------|---------|----------------|
| `libpng` | 1.6.55 | `libpng` / `libpng16` |
| `zlib-ng-compat` | 2.3.3 | `zlib` |
| `openal` | 1.25.1 | `openal` |
| `libarchive` | 3.8.5 | `libarchive` |
| `cmake` | 4.2.3 | — |
| `gcc` | 15.2.1 | — |

Optional (not needed for build-only, but will be needed later):
| `sdl2-compat` | 2.32.64 | `sdl2` |
| `curl` | 8.18.0 | `libcurl` |

## Module Build Strategy (for this phase)

For the initial build system port, the simplest approach is **static linking** of modules:
- Compile all module source files directly into the client executable
- Skip the DLL/.so complexity entirely
- This avoids the ordinal-vs-name export problem
- Can be revisited later when actually implementing module loading

Alternative: build modules as `.so` files but defer the symbol export redesign.

## Risks & Open Questions

1. **Stub completeness**: How many Win32 functions will need stubs? Could be 100+. Iterative approach (compile → fix → repeat) is the way.
2. **windowsx.h macros**: The client uses `HANDLE_MSG`, `FORWARD_WM_*`, and control macros heavily. Need to either provide a compat header or rewrite the call sites.
3. **C++ mode for .c files**: GCC/Clang handle this differently from MSVC. May surface name-mangling or linkage issues.
4. **Warning flood**: GCC 15 with `-Wall -Werror` will likely flag many more things than MSVC `/W3 /WX`. May need to relax initially.
5. **Keeping Windows building**: Should the CMake system support both platforms, or is it Linux-only? Supporting both from the start is more work but prevents divergence.

## Success Criteria

- [ ] `cmake --build build` completes with zero errors on Linux
- [ ] All 97 client source files compile
- [ ] All 6 module source sets compile (53 files total)
- [ ] Generated files (trig.c/h, pal.c) are produced at build time
- [ ] Binary links against system libpng, zlib, libarchive, OpenAL
- [ ] Binary can be executed (and immediately exits / prints "not implemented")
