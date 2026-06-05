unit nextpas.core.platform.signal;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformSignalHandler = procedure(ASignal: Int32); cdecl;

const
  PLATFORM_SIGINT  = 2;
  PLATFORM_SIGTERM = 15;
  PLATFORM_SIGHUP  = 1;
  PLATFORM_SIGPIPE = 13;
{$IFDEF NEXTPAS_WINDOWS}
  { Windows console control event: Ctrl+Break has no POSIX signal twin. }
  PLATFORM_SIGBREAK = 21;
{$ENDIF}
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  PLATFORM_SIGUSR1 = 30;
  PLATFORM_SIGUSR2 = 31;
{$ELSE}
  PLATFORM_SIGUSR1 = 10;
  PLATFORM_SIGUSR2 = 12;
{$ENDIF}
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD) or defined(NEXTPAS_ANDROID)}
  { 窗口尺寸变化信号。Linux/macOS/FreeBSD/Android 一致为 28。
    Windows 无 SIGWINCH（窗口变化经输入事件处理），故不定义。 }
  PLATFORM_SIGWINCH = 28;
{$ENDIF}

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
function platform_signal_ignore(ASignal: Int32): Int32;
function platform_signal_reset(ASignal: Int32): Int32;
function platform_signal_block(ASignal: Int32): Int32;
function platform_signal_unblock(ASignal: Int32): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.ffi;

const
  SA_RESTART  = $10000000;
  SA_SIGINFO  = $00000004;
  SIG_DFL     = Pointer(0);
  SIG_BLOCK   = 0;
  SIG_UNBLOCK = 1;

type
  TLibcSigSet = record
    Bits: array[0..15] of QWord;
  end;
  TLibcSigAction = record
    sa_handler: Pointer;
    sa_mask: TLibcSigSet;
    sa_flags: Int32;
    sa_restorer: Pointer;
  end;

procedure SigSetEmpty(out ASet: TLibcSigSet);
begin
  FillChar(ASet, SizeOf(ASet), 0);
end;

procedure SigSetAdd(var ASet: TLibcSigSet; ASig: Int32);
var
  LIdx, LBit: Int32;
begin
  Dec(ASig);
  LIdx := ASig div 64;
  LBit := ASig mod 64;
  ASet.Bits[LIdx] := ASet.Bits[LIdx] or (QWord(1) shl LBit);
end;

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
var
  LAct: TLibcSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := Pointer(AHandler);
  LAct.sa_flags := SA_RESTART;
  SigSetEmpty(LAct.sa_mask);
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_ignore(ASignal: Int32): Int32;
var
  LAct: TLibcSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := Pointer(1);
  LAct.sa_flags := 0;
  SigSetEmpty(LAct.sa_mask);
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_reset(ASignal: Int32): Int32;
var
  LAct: TLibcSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := SIG_DFL;
  LAct.sa_flags := 0;
  SigSetEmpty(LAct.sa_mask);
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_block(ASignal: Int32): Int32;
var
  LSet: TLibcSigSet;
begin
  SigSetEmpty(LSet);
  SigSetAdd(LSet, ASignal);
  if sigprocmask(SIG_BLOCK, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_unblock(ASignal: Int32): Int32;
var
  LSet: TLibcSigSet;
begin
  SigSetEmpty(LSet);
  SigSetAdd(LSet, ASignal);
  if sigprocmask(SIG_UNBLOCK, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.darwin.ffi;

const
  SA_RESTART = $0002;

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
var
  LAct: TPlatformDarwinSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := TPlatformDarwinSigActionHandler(AHandler);
  LAct.sa_flags := SA_RESTART;
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_ignore(ASignal: Int32): Int32;
var
  LAct: TPlatformDarwinSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := TPlatformDarwinSigActionHandler(Pointer(1));
  LAct.sa_flags := 0;
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_reset(ASignal: Int32): Int32;
var
  LAct: TPlatformDarwinSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_block(ASignal: Int32): Int32;
var
  LSet: TPlatformDarwinSignalSet;
begin
  FillChar(LSet, SizeOf(LSet), 0);
  LSet.Words[0] := UInt32(1) shl (ASignal - 1);
  if sigprocmask(1{SIG_BLOCK}, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_unblock(ASignal: Int32): Int32;
var
  LSet: TPlatformDarwinSignalSet;
begin
  FillChar(LSet, SizeOf(LSet), 0);
  LSet.Words[0] := UInt32(1) shl (ASignal - 1);
  if sigprocmask(2{SIG_UNBLOCK}, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.freebsd.base,
  nextpas.core.platform.freebsd.ffi;

const
  SA_RESTART = $0002;

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
var
  LAct: TPlatformFreeBSDSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := TPlatformFreeBSDSigActionHandler(AHandler);
  LAct.sa_flags := SA_RESTART;
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_ignore(ASignal: Int32): Int32;
var
  LAct: TPlatformFreeBSDSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := TPlatformFreeBSDSigActionHandler(Pointer(1));
  LAct.sa_flags := 0;
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_reset(ASignal: Int32): Int32;
var
  LAct: TPlatformFreeBSDSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  if sigaction(ASignal, @LAct, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_block(ASignal: Int32): Int32;
var
  LSet: TPlatformFreeBSDSignalSet;
  LIdx, LBit: Int32;
begin
  FillChar(LSet, SizeOf(LSet), 0);
  LIdx := (ASignal - 1) div 32;
  LBit := (ASignal - 1) mod 32;
  LSet.Words[LIdx] := Int32(1 shl LBit);
  if sigprocmask(1{SIG_BLOCK}, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_signal_unblock(ASignal: Int32): Int32;
var
  LSet: TPlatformFreeBSDSignalSet;
  LIdx, LBit: Int32;
begin
  FillChar(LSet, SizeOf(LSet), 0);
  LIdx := (ASignal - 1) div 32;
  LBit := (ASignal - 1) mod 32;
  LSet.Words[LIdx] := Int32(1 shl LBit);
  if sigprocmask(2{SIG_UNBLOCK}, @LSet, nil) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

const
  WINDOWS_SIGNAL_DEFAULT = 0;
  WINDOWS_SIGNAL_HANDLER = 1;
  WINDOWS_SIGNAL_IGNORE = 2;
  WINDOWS_SIGNAL_CTRL_C_INDEX = 0;
  WINDOWS_SIGNAL_CTRL_BREAK_INDEX = 1;

var
  GWindowsSignalModes: array[0..1] of Int32 = (
    WINDOWS_SIGNAL_DEFAULT,
    WINDOWS_SIGNAL_DEFAULT
  );
  GWindowsSignalHandlers: array[0..1] of TPlatformSignalHandler = (nil, nil);
  GWindowsConsoleCtrlInstalled: Boolean = False;

function WindowsSignalIndex(ASignal: Int32; out AIndex: Int32): Boolean;
begin
  case ASignal of
    PLATFORM_SIGINT:
      begin
        AIndex := WINDOWS_SIGNAL_CTRL_C_INDEX;
        Result := True;
      end;
    PLATFORM_SIGBREAK:
      begin
        AIndex := WINDOWS_SIGNAL_CTRL_BREAK_INDEX;
        Result := True;
      end;
  else
    AIndex := -1;
    Result := False;
  end;
end;

function WindowsCtrlEventToSignal(ACtrlType: DWORD; out ASignal: Int32;
  out AIndex: Int32): Boolean;
begin
  case ACtrlType of
    CTRL_C_EVENT:
      begin
        ASignal := PLATFORM_SIGINT;
        AIndex := WINDOWS_SIGNAL_CTRL_C_INDEX;
        Result := True;
      end;
    CTRL_BREAK_EVENT:
      begin
        ASignal := PLATFORM_SIGBREAK;
        AIndex := WINDOWS_SIGNAL_CTRL_BREAK_INDEX;
        Result := True;
      end;
  else
    ASignal := 0;
    AIndex := -1;
    Result := False;
  end;
end;

function WindowsConsoleCtrlDispatcher(ACtrlType: DWORD): WINBOOL; stdcall;
var
  LSignal: Int32;
  LIndex: Int32;
  LHandler: TPlatformSignalHandler;
begin
  if not WindowsCtrlEventToSignal(ACtrlType, LSignal, LIndex) then
    Exit(False);

  case GWindowsSignalModes[LIndex] of
    WINDOWS_SIGNAL_IGNORE:
      Exit(True);
    WINDOWS_SIGNAL_HANDLER:
      begin
        LHandler := GWindowsSignalHandlers[LIndex];
        if Assigned(LHandler) then
        begin
          LHandler(LSignal);
          Exit(True);
        end;
      end;
  end;
  Result := False;
end;

function EnsureWindowsConsoleCtrlHandler: Int32;
begin
  if GWindowsConsoleCtrlInstalled then
    Exit(0);
  if SetConsoleCtrlHandler(@WindowsConsoleCtrlDispatcher, True) then
  begin
    GWindowsConsoleCtrlInstalled := True;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function MaybeRemoveWindowsConsoleCtrlHandler: Int32;
begin
  if not GWindowsConsoleCtrlInstalled then
    Exit(0);
  if (GWindowsSignalModes[WINDOWS_SIGNAL_CTRL_C_INDEX] <> WINDOWS_SIGNAL_DEFAULT) or
     (GWindowsSignalModes[WINDOWS_SIGNAL_CTRL_BREAK_INDEX] <> WINDOWS_SIGNAL_DEFAULT) then
    Exit(0);
  if SetConsoleCtrlHandler(@WindowsConsoleCtrlDispatcher, False) then
  begin
    GWindowsConsoleCtrlInstalled := False;
    Result := 0;
  end
  else
    Result := Int32(GetLastError);
end;

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
var
  LIndex: Int32;
begin
  if not WindowsSignalIndex(ASignal, LIndex) then
    Exit(Int32(ERROR_NOT_SUPPORTED));
  if not Assigned(AHandler) then
    Exit(Int32(ERROR_INVALID_PARAMETER));
  Result := EnsureWindowsConsoleCtrlHandler;
  if Result <> 0 then
    Exit;
  GWindowsSignalHandlers[LIndex] := AHandler;
  GWindowsSignalModes[LIndex] := WINDOWS_SIGNAL_HANDLER;
  Result := 0;
end;

function platform_signal_reset(ASignal: Int32): Int32;
var
  LIndex: Int32;
begin
  if not WindowsSignalIndex(ASignal, LIndex) then
    Exit(Int32(ERROR_NOT_SUPPORTED));
  GWindowsSignalHandlers[LIndex] := nil;
  GWindowsSignalModes[LIndex] := WINDOWS_SIGNAL_DEFAULT;
  Result := MaybeRemoveWindowsConsoleCtrlHandler;
end;

function platform_signal_ignore(ASignal: Int32): Int32;
var
  LIndex: Int32;
begin
  if not WindowsSignalIndex(ASignal, LIndex) then
    Exit(Int32(ERROR_NOT_SUPPORTED));
  Result := EnsureWindowsConsoleCtrlHandler;
  if Result <> 0 then
    Exit;
  GWindowsSignalHandlers[LIndex] := nil;
  GWindowsSignalModes[LIndex] := WINDOWS_SIGNAL_IGNORE;
  Result := 0;
end;

function platform_signal_block(ASignal: Int32): Int32;
begin
  Result := Int32(ERROR_NOT_SUPPORTED);
end;

function platform_signal_unblock(ASignal: Int32): Int32;
begin
  Result := Int32(ERROR_NOT_SUPPORTED);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
begin Result := -1; end;
function platform_signal_ignore(ASignal: Int32): Int32;
begin Result := -1; end;
function platform_signal_reset(ASignal: Int32): Int32;
begin Result := -1; end;
function platform_signal_block(ASignal: Int32): Int32;
begin Result := -1; end;
function platform_signal_unblock(ASignal: Int32): Int32;
begin Result := -1; end;
{$ENDIF}

end.
