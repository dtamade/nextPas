unit nextpas.core.git.native.repository.diff.hunks;

{$I nextpas.core.settings.inc}

{ repository.diff 纯文件 hunk 域: Myers 行 opcodes + 合并 hunk 构建.
  依赖: L0-L1 owner + diff.myers/diff.base + native.diff 类型. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.base;

type
  THunkArray = array of TGitDiffHunk;

procedure BuildLCSOps(const AOld, ANew: TStringArray; out AOpcodes: TStringArray; out AOldTexts: TStringArray; out ANewTexts: TStringArray);
function UnifiedHunksFromOps(const AOpcodes: TStringArray; const AOldTexts, ANewTexts: TStringArray; AContext: Integer): THunkArray;
function BuildPureFileHunks(const AOldLines, ANewLines: TStringArray; AContext: Integer): THunkArray;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.diff.base,
  nextpas.core.diff.myers;

procedure BuildLCSOps(const AOld, ANew: nextpas.core.base.TStringArray; out AOpcodes: nextpas.core.base.TStringArray; out AOldTexts: nextpas.core.base.TStringArray; out ANewTexts: nextpas.core.base.TStringArray);
var
  LEdits: TDiffEditArray;
  LCnt, I: Integer;
begin
  // perf: Myers O(ND) single source via nextpas.core.diff.myers (owner), avoids (N+1)*(M+1) OOM; single allocation for outputs, zero-copy string CoW, amortized via bytes.ops GrowArrayCapacity discipline (no per-entry Length+1 churn)
  // stability: no manual LCS table to free, auto-managed dynamic arrays; inline path delegates to unified Myers core
  LEdits := DiffLines(AOld, ANew);
  LCnt := Length(LEdits);
  SetLength(AOpcodes, LCnt);
  SetLength(AOldTexts, LCnt);
  SetLength(ANewTexts, LCnt);
  for I := 0 to LCnt - 1 do
    case LEdits[I].Action of
      daEqual: begin AOpcodes[I] := ' '; AOldTexts[I] := AOld[LEdits[I].OldIndex]; ANewTexts[I] := ANew[LEdits[I].NewIndex]; end;
      daDelete: begin AOpcodes[I] := '-'; AOldTexts[I] := AOld[LEdits[I].OldIndex]; ANewTexts[I] := ''; end;
      daInsert: begin AOpcodes[I] := '+'; AOldTexts[I] := ''; ANewTexts[I] := ANew[LEdits[I].NewIndex]; end;
    end;
end;

function UnifiedHunksFromOps(const AOpcodes: nextpas.core.base.TStringArray; const AOldTexts, ANewTexts: nextpas.core.base.TStringArray; AContext: Integer): THunkArray;
var
  N,I, OldNo, NewNo, SPos, EPos, HS, HE, OC, NC, K: Integer;
  H: TGitDiffHunk;
  ChangedBlocks: array of record SPos,EPos: Integer; end;
  CB, ResCount, LOldLen, LAddLen: Integer;
begin
  Result:=nil;
  N:=Length(AOpcodes);
  if N=0 then
    Exit;
  SetLength(ChangedBlocks,0);
  I:=0;
  while I<N do
  begin
    if AOpcodes[I]<>' ' then
    begin
      SPos:=I;
      while (I<N) and (AOpcodes[I]<>' ') do
        Inc(I);
      EPos:=I-1;
      CB:=Length(ChangedBlocks);
      SetLength(ChangedBlocks,CB+1);
      ChangedBlocks[CB].SPos:=SPos;
      ChangedBlocks[CB].EPos:=EPos;
    end
    else
      Inc(I);
  end;
  if Length(ChangedBlocks)=0 then
    Exit;
  // perf: pre-allocate Result to ChangedBlocks upper bound (single allocation, amortized O(1) append via index)
  ResCount:=0;
  SetLength(Result, Length(ChangedBlocks));
  OldNo:=1;
  NewNo:=1;
  for I:=0 to High(AOpcodes) do
  begin
    if I=0 then
    begin
    end;
  end;
  for CB:=0 to High(ChangedBlocks) do
  begin
    SPos:=ChangedBlocks[CB].SPos - AContext;
    if SPos<0 then
      SPos:=0;
    EPos:=ChangedBlocks[CB].EPos + AContext;
    if EPos>=N then
      EPos:=N-1;
    if (CB>0) and (SPos <= ChangedBlocks[CB-1].EPos + AContext*2 +1) then
    begin
      if SPos <= ChangedBlocks[CB-1].EPos + AContext then
        Continue;
    end;
    HS:=SPos;
    HE:=EPos;
    H.OldStart:=1;
    H.NewStart:=1;
    OC:=0;
    NC:=0;
    OldNo:=1;
    NewNo:=1;
    for K:=0 to HS-1 do
    begin
      if AOpcodes[K]=' ' then
      begin
        Inc(OldNo);
        Inc(NewNo);
      end
      else if AOpcodes[K]='-' then
        Inc(OldNo)
      else
        Inc(NewNo);
    end;
    H.OldStart:=OldNo;
    H.NewStart:=NewNo;
    for K:=HS to HE do
    begin
      if AOpcodes[K]=' ' then
      begin
        Inc(OC);
        Inc(NC);
      end
      else if AOpcodes[K]='-' then
        Inc(OC)
      else
        Inc(NC);
    end;
    H.OldCount:=OC;
    H.NewCount:=NC;
    H.Header:='@@ -'+IntToStr(H.OldStart)+','+IntToStr(H.OldCount)+' +'+IntToStr(H.NewStart)+','+IntToStr(H.NewCount)+' @@';
    // perf: single allocation for hunk lines (HE-HS+1) vs per-line SetLength(Length+1) O(n²) realloc/copy
    SetLength(H.Lines, HE - HS + 1);
    for K:=HS to HE do
    begin
      if AOpcodes[K]=' ' then
        H.Lines[K - HS]:=' '+AOldTexts[K]
      else if AOpcodes[K]='-' then
        H.Lines[K - HS]:='-'+AOldTexts[K]
      else
        H.Lines[K - HS]:='+'+ANewTexts[K];
    end;
    // perf: amortized single pre-allocation to ChangedBlocks upper bound (single SetLength) + index append; no per-hunk Length+1 churn (bytes.ops GrowArrayCapacity discipline)
    Result[ResCount]:=H;
    Inc(ResCount);
  end;
  SetLength(Result, ResCount);
  if Length(Result)>1 then
  begin
    I:=0;
    while I<Length(Result)-1 do
    begin
      if Result[I].NewStart+Result[I].NewCount + AContext >= Result[I+1].NewStart then
      begin
        // perf: single allocation for merged lines (old+add) vs per-line SetLength(Length+1)
        LOldLen:=Length(Result[I].Lines);
        LAddLen:=Length(Result[I+1].Lines);
        SetLength(Result[I].Lines, LOldLen + LAddLen);
        for K:=0 to LAddLen-1 do
          Result[I].Lines[LOldLen + K]:=Result[I+1].Lines[K];
        Result[I].OldCount:=Result[I].OldCount+Result[I+1].OldCount;
        Result[I].NewCount:=Result[I].NewCount+Result[I+1].NewCount;
        Result[I].Header:='@@ -'+IntToStr(Result[I].OldStart)+','+IntToStr(Result[I].OldCount)+' +'+IntToStr(Result[I].NewStart)+','+IntToStr(Result[I].NewCount)+' @@';
        for K:=I+1 to High(Result)-1 do
          Result[K]:=Result[K+1];
        SetLength(Result,Length(Result)-1);
      end
      else
        Inc(I);
    end;
  end;
end;

function BuildPureFileHunks(const AOldLines, ANewLines: nextpas.core.base.TStringArray; AContext: Integer): THunkArray;
var
  Opcs: nextpas.core.base.TStringArray;
  OT, NT: nextpas.core.base.TStringArray;
begin
  Result:=nil;
  if (AOldLines=nil) and (ANewLines=nil) then
    Exit(nil);
  if (AOldLines=nil) then
  begin
    if (ANewLines=nil) or (Length(ANewLines)=0) then
      Exit(nil);
  end;
  BuildLCSOps(AOldLines,ANewLines,Opcs,OT,NT);
  Result:=UnifiedHunksFromOps(Opcs,OT,NT,AContext);
end;

end.
