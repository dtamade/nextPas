unit nextpas.core.simd.cpuinfo.windows;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

// Detect physical and logical core counts on Windows
function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;

implementation

{$IFDEF WINDOWS}

uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

type
  PSYSTEM_LOGICAL_PROCESSOR_INFORMATION = ^SYSTEM_LOGICAL_PROCESSOR_INFORMATION;
  SYSTEM_LOGICAL_PROCESSOR_INFORMATION = record
    ProcessorMask: PtrUInt;
    Relationship: DWORD;
    case Integer of
      0: (ProcessorCore: record
            Flags: Byte;
          end);
      1: (NumaNode: record
            NodeNumber: DWORD;
          end);
      2: (Cache: record
            Level: Byte;
            Associativity: Byte;
            LineSize: Word;
            Size: DWORD;
            Type_: DWORD;
          end);
      3: (Reserved: array[0..1] of UInt64);
  end;

function GetLogicalProcessorInformation(Buffer: Pointer; var ReturnLength: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'GetLogicalProcessorInformation';
function GetActiveProcessorCount(GroupNumber: WORD): DWORD; stdcall;
  external 'kernel32.dll' name 'GetActiveProcessorCount';

const
  RelationProcessorCore = 0;
  ALL_PROCESSOR_GROUPS = WORD($FFFF);

function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;
var
  Buffer: array of Byte;
  BufferSize: DWORD;
  P: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;
  BytesRead: DWORD;
  SI: SYSTEM_INFO;
  GroupCount: DWORD;
begin
  Physical := 0;
  Logical := 0;

  // Logical processors from SYSTEM_INFO (fallback)
  GetSystemInfo(SI);
  Logical := LongInt(SI.dwNumberOfProcessors);
  // Prefer groups-aware count when available (Win7+)
  GroupCount := GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
  if GroupCount > DWORD(Logical) then
    Logical := LongInt(GroupCount);

  // Try to count physical cores via GLPI
  BufferSize := 0;
  GetLogicalProcessorInformation(nil, BufferSize);
  if GetLastError = ERROR_INSUFFICIENT_BUFFER then
  begin
    SetLength(Buffer, BufferSize);
    if GetLogicalProcessorInformation(@Buffer[0], BufferSize) then
    begin
      BytesRead := 0;
      while BytesRead + SizeOf(SYSTEM_LOGICAL_PROCESSOR_INFORMATION) <= BufferSize do
      begin
        P := PSYSTEM_LOGICAL_PROCESSOR_INFORMATION(@Buffer[BytesRead]);
        if P^.Relationship = RelationProcessorCore then
          Inc(Physical);
        Inc(BytesRead, SizeOf(SYSTEM_LOGICAL_PROCESSOR_INFORMATION));
      end;
    end;
  end;

  if Physical = 0 then
    Physical := Logical;

  if Physical < 1 then Physical := 1;
  if Logical < 1 then Logical := 1;
  Result := (Physical > 0) and (Logical > 0);
end;

{$ELSE}

function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;
begin
  Physical := 0;
  Logical := 0;
  Result := False;
end;

{$ENDIF}

end.
