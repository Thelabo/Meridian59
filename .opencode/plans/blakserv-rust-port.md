# Rust Port of blakserv (Meridian 59 Server)

**Status:** PLANNING  
**GitHub account:** Thelabo  
**Fork:** `Thelabo/Meridian59` (upstream: `Meridian59/Meridian59`)  
**Local path:** `/home/fredde/git/Meridian59/blakserv-rs/`  
**Goal:** Drop-in replacement for `blakserv` — loads existing BOF v5 bytecode, existing save files, and serves existing Classic clients  

## Context

The Meridian 59 server (`blakserv`) is ~30,000 lines of C compiled as C++20. It runs a bytecode interpreter for the Blakod scripting language (1,232 `.kod` files compiled to `.bof` bytecode), manages game objects, handles client connections, and persists game state to disk.

### Existing Rust Ecosystem

| Project | Status | Relevance to Server Port |
|---------|--------|--------------------------|
| `tree-sitter-kod` | Complete | Grammar for Blakod language |
| `kod-parser` | Complete | CST→AST, symbol tables, inheritance resolution |
| `kod-lsp` | Complete | IDE support for Blakod development |
| `kod.nvim` | Complete | Neovim integration |
| `kod-compiler` | Planned | Rust `.kod` → `.bof` compiler (separate plan) |
| `m59-package-sniffer` | Active | Protocol decoding, message types, CRC, token system |

### Constraints

1. **Must load existing save files** — binary format v1 with 64-bit tagged values
2. **Must serve existing Classic clients** — transparent replacement, same protocol
3. **Must load BOF v5 bytecode** — the Blakod compiler is a separate project; the server just loads `.bof` files
4. **Must load existing `.roo` room files** — binary BSP format
5. **Must load existing `.rsc` resource files**
6. **Must read existing `blakserv.cfg` configuration**
7. **Must read existing `kodbase.txt` symbol database

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    blakserv-rs                          │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Network  │  │   VM     │  │  World   │              │
│  │ (tokio)  │──│ (interp) │──│ (objects)│              │
│  └──────────┘  └──────────┘  └──────────┘              │
│       │              │              │                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Protocol │  │ C-Funcs  │  │   GC     │              │
│  │ (reuse   │  │ (80+     │  │ (mark-   │              │
│  │  sniffer)│  │  builtins│  │  compact)│              │
│  └──────────┘  └──────────┘  └──────────┘              │
│       │              │              │                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Sessions │  │ BOF      │  │ Persist  │              │
│  │ (state   │  │ Loader   │  │ (save/   │              │
│  │  machine)│  │          │  │  load)   │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Rooms    │  │ Config   │  │ Admin    │              │
│  │ (.roo)   │  │ (.cfg)   │  │ (text)   │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────┘
```

### Crate Dependencies

| Crate | Purpose | Replaces |
|-------|---------|----------|
| `tokio` (features: full) | Async runtime, TCP, timers | epoll/kqueue/WinSock, systimer |
| `bytes` | Efficient byte buffers | buffer_node, bufpool.c |
| `tracing` + `tracing-subscriber` | Structured logging | channel.c, dprintf/eprintf/lprintf |
| `tracing-appender` | Log file rotation | Daily log rotation systimer |
| `md5` | Password hashing | util/md5.c |
| `crc32fast` | CRC32 calculation | util/crc.c |
| `thiserror` | Error types | (new) |
| `serde` + `toml` (optional) | Config parsing | config.c (if migrating to TOML) |
| `clap` | CLI argument parsing | (new) |
| `byteorder` | Binary format reading | Direct fread() calls |

**NOT needed** (standard library covers it):
- HashMap/BTreeMap replace all custom hash tables (stringinthash, intstringhash, class hash, resource hash)
- Vec replaces all flat arrays (objects, lists, strings)
- String replaces all manual char* management

### Threading Model

The C server is effectively single-threaded for game logic (everything runs under `muxServer`). The Rust port should use a **single-threaded tokio runtime** for game logic, matching this model:

```rust
#[tokio::main(flavor = "current_thread")]
async fn main() {
    // All game logic runs on one thread
    // tokio handles I/O multiplexing (replaces epoll/kqueue)
}
```

This avoids all the complexity of shared mutable game state across threads while still getting async I/O.

---

## Module Structure

```
blakserv-rs/
├── Cargo.toml
├── src/
│   ├── main.rs              — Entry point, initialization sequence, CLI
│   ├── lib.rs               — Public API for testing
│   │
│   ├── val.rs               — Tagged value type (Val enum, 64-bit runtime)
│   ├── bkod.rs              — Bytecode opcode definitions, BOF constants
│   │
│   ├── vm/
│   │   ├── mod.rs            — VM state, top-level send/post
│   │   ├── interpret.rs      — Bytecode interpreter loop (58 opcodes)
│   │   ├── opcodes.rs        — Individual opcode implementations
│   │   ├── stack.rs          — Call stack, local variables
│   │   └── post_queue.rs     — Post message queue
│   │
│   ├── cfunc/
│   │   ├── mod.rs            — C-function dispatch table
│   │   ├── object.rs         — CreateObject, GetClass, IsObject, IsClass
│   │   ├── message.rs        — SendMessage, PostMessage, SendListMessage*
│   │   ├── string.rs         — String operations (12+ functions)
│   │   ├── list.rs           — List operations (20+ functions)
│   │   ├── timer.rs          — CreateTimer, DeleteTimer, GetTimeRemaining
│   │   ├── room.rs           — Room/BSP functions (LoadRoom, CanMove, etc.)
│   │   ├── table.rs          — Table operations (Create, Add, Get, Delete)
│   │   ├── packet.rs         — AddPacket, SendPacket, ClearPacket
│   │   ├── math.rs           — Random, Abs, Bound, Sqrt
│   │   ├── system.rs         — SaveGame, LoadGame, Debug, DumpStack
│   │   └── misc.rs           — GetTime, RecycleUser, RecordStat, etc.
│   │
│   ├── world/
│   │   ├── mod.rs            — GameState: owns all game data
│   │   ├── object.rs         — Object storage (Vec<ObjectNode>)
│   │   ├── class.rs          — Class definitions, hierarchy, property names
│   │   ├── message.rs        — Message dispatch tables, propagation chains
│   │   ├── list.rs           — Cons-cell list storage (Vec<ListNode>)
│   │   ├── string.rs         — Dynamic string storage (Vec<StringNode>)
│   │   ├── timer.rs          — Timer storage (BTreeMap or sorted Vec)
│   │   ├── table.rs          — Hash table storage
│   │   ├── resource.rs       — Resource strings (static + dynamic)
│   │   └── garbage.rs        — Mark-sweep-compact GC
│   │
│   ├── loader/
│   │   ├── mod.rs            — Load orchestration (LoadAll)
│   │   ├── bof.rs            — BOF v5 file parser
│   │   ├── rsc.rs            — .rsc resource file parser
│   │   ├── roo.rs            — .roo room file parser (BSP, grids)
│   │   ├── kodbase.rs        — kodbase.txt parser
│   │   └── config.rs         — blakserv.cfg INI parser
│   │
│   ├── persist/
│   │   ├── mod.rs            — Save/Load orchestration (SaveAll/LoadAll)
│   │   ├── save_game.rs      — Game state writer (v1 format)
│   │   ├── load_game.rs      — Game state reader (v0 + v1 format)
│   │   ├── save_account.rs   — Account file writer
│   │   ├── load_account.rs   — Account file reader
│   │   ├── save_string.rs    — String file writer
│   │   └── load_string.rs    — String file reader
│   │
│   ├── net/
│   │   ├── mod.rs            — Server startup, listener management
│   │   ├── session.rs        — Session state machine (enum SessionState)
│   │   ├── protocol.rs       — Message framing (header parse, CRC, epoch)
│   │   ├── client_parse.rs   — Incoming BP_* message dispatch
│   │   ├── client_send.rs    — Outgoing message construction + security
│   │   ├── login.rs          — AP_* login protocol (STATE_SYNCHED)
│   │   ├── sync.rs           — File sync, try-sync, resync states
│   │   └── security.rs       — Token system, seed management, CRC validation
│   │
│   ├── account.rs            — Account management, authentication
│   ├── user.rs               — User/character management
│   ├── admin/
│   │   ├── mod.rs            — Admin command dispatch
│   │   └── commands.rs       — Individual admin command implementations
│   │
│   ├── room.rs               — Room data storage, movement validation
│   └── error.rs              — Error types
│
└── tests/
    ├── test_val.rs            — Tagged value tests
    ├── test_interpreter.rs    — Bytecode execution tests
    ├── test_bof_loader.rs     — BOF parsing tests
    ├── test_save_load.rs      — Save/load roundtrip tests
    ├── test_protocol.rs       — Protocol framing tests
    └── test_gc.rs             — Garbage collection tests
```

---

## Core Type Definitions

### Tagged Value (`val.rs`) [sonnet]

```rust
/// Runtime tagged value — 64-bit (4-bit tag + 60-bit data).
/// In BOF files these are packed as 32-bit (4-bit tag + 28-bit data).
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Val {
    raw: i64,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tag {
    Nil       = 0,
    Int       = 1,
    Object    = 2,
    List      = 3,
    Resource  = 4,
    Timer     = 5,
    Session   = 6,
    RoomData  = 7,
    TempString = 8,
    String    = 9,
    Class     = 10,
    Message   = 11,
    DebugStr  = 12,
    Override  = 13,
    Reserved  = 14,
    Invalid   = 15,
}

impl Val {
    pub fn nil() -> Self { ... }
    pub fn int(n: i64) -> Self { ... }
    pub fn object(id: u32) -> Self { ... }
    pub fn list(id: u32) -> Self { ... }
    // etc.
    
    pub fn tag(&self) -> Tag { ... }
    pub fn data(&self) -> i64 { ... }
    
    /// Unpack from 32-bit BOF constant (4-bit tag + 28-bit signed data)
    pub fn from_bof_constant(packed: u32) -> Self { ... }
    
    /// Pack to 32-bit BOF constant
    pub fn to_bof_constant(&self) -> u32 { ... }
}
```

### Game State (`world/mod.rs`) [opus]

```rust
/// The complete mutable game state. Owned by the server main loop.
/// NOT shared across threads — single-threaded game logic.
pub struct GameState {
    pub objects: ObjectStore,      // Vec<Option<ObjectNode>>, indexed by object_id
    pub classes: ClassStore,       // HashMap<u32, ClassNode>
    pub messages: MessageStore,    // Global message dispatch
    pub lists: ListStore,          // Vec<ListNode>, indexed by list_id
    pub strings: StringStore,     // Vec<Option<StringNode>>, indexed by string_id
    pub timers: TimerStore,       // Sorted by fire time
    pub tables: TableStore,       // HashMap<u32, Table>
    pub resources: ResourceStore, // HashMap<u32, Resource>
    pub accounts: AccountStore,   // HashMap<u32, Account>
    pub users: UserStore,         // User-account associations
    pub rooms: RoomStore,         // Loaded room data
    
    pub system_object_id: u32,    // The system object
    pub epoch: u8,                // Current epoch (1-255, wraps skipping 0)
    pub config: Config,           // Server configuration
    pub temp_string: String,      // Global temporary string buffer
    
    // Packet building state (used by C_AddPacket/C_SendPacket)
    pub packet_buffers: Vec<u8>,
}
```

---

## Phases

### Phase 0: Project Scaffolding [sonnet]

1. Create `/home/fredde/git/Meridian59/blakserv-rs/` with `cargo init`
2. Set up Cargo.toml with initial dependencies (byteorder, thiserror, tracing)
3. Create module structure (empty files with module declarations)
4. Add `.gitignore` for Cargo artifacts
5. Verify `cargo check` passes with empty modules

### Phase 1: Tagged Values and BOF Constants [sonnet]

Implement the `Val` type and `Tag` enum. This is the foundational type used everywhere.

1. Implement `Val` with 64-bit runtime representation (60-bit data + 4-bit tag)
2. Implement `Tag` enum with all 16 variants
3. Implement `Val::from_bof_constant(u32)` — unpacks 32-bit BOF constants (sign-extends 28-bit data to 60-bit)
4. Implement `Val::to_bof_constant()` — packs back to 32-bit
5. Implement arithmetic helpers: `Val::int_val()`, `Val::is_nil()`, `Val::is_true()` (nonzero int or non-nil)
6. Write comprehensive tests (edge cases: negative ints, max/min values, tag preservation)

### Phase 2: BOF Loader [sonnet]

Parse `.bof` files into in-memory class/message structures. This is the first real piece that can be tested against existing `.bof` files.

1. Define `BofFile`, `BofClass`, `BofMessage`, `BofProperty`, `BofClassVar` structs
2. Implement BOF header parsing (magic `BOF\xFF`, version 5, class table)
3. Implement class parsing (superclass, classvars with defaults, properties with defaults)
4. Implement message dispatch table parsing (sorted by message ID, handler offsets)
5. Implement handler header parsing (num_locals, num_params, param defaults)
6. Implement debug string table parsing
7. Implement line number table parsing
8. Store raw bytecode slices (don't decode instructions yet — just keep byte offsets)
9. Test against all `.bof` files in `~/git/Meridian59/run/server/loadkod/`

### Phase 3: Class and Message System [opus]

Build the class hierarchy and message dispatch infrastructure on top of loaded BOF data.

1. Implement `ClassStore` — stores class nodes, resolves `super_ptr` chains after all classes loaded
2. Implement `SetClassVariables()` — recursive classvar resolution up the inheritance chain, handling `TAG_OVERRIDE`
3. Implement property name lookup (`GetPropertyIDByName`) using class hierarchy
4. Implement `MessageStore` — message ID → handler offset mapping, propagation chain (message → parent class handler)
5. Implement `SetMessagesPropagate()` — link each message handler to its parent class override
6. Implement `kodbase.txt` parser — map symbolic names to class/message/property/resource IDs

### Phase 4: Object System [sonnet]

Implement the game object store.

1. Implement `ObjectStore` — `Vec<Option<ObjectNode>>` indexed by object_id
2. Implement `ObjectNode` — class_id, property array (`Vec<Val>`), deleted flag
3. Implement `AllocateObject()` — appends to vec, initializes property array
4. Implement `SetObjectProperties()` — recursive property default application from superclass chain
5. Implement `GetObjectByID()` — bounds check + deleted check
6. Implement property get/set by ID and by name
7. Implement `ForEachObject()` iterator
8. Write tests for object creation, property access, deletion

### Phase 5: List, String, Timer, Table Systems [sonnet]

Implement the four auxiliary data stores.

**Lists:**
1. Implement `ListStore` — `Vec<ListNode>` with cons cells (`first: Val`, `rest: Val`)
2. Implement `Cons`, `First`, `Rest`, `Length`, `Nth`, `SetFirst`, `SetNth`
3. Implement `FindListElem`, `DelListElem`, `MoveListElem`

**Strings:**
1. Implement `StringStore` — `Vec<Option<StringNode>>` with heap-allocated string data
2. Implement `CreateString`, `SetString`, temp string operations (`SetTempString`, `AppendTempString`, `GetTempString`, `ClearTempString`)

**Timers:**
1. Implement `TimerStore` — sorted collection (BTreeMap<u64, Vec<TimerNode>> by fire time, or a `BinaryHeap`)
2. Implement `CreateTimer`, `DeleteTimer`, `TimerActivate` (fire first due timer)
3. Implement `PauseTimers`/`UnpauseTimers` (shift all fire times)
4. Implement `GetMainLoopWaitTime()` — returns duration until next timer (capped at 500ms)

**Tables:**
1. Implement `TableStore` — `HashMap<u32, Table>` where each `Table` is `HashMap<Val, Val>`
2. Implement `CreateTable`, `InsertTable`, `GetTableEntry`, `DeleteTableEntry`, `DeleteTable`
3. Implement `ResetTable()` (destroy all tables — called during GC)
4. String key matching: case-insensitive for TAG_STRING/TAG_RESOURCE/TAG_TEMP_STRING keys

### Phase 6: Bytecode Interpreter [opus]

The core of the server. This is the most complex and critical phase.

1. Define `Opcode` enum with all 58 opcodes and their bitfield encoding:
   - Command (3 bits): UNARY_ASSIGN, BINARY_ASSIGN, GOTO, CALL, RETURN, DEBUG_LINE
   - Dest (1 bit), Source1 (2 bits), Source2 (2 bits)
2. Implement opcode decoder — unpack 1-byte opcode into command + fields
3. Implement `RetrieveValue(data_type, data)` — resolves LOCAL_VAR/PROPERTY/CONSTANT/CLASS_VAR to `Val`
4. Implement `StoreValue(dest_type, dest_id, val)` — stores `Val` into local or property
5. Implement the main interpreter loop (`InterpretAtMessage`):
   - Fetch opcode byte, decode, dispatch to handler
   - Instruction counter with `MAX_BLAKOD_STATEMENTS` limit
   - Call stack management (`Vec<StackFrame>`, max depth check)
6. Implement all opcode handlers:
   - **UNARY_ASSIGN** (4 ops × 2 dest types): NOT, NEGATE, NONE (plain assign), BITWISE_NOT
   - **BINARY_ASSIGN** (15 ops × 2 dest types): ADD, SUB, MUL, DIV, MOD, AND, OR, EQ, NEQ, LT, GT, LEQ, GEQ, BITAND, BITOR
   - **GOTO** (9 variants): unconditional, if_true/if_false × (local, property, constant, classvar)
   - **CALL** (3 variants): no_assign, assign_local, assign_property
   - **RETURN** (2 variants): return value, propagate
7. Implement `SendBlakodMessage()` — synchronous message send (save/restore interpreter state)
8. Implement `PostBlakodMessage()` — enqueue to post queue (circular buffer)
9. Implement `SendTopLevelBlakodMessage()` — entry point from network/timer, drains post queue after completion
10. Implement propagation: when handler returns PROPAGATE, follow `propagate_class`/`propagate_message` chain
11. Implement error recovery: log errors, return NIL on failure (don't crash)
12. Test with hand-crafted bytecode sequences, then with real `.bof` files

### Phase 7: C-Callable Functions [opus for design, sonnet for implementation]

Implement all 80+ built-in functions callable from Blakod via the CALL opcode.

**Design decisions [opus]:**
1. Define the dispatch table structure — function ID (1 byte) → Rust function pointer
2. Define parameter extraction pattern — how to read normal_parms and name_parms
3. Define return value convention — Val return type

**Implementation [sonnet] — grouped by category:**

1. **Object functions** (5): CreateObject, GetClass, IsObject, IsClass (if present in v5), RecycleUser
2. **Message functions** (6): SendMessage, PostMessage, SendListMessage, SendListMessageBreak, SendListMessageByClass, SendListMessageByClassBreak
3. **String functions** (12): StringEqual, StringContain, SetResource, ParseString, SetString, CreateString, StringSubstitute, AppendTempString, ClearTempString, GetTempString, StringLength, StringConsistsOf
4. **List functions** (15+): Cons, First, Rest, Length, Nth, List, IsList, SetFirst, SetNth, DelListElem, FindListElem, MoveListElem, SwapListElem, InsertListElem, Last, GetListElemByClass, GetAllListNodesByClass, ListCopy, AppendListElem, GetListNode, DelLastListElem, IsListMatch
5. **Timer functions** (4): CreateTimer, DeleteTimer, GetTimeRemaining, IsTimer
6. **Table functions** (5): CreateTable, AddTableEntry, GetTableEntry, DeleteTableEntry, DeleteTable, IsTable
7. **Room/BSP functions** (12): LoadRoom, FreeRoom, RoomData, LineOfSightView, LineOfSightBSP, CanMoveInRoomBSP, ChangeTextureBSP, MoveSectorBSP, GetLocationInfoBSP, BlockerAddBSP, BlockerMoveBSP, BlockerRemoveBSP, BlockerClearBSP, GetRandomPointBSP, GetStepTowardsBSP, PointInSector
8. **Packet functions** (4): AddPacket, SendPacket, SendCopyPacket, ClearPacket
9. **Math functions** (4): Random, Abs, Bound, Sqrt
10. **System functions** (7): SaveGame, LoadGame, Debug, DumpStack, GetInactiveTime, GodLog, GetTime, GetTickCount
11. **Misc** (4): RecordStat, GetSessionIP, GetTimeZoneOffset, SendWebhook, SetClassVar, StringToNumber, MiniGameNumberToString, MiniGameStringToNumber

### Phase 8: Resource System [sonnet]

1. Implement `.rsc` file parser (magic `RSC\x01`, version, resource entries)
2. Implement `ResourceStore` — `HashMap<u32, Resource>` with name index
3. Implement dynamic resource creation and change notification
4. Implement `SetResourceName()` from kodbase

### Phase 9: Room System [sonnet]

1. Implement `.roo` file parser:
   - Header: magic `ROO\xB1`, version (≥4), security, section offsets
   - Server section: rows, cols, movement grid, flags grid, monster_grid (v12+)
   - Client section: BSP nodes, sector polygons (for `RoomData` queries)
2. Implement `RoomStore` — loaded room data indexed by roomdata_id
3. Implement `CanMoveInRoom()` — direction bitmask validation
4. Implement `CanMoveInRoomFine()` — monster movement validation
5. Implement BSP query functions used by C-functions (LineOfSight, GetLocationInfo, etc.)

### Phase 10: Garbage Collector [opus]

Port the mark-sweep-compact GC algorithm.

1. Implement mark phase for list nodes:
   - Clear all garbage_ref to UNREFERENCED
   - Walk all object properties, mark reachable list nodes (handle shared structure via VISITED_LIST bit)
2. Implement mark phase for objects:
   - GC roots: system object + all user objects
   - Transitively mark objects reachable through properties and list nodes
3. Implement mark phase for strings:
   - Mark strings referenced by objects and list nodes
4. Implement compaction for all four types:
   - Renumber IDs sequentially
   - Update all references (objects, lists, timers, users, sessions)
   - Move data to compact positions
   - Truncate storage
5. Implement timer renumbering (prevent ID rollover)
6. Implement `ResetTable()` call during GC (tables don't survive GC)
7. Implement `NewEpoch()` call after GC (clients must discard stale references)
8. Test: create objects, delete some, GC, verify survivors are correct and renumbered

### Phase 11: Persistence — Save/Load [sonnet]

Implement save/load for game state compatibility with the C server.

**Save format v1 (must produce):**
1. Game file: `[V][version=1]` then class/resource/system/object/listnode/timer/user records
2. String file: `[version][count]` then per string `[id][len][data]`
3. Account file: per account `[id][name][password][type][last_login][suspend_time][credits]`
4. Dynamic resource file: per resource `[id][value]`
5. Control file: `lastsave.txt` with `LASTSAVE <timestamp>`

**Load format (must read both v0 and v1):**
1. v0: 32-bit property values → widen to 64-bit
2. v1: 64-bit property values
3. Properties matched by NAME (not position) — allows schema evolution
4. Classes matched by NAME — allows class ID changes between recompilations
5. Timer messages matched by NAME
6. Self (property 0) reconstructed, not loaded

**Implementation:**
1. Implement `SaveAll()` — GC → save game + strings + accounts + dynamic resources + control file
2. Implement `LoadAll()` — read control file → load accounts → load strings → load game → load dynamic resources
3. Test: load a save from the C server, verify objects/properties/lists/timers are correct

### Phase 12: Account System [sonnet]

1. Implement `Account` struct (id, name, password_hash, type, credits, last_login, suspend_time)
2. Implement `AccountStore` — `HashMap<u32, Account>` with name index
3. Implement authentication: MD5 hash comparison (case-insensitive name lookup)
4. Implement account creation, deletion, suspension
5. Implement built-in accounts (Chris.Kirmse, Andrew.Kirmse — for compatibility)

### Phase 13: Configuration System [sonnet]

1. Implement INI parser for `blakserv.cfg` format:
   - `[Group]` sections, `Key = Value` entries, `#` comments
   - `Key = <@filename.txt>` file inclusion
   - Path validation on load
2. Implement all configuration groups and keys (matching C server defaults):
   - Path, Socket, Channel, Login, Inactive, Credit, Session, Lock, Memory, Auto, Security, Blakod, Webhook, etc.
3. Implement dynamic vs static config distinction:
   - Dynamic: can be changed at runtime (behind RwLock)
   - Static: fixed at startup
4. Implement `ConfigInt()`, `ConfigStr()`, `ConfigBool()` accessors

### Phase 14: Network Layer [opus for design, sonnet for implementation]

Implement the TCP server using tokio.

**Design [opus]:**
1. Two TCP listeners: game port (default 5959) and maintenance port (default 9998)
2. Session state machine as a Rust enum:
   ```rust
   enum SessionState {
       TrySync(TrySyncState),
       Synched(SynchedState),
       Game(GameState),
       Resync(ResyncState),
       Admin(AdminState),
       Maintenance(AdminState),
   }
   ```
3. Per-session state: connection info, account, seeds, secure_token, sliding_token
4. Message framing: 7-byte header `[2B len][2B CRC16][2B len_verify][1B epoch]`

**Implementation [sonnet]:**
1. Implement `Server` — owns tokio TCP listeners, session map, game state
2. Implement session lifecycle: accept → create session → state machine loop → close
3. Implement message framing: read header, validate CRC, read payload
4. Implement `SendGameClient()` — build header, send payload
5. Implement `SendClient()` — raw send (for non-game states)

### Phase 15: Protocol — Login Flow [sonnet]

Implement the AP_* login protocol (STATE_SYNCHED in C server).

1. Implement STATE_TRYSYNC: send `tell_cli_str`, wait for `detect_str` byte match, transition to SYNCHED
2. Implement AP_LOGIN parsing: version info, system info, credentials
3. Implement version checking (Classic major=50)
4. Implement authentication: verify credentials against AccountStore
5. Implement AP_REQ_GAME: transition to STATE_GAME
6. Implement AP_GETCHOICE: send 5 random seeds for crypto initialization
7. Implement AP_DOWNLOAD: file sync protocol (send changed files)
8. Implement AP_REQ_ADMIN: transition to STATE_ADMIN
9. Implement AP_PING echo
10. Implement STATE_RESYNC: wait for `beacon_str`, transition to TRYSYNC

### Phase 16: Protocol — Game State [opus for security, sonnet for messages]

Implement BP_* game protocol (STATE_GAME).

**Security [opus]:**
1. Implement seed-based random stream: `seed = (seed * 9301 + 49297) % 233280`
2. Implement secure token generation and advancement
3. Implement sliding token (XOR with redbook string)
4. Implement `SecurePacketBufferList()` — XOR first byte, advance token

**Message parsing [sonnet]:**
1. Port `sprocket.c` command definitions — all ~90 BP_* message formats
2. Implement client message parser — command byte → parameter extraction → Blakod dispatch
3. Implement `GameProtocolParse()` — validates CRC, decrypts, dispatches
4. Implement beacon/resync detection (GAME_BEACON sub-state)
5. Implement inactivity timeout

**Reuse from m59-package-sniffer:**
- Protocol message type enums
- CRC calculation
- Token/security system (already implemented for decoding)
- Many BP_* message format definitions

### Phase 17: Outgoing Packet Construction [sonnet]

Implement server→client message building (C_AddPacket/C_SendPacket from Blakod).

1. Implement packet buffer accumulator (replaces `buffer_node` chain)
2. Implement `AddBlakodToPacket()` — convert tagged values to wire format:
   - 1/2/4-byte integers
   - Strings (null-terminated, length-prefixed variants)
   - Object IDs (NUMBER_OBJECT = 5-byte format)
   - Resource strings (STRING_RESOURCE = 6-byte format)
3. Implement `SendPacket()` — secure and send accumulated buffer
4. Implement `SendCopyPacket()` — send copy, keep original
5. Implement `ClearPacket()` — discard accumulated buffer

### Phase 18: Admin Interface [sonnet]

1. Implement maintenance port text protocol (character-by-character input, CR dispatch)
2. Implement admin command dispatch table (prefix matching, permissions)
3. Implement essential admin commands:
   - `show` (sessions, objects, memory, timers, config)
   - `send` (send Blakod message)
   - `save` (trigger save)
   - `garbage` (trigger GC)
   - `reload` (reload BOF/RSC)
   - `lock`/`unlock` (maintenance mode)
   - `kick`/`hangup` (disconnect players)
   - `who` (list connected players)
   - `set` (change dynamic config)
4. Lower-priority admin commands can be added incrementally

### Phase 19: System Timers and Main Loop [sonnet]

Implement the periodic maintenance tasks.

1. Implement system timer equivalents using `tokio::time::interval()`:
   - Auto-save (default: every 3 hours, with GC first)
   - Blakod "new hour" message (default: every 5 minutes)
   - Log file rotation (daily)
   - Inactivity checks
2. Implement the main game loop:
   ```rust
   loop {
       tokio::select! {
           conn = game_listener.accept() => handle_new_connection(conn),
           conn = maint_listener.accept() => handle_maintenance(conn),
           _ = timer_tick => { activate_blakod_timers(); },
           _ = save_interval => { gc_and_save(); },
           _ = hour_interval => { send_new_hour(); },
       }
   }
   ```
3. Implement `TimerActivate()` in the main loop — fire due Blakod timers

### Phase 20: Webhook System [sonnet]

1. Implement webhook delivery (named pipes on Linux, matching C server format)
2. JSON message formatting
3. Round-robin across up to 10 pipes

### Phase 21: Integration Testing [opus]

**Critical phase** — must prove the Rust server is a working replacement.

1. **BOF loading test**: Load all `.bof` files, verify class hierarchy matches C server
2. **Save/load roundtrip**: Load a C server save, save from Rust, load back, compare
3. **Protocol test**: Use m59-package-sniffer to verify wire format matches
4. **Client connection test**: Connect a real Classic client, verify login, character select, enter game
5. **Blakod execution test**: Verify game logic runs correctly (NPCs respond, combat works, spells function)
6. **Stress test**: Multiple concurrent clients, extended uptime, save/load cycles
7. **GC test**: Run GC under load, verify no corruption
8. **Admin test**: Connect via maintenance port, run admin commands

### Phase 22: Polish and Optimization [sonnet]

1. Better error messages with source line context (using BOF debug info)
2. Structured logging with tracing spans (per-session, per-message context)
3. Performance profiling (interpreter hot path optimization)
4. Memory usage comparison with C server
5. Configuration validation and helpful startup messages

---

## Key Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Bytecode interpreter behavior mismatch | Game logic breaks silently | Test with real `.bof` files; compare interpreter traces between C and Rust |
| Save format parsing edge cases | Can't load existing worlds | Test with multiple real save files from different server versions |
| Security token system mismatch | Clients can't connect or get desynced | Already implemented in m59-package-sniffer; validate against captured traffic |
| GC correctness (shared list nodes) | Data corruption after GC | Extensive GC testing with complex object graphs; compare before/after snapshots |
| C-function behavioral differences | Blakod scripts behave differently | Test each C-function individually, then end-to-end with real game scenarios |
| Room BSP query correctness | Movement/line-of-sight broken | Test with all `.roo` files; compare query results against C server |
| Thread safety in async context | Race conditions | Single-threaded tokio runtime eliminates this risk |
| Performance regression | Server too slow for production | Profile early; the interpreter loop is the hot path |

---

## Estimated Effort

| Phase | Description | Estimate | Model |
|-------|-------------|----------|-------|
| 0 | Scaffolding | 1 day | sonnet |
| 1 | Tagged values | 2 days | sonnet |
| 2 | BOF loader | 3-4 days | sonnet |
| 3 | Class/message system | 1 week | opus |
| 4 | Object system | 3-4 days | sonnet |
| 5 | Lists/strings/timers/tables | 1 week | sonnet |
| 6 | Bytecode interpreter | 2-3 weeks | opus |
| 7 | C-callable functions (80+) | 3-4 weeks | opus+sonnet |
| 8 | Resource system | 2-3 days | sonnet |
| 9 | Room system | 1 week | sonnet |
| 10 | Garbage collector | 1 week | opus |
| 11 | Persistence (save/load) | 1-2 weeks | sonnet |
| 12 | Account system | 3-4 days | sonnet |
| 13 | Configuration system | 3-4 days | sonnet |
| 14 | Network layer | 1 week | opus+sonnet |
| 15 | Login protocol | 1 week | sonnet |
| 16 | Game protocol | 1-2 weeks | opus+sonnet |
| 17 | Outgoing packets | 3-4 days | sonnet |
| 18 | Admin interface | 1 week | sonnet |
| 19 | System timers / main loop | 3-4 days | sonnet |
| 20 | Webhook system | 2 days | sonnet |
| 21 | Integration testing | 2-3 weeks | opus |
| 22 | Polish | 1 week | sonnet |
| **Total** | | **~5-7 months** | |

---

## Dependency Graph

```
Phase 0 (scaffold)
  └─► Phase 1 (Val type)
       ├─► Phase 2 (BOF loader)
       │    └─► Phase 3 (class/message system)
       │         ├─► Phase 4 (object system)
       │         │    ├─► Phase 5 (lists/strings/timers/tables)
       │         │    │    ├─► Phase 6 (interpreter) ◄── CRITICAL PATH
       │         │    │    │    ├─► Phase 7 (C-functions)
       │         │    │    │    │    ├─► Phase 10 (GC)
       │         │    │    │    │    ├─► Phase 17 (outgoing packets)
       │         │    │    │    │    └─► Phase 9 (rooms) ◄── needed by room C-funcs
       │         │    │    │    └─► Phase 19 (main loop)
       │         │    │    └─► Phase 11 (persistence)
       │         │    └─► Phase 12 (accounts)
       │         └─► Phase 8 (resources)
       └─► Phase 13 (config) ◄── independent, can start early
       
Phase 14 (network) ◄── needs Phase 6, 12, 13
  ├─► Phase 15 (login protocol)
  ├─► Phase 16 (game protocol) ◄── needs Phase 7, 17
  └─► Phase 18 (admin) ◄── needs Phase 7

Phase 20 (webhooks) ◄── independent
Phase 21 (integration testing) ◄── needs all above
Phase 22 (polish) ◄── needs Phase 21
```

---

## Relationship to Other Plans

### Compiler Plan (`kod-compiler-rust-rewrite.md`)

The compiler and server are **independent projects** that share the BOF format as a contract:
- Compiler produces `.bof` v5 files + `.rsc` files + `kodbase.txt`
- Server consumes `.bof` v5 files + `.rsc` files + `kodbase.txt`

The compiler plan targets BOF v5 (matching this fork), not v8. The compiler plan should be updated to reflect this.

Work can proceed in parallel:
- The server can load `.bof` files produced by the existing C compiler (`bc`)
- The compiler can be validated by loading its output into the existing C server

Eventually both replace their C counterparts, and the entire `.kod` → server pipeline is pure Rust.

### m59-package-sniffer

The sniffer already has:
- Protocol message type enums and definitions
- CRC calculation
- Token/security system implementation
- Message parsing logic

The server should depend on the sniffer as a library crate for protocol types and security, or extract shared protocol code into a common crate.

---

## Open Questions

1. **Shared protocol crate**: Should we extract protocol types from m59-package-sniffer into a `m59-protocol` crate that both the sniffer and server depend on? Or should the server just depend on the sniffer directly?

2. **BSP query functions**: The room system has complex BSP operations (LineOfSight, GetStepTowards, BlockerAdd/Move/Remove, GetRandomPoint, GetLocationInfo). These may require significant reverse-engineering effort. How complete does the BSP implementation need to be for initial functionality?

3. **Build integration**: How should blakserv-rs integrate with the existing Makefile build system? Options:
   - Standalone Cargo build (users run `cargo build` in `blakserv-rs/`)
   - Add Cargo invocation to the top-level Makefile
   - Ignore Makefiles entirely since this is your fork

4. **Incremental deployment**: Is there a way to run both C and Rust servers against the same data directory for A/B testing? This would require coordinating save file access and port binding.
