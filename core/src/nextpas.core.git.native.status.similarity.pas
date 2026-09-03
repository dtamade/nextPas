unit nextpas.core.git.native.status.similarity;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.collections.arr.sort,
  nextpas.core.collections.algorithms;

type
  TPathOid = record
    Path: string;
    Oid: TGitOid;
    Mode: Cardinal;
  end;
  TPathOidArray = array of TPathOid;

  TRenameCandidate = record
    SrcIdx: Integer;
    DstIdx: Integer;
    Score: Integer;
  end;
  TRenameCandidateArray = array of TRenameCandidate;

  TBlobSig = record
    Valid: Boolean;
    Size: Int64;
    Count: Integer;
    Hashes: array[0..126] of UInt32;
  end;
  TBlobSigArray = array of TBlobSig;

const
  CMaxSimilarityBlobBytes = Int64(1024 * 1024);

function IsBlobMode(AMode: Cardinal): Boolean; inline;
function OidHash(const AOid: TGitOid): UInt32; inline;
function CompareCandidateDesc(const A, B: TRenameCandidate; AData: Pointer): SizeInt;
procedure SortCandidatesByScoreDesc(var AList: TRenameCandidateArray);
function HashForLine(const ASpan: TByteSpan): UInt32;
procedure CollectLineHashes(const ASpan: TByteSpan; var AOut: array of UInt32; var ACount: Integer);
procedure SortU32(var AData: array of UInt32; ACount: Integer);
function HashSigScoreForBlobs(const ADataA, ADataB: TBytes): Integer;
procedure FillBlobSig(ARepo: TNativeRepository; const AEntry: TPathOid; out ASig: TBlobSig);
function ScoreFromSigs(const SA, SB: TBlobSig): Integer;
procedure BuildBlobSigCache(ARepo: TNativeRepository; const AList: TPathOidArray; var AOut: TBlobSigArray);
function SimilarityForPair(ARepo: TNativeRepository; const ASource, ATarget: TPathOid): Integer;

implementation

uses
  nextpas.core.exception;

function IsBlobMode(AMode: Cardinal): Boolean; inline;
begin
  Result := (AMode = GIT_MODE_REGULAR) or (AMode = GIT_MODE_EXEC);
end;

function OidHash(const AOid: TGitOid): UInt32; inline;
begin
  Result := SpanHashFNV1a(TByteSpan.Create(PByte(@AOid.Bytes[0]), SizeUInt(GitOidRawLen)));
end;

function CompareCandidateDesc(const A, B: TRenameCandidate; AData: Pointer): SizeInt;
begin
  if A.Score > B.Score then Exit(-1);
  if A.Score < B.Score then Exit(1);
  if A.SrcIdx < B.SrcIdx then Exit(-1);
  if A.SrcIdx > B.SrcIdx then Exit(1);
  Result := 0;
end;

procedure SortCandidatesByScoreDesc(var AList: TRenameCandidateArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TRenameCandidate>(AList, @CompareCandidateDesc, nil);
end;

function HashForLine(const ASpan: TByteSpan): UInt32;
const
  CHashStart: UInt64 = UInt64($012345678ABCDEF0);
var
  S: UInt64;
  I: Integer;
  UpTo: SizeUInt;
begin
  S := CHashStart;
  UpTo := ASpan.Len;
  if UpTo > 80 then UpTo := 80;
  for I := 0 to Integer(UpTo) - 1 do
    S := S * 31 + UInt64((ASpan.Data + I)^);
  Result := UInt32(S and $FFFFFFFF);
end;

procedure CollectLineHashes(const ASpan: TByteSpan; var AOut: array of UInt32; var ACount: Integer);
var
  I, Start, N: Integer;
  LineSpan: TByteSpan;
begin
  ACount := 0;
  if ASpan.Len = 0 then Exit;
  Start := 0;
  for I := 0 to Integer(ASpan.Len) - 1 do
  begin
    if (ASpan.Data + I)^ = 10 then
    begin
      N := I - Start;
      if (N > 0) and ((ASpan.Data + I - 1)^ = 13) then Dec(N);
      if N > 0 then
      begin
        LineSpan := ASpan.Slice(SizeUInt(Start), SizeUInt(N));
        if ACount < Length(AOut) then AOut[ACount] := HashForLine(LineSpan);
        Inc(ACount);
      end;
      Start := I + 1;
    end;
  end;
  if Start < Integer(ASpan.Len) then
  begin
    N := Integer(ASpan.Len) - Start;
    if N > 0 then
    begin
      LineSpan := ASpan.Slice(SizeUInt(Start), SizeUInt(N));
      if ACount < Length(AOut) then AOut[ACount] := HashForLine(LineSpan);
      Inc(ACount);
    end;
  end;
end;

procedure SortU32(var AData: array of UInt32; ACount: Integer);
begin
  if ACount < 2 then Exit;
  if ACount > Length(AData) then ACount := Length(AData);
  if ACount < 2 then Exit;
  nextpas.core.collections.arr.sort.SortU32(PUInt32(@AData[0]), SizeUInt(ACount));
end;

function HashSigScoreForBlobs(const ADataA, ADataB: TBytes): Integer;
var
  HA, HB: array[0..255] of UInt32;
  CA, CB: Integer;
  IA, IB, Matches: Integer;
begin
  Result := 0;
  if (Length(ADataA) = 0) and (Length(ADataB) = 0) then Exit(100);
  if (Length(ADataA) = 0) or (Length(ADataB) = 0) then Exit(0);
  CA := 0;
  CB := 0;
  CollectLineHashes(TByteSpan.FromBytes(ADataA), HA, CA);
  CollectLineHashes(TByteSpan.FromBytes(ADataB), HB, CB);
  if CA > 127 then CA := 127;
  if CB > 127 then CB := 127;
  if (CA = 0) and (CB = 0) then Exit(100);
  if (CA = 0) or (CB = 0) then Exit(0);
  SortU32(HA, CA);
  SortU32(HB, CB);
  IA := 0; IB := 0; Matches := 0;
  while (IA < CA) and (IB < CB) do
  begin
    if HA[IA] < HB[IB] then Inc(IA)
    else if HA[IA] > HB[IB] then Inc(IB)
    else begin Inc(Matches); Inc(IA); Inc(IB); end;
  end;
  Result := (100 * (Matches * 2)) div (CA + CB);
end;

procedure FillBlobSig(ARepo: TNativeRepository; const AEntry: TPathOid; out ASig: TBlobSig);
var
  Kind: TGitObjectKind;
  Size: Int64;
  Data: TBytes;
  Tmp: array[0..255] of UInt32;
  C, I: Integer;
begin
  ASig.Valid := False;
  ASig.Size := 0;
  ASig.Count := 0;
  if not IsBlobMode(AEntry.Mode) then Exit;
  try
    if not ARepo.TryGetObjectSize(AEntry.Oid, Kind, Size) then Exit;
    if Kind <> gokBlob then Exit;
    ASig.Size := Size;
    if Size > CMaxSimilarityBlobBytes then Exit;
    Data := ARepo.ReadObject(AEntry.Oid, Kind);
    if Kind <> gokBlob then Exit;
  except
    on E: EGitError do Exit;
  end;
  C := 0;
  CollectLineHashes(TByteSpan.FromBytes(Data), Tmp, C);
  if C > 127 then C := 127;
  if C > 1 then SortU32(Tmp, C);
  ASig.Count := C;
  for I := 0 to C - 1 do ASig.Hashes[I] := Tmp[I];
  ASig.Valid := True;
end;

function ScoreFromSigs(const SA, SB: TBlobSig): Integer;
var
  IA, IB, Matches: Integer;
begin
  Result := -1;
  if not SA.Valid or not SB.Valid then Exit;
  if (SA.Size > CMaxSimilarityBlobBytes) or (SB.Size > CMaxSimilarityBlobBytes) then Exit(-1);
  if (SA.Size > 127) and (SB.Size > 127) then
    if (SA.Size > SB.Size * 8) or (SB.Size > SA.Size * 8) then Exit(-1);
  if (SA.Count = 0) and (SB.Count = 0) then Exit(100);
  if (SA.Count = 0) or (SB.Count = 0) then Exit(0);
  IA := 0; IB := 0; Matches := 0;
  while (IA < SA.Count) and (IB < SB.Count) do
  begin
    if SA.Hashes[IA] < SB.Hashes[IB] then Inc(IA)
    else if SA.Hashes[IA] > SB.Hashes[IB] then Inc(IB)
    else begin Inc(Matches); Inc(IA); Inc(IB); end;
  end;
  Result := (100 * (Matches * 2)) div (SA.Count + SB.Count);
end;

procedure BuildBlobSigCache(ARepo: TNativeRepository; const AList: TPathOidArray; var AOut: TBlobSigArray);
var
  I, Cap, Mask, Idx: Integer;
  LHash: UInt32;
  LIsBlob: Boolean;
  Found: Boolean;
  Buckets: array of TGitOid;
  Modes: array of Boolean;
  States: array of Byte;
  FirstPos: array of Integer;
begin
  SetLength(AOut, Length(AList));
  if Length(AList) = 0 then Exit;
  Cap := 16;
  while Cap < Length(AList) * 2 do Cap := Cap * 2;
  Mask := Cap - 1;
  SetLength(Buckets, Cap);
  SetLength(Modes, Cap);
  SetLength(States, Cap);
  SetLength(FirstPos, Cap);
  for I := 0 to High(AList) do
  begin
    LIsBlob := IsBlobMode(AList[I].Mode);
    LHash := OidHash(AList[I].Oid);
    if LIsBlob then LHash := LHash xor UInt32($9E3779B9);
    Idx := Integer(LHash and UInt32(Mask));
    Found := False;
    while States[Idx] = 1 do
    begin
      if GitOidSame(Buckets[Idx], AList[I].Oid) and (Modes[Idx] = LIsBlob) then
      begin
        AOut[I] := AOut[FirstPos[Idx]];
        Found := True;
        Break;
      end;
      Idx := (Idx + 1) and Mask;
    end;
    if Found then Continue;
    FillBlobSig(ARepo, AList[I], AOut[I]);
    Buckets[Idx] := AList[I].Oid;
    Modes[Idx] := LIsBlob;
    States[Idx] := 1;
    FirstPos[Idx] := I;
  end;
end;

function SimilarityForPair(ARepo: TNativeRepository; const ASource, ATarget: TPathOid): Integer;
var
  SA, SB: TBlobSig;
begin
  Result := -1;
  if not IsBlobMode(ASource.Mode) then Exit;
  if not IsBlobMode(ATarget.Mode) then Exit;
  if GitOidSame(ASource.Oid, ATarget.Oid) then Exit(100);
  FillBlobSig(ARepo, ASource, SA);
  FillBlobSig(ARepo, ATarget, SB);
  if not SA.Valid or not SB.Valid then Exit(-1);
  Result := ScoreFromSigs(SA, SB);
end;

end.
