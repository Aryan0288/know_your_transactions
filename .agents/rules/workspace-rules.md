---
trigger: always_on
---

# Flutter Global Rules

## General
- Think before coding.
- Understand the existing codebase before making changes.
- Do not change existing functionality unless explicitly requested.
- Preserve backward compatibility whenever possible.
- Explain major architectural changes before implementing.

## Architecture
- Follow MVVM architecture.
- Follow Clean Architecture principles.
- Keep business logic separate from UI.
- Use proper separation of concerns.
- Keep code modular, scalable, and maintainable.

## SOLID Principles
- Follow SOLID principles.
- Avoid tightly coupled code.
- Prefer dependency injection.
- Program against abstractions, not implementations.

## Performance
- Never perform calculations inside build().
- Never perform API calls inside build().
- Never perform database queries inside build().
- Avoid unnecessary widget rebuilds.
- Use const constructors wherever possible.
- Use lazy loading for large lists.
- Use ListView.builder/GridView.builder for dynamic content.
- Optimize image loading and caching.
- Profile performance before applying optimizations.
- Do not sacrifice readability for micro-optimizations.

## UI Development
- Keep widgets small and reusable.
- Extract large widgets into separate files.
- Maintain responsive layouts.
- Follow existing design patterns and UI consistency.
- Ensure smooth animations and transitions.
- Do not introduce UI jank or frame drops.

## State Management
- Keep state management clean and predictable.
- Avoid unnecessary global state.
- Keep UI state and business state separate.
- Dispose controllers, streams, and listeners properly.

## Code Quality
- Write clean, readable, and self-documenting code.
- Use meaningful variable, class, and method names.
- Avoid duplicate code.
- Prefer composition over inheritance.
- Remove dead and unused code when safe.
- Keep methods focused on a single responsibility.

## Error Handling
- Handle exceptions gracefully.
- Never silently swallow exceptions.
- Add proper logging where necessary.
- Show user-friendly error messages.

## Security
- Do not hardcode secrets, API keys, or credentials.
- Use secure storage when required.
- Validate user inputs properly.

## Testing & Validation
- Run flutter analyze after modifications.
- Fix warnings and errors whenever possible.
- Verify affected functionality after changes.
- Do not mark tasks complete without validation.

## Dependencies
- Reuse existing dependencies when possible.
- Do not add new packages unless necessary.
- Justify adding new dependencies.

## File Organization
- Follow existing folder structure.
- Keep files focused on a single purpose.
- Avoid creating unnecessary files.

## Documentation
- Add comments only when they improve understanding.
- Document complex business logic.
- Avoid obvious comments that repeat the code.

<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
<!-- caveman-end -->

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

<!-- CONTEXT-MODE_START -->

# context-mode — MANDATORY routing rules

context-mode MCP tools available. Rules protect context window from flooding. One unrouted command dumps 56 KB into context. ## Think in Code — MANDATORY

Analyze/count/filter/compare/search/parse/transform data: **write code** via `mcp__context-mode__ctx_execute(language, code)`, `console.log()` only the answer. Do NOT read raw data into context. PROGRAM the analysis, not COMPUTE it. Pure JavaScript — Node.js built-ins only (`fs`, `path`, `child_process`). `try/catch`, handle `null`/`undefined`. One script replaces ten tool calls.

## BLOCKED — do NOT use

### curl / wget — FORBIDDEN
Do NOT use `curl`/`wget` via `run_command`. Dumps raw HTTP into context.
Use: `mcp__context-mode__ctx_fetch_and_index(url, source)` or `mcp__context-mode__ctx_execute(language: "javascript", code: "const r = await fetch(...)")`

### Inline HTTP — FORBIDDEN
No `node -e "fetch(..."`, `python -c "requests.get(..."` via `run_command`. Bypasses sandbox.
Use: `mcp__context-mode__ctx_execute(language, code)` — only stdout enters context

### Direct web fetching — FORBIDDEN
No `read_url_content` for large pages. Raw HTML can exceed 100 KB.
Use: `mcp__context-mode__ctx_fetch_and_index(url, source)` then `mcp__context-mode__ctx_search(queries)`

## REDIRECTED — use sandbox

### Shell (>20 lines output)
`run_command` ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`.
Otherwise: `mcp__context-mode__ctx_batch_execute(commands, queries)` or `mcp__context-mode__ctx_execute(language: "javascript", code: "...")`. Use `language: "shell"` only when code matches the host shell.

### File reading (for analysis)
Reading to **edit** → `view_file`/`replace_file_content` correct. Reading to **analyze/explore/summarize** → `mcp__context-mode__ctx_execute_file(path, language, code)`.

### Search (large results)
Use `mcp__context-mode__ctx_execute(language: "javascript", code: "...")` in sandbox for portable filtering/counting.

## Tool selection

1. **GATHER**: `mcp__context-mode__ctx_batch_execute(commands, queries)` — runs all commands, auto-indexes, returns search. ONE call replaces 30+. Each command: `{label: "header", command: "..."}`.
2. **FOLLOW-UP**: `mcp__context-mode__ctx_search(queries: ["q1", "q2", ...])` — all questions as array, ONE call.
3. **PROCESSING**: `mcp__context-mode__ctx_execute(language, code)` | `mcp__context-mode__ctx_execute_file(path, language, code)` — sandbox, only stdout enters context.
4. **WEB**: `mcp__context-mode__ctx_fetch_and_index(url, source)` then `mcp__context-mode__ctx_search(queries)` — raw HTML never enters context.
5. **INDEX**: `mcp__context-mode__ctx_index(content, source)` — store in FTS5 for later search.

## Parallel I/O batches

For multi-URL fetches or multi-API calls, **always** include `concurrency: N` (1-8):

- `mcp__context-mode__ctx_batch_execute(commands: [3+ network commands], concurrency: 5)` — gh, curl, dig, docker inspect, multi-region cloud queries
- `mcp__context-mode__ctx_fetch_and_index(requests: [{url, source}, ...], concurrency: 5)` — multi-URL batch fetch

**Use concurrency 4-8** for I/O-bound work (network calls, API queries). **Keep concurrency 1** for CPU-bound (npm test, build, lint) or commands sharing state (ports, lock files, same-repo writes).

GitHub API rate-limit: cap at 4 for `gh` calls.

## Output

Write artifacts to FILES — never inline. Return: file path + 1-line description.
Descriptive source labels for `search(source: "label")`.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call `stats` MCP tool, display full output verbatim |
| `ctx doctor` | Call `doctor` MCP tool, run returned shell command, display as checklist |
| `ctx upgrade` | Call `upgrade` MCP tool, run returned shell command, display as checklist |
| `ctx purge` | Call `purge` MCP tool with confirm: true. Warns before wiping knowledge base. |

After /clear or /compact: knowledge base and session stats preserved. Use `ctx purge` to start fresh.

<!-- CONTEXT-MODE_END -->
