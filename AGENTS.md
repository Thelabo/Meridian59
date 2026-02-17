# AGENTS.md

This file provides guidance to agentic coding tools (Claude, Cursor, Copilot) when working with the Meridian 59 codebase.

## Project Overview

**Classic Meridian 59** — a 1996 MMORPG, one of the first graphical MMOs.

- **Fork:** `Thelabo/Meridian59` (upstream: `Meridian59/Meridian59`)
- **Language:** C compiled as C++20 (`-x c++` on Linux, `/TP` on Windows)
- **BOF version:** 5 (NOT OpenMeridian105/v8)
- **Platforms:** Server runs on Linux/macOS/Windows; Client is Windows-only (D3D9)

## Repository Structure

```
Meridian59/
├── blakserv/         — Game server (C, ~30K lines, cross-platform)
├── blakcomp/         — Blakod compiler: .kod → .bof + .rsc (C, flex/bison)
├── blakdeco/         — Blakod decompiler
├── clientd3d/        — Game client (C, Win32/D3D9, Windows-only)
├── module/           — Client plugin modules (merintr, char)
├── kod/              — Game scripts (~1,232 .kod files, Blakod language)
├── include/          — Shared headers (bkod.h, bof.h, proto.h, etc.)
├── external/         — Third-party: zlib, libpng, libarchive, fmtlib
├── util/             — Utilities: rscload, rscmerge, rscprint, crc, md5
├── resource/         — Game resources (BGF graphics, WAV audio)
├── run/server/       — Server runtime directory (config, saves, loadkod/)
├── makebgf/          — BGF (graphics format) tool
├── roomedit/         — Room editor
├── club/             — Client updater
├── bbgun/            — BBGun component
├── doc/, docs/       — Documentation
├── .opencode/        — Agent plans and skills
│   ├── plans/        — Project plans (markdown)
│   └── skills/       — Specialized knowledge for agents
├── makefile          — Top-level Windows build (nmake)
├── common.mak        — Shared build config (Windows)
├── common.mak.linux  — Shared build config (Linux/macOS)
├── rules.mak         — Build rules (Windows)
└── rules.mak.linux   — Build rules (Linux/macOS)
```

## Build Commands

### Prerequisites

**Linux/macOS:** `g++` (C++20 support), `flex`, `bison`, `make`
**Windows:** Visual Studio 2022 Community Edition

### Linux / macOS

There is no top-level Linux makefile. Each component is built individually:

```bash
# Build the server
make -f makefile.linux
# (from blakserv/ directory)

# Build the Blakod compiler
make -f makefile.linux
# (from blakcomp/ directory)

# Compile all game scripts (requires bc compiler built first)
make -f makefile.linux
# (from kod/ directory)

# Build utilities
make -f makefile.linux
# (from util/ directory)

# Release build (any component)
make -f makefile.linux RELEASE=1

# Clean (any component)
make -f makefile.linux clean
```

Binaries go to `debug/` (or `release/`) subdirectory. The server binary is also copied to `run/server/`, the compiler to `bin/`.

### Windows

```bash
# Run vcvars32.bat first (Visual Studio Developer Command Prompt)

nmake                          # Build everything (debug)
nmake RELEASE=1                # Build everything (release)
nmake Bserver                  # Server only
nmake Bclient Bmodules         # Client + modules
nmake Bcompiler                # Blakod compiler only
nmake Bkod                     # Compile game scripts (builds compiler first)
nmake clean                    # Clean all
```

### CI

GitHub Actions builds: Linux, macOS, Windows x86, Windows x64. See `.github/workflows/c-cpp.yml`.

## Running the Server

```bash
# From run/server/ directory:
./blakserv                     # Linux/macOS
blakserv.exe                   # Windows

# First-time setup (in the server admin console):
create account admin joe.smith password
create admin <account_id>
save game

# Client connection:
meridian.exe /U:username /W:password /H:localhost /P:5959
```

Configuration: `run/server/blakserv.cfg` (INI format, may need manual edits for Linux paths).

## Code Style

### General

- All C code compiled as C++20 — do NOT use C99/C11 features unavailable in C++
- Platform abstraction via `osd_*.c` / `osd_*.h` files (Windows, Linux, epoll, kqueue)
- `#ifdef BLAK_PLATFORM_LINUX` / `#ifdef BLAK_PLATFORM_WINDOWS` for platform-specific code
- `-Werror` — all warnings are errors on Linux builds
- Output files use `.obj` extension even on Linux

### Naming Conventions

- **Functions:** PascalCase (e.g., `SendBlakodMessage`, `CreateObject`, `InterpretAtMessage`)
- **Variables:** snake_case or camelCase (mixed — follow surrounding code)
- **Constants/Macros:** SCREAMING_SNAKE_CASE (e.g., `MAX_LOCALS`, `BOF_VERSION`, `TAG_INT`)
- **Types:** PascalCase with `_type` suffix for typedefs (e.g., `val_type`, `object_node`, `class_node`)
- **Files:** lowercase, no separators (e.g., `sendmsg.c`, `loadgame.c`, `ccode.c`)

### Blakod (.kod files)

- Comment character: `%`
- Identifiers: PascalCase for classes, camelCase for properties/messages/params
- Class files: one class per `.kod` file, filename matches class name
- See the `meridian59-server` skill for Blakod language details

## Key Architecture

### Server (blakserv)

- **Effectively single-threaded** — all game logic runs under `muxServer` lock
- **Bytecode interpreter** — executes BOF v5 bytecode (58 opcode variants via 6 command types)
- **Tagged values** — 64-bit at runtime (4-bit tag + 60-bit data), 32-bit in BOF files (4-bit tag + 28-bit data)
- **GC** — mark-sweep-compact across objects, lists, strings, timers; tables destroyed during GC
- **Session state machine** — TrySync → Synched → Game (with Resync recovery)
- **Platform I/O** — epoll (Linux), kqueue (macOS), WinSock+MsgWaitForMultipleObjects (Windows)
- **Save format** — binary v1 format, name-based property matching (allows schema evolution)

### Client (clientd3d)

- **Windows-only** — Win32 API, Direct3D 9, OpenAL
- **Module system** — plugin DLLs (merintr, char) loaded at runtime
- **Protocol** — 7-byte header: `[2B len][2B CRC16][2B len_verify][1B epoch]`
- **Security** — per-session seeds, XOR encryption with sliding redbook token

### Blakod Compiler (blakcomp)

- **flex/bison** parser → bytecode emitter
- **Input:** `.kod` source files
- **Output:** `.bof` bytecode (BOF v5) + `.rsc` resource files + `kodbase.txt`
- **60 built-in functions**, 35 built-in identifiers

### Protocol

- **Login phase (AP_*):** version check, authentication, file sync, crypto seed exchange
- **Game phase (BP_*):** ~90 message types, CRC16 validation, XOR token encryption
- **Security:** LCG-based seed advancement: `seed = (seed * 9301 + 49297) % 233280`

## Planning

- Always save plans to disk before starting work. Plans should be written as markdown files in `.opencode/plans/` with a descriptive filename.
- Update the plan document as phases are completed or requirements change.
- Break down large tasks into small, concrete steps. Work on one step at a time — complete and verify it before moving on.
- **NEVER mark a plan as COMPLETE or commit changes without explicitly asking the user first.**

## Model Selection

When using multi-model workflows, use the **`model-selection` skill** for guidance.

**Quick reference:**
- **Opus** — Planning, architectural decisions, ambiguity resolution, novel algorithm design, protocol-level decisions, and tasks where the "what" or "how" isn't fully specified.
- **Sonnet** — Executing well-defined implementation steps, mechanical refactoring, following established code patterns, writing tests, and tasks where the plan specifies exactly what to do.

Plans in `.opencode/plans/` should annotate each step with `[sonnet]` or `[opus]`.

## Active Projects

### Rust Server Port (`blakserv-rs`)

Full Rust replacement for `blakserv`. Drop-in compatible: loads existing BOF v5 bytecode, save files, and serves existing Classic clients. Will live in `blakserv-rs/` in this repo.

**Plan:** `.opencode/plans/blakserv-rust-port.md` (22 phases, ~5-7 months estimated)
**Status:** Planning complete, implementation not started.

### Rust Blakod Compiler (`kod-compiler`)

Rust replacement for `blakcomp`. Produces bit-identical `.bof` and `.rsc` files. Uses existing `tree-sitter-kod` grammar and `kod-parser` crate. Will live in a separate repo (`~/git/kod-compiler/`).

**Plan:** `.opencode/plans/kod-compiler-rust-rewrite.md` (10 phases, ~8-12 weeks estimated)
**Status:** Planning complete, implementation not started.

### Linux Client Port

Port `clientd3d` from Win32/D3D9 to Linux using SDL2/OpenGL. Two-phase approach: first get it compiling with stubs (CMake build system), then replace Win32/D3D APIs.

**Plans:**
- `.opencode/plans/linux-client-buildsystem.md` — CMake build system (Phase 1)
- `.opencode/plans/linux-client-port.md` — Full port (Phase 2, ~20-30 weeks)

**Status:** Planning complete, implementation not started.

## Related Repositories

| Repository | Path | Description |
|-----------|------|-------------|
| `m59-package-sniffer` | `~/git/m59-package-sniffer/` | Meridian 59 protocol decoder, packet sniffer, TUI, web interface |
| `tree-sitter-kod` | `~/git/tree-sitter-kod/` | Complete tree-sitter grammar for the Blakod language |
| `kod-parser` | `~/git/kod-parser/` | Rust: CST→AST, symbol tables, constant evaluation, inheritance resolution |
| `kod-lsp` | `~/git/kod-lsp/` | Full LSP server for Blakod: go-to-def, references, hover, completion, diagnostics |
| `kod.nvim` | `~/git/kod.nvim/` | Neovim integration plugin for Blakod |

## Important Notes

1. **BOF version 5 only** — this fork does NOT use OpenMeridian105 extensions (do-while, switch/case, ++/--, compound assignment, C-style for)
2. **Client is Windows-only** — there is no `clientd3d/makefile.linux`; the Linux client port is a planned project
3. **No top-level Linux makefile** — each component must be built individually with `make -f makefile.linux`
4. **Server runtime** — the server runs from `run/server/` and expects `blakserv.cfg`, `loadkod/` (compiled .bof files), and save directories to exist there
5. **Game assets not in repo** — client artwork (.bgf), rooms (.roo), and audio (.wav/.ogg) are distributed separately
