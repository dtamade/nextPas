unit nextpas.core.platform.console;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformConsoleSize = record
    Cols: Int32;
    Rows: Int32;
  end;

function platform_console_is_terminal(AFd: Int32): Boolean;
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
function platform_console_enable_ansi: Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

type
  TWinSize = packed record
    ws_row: UInt16;
    ws_col: UInt16;
    ws_xpixel: UInt16;
    ws_ypixel: UInt16;
  end;

const
{$IFDEF NEXTPAS_LINUX}
  TIOCGWINSZ = $5413;
{$ELSE}
  TIOCGWINSZ = $40087468;
{$ENDIF}

function platform_console_is_terminal(AFd: Int32): Boolean;
begin
  Result := isatty(AFd) <> 0;
end;

function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
var
  LWin: TWinSize;
begin
  ASize.Cols := 0;
  ASize.Rows := 0;
  if ioctl(1, TIOCGWINSZ, @LWin) < 0 then
    Exit(platform_get_errno);
  ASize.Cols := Int32(LWin.ws_col);
  ASize.Rows := Int32(LWin.ws_row);
  Result := 0;
end;

function platform_console_enable_ansi: Int32;
begin
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_console_is_terminal(AFd: Int32): Boolean;
var
  LHandle: HANDLE;
  LMode: DWORD;
  LStd: DWORD;
begin
  case AFd of
    0: LStd := STD_INPUT_HANDLE;
    1: LStd := STD_OUTPUT_HANDLE;
    2: LStd := STD_ERROR_HANDLE;
  else
    Exit(False);
  end;
  LHandle := GetStdHandle(LStd);
  if LHandle = HANDLE(PtrInt(-1)) then
    Exit(False);
  LMode := 0;
  Result := GetConsoleMode(LHandle, @LMode) <> 0;
end;

function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
type
  TConsoleScreenBufferInfo = packed record
    dwSizeX, dwSizeY: Int16;
    dwCursorX, dwCursorY: Int16;
    wAttributes: UInt16;
    srWindowLeft, srWindowTop, srWindowRight, srWindowBottom: Int16;
    dwMaxSizeX, dwMaxSizeY: Int16;
  end;
var
  LHandle: HANDLE;
  LInfo: TConsoleScreenBufferInfo;
begin
  ASize.Cols := 0;
  ASize.Rows := 0;
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if LHandle = HANDLE(PtrInt(-1)) then
    Exit(Int32(GetLastError));
  if GetConsoleScreenBufferInfo(LHandle, @LInfo) = 0 then
    Exit(Int32(GetLastError));
  ASize.Cols := Int32(LInfo.srWindowRight - LInfo.srWindowLeft + 1);
  ASize.Rows := Int32(LInfo.srWindowBottom - LInfo.srWindowTop + 1);
  Result := 0;
end;

function platform_console_enable_ansi: Int32;
var
  LHandle: HANDLE;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if LHandle <> HANDLE(PtrInt(-1)) then
  begin
    LMode := 0;
    if GetConsoleMode(LHandle, @LMode) <> 0 then
      SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  LHandle := GetStdHandle(STD_ERROR_HANDLE);
  if LHandle <> HANDLE(PtrInt(-1)) then
  begin
    LMode := 0;
    if GetConsoleMode(LHandle, @LMode) <> 0 then
      SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  Result := 0;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_console_is_terminal(AFd: Int32): Boolean;
begin Result := False; end;
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
begin ASize.Cols := 0; ASize.Rows := 0; Result := -1; end;
function platform_console_enable_ansi: Int32;
begin Result := -1; end;
{$ENDIF}

end.
