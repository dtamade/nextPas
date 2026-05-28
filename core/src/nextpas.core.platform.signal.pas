unit nextpas.core.platform.signal;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformSignalHandler = procedure(ASignal: Int32); cdecl;

const
  PLATFORM_SIGINT  = 2;
  PLATFORM_SIGTERM = 15;
  PLATFORM_SIGHUP  = 1;
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  PLATFORM_SIGUSR1 = 30;
  PLATFORM_SIGUSR2 = 31;
{$ELSE}
  PLATFORM_SIGUSR1 = 10;
  PLATFORM_SIGUSR2 = 12;
{$ENDIF}

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
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

function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
begin
  Result := -1; // Windows: use SetConsoleCtrlHandler directly
end;

function platform_signal_reset(ASignal: Int32): Int32;
begin
  Result := -1;
end;

function platform_signal_block(ASignal: Int32): Int32;
begin
  Result := -1;
end;

function platform_signal_unblock(ASignal: Int32): Int32;
begin
  Result := -1;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_signal_set(ASignal: Int32;
  AHandler: TPlatformSignalHandler): Int32;
begin Result := -1; end;
function platform_signal_reset(ASignal: Int32): Int32;
begin Result := -1; end;
function platform_signal_block(ASignal: Int32): Int32;
begin Result := -1; end;
function platform_signal_unblock(ASignal: Int32): Int32;
begin Result := -1; end;
{$ENDIF}

end.
