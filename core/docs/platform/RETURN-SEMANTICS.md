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

## files / fs / io stance

- **files**: handle and directory primitives (`open`/`read`/`write`/`stat`/`dir_*`).
- **fs**: path-level composition (`mkdir_p`, `copy`, `exists`, `temp_dir`); may call files.
- **io**: poller/event surface (`platform.io`); generic fd helpers living under `process` (`platform_io_read` etc.) are value/sentinel and transitional for `process.pipe`. Prefer `platform.files` / `*_ex` process pipe APIs for new code.

## Args ownership

| Host | Source of truth | Notes |
|------|-----------------|-------|
| Linux | `/proc/self/cmdline` + `/proc/self/exe` | No `ParamCount`/`ParamStr` |
| Other Unix | `/proc/self/cmdline` when present; else argv[0] via same parser | exe_path may fall back to arg0 |
| Windows | `GetCommandLineW` + `CommandLineToArgvW`; exe via `GetModuleFileNameW` | UTF-16 → UTF-8 |
