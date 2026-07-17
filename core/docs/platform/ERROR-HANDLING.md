# Platform error handling

**Authority**: `core/src/nextpas.core.platform.error.pas`
**Return model**: [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)
**Status**: active (rewritten 2026-07-17 to match live constants)

## 1. PLATFORM_ERR_* (live values)

These mirror focused-runtime Linux errno numbers. Non-Linux hosts map native errors into this set via `platform_get_last_error` / host errno helpers.

| Constant | Value | Meaning |
|----------|------:|---------|
| *(success)* | 0 | Success for error-code APIs |
| `PLATFORM_ERR_PERM` | 1 | Operation not permitted |
| `PLATFORM_ERR_NOENT` | 2 | No such file or directory |
| `PLATFORM_ERR_INTR` | 4 | Interrupted system call |
| `PLATFORM_ERR_IO` | 5 | I/O error |
| `PLATFORM_ERR_BADF` | 9 | Bad file descriptor |
| `PLATFORM_ERR_AGAIN` | 11 | Resource temporarily unavailable |
| `PLATFORM_ERR_NOMEM` | 12 | Out of memory |
| `PLATFORM_ERR_BUSY` | 16 | Device or resource busy |
| `PLATFORM_ERR_EXIST` | 17 | File exists |
| `PLATFORM_ERR_NOTDIR` | 20 | Not a directory |
| `PLATFORM_ERR_INVALID` | 22 | Invalid argument |
| `PLATFORM_ERR_NOSPC` | 28 | No space left on device |
| `PLATFORM_ERR_PIPE` | 32 | Broken pipe |
| `PLATFORM_ERR_NOSYS` | 38 | Function not implemented |
| `PLATFORM_ERR_UNSUPPORTED` | 95 | Operation not supported |
| `PLATFORM_ERR_CONNRESET` | 104 | Connection reset by peer |
| `PLATFORM_ERR_TIMEDOUT` | 110 | Operation timed out |
| `PLATFORM_ERR_CONNREFUSED` | 111 | Connection refused |
| `PLATFORM_ERR_PATH_TOO_LONG` | -7 | Domain path exceeds `PLATFORM_FS_MAX_PATH` (not OS `ENAMETOOLONG`) |
| `PLATFORM_ERR_UNKNOWN` | -8 | Host native error could not be mapped to a portable `PLATFORM_ERR_*` |

Aliases (same values): `PLATFORM_ERR_ENOENT`, `PLATFORM_ERR_EEXIST`, `PLATFORM_ERR_ENOTDIR`, `PLATFORM_ERR_TIMEOUT`, `PLATFORM_ERR_INVALID_HANDLE`.

There is **no** `PLATFORM_ERR_OK` constant; success is the integer `0`.

### Mapping rules

- **POSIX**: `platform_get_last_error` returns host errno; known values already match `PLATFORM_ERR_*` Linux numbers. Unknown errno values stay as host errno for `platform_error_message` (strerror) but categorize as `ecInternal` when not in the portable set.
- **Windows**: `platform_map_windows_error_code` maps `ERROR_*` / `WSAE*` into `PLATFORM_ERR_*`. **Unmapped codes become `PLATFORM_ERR_UNKNOWN`**, never raw `ERROR_*` passthrough.
- **`PATH_TOO_LONG` (-7)** is a client-side domain limit used by `platform.fs` path clamps; it is intentionally not Linux `ENAMETOOLONG` (36).
- **`PLATFORM_FS_SHORT_READ_ERROR` / `PLATFORM_FS_SHORT_WRITE_ERROR`** are **aliases of `PLATFORM_ERR_IO` (5)**. They are not a second public error family and no longer use parallel magic values `-6`/`-5`.
- **`platform_parse_*`**: failure is `PLATFORM_ERR_INVALID` (error-code tier), never bare `-1`.
- **Observability note (F7 deferred)**: portable code space does not carry raw `GetLastError` / errno for unmapped Windows codes (`UNKNOWN`). Host-side debug logs remain the place for raw OS codes until a dedicated side-channel API is introduced.

## 2. Call pattern (error-code APIs)

```pascal
uses
  nextpas.core.platform.error,
  nextpas.core.platform.files;

var
  LHandle: TPlatformFileHandle;
  LErr: Int32;
  LBuf: array[0..255] of AnsiChar;
begin
  LErr := platform_file_open('/path', fomReadOnly, fcmOpenExisting, LHandle);
  if LErr <> 0 then
  begin
    platform_error_message(LErr, @LBuf[0], SizeOf(LBuf));
    { LBuf holds a portable message for known PLATFORM_ERR_* codes }
    Exit;
  end;
  platform_file_close(LHandle);
end;
```

Last host error (after a failed native call):

```pascal
LErr := platform_get_last_error; { already mapped to PLATFORM_ERR_* when possible }
```

## 3. What not to do

- Do not treat `-1` as a portable error-code for **error-code** APIs.
- Do not use the obsolete negative error table (`INVALID = -1`, `NOT_FOUND = -2`, ...). That table is **wrong** relative to `error.pas`.
- Do not invent a second public family such as `PLATFORM_RESOURCE_ERROR_*`; resource uses `PLATFORM_ERR_*`.

## 4. Length and sentinel APIs

See [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md). Length APIs return `>= 0` on success and `PLATFORM_ERR_*` on failure. Value/sentinel APIs may use `-1`/`nil` as domain sentinels.
