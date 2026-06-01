# Task Plan: parser TryParse API compliance

## Goal
Add backward-compatible TryParse facade APIs for JSON, YAML, TOML, and XML parser modules following `docs/api-conventions.md`, with focused tests and leak-aware verification.

## Current Phase
Complete

## Phases

### Phase 0: Conventions and discovery
- [x] Read `docs/api-conventions.md`.
- [x] Confirm actual parse function names, document types, and error/HasError surfaces.
- [x] Locate relevant test files and existing compile/run conventions.
- **Status:** complete

### Phase 1: RED tests
- [x] Add TryParse success/failure tests for JSON.
- [x] Add TryParse success/failure tests for YAML.
- [x] Add TryParse success/failure tests for TOML.
- [x] Add TryParse success/failure tests for XML, including failed-output ownership.
- [x] Compile modified tests and confirm expected failures before production code.
- **Status:** complete

### Phase 2: Thin wrapper APIs
- [x] Add interface and implementation declarations for `TryJsonParse`.
- [x] Add interface and implementation declarations for `TryYamlParse`.
- [x] Add interface and implementation declarations for `TryTomlParse`.
- [x] Add interface and implementation declarations for `TryXmlParse`.
- **Status:** complete

### Phase 3: Verification and cleanup
- [x] Compile and run modified tests with heaptrc where supported.
- [x] Check git diff/status and remove accidental generated outputs.
- [x] Record PASS/FAIL and leak evidence.
- **Status:** complete

## Decisions
| Decision | Rationale |
|---|---|
| Keep TryParse as thin facade wrappers | User explicitly requested backward-compatible wrapper APIs and no parsing logic duplication |

## Errors Encountered
| Error | Attempt | Resolution |
|---|---|---|
| Unrelated config/ini files were modified in the worktree by closeout | 1 | Confirmed they are outside this parser TryParse task and left them untouched |
