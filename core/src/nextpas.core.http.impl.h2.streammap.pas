unit nextpas.core.http.impl.h2.streammap;
{**
 * @desc H2 server stream ID map (open-addressed hash).
 *       Mechanical extract from impl.h2.session (behavior freeze).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.stream,
  nextpas.core.http.impl.h2.types;

type
  TH2StreamMap = class
  private const
    INITIAL_CAPACITY = 16;
    LOAD_FACTOR_NUM = 3; { numerator: 3/4 = 75% }
    LOAD_FACTOR_DEN = 4;
    SLOT_EMPTY = 0;
    SLOT_USED = 1;
    SLOT_DELETED = 2;
  private
    FKeys: array of UInt32;
    FStreams: array of TH2Stream;
    FSlots: array of Byte;
    FCapacity: SizeInt;
    FCount: SizeInt;
    FDeletedCount: SizeInt;
    procedure Grow;
    function FindSlot(const AStreamID: UInt32): SizeInt;
  public
    constructor Create;
    destructor Destroy; override;
    function Find(const AStreamID: UInt32): TH2Stream;
    function FindOrCreate(const AStreamID: UInt32;
      const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
      var AConnectionFlow: TH2ConnectionFlowControl;
      var ADecoder: THPackDecoder;
      const AMaxHeaderListSize: UInt32 = H2_DEFAULT_MAX_HEADER_LIST_SIZE): TH2Stream;
    procedure Remove(const AStreamID: UInt32);
    function ActiveCount: SizeInt;
    function AnyPending: Boolean;
    procedure CloseAll(const AErrorCode: UInt32);
    procedure ApplyPeerInitialWindowSize(const ANewInitialWindowSize: UInt32);
    function ItemAt(const AIndex: SizeInt): TH2Stream;
  end;

implementation

constructor TH2StreamMap.Create;
begin
  inherited Create;
  FCapacity := INITIAL_CAPACITY;
  SetLength(FKeys, FCapacity);
  SetLength(FStreams, FCapacity);
  SetLength(FSlots, FCapacity);
  { FSlots is zero-initialized (SLOT_EMPTY = 0) }
end;

destructor TH2StreamMap.Destroy;
begin
  CloseAll(H2_ERR_CANCEL);
  FKeys := nil;
  FStreams := nil;
  FSlots := nil;
  inherited Destroy;
end;

function TH2StreamMap.FindSlot(const AStreamID: UInt32): SizeInt;
var
  LMask: SizeInt;
  LIndex: SizeInt;
  LFirstDeleted: SizeInt;
begin
  LMask := FCapacity - 1;
  LIndex := (AStreamID * 2654435761) and LMask; { Fibonacci hashing }
  LFirstDeleted := -1;
  while True do
  begin
    case FSlots[LIndex] of
      SLOT_EMPTY:
        begin
          if LFirstDeleted >= 0 then
            Result := LFirstDeleted
          else
            Result := LIndex;
          Exit;
        end;
      SLOT_USED:
        begin
          if FKeys[LIndex] = AStreamID then
          begin
            Result := LIndex;
            Exit;
          end;
        end;
      SLOT_DELETED:
        begin
          if LFirstDeleted < 0 then
            LFirstDeleted := LIndex;
        end;
    end;
    LIndex := (LIndex + 1) and LMask;
  end;
end;

procedure TH2StreamMap.Grow;
var
  LOldKeys: array of UInt32;
  LOldStreams: array of TH2Stream;
  LOldSlots: array of Byte;
  LOldCapacity: SizeInt;
  LI: SizeInt;
  LIndex: SizeInt;
  LMask: SizeInt;
begin
  LOldKeys := FKeys;
  LOldStreams := FStreams;
  LOldSlots := FSlots;
  LOldCapacity := FCapacity;

  FCapacity := FCapacity * 2;
  SetLength(FKeys, FCapacity);
  SetLength(FStreams, FCapacity);
  SetLength(FSlots, FCapacity);
  FCount := 0;
  FDeletedCount := 0;
  { FSlots is zero-initialized }

  LMask := FCapacity - 1;
  for LI := 0 to LOldCapacity - 1 do
  begin
    if LOldSlots[LI] = SLOT_USED then
    begin
      LIndex := (LOldKeys[LI] * 2654435761) and LMask;
      while FSlots[LIndex] = SLOT_USED do
        LIndex := (LIndex + 1) and LMask;
      FKeys[LIndex] := LOldKeys[LI];
      FStreams[LIndex] := LOldStreams[LI];
      FSlots[LIndex] := SLOT_USED;
      Inc(FCount);
    end;
  end;
end;

function TH2StreamMap.Find(const AStreamID: UInt32): TH2Stream;
var
  LIndex: SizeInt;
begin
  LIndex := FindSlot(AStreamID);
  if (LIndex >= 0) and (FSlots[LIndex] = SLOT_USED) and
     (FKeys[LIndex] = AStreamID) then
    Result := FStreams[LIndex]
  else
    Result := nil;
end;

function TH2StreamMap.FindOrCreate(const AStreamID: UInt32;
  const ASendWindowSize: UInt32; const ARecvWindowSize: UInt32;
  var AConnectionFlow: TH2ConnectionFlowControl;
  var ADecoder: THPackDecoder; const AMaxHeaderListSize: UInt32): TH2Stream;
var
  LIndex: SizeInt;
begin
  LIndex := FindSlot(AStreamID);
  if (LIndex >= 0) and (FSlots[LIndex] = SLOT_USED) and
     (FKeys[LIndex] = AStreamID) then
    Exit(FStreams[LIndex]);

  { Check load factor: (used + deleted + 1) / capacity > 3/4?
    Must include FDeletedCount: tombstones consume probe slots, so a table
    with many deleted entries degrades to O(n) probing unless we rehash. }
  if (FCount + FDeletedCount + 1) * LOAD_FACTOR_DEN > FCapacity * LOAD_FACTOR_NUM then
  begin
    Grow;
    LIndex := FindSlot(AStreamID);
  end;

  FKeys[LIndex] := AStreamID;
  FStreams[LIndex] := TH2Stream.Create(AStreamID, ASendWindowSize,
    ARecvWindowSize, AConnectionFlow, ADecoder, AMaxHeaderListSize);
  if FSlots[LIndex] = SLOT_DELETED then
    Dec(FDeletedCount);
  FSlots[LIndex] := SLOT_USED;
  Inc(FCount);
  Result := FStreams[LIndex];
end;

procedure TH2StreamMap.Remove(const AStreamID: UInt32);
var
  LIndex: SizeInt;
begin
  LIndex := FindSlot(AStreamID);
  if (LIndex < 0) or (FSlots[LIndex] <> SLOT_USED) or
     (FKeys[LIndex] <> AStreamID) then
    Exit;
  FStreams[LIndex].Free;
  FStreams[LIndex] := nil;
  FSlots[LIndex] := SLOT_DELETED;
  Dec(FCount);
  Inc(FDeletedCount);
end;

function TH2StreamMap.ActiveCount: SizeInt;
begin
  Result := FCount;
end;

function TH2StreamMap.AnyPending: Boolean;
begin
  Result := FCount > 0;
end;

procedure TH2StreamMap.CloseAll(const AErrorCode: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to FCapacity - 1 do
  begin
    if FSlots[LI] = SLOT_USED then
    begin
      FStreams[LI].Reset(AErrorCode);
      FStreams[LI].Free;
      FStreams[LI] := nil;
      FSlots[LI] := SLOT_EMPTY;
    end;
  end;
  FCount := 0;
  FDeletedCount := 0;
end;

procedure TH2StreamMap.ApplyPeerInitialWindowSize(
  const ANewInitialWindowSize: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to FCapacity - 1 do
    if FSlots[LI] = SLOT_USED then
      FStreams[LI].ApplyPeerInitialWindowSize(ANewInitialWindowSize);
end;

function TH2StreamMap.ItemAt(const AIndex: SizeInt): TH2Stream;
var
  LI, LFound: SizeInt;
begin
  { Iterate hash table to find the AIndex-th active entry }
  LFound := 0;
  for LI := 0 to FCapacity - 1 do
  begin
    if FSlots[LI] = SLOT_USED then
    begin
      if LFound = AIndex then
        Exit(FStreams[LI]);
      Inc(LFound);
    end;
  end;
  Result := nil;
end;

end.