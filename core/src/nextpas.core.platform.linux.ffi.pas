unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

const
  FUTEX_WAIT         = 0;
  FUTEX_WAKE         = 1;
  FUTEX_PRIVATE_FLAG = 128;

  {$IFDEF NEXTPAS_X86_64}
  LINUX_SYSCALL_FUTEX = 202;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  LINUX_SYSCALL_FUTEX = 98;
  {$ELSE}
    {$FATAL 'nextpas.core.platform.linux.ffi: unsupported Linux CPU for futex syscall'}
  {$ENDIF}

function linux_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function linux_errno: Int32;

implementation

function __errno_location: PInt32; cdecl; external 'c' name '__errno_location';

function linux_errno: Int32;
begin
  Result := __errno_location^;
end;

end.
