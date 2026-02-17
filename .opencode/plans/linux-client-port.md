# Meridian 59 Client Linux Port

## Status: PLANNING

## Overview

Port the Meridian 59 `clientd3d` (~92K lines of C/C++) from Windows to Linux by creating a platform abstraction layer, following the server's `osd_linux.c` / `osd_windows.c` pattern. Replace Win32/D3D9 dependencies incrementally with cross-platform alternatives.

## Current State

| Subsystem | Windows API | Lines | Cross-Platform? |
|-----------|-------------|-------|----------------|
| Audio | OpenAL Soft | ~800 | Yes (already) |
| Networking | WinSock + WSAAsyncSelect | ~800 | Mostly (BSD sockets, but coupled to message pump) |
| Config/INI | GetPrivateProfileString | ~600 | No (124 occurrences) |
| File I/O | CreateFile, MapViewOfFile | ~400 | No (33 occurrences) |
| Rendering | Direct3D 9 | ~13,000 | No (596 D3D calls, 27 files) |
| 2D Drawing | GDI (HDC, BitBlt) | ~3,000 | No (326 occurrences) |
| Windowing/UI | Win32 (HWND, dialogs) | ~5,000 | No (794 occurrences) |
| Input | WndProc + GetKeyboardState | ~1,000 | No |
| Module System | LoadLibrary/DLLs | ~500 | No (17 occurrences) |
| Resources | .rc file (strings, dialogs, menus) | ~400 | No |
| HTTP | WinInet | ~200 | No (19 occurrences) |

## Architecture & Coupling Analysis

### The Central Bottleneck: Win32 Message Pump

Everything flows through the Win32 message loop in `client.c`:
- **Network data**: WSAAsyncSelect posts BK_SOCKETEVENT to HWND → WndProc → MainReadSocket
- **Rendering**: MainIdle → GameIdle → AnimationTimerProc → RedrawAll → DrawRoom → D3DRenderBegin
- **Input**: WM_KEYDOWN/WM_MOUSEMOVE → WndProc → ModuleEvent
- **Timers**: SetTimer → WM_TIMER → WndProc
- **Module events**: PostMessage → BK_MODULEUNLOAD

### Natural Seams for Abstraction

1. **Protocol layer** (`ProcessMsgBuffer`, `HandleMessage`) is already decoupled from Win32
2. **Action system** (`TranslateKey` → `PerformAction`) is already abstracted from raw input
3. **Render entry point** is clean: `D3DRenderBegin(room, params)` is the single entry
4. **Game logic** (matrix.c, fixed.c, bspload.c, animate.c, moveobj.c, object.c) is mostly platform-independent
5. **Audio** is already cross-platform (OpenAL Soft)

## Phased Porting Plan

### Phase 0: Build System & Compilation [sonnet]
**Goal**: Get the client compiling on Linux (with stubs) using CMake.

- [ ] Create `CMakeLists.txt` for the client (replacing NMAKE/MSVC)
- [ ] Create `clientd3d/osd_linux.h` with Win32 type mappings (following server pattern):
  - HWND, HINSTANCE, DWORD, HANDLE → int/void*
  - closesocket → close
  - stricmp → strcasecmp
  - MAX_PATH → PATH_MAX
  - FD_READ/FD_WRITE/FD_CLOSE → constants
- [ ] Create `clientd3d/osd_linux.c` with stub implementations for Win32 GUI functions
- [ ] Add `#ifdef BLAK_PLATFORM_LINUX` to `client.h` to select platform headers
- [ ] Stub out all D3D9 headers/types/functions so code compiles
- [ ] Get clean compile on Linux with all gameplay disabled (just builds, links with stubs)

### Phase 1: Networking [sonnet]
**Goal**: TCP communication works on Linux.

- [ ] Replace `WSAStartup`/`WSACleanup` with no-ops on Linux
- [ ] Replace `WSAAsyncSelect` with poll()-based check in MainIdle loop
- [ ] Replace `WSAGetLastError` with errno
- [ ] Map `SOCKET`/`closesocket`/`SOCKET_ERROR` via osd_linux.h
- [ ] Replace `WSAAsyncSelect` event delivery (BK_SOCKETEVENT window message) with direct function calls from a poll loop
- [ ] Test: client connects to server, completes login handshake, receives game state
- [ ] Replace WinInet HTTP calls (`web.c`, `transfer.c`) with libcurl

### Phase 2: Windowing & Event Loop (SDL2) [opus]
**Goal**: Window creation, input handling, and event loop work on Linux.

- [ ] Add SDL2 dependency
- [ ] Replace WinMain + message pump with SDL2 event loop
  - `SDL_CreateWindow` replaces `CreateWindow`
  - `SDL_PollEvent` replaces `PeekMessage`/`GetMessage`
  - SDL_KEYDOWN/SDL_MOUSEMOTION etc replace WM_KEYDOWN/WM_MOUSEMOVE
- [ ] Replace `GetKeyboardState()` polling with `SDL_GetKeyboardState()`
- [ ] Replace mouse input (capture, cursor position, cursor shape) with SDL2 equivalents
- [ ] Replace `SetTimer`/`KillTimer` with SDL timer or manual timing in main loop
- [ ] Replace cursor management (LoadCursor, SetCursor, ClipCursor) with SDL2
- [ ] Integrate network polling into the SDL event loop (via SDL_AddTimer or manual poll in idle)
- [ ] Test: window opens, receives input events, network events still work

### Phase 3: Rendering (D3D9 → OpenGL 3.3) [opus]
**Goal**: 3D world rendering works on Linux.

This is the largest and hardest phase. The D3D9 renderer spans ~13K lines across 27 files.

- [ ] Create OpenGL 3.3 context via SDL2 (SDL_GL_CreateContext)
- [ ] Port D3D9 initialization (`D3DRenderInit`) to OpenGL
- [ ] Port vertex format (D3DVERTEXELEMENT9 → VAO/VBO with glVertexAttribPointer)
- [ ] Port render states (D3DRS_* → glEnable/glBlendFunc/glDepthFunc)
- [ ] Port texture management (IDirect3DTexture9 → GLuint textures)
- [ ] Port world rendering (`d3drender_world.c` - BSP geometry, walls, floors, ceilings)
- [ ] Port object rendering (`d3drender_objects.c` - sprites, 3D objects)
- [ ] Port particle system (`d3dparticle.c`)
- [ ] Port lighting (`d3drender_lights.c`)
- [ ] Port skybox (`d3drender_skybox.c`)
- [ ] Port effects/materials (`d3drender_fx.c`, `d3drender_materials.c`)
- [ ] Port overlays/HUD (`d3drender_overlays.c`)
- [ ] Write basic GLSL shaders to replace fixed-function pipeline
- [ ] Test: rooms render correctly, objects display, particles work

### Phase 4: 2D Drawing & UI [opus]
**Goal**: Game UI renders correctly on Linux.

- [ ] Replace GDI 2D drawing (HDC, BitBlt, CreateCompatibleDC) with SDL2 surfaces or OpenGL quads
- [ ] Replace Win32 font rendering (CreateFont, TextOut, DrawText) with SDL_ttf or stb_truetype
- [ ] Port minimap rendering
- [ ] Replace RichEdit control with custom text rendering
- [ ] Replace string table (LoadString from .rc) with a data file or embedded strings
- [ ] Replace menu system (HMENU) with custom menus or dear imgui
- [ ] Test: text renders, minimap works, menus functional

### Phase 5: Dialog System [opus]
**Goal**: All gameplay dialogs work on Linux.

- [ ] Choose dialog replacement strategy:
  - Option A: dear imgui for all dialogs (modern, immediate mode)
  - Option B: SDL2 + custom dialog framework
- [ ] Port login dialog
- [ ] Port preferences/settings dialog
- [ ] Port description/look dialogs (gameplay-critical)
- [ ] Port buy/sell dialogs
- [ ] Port offer dialogs
- [ ] Port amount input dialog
- [ ] Port color picker
- [ ] Port all remaining dialogs (~30 total)
- [ ] Test: full gameplay loop with all dialogs

### Phase 6: Module System [sonnet]
**Goal**: Game modules (merintr, char, etc.) load on Linux.

- [ ] Replace `LoadLibrary`/`GetProcAddress` with `dlopen`/`dlsym`
- [ ] Change module file extension from .dll to .so
- [ ] Remove Win32 types from `ClientInfo` struct (HWND, HINSTANCE, etc.)
- [ ] Build merintr module for Linux
- [ ] Port merintr's Win32 controls (toolbar, stat bars, inventory list, spell list) to SDL2/imgui
- [ ] Build and port remaining modules (char, admin, dm, chess, mailnews)
- [ ] Test: modules load, merintr UI functional

### Phase 7: Resource System & Polish [sonnet]
**Goal**: All resources load correctly, no Windows dependencies remain.

- [ ] Move string tables from .rc to a loadable data file (JSON, TOML, or custom format)
- [ ] Move dialog templates to code or data files
- [ ] Replace icon/cursor resources with PNG/SVG files loaded at runtime
- [ ] Replace bitmap resources
- [ ] Replace `GetPrivateProfileString`/`WritePrivateProfileString` with a cross-platform INI parser (or TOML)
- [ ] Replace memory-mapped file I/O (CreateFileMapping/MapViewOfFile) with mmap()
- [ ] Final cleanup: remove all `#ifdef BLAK_PLATFORM_WINDOWS` dead code paths (or keep for dual-platform)
- [ ] Test: full game session on Linux from login to gameplay

## Technology Choices

| Component | Recommendation | Rationale |
|-----------|---------------|-----------|
| Build system | CMake | Industry standard, cross-platform |
| Windowing | SDL2 | Mature, well-tested, handles X11/Wayland |
| Rendering | OpenGL 3.3 | Widest Linux compatibility; D3D9 maps well to GL3 |
| Audio | OpenAL Soft | Already in use |
| UI/Dialogs | dear imgui | Immediate mode, minimal deps, easy to embed in OpenGL |
| Fonts | stb_truetype or SDL_ttf | Cross-platform, no system deps |
| HTTP | libcurl | Standard, replaces WinInet |
| INI config | Custom or inih | Simple, replaces GetPrivateProfileString |
| Shared libs | dlopen/dlsym | POSIX equivalent of LoadLibrary |

## Effort Estimates

| Phase | Estimated Effort | Complexity |
|-------|-----------------|------------|
| Phase 0: Build & Compile | 1-2 weeks | Medium |
| Phase 1: Networking | 1 week | Low-Medium |
| Phase 2: Windowing & Events | 2-3 weeks | Medium-High |
| Phase 3: Rendering | 6-10 weeks | Very High |
| Phase 4: 2D Drawing & UI | 3-4 weeks | High |
| Phase 5: Dialog System | 3-4 weeks | High |
| Phase 6: Module System | 2-3 weeks | Medium |
| Phase 7: Resources & Polish | 2-3 weeks | Medium |
| **Total** | **~20-30 weeks** | |

This is a solo developer estimate. Phases 0-2 could yield a "connects and receives data" milestone. Phase 3 is the critical path -- once rendering works, the rest is UI grind.

## Risks

1. **D3D9→OpenGL translation**: The fixed-function pipeline used by D3D9 doesn't map 1:1 to modern OpenGL. Need shaders.
2. **BSP renderer subtleties**: drawbsp.c (4,389 lines) contains intricate rendering math that must be preserved exactly.
3. **Module system**: merintr module is ~12K lines of Win32 UI code -- essentially a second porting project.
4. **Upstream divergence**: The main repo is actively developed. Need to track changes.
5. **Testing**: No automated tests exist for the client. Manual testing against live server required.

## Alternative: SDL2 + ANGLE

Instead of porting D3D9→OpenGL manually, could use Google's ANGLE library to translate D3D9 calls to OpenGL. This would:
- Preserve the existing D3D9 code unchanged
- Reduce Phase 3 to just linking against ANGLE
- But add a large dependency and potential compatibility issues
- ANGLE's D3D9 translation layer is less mature than D3D11

## Where This Work Happens

This port should be done as a **branch or fork of the main Meridian59 repository** (`~/git/Meridian59/`), not in the m59-package-sniffer repo. The sniffer's protocol knowledge will be useful as reference but the actual work is in the client codebase.
