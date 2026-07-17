# Platform return semantics (design freeze)

Authority companion to [CONTRACT.md](CONTRACT.md). Live constants: `nextpas.core.platform.error`.

## Three tiers

| Tier | Success | Failure | Examples |
|------|---------|---------|----------|
| **Error-code** | `0` | `PLATFORM_ERR_*` only (never bare `-1` as a portable error code) | `platform_file_open`, `platform_process_write_stdin_ex`, `platform_resource_get_limit`, `platform_io_close` |
| **Length / size** | `>= 0` bytes or count written | `PLATFORM_ERR_*` (negative portable codes; not raw errno unless already a `PLATFORM_ERR_*`) | `platform_args_get`, `platform_error_message`, `platform_fs_temp_dir` |
| **Value / sentinel** | domain value | domain sentinel (`-1` fd/pid/index, `nil` pointer) | `platform_getpid`, `platform_io_read`/`write` (byte counts), `platform_pty_master_fd`, poller index find, `platform_aligned_alloc` |

## Rules

1. New **error-code** APIs must not `Result := -1` on failure.
2. Legacy length-return wrappers may still map failures to `-1` only when `deprecated` and documented (prefer `*_ex`).
3. Single public error family: `PLATFORM_ERR_*`. Resource APIs use the same family (docs must not invent `PLATFORM_RESOURCE_ERROR_*` as public language).
4. FPC RTL isolation: production platform units must not `uses SysUtils`/`BaseUnix`/`Windows`/`Classes`. Args must not call `ParamCount`/`ParamStr`; use host sources (`/proc/self/cmdline`, Win32 command line).
5. `platform_error_message` is a length API: on failure return `PLATFORM_ERR_*`, not bare `-1`.
6. `platform_io_close` is an **error-code** API (`0` / `PLATFORM_ERR_*`). `platform_io_read` / `platform_io_write` / `platform_io_poll` remain **value/sentinel** (byte counts or ready count; failure sentinel `-1`).
7. Live gate: `core/tests/nextpas.core.platform/test_platform_return_semantics_contract`.
8. Windows unmapped host errors map to `PLATFORM_ERR_UNKNOWN` (-8), never raw `ERROR_*` passthrough.
9. `PLATFORM_ERR_PATH_TOO_LONG` stays **-7** (domain path clamp); not OS `ENAMETOOLONG` (36).
10. `PLATFORM_FS_SHORT_*_ERROR` aliases `PLATFORM_ERR_IO` (5) — no parallel `-5`/`-6` public values.
11. `platform_parse_*` is **error-code**: success `0`, failure `PLATFORM_ERR_INVALID` (not bare `-1`). Index find APIs remain value/sentinel (`-1` = not found).
12. **Length APIs** (`platform_fmt_*`, `platform_str_lower/upper/trim`, `platform_dl_error`, `platform_error_message`, …): success returns `>= 0` written length; **failure returns `PLATFORM_ERR_*`** (callers may use `if L < 0`). Never bare `-1` for portable buffer/arg failure on non-deprecated length APIs.
13. **Out-init**: for error-code APIs with `out` handles/positions/stats, initialize sentinels **before** host work (`AHandle.Value := -1`, `ANewPos := -1`, `FillChar(AStat, …)`, …) so failure paths never leave out-params undefined. **Unsupported stubs** with `out` handles must set the same sentinels (not only `Result := PLATFORM_ERR_UNSUPPORTED`).
14. **Error-code stubs** on unsupported hosts must return `PLATFORM_ERR_UNSUPPORTED` (or another `PLATFORM_ERR_*`), not bare `Result := -1` (value/sentinel APIs may still use domain `-1`).
15. **Index / find value-sentinel**: `platform_str_find` returns the byte index on hit and **`-1` when not found** (not an error-code API). Same family as poller entry index find.

## files / fs / io stance

- **files**: handle and directory primitives (`open`/`read`/`write`/`stat`/`dir_*`).
- **fs**: path-level composition (`mkdir_p`, `copy`, `exists`, `temp_dir`); may call files.
- **io**: poller/event surface (`platform.io`); generic fd helpers living under `process` (`platform_io_read` / `write` / `poll`) are **transitional / dual-API** value/sentinel surfaces for `process.pipe` only. New code must prefer `platform.files` and `platform_process_*_ex`. Do not expand `platform_io_*` surface.

## Dual API deprecation (process)

| Legacy | Prefer | Notes |
|--------|--------|-------|
| `platform_process_write_stdin` / `read_stdout` / `read_stderr` | `*_ex` variants | FPC `deprecated`; length/-1 wrappers |
| `platform_io_read` / `write` / `poll` | `platform.files` / process `*_ex` | Kept for process.pipe; value/sentinel; not for new public use |
| `platform_io_close` | `platform_process_close_handle` / files close | Error-code API; keep

## Args ownership

| Host | Source of truth | Notes |
|------|-----------------|-------|
| Linux | `/proc/self/cmdline` + `/proc/self/exe` | No `ParamCount`/`ParamStr` |
| Other Unix | `/proc/self/cmdline` when present; else argv[0] via same parser | exe_path may fall back to arg0 |
| Windows | `GetCommandLineW` + `CommandLineToArgvW`; exe via `GetModuleFileNameW` | UTF-16 → UTF-8 |
