unit nextpas.core.git.native.status.match;

{$I nextpas.core.settings.inc}

{ status 配对域: 结果行追加 + 路径序输出.
  依赖: base (status.*) + L0-L1 owner. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.status.base;

procedure AppendStatusFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const APath: string; AHeadCode, AWorkCode: TGitStatusCode); inline;
procedure AppendRenamedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
procedure AppendCopiedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
function CompareStatusByPath(const A, B: TGitNativeStatusEntry; AData: Pointer): SizeInt; inline;
procedure SortStatusByPath(var AList: TGitNativeStatusArray); inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.arr.sort;

procedure AppendStatusFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const APath: string; AHeadCode, AWorkCode: TGitStatusCode); inline;
begin
  if (AHeadCode = gscUnmodified) and (AWorkCode = gscUnmodified) then Exit;
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := APath;
  AOut[ACount].OldPath := '';
  AOut[ACount].Similarity := 0;
  AOut[ACount].HeadCode := AHeadCode;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

procedure AppendRenamedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
begin
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := ANewPath;
  AOut[ACount].OldPath := AOldPath;
  AOut[ACount].Similarity := ASimilarity;
  AOut[ACount].HeadCode := gscRenamed;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

procedure AppendCopiedFast(var AOut: TGitNativeStatusArray; var ACount, ACap: SizeInt;
  const AOldPath, ANewPath: string; ASimilarity: Byte; AWorkCode: TGitStatusCode); inline;
begin
  if ACount = ACap then
  begin
    ACap := SizeInt(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
    SetLength(AOut, ACap);
  end;
  AOut[ACount].Path := ANewPath;
  AOut[ACount].OldPath := AOldPath;
  AOut[ACount].Similarity := ASimilarity;
  AOut[ACount].HeadCode := gscCopied;
  AOut[ACount].WorkCode := AWorkCode;
  Inc(ACount);
end;

function CompareStatusByPath(const A, B: TGitNativeStatusEntry; AData: Pointer): SizeInt; inline;
var
  LA, LB: TByteSpan;
begin
  if A.Path = B.Path then Exit(0);
  if A.Path = '' then LA := TByteSpan.Empty else LA := TByteSpan.Create(PByte(@A.Path[1]), SizeUInt(Length(A.Path)));
  if B.Path = '' then LB := TByteSpan.Empty else LB := TByteSpan.Create(PByte(@B.Path[1]), SizeUInt(Length(B.Path)));
  Result := SpanCompare(LA, LB);
end;

procedure SortStatusByPath(var AList: TGitNativeStatusArray); inline;
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<TGitNativeStatusEntry>(AList, @CompareStatusByPath, nil);
end;

end.
