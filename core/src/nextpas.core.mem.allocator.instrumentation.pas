unit nextpas.core.mem.allocator.instrumentation;

{$I nextpas.core.settings.inc}

{*
 * Allocator instrumentation skeleton
 * - Statistics and fault-injection hooks
 * - Safe-by-default: macro-controlled and no-op when disabled
 * - Backward compatible: does not modify IAllocator
 *
 * Enable by defining FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION in settings
 *}

interface

uses
  SysUtils;

type
  { Summary statistics for allocator operations }
  TAllocatorStats = record
    AllocCount   : QWord;
    ReallocCount : QWord;
    FreeCount    : QWord;
    AllocBytes   : QWord;
    ReallocBytes : QWord;
    FreeBytes    : QWord;
  end;

{ Statistics API (no-op by default) }
procedure AllocatorStats_Reset; inline;
procedure AllocatorStats_Snapshot(out S: TAllocatorStats); inline;
procedure AllocatorStats_OnAlloc(ABytes: SizeUInt); inline;
procedure AllocatorStats_OnRealloc(ABytes: SizeUInt); inline;
procedure AllocatorStats_OnFree; inline;

{ Fault injection controls (no-op by default) }
procedure AllocatorFaults_Enable(AEnable: Boolean); inline;
procedure AllocatorFaults_SetFailEvery(AN: Cardinal); inline;
function  AllocatorFaults_IsEnabled: Boolean; inline;
function  AllocatorFaults_ShouldFailNow: Boolean; inline;

implementation

{$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
var
  GStats: TAllocatorStats;
  GFaultsEnabled: Boolean = False;
  GFailEvery: Cardinal = 0; // 0 => disabled
  GOpCounter: Cardinal = 0;
{$ENDIF}

procedure AllocatorStats_Reset; inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  FillChar(GStats, SizeOf(GStats), 0);
  {$ELSE}
  // no-op
  {$ENDIF}
end;

procedure AllocatorStats_Snapshot(out S: TAllocatorStats); inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  S := GStats;
  {$ELSE}
  FillChar(S, SizeOf(TAllocatorStats), 0);
  {$ENDIF}
end;

procedure AllocatorFaults_Enable(AEnable: Boolean); inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  GFaultsEnabled := AEnable;
  {$ELSE}
  // no-op
  {$ENDIF}
end;

procedure AllocatorFaults_SetFailEvery(AN: Cardinal); inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  GFailEvery := AN;
  GOpCounter := 0;
  {$ELSE}
  // no-op
  {$ENDIF}
end;

function AllocatorFaults_IsEnabled: Boolean; inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  Result := GFaultsEnabled and (GFailEvery <> 0);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure AllocatorStats_OnAlloc(ABytes: SizeUInt); inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  Inc(GStats.AllocCount);
  Inc(GStats.AllocBytes, ABytes);
  {$ELSE}
  // no-op
  {$ENDIF}
end;

procedure AllocatorStats_OnRealloc(ABytes: SizeUInt); inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  Inc(GStats.ReallocCount);
  Inc(GStats.ReallocBytes, ABytes);
  {$ELSE}
  // no-op
  {$ENDIF}
end;

procedure AllocatorStats_OnFree; inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  Inc(GStats.FreeCount);
  {$ELSE}
  // no-op
  {$ENDIF}
end;

function AllocatorFaults_ShouldFailNow: Boolean; inline;
begin
  {$IFDEF FAFAFA_CORE_ALLOCATOR_INSTRUMENTATION}
  if not AllocatorFaults_IsEnabled then Exit(False);
  Inc(GOpCounter);
  if (GFailEvery > 0) and (GOpCounter mod GFailEvery = 0) then Exit(True);
  Result := False;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

end.
