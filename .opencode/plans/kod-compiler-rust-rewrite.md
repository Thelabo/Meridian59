# Rust Rewrite of the Blakod Compiler

**Status:** PLANNING  
**GitHub account:** Thelabo  
**Local path:** `/home/fredde/git/kod-compiler`  
**Goal:** Drop-in replacement for `blakcomp` (`bc`) — produces bit-identical `.bof` and `.rsc` files  

## Context

The current Blakod compiler (`blakcomp`) is ~6,000 lines of C compiled as C++20, using flex/bison. It compiles `.kod` source files into `.bof` bytecode (BOF_VERSION 5) and `.rsc` resource files consumed by the Meridian 59 server (`blakserv`).

**Target:** Classic Meridian 59 (`Meridian59/Meridian59`, fork `Thelabo/Meridian59`) — NOT OpenMeridian105.

We already have:
- **tree-sitter-kod** — complete grammar for the KOD language (CST) — already handles all v5 constructs
- **kod-parser** — Rust crate: CST→AST conversion, symbol table, constant evaluation, inheritance resolution

The compiler will be a new sibling crate (`kod-compiler`) that takes `kod-parser`'s AST and emits `.bof`/`.rsc` files.

## Architecture

```
.kod source file
     │
     ▼
tree-sitter-kod (grammar.js → C)  ──► CST
     │
     ▼
kod-parser (Rust)  ──► AST + SymbolTable + ResolvedClass
     │
     ▼
kod-compiler (NEW, Rust)  ──► .bof bytecode + .rsc resources + kodbase.txt
```

## Dependency Chain

```
kod-compiler ──► kod-parser ──► tree-sitter-kod
```

Cargo.toml:
```toml
[dependencies]
kod-parser = { path = "../kod-parser" }
```

## Language Features (BOF v5)

The v5 blakcomp supports a focused set of language constructs. Unlike OpenMeridian105 (BOF v8), there are **no** do-while, switch/case, C-style for, ++/--, or compound assignment operators.

### Statements

| Statement | Syntax | Enum |
|-----------|--------|------|
| If/Else | `if expr { stmts } [else { stmts }]` | S_IF |
| Assign | `id = expr ;` | S_ASSIGN |
| Call | `id(args) ;` or `[expr, ...]` | S_CALL |
| For-in | `for id in expr { stmts }` | S_FOR |
| While | `while expr { stmts }` | S_WHILE |
| Property assign | `expr.property = expr ;` | S_PROP |
| Return | `return [expr] ;` | S_RETURN |
| Break | `break ;` | S_BREAK |
| Continue | `continue ;` | S_CONTINUE |
| Propagate | `propagate ;` | (special return) |
| Include | `include fname ;` | (preprocessor) |

### Expressions

| Expression | Syntax |
|-----------|--------|
| Logical | `expr AND expr`, `expr OR expr`, `NOT expr` |
| Relational | `<>`, `<`, `>`, `<=`, `>=`, `=` (equality) |
| Arithmetic | `+`, `-`, `*`, `/`, `MOD`, unary `-` |
| Bitwise | `&`, `\|`, `~` |
| Literals | decimal numbers, `0x` hex, `$` (nil), string constants |
| References | `&id` (class), `@id` (message) |
| Call | `id(args)` |
| Identifier | plain identifiers |

### Class Structure

```
id [is superclass]        % class signature
constants:                % optional
resources:                % optional
classvars:                % optional
properties:               % optional
messages:                 % optional
end
```

### Comments

`%` introduces a comment to end of line.

## Bytecode Architecture

### Opcode Encoding

The opcode is a **1-byte bitfield** (defined in `bkod.h`):

```
Bits: [command:3][dest:1][source1:2][source2:2]
```

| Field | Bits | Values |
|-------|------|--------|
| command | 3 | UNARY_ASSIGN=0, BINARY_ASSIGN=1, GOTO=2, CALL=3, RETURN=4, DEBUG_LINE=5 |
| dest | 1 | LOCAL_VAR=0, PROPERTY=1 |
| source1 | 2 | LOCAL_VAR=0, PROPERTY=1, CONSTANT=2, CLASS_VAR=3 |
| source2 | 2 | LOCAL_VAR=0, PROPERTY=1, CONSTANT=2, CLASS_VAR=3 |

This gives 6 command types with sub-operations, NOT 59 separate opcodes. The combination of command + dest + source types determines the exact instruction behavior.

### Sub-operations

**Unary operations** (4): NOT=0, NEGATE=1, NONE=2 (plain assign), BITWISE_NOT=3

**Binary operations** (15): ADD=0, SUBTRACT=1, MULTIPLY=2, DIV=3, MOD=4, AND=5, OR=6, EQUAL=7, NOT_EQUAL=8, LESS_THAN=9, GREATER_THAN=10, LESS_EQUAL=11, GREATER_EQUAL=12, BITWISE_AND=13, BITWISE_OR=14

### Source Location Types

LOCAL_VAR=0, PROPERTY=1, CONSTANT=2, CLASS_VAR=3

### Tag Types (32-bit BOF constants: 4-bit tag + 28-bit data)

```rust
#[repr(u8)]
enum Tag {
    Nil = 0, Int = 1, Object = 2, List = 3,
    Resource = 4, Timer = 5, Session = 6,
    RoomData = 7, TempString = 8, String = 9,
    Class = 10, Message = 11, DebugStr = 12,
    Table = 13, Override = 14,
}
```

## Built-in Functions

**60 built-in functions** callable from Blakod via the CALL opcode (function ID is 1 byte).

Source: `blakcomp/function.c`, `Functions[]` array.

| # | Function | ID | Params |
|---|----------|----|--------|
| 1 | Send | 11 | expr, expr, settings... |
| 2 | Create | 1 | expr, settings... |
| 3 | Cons | 101 | expr, expr |
| 4 | First | 102 | expr |
| 5 | Rest | 103 | expr |
| 6 | Length | 104 | expr |
| 7 | List | 106 | exprs... |
| 8 | Nth | 105 | expr, expr |
| 9 | SetFirst | 108 | expr, expr |
| 10 | SetNth | 109 | expr, expr, expr |
| 11 | DelListElem | 110 | expr, expr |
| 12 | FindListElem | 111 | expr, expr |
| 13 | MoveListElem | 112 | expr, expr, expr |
| 14 | Random | 201 | expr, expr |
| 15 | AddPacket | 23 | exprs... |
| 16 | SendPacket | 24 | expr |
| 17 | SendCopyPacket | 25 | expr |
| 18 | ClearPacket | 26 | (none) |
| 19 | Debug | 22 | exprs... |
| 20 | GetInactiveTime | 27 | expr |
| 21 | DumpStack | 28 | (none) |
| 22 | StringEqual | 31 | expr, expr |
| 23 | StringContain | 32 | expr, expr |
| 24 | StringSubstitute | 37 | expr, expr, expr |
| 25 | BuildString | 41 | expr, exprs... |
| 26 | StringLength | 43 | expr |
| 27 | StringConsistsOf | 44 | expr, expr |
| 28 | CreateTimer | 51 | expr, expr, expr |
| 29 | DeleteTimer | 52 | expr |
| 30 | IsList | 107 | expr |
| 31 | IsClass | 3 | expr, expr |
| 32 | RoomData | 63 | expr |
| 33 | LoadRoom | 61 | expr |
| 34 | GetClass | 5 | expr |
| 35 | GetTime | 120 | (none) |
| 36 | CanMoveInRoom | 64 | expr, expr, expr, expr, expr |
| 37 | CanMoveInRoomFine | 65 | expr, expr, expr, expr, expr |
| 38 | IsPointInSector | 66 | expr, expr, expr, expr, expr, expr |
| 39 | SetResource | 33 | expr, expr |
| 40 | Post | 12 | expr, expr, settings... |
| 41 | Abs | 131 | expr |
| 42 | Sqrt | 133 | expr |
| 43 | ParseString | 34 | expr, expr, expr |
| 44 | CreateTable | 141 | (none) |
| 45 | AddTableEntry | 142 | expr, expr, expr |
| 46 | GetTableEntry | 143 | expr, expr |
| 47 | DeleteTableEntry | 144 | expr, expr |
| 48 | DeleteTable | 145 | expr |
| 49 | Bound | 132 | expr, expr, expr |
| 50 | GetTimeRemaining | 53 | expr |
| 51 | SetString | 35 | expr, expr |
| 52 | AppendTempString | 38 | expr |
| 53 | ClearTempString | 39 | (none) |
| 54 | GetTempString | 40 | (none) |
| 55 | CreateString | 36 | (none) |
| 56 | IsObject | 161 | expr |
| 57 | RecycleUser | 151 | expr |
| 58 | MinigameNumberToString | 71 | expr, expr |
| 59 | MinigameStringToNumber | 72 | expr |
| 60 | SendWebhook | 202 | exprs... |

**Note:** `IsClass` is a built-in function (ID 3), NOT a language operator. It's dispatched via the CALL opcode like any other built-in.

## Built-in IDs

**35 built-in identifiers** (IDs 0–34) pre-loaded into the symbol table before any source is compiled.

Source: `blakcomp/function.c`, `BuiltinIds[]` array.

| ID | Name | Type |
|----|------|------|
| 0 | self | property |
| 1 | user | class |
| 2 | userlogon | message |
| 3 | session_id | parameter |
| 4 | system | class |
| 5 | receive_client | message |
| 6 | client_msg | parameter |
| 7 | garbage | message |
| 8 | loaded | message |
| 9 | name | parameter |
| 10 | constructor | message |
| 11 | destructor | message |
| 12 | newowner | parameter |
| 13 | admin | class |
| 14 | guestaccount | message |
| 15 | value | parameter |
| 16 | dm | class |
| 17 | string | parameter |
| 18 | type | parameter |
| 19 | newhour | message |
| 20 | number | parameter |
| 21 | admindm | class |
| 22 | settings | class |
| 23 | timer_id | parameter |
| 24 | systemrecycled | message |
| 25 | what | parameter |
| 26 | systementer | message |
| 27 | systemleave | message |
| 28 | sysrecycleuser | message |
| 29 | delete | message |
| 30 | resource | parameter |
| 31 | row | parameter |
| 32 | col | parameter |
| 33 | data | parameter |
| 34 | creator | class |

User-defined IDs start at `IDBASE = 10000`.
User-defined resources start at `RESOURCEBASE = 20000`.

## Limits

| Limit | Compiler | Server Runtime | Notes |
|-------|----------|---------------|-------|
| MAX_LOCALS | 255 | 50 | Compiler allows more, but server allocates 50 slots |
| MAX_NAME_PARMS | — | 45 | Max named parameters per message call |
| MAX_C_PARMS | — | 40 | Max params to a C function call |
| MAXARGS | 30 | — | Max args in a single built-in function signature |
| MAX_INCLUDE_DEPTH | 10 | — | Max include file nesting |
| MAXERRORS | 25 | — | Max errors before aborting compilation |

## Gap Analysis

Since we're targeting BOF v5 (Classic Meridian 59), the existing tree-sitter-kod grammar and kod-parser AST already cover **all required language constructs**. No grammar or parser extensions are needed.

**No gap** — Phase 0 from the original plan (grammar/parser extensions for v8 features) is eliminated entirely.

The only verification needed is confirming that all ~1,232 `.kod` files in `~/git/Meridian59/kod/` parse successfully with the existing grammar and AST conversion. This should already be the case since the grammar was developed against this exact codebase.

## Phases

### Phase 1: Project Scaffolding [sonnet]

1. Create `/home/fredde/git/kod-compiler/` with `cargo init --lib`
2. Set up Cargo.toml with `kod-parser` dependency
3. Add binary entry point `src/bin/bc.rs` (CLI matching blakcomp flags: `-d`, `-K kodbase`, `-I includedir`)
4. Define module structure:
   - `src/lib.rs` — public API
   - `src/bof.rs` — BOF file format types and writer
   - `src/bkod.rs` — bytecode opcodes, tag types, constants
   - `src/codegen.rs` — code generation from AST to bytecode
   - `src/flatten.rs` — expression flattening to 3-address code
   - `src/symbol_ids.rs` — symbol ID assignment (class, message, param, property, classvar, resource IDs)
   - `src/kodbase.rs` — kodbase.txt read/write
   - `src/rsc.rs` — .rsc resource file writer
   - `src/builtins.rs` — built-in function table (60 functions) and builtin IDs (35 entries)
   - `src/error.rs` — compiler error types
5. Verify `cargo check` passes

### Phase 2: Bytecode Representation [sonnet]

1. Define the opcode bitfield structure:
   ```rust
   /// Opcode byte: [command:3][dest:1][source1:2][source2:2]
   #[repr(u8)]
   enum Command {
       UnaryAssign = 0,
       BinaryAssign = 1,
       Goto = 2,
       Call = 3,
       Return = 4,
       DebugLine = 5,
   }

   #[repr(u8)]
   enum UnaryOp { Not = 0, Negate = 1, None = 2, BitwiseNot = 3 }

   #[repr(u8)]
   enum BinaryOp {
       Add = 0, Subtract = 1, Multiply = 2, Div = 3, Mod = 4,
       And = 5, Or = 6, Equal = 7, NotEqual = 8,
       LessThan = 9, GreaterThan = 10, LessEqual = 11, GreaterEqual = 12,
       BitwiseAnd = 13, BitwiseOr = 14,
   }

   #[repr(u8)]
   enum SourceType { LocalVar = 0, Property = 1, Constant = 2, ClassVar = 3 }
   ```
2. Define `Tag` enum (15 variants)
3. Define `TaggedValue` (32-bit: 4-bit tag + 28-bit data)
4. Define built-in function table with all 60 entries (function ID, store_required, param types)
5. Define builtin ID table (35 entries)
6. Define limits: `MAX_LOCALS = 255` (compiler), `IDBASE = 10000`, `RESOURCEBASE = 20000`
7. Write tests for opcode encoding/decoding and tagged value packing

### Phase 3: Symbol ID Assignment [opus]

The compiler must assign stable integer IDs to every symbol (class, message, parameter, property, classvar, resource). These IDs are embedded in the `.bof` file and used by the server at runtime.

1. Implement kodbase.txt reader (parse all line types: `T/C/M/R/P/Y/V/c/m/p`)
2. Implement ID allocator:
   - Pre-load builtin IDs (0–34)
   - Load existing IDs from kodbase.txt
   - Assign new IDs starting from `maxid + 1` for identifiers, `maxresources + 1` for resources
3. Map `kod-parser` AST identifiers to compiler symbol IDs:
   - Walk each `KodClass` from `SymbolTable`
   - Assign IDs to class name, all messages, parameters, properties, classvars, resources
   - Track `I_MISSING` references (cross-file references resolved via kodbase)
4. Implement kodbase.txt writer (matching blakcomp format for compatibility)
5. Handle superclass numbering (inherited properties/classvars get sequential IDs starting from parent's count)
6. Handle the `C_OVERRIDE` tag for classvars overridden by properties

### Phase 4: Expression Flattening [opus]

The bytecode uses 3-address instructions. Complex nested expressions must be flattened into sequences of simple operations using temporary local variables.

Example: `a = b + c * d` becomes:
```
temp1 = c * d       (BINARY_ASSIGN, op=Multiply, dest=temp1)
a = b + temp1       (BINARY_ASSIGN, op=Add, dest=a)
```

1. Implement temp variable allocator (uses locals beyond the user-declared ones, up to MAX_LOCALS=255)
2. Implement `flatten_expr()`:
   - Leaf expressions (identifier, constant, nil) → no flattening needed
   - Binary ops → flatten left, flatten right, emit BINARY_ASSIGN opcode
   - Unary ops → flatten operand, emit UNARY_ASSIGN opcode
   - Call expressions → flatten args, emit CALL opcode
   - Short-circuit AND/OR → emit conditional GOTOs (special case, not a binary op)
3. Handle destination tracking (where does the result go? LOCAL_VAR or PROPERTY)
4. Handle `STORE_REQUIRED` vs `STORE_OPTIONAL` for function calls

### Phase 5: Statement Code Generation [opus]

1. Implement `codegen_statement()` dispatch for each of the 9 statement types:
   - **Assign**: flatten RHS, emit UNARY_ASSIGN(None) or BINARY_ASSIGN to target
   - **Call** (standalone): flatten args, emit CALL opcode, discard result
   - **If/Else**: flatten condition, emit conditional GOTO, codegen then/else bodies, backpatch
   - **While**: emit label, flatten condition, conditional GOTO to exit, codegen body, GOTO top, backpatch exit
   - **For-in** (list iteration): flatten list expr, emit First/Rest iteration loop using built-in calls
   - **Return**: flatten return expr (if any), emit RETURN opcode
   - **Propagate**: emit RETURN with PROPAGATE flag
   - **Break**: emit unconditional GOTO, add to break backpatch list
   - **Continue**: emit unconditional GOTO, add to continue backpatch list
2. Implement goto backpatching:
   - Forward gotos write placeholder offsets, saved in a list
   - When target is known, go back and fill in the correct offsets
   - Break/continue maintain per-loop backpatch lists (loop stack)
3. Implement debug line info emission (DEBUG_LINE command)
4. Enforce: last statement in every handler must be `return` or `propagate`

### Phase 6: BOF File Writer [sonnet]

1. Implement BOF header writer:
   - Magic: `42 4F 46 FF`
   - Version: `5` (u32 LE)
   - Source filename offset (backpatched)
   - String table offset (backpatched)
   - Debug info offset (backpatched, 0 if no debug)
2. Implement class table writer:
   - Number of classes (u32)
   - Per class: class_id (u32), file offset (u32)
3. Implement per-class writer:
   - Superclass ID (u32)
   - Property section offset, message section offset (backpatched)
   - Classvar section: total count (including parents), default count, default values (tagged 32-bit)
   - Property section: total count (including parents), default count, default values (tagged 32-bit)
   - Message dispatch table: count, entries sorted by message ID (for binary search), handler offsets
   - Handler bytecode: local count (1 byte), param count (1 byte), param defaults, bkod bytes
4. Implement string table writer (debug strings)
5. Implement debug info writer (offset → line number mappings)
6. Implement source filename writer (null-terminated string at end of file)
7. Sort message handlers by ID ascending (required for binary search in server's `InterpretAtMessage`)
8. Sort parameters by ID ascending (required for server's parameter lookup)

### Phase 7: RSC File Writer [sonnet]

1. Implement RSC header:
   - Magic: `52 53 43 01`
   - Version: `5` (u32 LE)
   - Resource count
2. Per resource: `4B resource_id + 4B language_id + null-terminated string`
3. Handle multi-language resources (up to `MAX_LANGUAGE_ID = 184`)
4. Distinguish `C_STRING` vs `C_FNAME` resource types

### Phase 8: CLI & Integration [sonnet]

1. Implement CLI (`bc` binary):
   - Parse args: input `.kod` file, `-d` (debug info), `-K kodbase_path`, `-I include_dir`
   - Output: `.bof` file (same name, different extension) + `.rsc` file
2. End-to-end pipeline: parse → assign IDs → codegen → write BOF + RSC + kodbase
3. Error reporting with file/line/column information

### Phase 9: Verification [opus]

**Critical phase** — must prove bit-identical output.

1. Build a test harness that compiles each `.kod` file with both `blakcomp` and `kod-compiler`
2. Binary diff the `.bof` output files — they must be identical
3. Binary diff the `.rsc` output files — they must be identical
4. Compare kodbase.txt output
5. Start with simple `.kod` files and work up to complex ones
6. Document any intentional differences (e.g., if we find blakcomp bugs)

### Phase 10: Optimization & Polish [sonnet]

1. Better error messages (leveraging tree-sitter spans for precise error locations)
2. Warnings for unused variables, missing return/propagate, unreachable code
3. Constant folding (matching blakcomp's `optimize.c` behavior: unary and binary operations on constants)
4. Performance: compile all ~1,232 files and benchmark against blakcomp

## BOF v5 File Layout

Complete binary layout (from `codegen.c`):

```
Offset  Content
──────  ───────
0x00    Magic: 42 4F 46 FF
0x04    Version: 05 00 00 00
0x08    Source filename offset (u32 LE, backpatched)
0x0C    String table offset (u32 LE, backpatched)
0x10    Debug info offset (u32 LE, 0 if none)
0x14    Number of classes (u32 LE)
0x18    Class table: [class_id: u32, offset: u32] × num_classes

        Per class (at offset from class table):
        ├── Superclass ID (u32)
        ├── Property section offset (u32, backpatched)
        ├── Message section offset (u32, backpatched)
        ├── Classvar section:
        │   ├── Total classvar count (u32, including inherited)
        │   ├── Number with defaults (u32)
        │   └── Defaults: [classvar_id: u32, value: u32 tagged] × count
        ├── Property section:
        │   ├── Total property count (u32, including inherited)
        │   ├── Number with defaults (u32)
        │   └── Defaults: [property_id: u32, value: u32 tagged] × count
        ├── Message dispatch table:
        │   ├── Number of messages (u32)
        │   └── Entries (sorted by msg_id ascending):
        │       [msg_id: u32, handler_offset: u32, comment_offset: u32] × count
        └── Handler bytecode (per message):
            ├── Local count (u8) — includes params and temporaries
            ├── Param count (u8)
            ├── Param defaults: [param_id: u32, default: u32 tagged, name_id: u32] × param_count
            └── Bytecode instructions (variable length)

        String table:
        ├── Count (u32)
        ├── Offsets: [offset: u32] × count
        └── Null-terminated strings

        Debug info (optional):
        ├── Count (u32)
        └── Entries: [bytecode_offset: u32, line_number: u32] × count

        Source filename: null-terminated string
```

## Key Risks

| Risk | Mitigation |
|------|-----------|
| Bit-identical output is hard | Use the decompiler (`blakdeco`) to compare structural equality if byte-equality fails; identify ordering differences |
| Undocumented blakcomp behaviors | Use the existing ~1,232 .kod files as a test corpus — any difference reveals a spec gap |
| Symbol ID ordering | IDs must be assigned in the exact same order as blakcomp traverses classes/messages/params |
| Expression flattening temp allocation | Must match blakcomp's `simplify_expr()` temp variable numbering exactly |
| Sort order for dispatch tables | Parameters sorted by ID ascending, messages sorted by ID ascending — must match |
| String table ordering | Debug strings must appear in the same order |
| CR-LF handling | blakcomp writes `\r\n` for `\n` escapes in strings — must replicate |

## Estimated Effort

| Phase | Estimate | Notes |
|-------|----------|-------|
| 1 - Scaffolding | 1-2 days | Boilerplate |
| 2 - Bytecode representation | 2-3 days | Mechanical translation of bkod.h |
| 3 - Symbol ID assignment | 1 week | Tricky: must match blakcomp's ID ordering exactly |
| 4 - Expression flattening | 1-2 weeks | Core algorithm; must match temp allocation |
| 5 - Statement codegen | 1-2 weeks | 9 statement types (simplified from v8's 12+) |
| 6 - BOF writer | 1 week | Binary format, backpatching offsets |
| 7 - RSC writer | 2-3 days | Simple format |
| 8 - CLI & integration | 2-3 days | Wiring it together |
| 9 - Verification | 2-3 weeks | The long tail of matching behavior |
| 10 - Polish | 1 week | Better errors, warnings, perf |
| **Total** | **~8-12 weeks** | ~2 weeks faster than v8 target (no grammar/parser phase) |

## Open Questions

1. **Do we need to compile single files independently?** blakcomp compiles one `.kod` file at a time, using `kodbase.txt` for cross-file symbol resolution. Our `SymbolTable` loads all files at once. We could either:
   - (a) Compile all files in one pass (simpler, but different workflow)
   - (b) Match blakcomp's one-file-at-a-time model with kodbase persistence

2. **Debug info**: Should we emit debug line info by default? blakcomp requires the `-d` flag.

## Relationship to Server Port

The compiler and server are **independent projects** that share the BOF v5 format as a contract:
- Compiler produces `.bof` v5 files + `.rsc` files + `kodbase.txt`
- Server consumes `.bof` v5 files + `.rsc` files + `kodbase.txt`

Work can proceed in parallel:
- The server can load `.bof` files produced by the existing C compiler (`bc`)
- The compiler can be validated by loading its output into the existing C server

See `blakserv-rust-port.md` for the server port plan.
