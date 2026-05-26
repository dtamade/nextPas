unit nextpas.core.platform.sync.windows.ffi;

{$I nextpas.core.settings.inc}

interface

type
  DWORD = UInt32;

procedure InitializeSRWLock(SRWLock: Pointer); stdcall; external 'kernel32' name 'InitializeSRWLock';
procedure AcquireSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockExclusive';
function TryAcquireSRWLockExclusive(SRWLock: Pointer): LongBool; stdcall; external 'kernel32' name 'TryAcquireSRWLockExclusive';
procedure ReleaseSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockExclusive';
procedure AcquireSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockShared';
function TryAcquireSRWLockShared(SRWLock: Pointer): LongBool; stdcall; external 'kernel32' name 'TryAcquireSRWLockShared';
procedure ReleaseSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockShared';

procedure InitializeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'InitializeConditionVariable';
function SleepConditionVariableSRW(ConditionVariable: Pointer; SRWLock: Pointer; dwMilliseconds: DWORD; Flags: DWORD): LongBool; stdcall; external 'kernel32' name 'SleepConditionVariableSRW';
procedure WakeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeConditionVariable';
procedure WakeAllConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeAllConditionVariable';

function WaitOnAddress(Address: Pointer; CompareAddress: Pointer; AddressSize: PtrUInt; dwMilliseconds: DWORD): LongBool; stdcall; external 'kernel32' name 'WaitOnAddress';
procedure WakeByAddressSingle(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressSingle';
procedure WakeByAddressAll(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressAll';
function GetLastError: DWORD; stdcall; external 'kernel32' name 'GetLastError';

const
  INFINITE = DWORD($FFFFFFFF);
  ERROR_TIMEOUT = DWORD(1460);

implementation

end.
