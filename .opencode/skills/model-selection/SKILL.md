---
name: model-selection
description: Guide for selecting Claude Opus vs Sonnet per implementation step in multi-model workflows
license: MIT
compatibility: opencode
---

You are guiding multi-model workflows where planning uses Claude Opus and execution uses Claude Sonnet. Your role is to help annotate plan steps with the optimal model and ensure the correct model executes each step.

## Model Characteristics

### Claude Opus (claude-opus-4)
**Strengths**: Deep reasoning, architectural vision, ambiguity resolution, novel design
**Use for**: Tasks where the "what" or "how" isn't fully specified

### Claude Sonnet (claude-sonnet-4 / claude-sonnet-4.5)
**Strengths**: Fast, precise execution of well-defined tasks, pattern matching, boilerplate
**Use for**: Tasks where the plan specifies exactly what to do

---

## When to Use Opus `[opus]`

Use Opus for steps requiring judgment, design decisions, or exploration:

### Architectural & Design Decisions
- API design, interface definitions, type system design
- Choosing between multiple implementation approaches
- Protocol-level decisions (message formats, state machines)
- Data model design (schemas, relationships)
- Error handling strategies
- System architecture planning

### Ambiguity Resolution
- Requirements clarification (when spec is vague)
- Trade-off analysis (performance vs. maintainability, etc.)
- Deciding what abstractions to introduce
- Interpreting unclear documentation or legacy code intent

### Novel Algorithm Design
- Creating new algorithms (not adapting existing ones)
- Complex state machine logic
- Non-obvious optimization strategies
- Parsing strategies for unusual formats

### Grammar & Language Analysis
- Tree-sitter grammar design or modification
- Parser implementation for new constructs
- LSP protocol interpretation
- Complex regex or query language design

### Code Exploration & Analysis
- Understanding unfamiliar codebases
- Reverse-engineering protocol behavior
- Analyzing complex inheritance chains
- Debugging subtle interaction bugs

### Planning & Scoping
- Breaking down large features into steps
- Estimating effort and identifying risks
- Determining test coverage strategy
- Deciding what to build first

---

## When to Use Sonnet `[sonnet]`

Use Sonnet for steps with clear specifications and established patterns:

### Well-Defined Implementation
- Implementing functions/structs where signature and behavior are specified
- Adding fields to existing types
- Implementing straightforward algorithms (sort, filter, map, etc.)
- Following existing code patterns (e.g., "add another message handler like the existing ones")

### Mechanical Refactoring
- Renaming functions, variables, types
- Changing visibility (`pub` → `pub(crate)`)
- Moving code between files
- Extracting helper functions
- Updating imports after moves

### Test Writing
- Writing unit tests that match existing test style
- Adding test cases for edge conditions
- Updating tests after refactoring
- Writing integration tests following existing patterns

### Boilerplate & Configuration
- Adding entries to match statements
- Implementing trait methods with obvious behavior
- Updating configuration files (Cargo.toml, .gitignore, etc.)
- Adding log statements
- Writing doc comments

### Component Wiring
- Connecting existing components (e.g., "wire handler to backend")
- Registering new items in tables/maps
- Plumbing data through layers
- Adding LSP capabilities using existing patterns

### Build & Tooling
- Updating makefiles, build scripts
- Adding CI/CD steps following existing patterns
- Fixing clippy warnings
- Formatting code

---

## Step Annotation Format

Annotate each step in the plan with `[opus]` or `[sonnet]` at the end of the step title:

```markdown
### Step 1: Design the protocol message format [opus]
### Step 2: Implement the message parser [sonnet]
### Step 3: Add unit tests for parser [sonnet]
### Step 4: Handle edge cases in error recovery [opus]
```

**No annotation** means the step is suitable for either model (simple, low-stakes tasks).

---

## Execution Guidelines

### Before Starting a Step

1. **Read the plan** — Check if the current step has a model annotation
2. **Verify model match** — If the step says `[opus]` but you're Sonnet (or vice versa), **pause and inform the user**
3. **Group same-model steps** — If possible, execute multiple adjacent same-model steps in one session to minimize handoffs
4. **Ask for clarification** — If unsure which model should handle a step, ask the user

### During Execution

- **Sonnet executing `[opus]` steps**: If the step requires design decisions you're not equipped for, pause and ask for Opus
- **Opus executing `[sonnet]` steps**: This is fine (Opus can do what Sonnet does), but may be slower/more expensive. Consider batching simple steps for Sonnet.

### When Model Mismatch Occurs

**If you're Sonnet and the step says `[opus]`**:
```
⚠️  This step is marked [opus] but I'm Claude Sonnet. The step involves [architectural 
decisions / ambiguity resolution / novel design], which is best handled by Opus.

Options:
1. Switch to Opus for this step (recommended)
2. I can attempt it, but may need guidance on design decisions
3. Skip for now and continue with later [sonnet] steps

What would you like to do?
```

**If you're Opus and multiple `[sonnet]` steps are queued**:
```
ℹ️  The next 4 steps are all marked [sonnet] (mechanical implementation tasks).

I can complete them now, or you can batch them for Sonnet to execute more efficiently.
What's your preference?
```

---

## Planning Best Practices

When creating or reviewing plans:

1. **Be specific in `[sonnet]` steps** — Sonnet needs clear instructions. Include:
   - Function signatures to implement
   - Expected behavior and edge cases
   - Relevant existing code to follow as patterns
   - Files to modify

2. **Keep `[opus]` steps focused** — Each should have a clear decision to make:
   - "Decide between approach A vs B"
   - "Design the error handling strategy"
   - "Determine which data structure to use"

3. **Group by model** — Arrange steps to minimize Opus ↔ Sonnet handoffs:
   ```markdown
   ✅ Good:
   Step 1: Design API [opus]
   Step 2: Design error types [opus]
   Step 3: Implement API [sonnet]
   Step 4: Implement error types [sonnet]
   
   ❌ Inefficient:
   Step 1: Design API [opus]
   Step 2: Implement API [sonnet]
   Step 3: Design error types [opus]
   Step 4: Implement error types [sonnet]
   ```

4. **Update annotations as scope changes** — If a "simple" step becomes complex, change `[sonnet]` → `[opus]`

---

## Common Patterns

### Feature Implementation
```markdown
1. Design the feature architecture [opus]
2. Define types and interfaces [opus]
3. Implement core logic [sonnet]
4. Add error handling [sonnet]
5. Write tests [sonnet]
6. Review integration points [opus]
```

### Bug Fix
```markdown
1. Investigate root cause [opus]
2. Decide on fix approach [opus]
3. Implement the fix [sonnet]
4. Add regression tests [sonnet]
```

### Refactoring
```markdown
1. Analyze current structure and decide on target architecture [opus]
2. Plan refactoring steps [opus]
3. Move code to new modules [sonnet]
4. Update imports and tests [sonnet]
5. Verify behavior unchanged [sonnet]
```

### Tree-sitter / LSP Work
```markdown
1. Analyze grammar requirements [opus]
2. Design CST node structure [opus]
3. Implement grammar rules [sonnet]
4. Add highlight queries [sonnet]
5. Wire LSP capabilities [sonnet]
6. Test and handle edge cases [opus]
```

---

## Integration with AGENTS.md

This skill supplements the "Model Selection" section in `AGENTS.md`. When creating plans:

1. Load this skill: `skill({ name: "model-selection" })`
2. Use the criteria above to annotate each step
3. Save the plan with annotations
4. During execution, check annotations before starting each step

---

## Summary Decision Tree

```
Is the task well-specified with clear implementation steps?
├─ YES → Can an experienced developer execute it mechanically?
│         ├─ YES → [sonnet]
│         └─ NO  → Does it require novel design? → [opus]
└─ NO  → Does it require design decisions or exploration?
          ├─ YES → [opus]
          └─ NO  → Clarify the task first, then re-evaluate
```

When in doubt, prefer `[opus]` for the first implementation of something new, then `[sonnet]` for similar tasks following the established pattern.
