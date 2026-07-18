{
    nextpas.core.mem.allocator.watermark
    ------------------------------------
    Watermark allocator — checkpoint/rollback.

    Allocates linearly from a region. Checkpoint saves the current
    position. Rollback restores to the last checkpoint, effectively
    freeing everything allocated after the checkpoint.

    No individual free — only bulk rollback. Extremely fast for
    scoped allocations (e.g., parsing, request handling).
}

unit nextpas.core.mem.allocator.watermark;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  WATERMARK_MAX_CHECKPOINTS = 16;
  WATERMARK_DEFAULT_REGION = 65536;

type
  TWatermarkStats = record
    AllocCount: UInt64;
    TotalBytes: UInt64;
    CheckpointCount: UInt64;
    RollbackCount: UInt64;
  end;

  TWatermarkAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRegion: PByte;
    FRegionSize: SizeUInt;
    FOffset: SizeUInt;
    FCheckpoints: array[0..WATERMARK_MAX_CHECKPOINTS - 1] of SizeUInt;
    FCheckpointCount: Integer;
    FStats: TWatermarkStats;
    function AllocateFromRegion(ASize: SizeUInt): Pointer;
  public
    constructor Create(AInner: IAllocator; ARegionSize: SizeUInt = WATERMARK_DEFAULT_REGION);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    function Checkpoint: Boolean;
    procedure Rollback;
    function GetStats: TWatermarkStats;
  end;

implementation

uses
  nextpas.core.base;

{ TWatermarkAllocator }

constructor TWatermarkAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  FRegionSize := ARegionSize;
  FRegion := PByte(FInner.GetMem(FRegionSize));
  FOffset := 0;
  FCheckpointCount := 0;
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TWatermarkAllocator.Destroy;
begin
  if FRegion <> nil then
    FInner.FreeMem(FRegion);
  FInner := nil;
  inherited Destroy;
end;

function TWatermarkAllocator.AllocateFromRegion(ASize: SizeUInt): Pointer;
var
  LAligned: SizeUInt;
begin
  if ASize = 0 then
    Exit(nil);
  // Align to 8 bytes，检查溢出
  LAligned := (ASize + 7) and not SizeUInt(7);
  if LAligned < ASize then
    Exit(nil); // 对联回绕
  if FOffset + LAligned > FRegionSize then
    Exit(nil);
  if FOffset + LAligned < FOffset then
    Exit(nil); // 偏移回绕
  Result := FRegion + FOffset;
  Inc(FOffset, LAligned);
  Inc(FStats.AllocCount);
  Inc(FStats.TotalBytes, ASize);
end;

function TWatermarkAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := AllocateFromRegion(ASize);
end;

function TWatermarkAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := AllocateFromRegion(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TWatermarkAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  // Watermark doesn't support individual realloc — allocate new
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);
  Result := AllocateFromRegion(ASize);
end;

procedure TWatermarkAllocator.FreeMem(APtr: Pointer); inline;
begin
  // No-op — watermark doesn't support individual free
end;

function TWatermarkAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := False;
end;

function TWatermarkAllocator.Checkpoint: Boolean;
begin
  if FCheckpointCount >= WATERMARK_MAX_CHECKPOINTS then
    Exit(False);
  FCheckpoints[FCheckpointCount] := FOffset;
  Inc(FCheckpointCount);
  Inc(FStats.CheckpointCount);
  Result := True;
end;

procedure TWatermarkAllocator.Rollback;
begin
  if FCheckpointCount <= 0 then
    Exit;
  Dec(FCheckpointCount);
  FOffset := FCheckpoints[FCheckpointCount];
  Inc(FStats.RollbackCount);
end;

function TWatermarkAllocator.GetStats: TWatermarkStats;
begin
  Result := FStats;
end;

end.
