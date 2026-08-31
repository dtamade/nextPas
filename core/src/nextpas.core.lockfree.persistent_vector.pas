{******************************************************************************
  nextpas.core.lockfree.persistent_vector

  Persistent immutable vector with chunk-level copy-on-write sharing.

  Design:
  - Values live in fixed 32-element chunks.
  - Every vector owns its pointer spine and retains unchanged chunks.
  - Append and Assoc clone only the modified chunk.
  - Atomic chunk reference counts allow immutable versions to be released
    independently after being shared across reader threads.
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.persistent_vector;

interface

uses
  nextpas.core.errors;

const
  PVECTOR_CHUNK_SIZE = 32;

type
  TPVectorResult = (
    pvOk,
    pvOutOfBounds,
    pvEmpty
  );

  {**
   * 持久化不可变向量。
   *
   * Append/Assoc 返回新版本，只复制修改路径上的 chunk；未修改 chunk
   * 通过原子引用计数共享。调用方拥有每个返回的 vector 对象。
   *}
  TPersistentVector = class
  private type
    PVectorChunk = ^TVectorChunk;
    TVectorChunk = record
      RefCount: Int32;
      Used: Int32;
      Items: array[0..PVECTOR_CHUNK_SIZE - 1] of AnsiString;
    end;
  private
    FChunks: array of PVectorChunk;
    FCount: Int32;
    function NewChunk: PVectorChunk;
    function CloneChunk(AChunk: PVectorChunk): PVectorChunk;
    procedure RetainChunk(AChunk: PVectorChunk);
    procedure ReleaseChunk(AChunk: PVectorChunk);
  public
    constructor Create;
    destructor Destroy; override;

    function Count: Int32;
    function Nth(AIdx: Int32; out AValue: AnsiString): TPVectorResult;
    function Append(const AValue: AnsiString): TPersistentVector;
    function Assoc(AIdx: Int32; const AValue: AnsiString): TPersistentVector;
    function Concat(AOther: TPersistentVector): TPersistentVector;
    function ToArray: specialize TArray<AnsiString>;
    function IsEmpty: Boolean;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TPersistentVector.Create;
begin
  inherited Create;
  FChunks := nil;
  FCount := 0;
end;

destructor TPersistentVector.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TPersistentVector.NewChunk: PVectorChunk;
begin
  New(Result);
  Result^.RefCount := 1;
  Result^.Used := 0;
end;

function TPersistentVector.CloneChunk(AChunk: PVectorChunk): PVectorChunk;
var
  LI: Int32;
begin
  Result := NewChunk;
  try
    Result^.Used := AChunk^.Used;
    for LI := 0 to AChunk^.Used - 1 do
      Result^.Items[LI] := AChunk^.Items[LI];
  except
    Dispose(Result);
    raise;
  end;
end;

procedure TPersistentVector.RetainChunk(AChunk: PVectorChunk);
begin
  if AChunk <> nil then
    atomic_fetch_add(AChunk^.RefCount, 1, mo_acq_rel);
end;

procedure TPersistentVector.ReleaseChunk(AChunk: PVectorChunk);
begin
  if (AChunk <> nil) and
     (atomic_fetch_sub(AChunk^.RefCount, 1, mo_acq_rel) = 1) then
    Dispose(AChunk);
end;

procedure TPersistentVector.Clear;
var
  LI: Int32;
begin
  for LI := 0 to High(FChunks) do
    ReleaseChunk(FChunks[LI]);
  FChunks := nil;
  FCount := 0;
end;

function TPersistentVector.Count: Int32;
begin
  Result := FCount;
end;

function TPersistentVector.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TPersistentVector.Nth(AIdx: Int32;
  out AValue: AnsiString): TPVectorResult;
var
  LChunkIndex, LItemIndex: Int32;
begin
  if (AIdx < 0) or (AIdx >= FCount) then
  begin
    AValue := '';
    Exit(pvOutOfBounds);
  end;
  LChunkIndex := AIdx div PVECTOR_CHUNK_SIZE;
  LItemIndex := AIdx mod PVECTOR_CHUNK_SIZE;
  AValue := FChunks[LChunkIndex]^.Items[LItemIndex];
  Result := pvOk;
end;

function TPersistentVector.Append(const AValue: AnsiString): TPersistentVector;
var
  LI, LChunkCount, LTailIndex: Int32;
  LTail: PVectorChunk;
begin
  if FCount = High(Int32) then
    raise EArgumentError.Create('TPersistentVector: maximum size reached');

  Result := TPersistentVector.Create;
  try
    Result.FCount := FCount + 1;
    LChunkCount := Length(FChunks);
    if (FCount mod PVECTOR_CHUNK_SIZE) = 0 then
    begin
      SetLength(Result.FChunks, LChunkCount + 1);
      for LI := 0 to LChunkCount - 1 do
      begin
        RetainChunk(FChunks[LI]);
        Result.FChunks[LI] := FChunks[LI];
      end;
      LTail := NewChunk;
      Result.FChunks[LChunkCount] := LTail;
      LTail^.Items[0] := AValue;
      LTail^.Used := 1;
    end
    else
    begin
      SetLength(Result.FChunks, LChunkCount);
      LTailIndex := LChunkCount - 1;
      for LI := 0 to LTailIndex - 1 do
      begin
        RetainChunk(FChunks[LI]);
        Result.FChunks[LI] := FChunks[LI];
      end;
      LTail := CloneChunk(FChunks[LTailIndex]);
      Result.FChunks[LTailIndex] := LTail;
      LTail^.Items[LTail^.Used] := AValue;
      Inc(LTail^.Used);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TPersistentVector.Assoc(AIdx: Int32;
  const AValue: AnsiString): TPersistentVector;
var
  LI, LChunkIndex, LItemIndex: Int32;
begin
  if (AIdx < 0) or (AIdx >= FCount) then
    Exit(nil);

  Result := TPersistentVector.Create;
  try
    Result.FCount := FCount;
    SetLength(Result.FChunks, Length(FChunks));
    LChunkIndex := AIdx div PVECTOR_CHUNK_SIZE;
    LItemIndex := AIdx mod PVECTOR_CHUNK_SIZE;
    for LI := 0 to High(FChunks) do
    begin
      if LI = LChunkIndex then
        Result.FChunks[LI] := CloneChunk(FChunks[LI])
      else
      begin
        RetainChunk(FChunks[LI]);
        Result.FChunks[LI] := FChunks[LI];
      end;
    end;
    Result.FChunks[LChunkIndex]^.Items[LItemIndex] := AValue;
  except
    Result.Free;
    raise;
  end;
end;

function TPersistentVector.Concat(AOther: TPersistentVector): TPersistentVector;
var
  LI, LTotal, LChunkIndex, LItemIndex: Int32;
  LOtherCount: Int32;
  LSourceChunk: PVectorChunk;
begin
  LOtherCount := 0;
  if AOther <> nil then
    LOtherCount := AOther.FCount;
  if LOtherCount > High(Int32) - FCount then
    raise EArgumentError.Create('TPersistentVector: concatenated size is too large');

  LTotal := FCount + LOtherCount;
  Result := TPersistentVector.Create;
  try
    Result.FCount := LTotal;
    SetLength(Result.FChunks,
      (LTotal + PVECTOR_CHUNK_SIZE - 1) div PVECTOR_CHUNK_SIZE);
    for LI := 0 to LTotal - 1 do
    begin
      LChunkIndex := LI div PVECTOR_CHUNK_SIZE;
      LItemIndex := LI mod PVECTOR_CHUNK_SIZE;
      if LItemIndex = 0 then
        Result.FChunks[LChunkIndex] := NewChunk;

      if LI < FCount then
        LSourceChunk := FChunks[LI div PVECTOR_CHUNK_SIZE]
      else
        LSourceChunk := AOther.FChunks[(LI - FCount) div PVECTOR_CHUNK_SIZE];
      if LI < FCount then
        Result.FChunks[LChunkIndex]^.Items[LItemIndex] :=
          LSourceChunk^.Items[LI mod PVECTOR_CHUNK_SIZE]
      else
        Result.FChunks[LChunkIndex]^.Items[LItemIndex] :=
          LSourceChunk^.Items[(LI - FCount) mod PVECTOR_CHUNK_SIZE];
      Inc(Result.FChunks[LChunkIndex]^.Used);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TPersistentVector.ToArray: specialize TArray<AnsiString>;
var
  LI: Int32;
begin
  Result := nil;
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
    Result[LI] := FChunks[LI div PVECTOR_CHUNK_SIZE]^
      .Items[LI mod PVECTOR_CHUNK_SIZE];
end;

end.
