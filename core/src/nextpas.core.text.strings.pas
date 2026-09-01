unit nextpas.core.text.strings;

{$I nextpas.core.settings.inc}
{$modeswitch typehelpers}

interface

uses
  nextpas.core.text.base;

type
  TStringArray = nextpas.core.text.base.TStringArray;
  TStringPredicate = function(const S: string): Boolean;
  TStringMapper = function(const S: string): string;

  TStringPair = record
    Key: string;
    Value: string;
  end;
  TStringPairArray = array of TStringPair;
  TStringChunks = array of TStringArray;

  TStringArrayHelper = type helper for TStringArray
    procedure Add(const AValue: string);
    procedure Insert(AIndex: SizeUInt; const AValue: string);
    procedure Delete(AIndex: SizeUInt);
    procedure Clear;
    procedure Sort;
    procedure Reverse;
    function Contains(const AValue: string): Boolean;
    function IndexOf(const AValue: string): SizeInt;
    function Count: SizeInt; inline;
    function IsEmpty: Boolean; inline;
    function Join(const ASep: string): string;
    function Slice(AStart, AEnd: SizeUInt): TStringArray;
    function Filter(APredicate: TStringPredicate): TStringArray;
    function Map(AMapper: TStringMapper): TStringArray;
    function Unique: TStringArray;
    function TrimAll: TStringArray;
    function ToUpper: TStringArray;
    function ToLower: TStringArray;
    function RemoveEmpty: TStringArray;
  end;

function StringsContains(const AArr: TStringArray; const AValue: string): Boolean;
function StringsIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
function StringsLastIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
procedure StringsSort(var AArr: TStringArray);
procedure StringsReverse(var AArr: TStringArray);
function StringsSplit(const AValue, ADelimiter: string): TStringArray;
function StringsJoin(const AArr: TStringArray; const ASep: string): string;
function StringsFilter(const AArr: TStringArray; APredicate: TStringPredicate): TStringArray;
function StringsMap(const AArr: TStringArray; AMapper: TStringMapper): TStringArray;
function StringsUnique(const AArr: TStringArray): TStringArray;
function StringsCount(const AArr: TStringArray; const AValue: string): SizeUInt;
procedure StringsAppend(var AArr: TStringArray; const AValue: string);
procedure StringsInsert(var AArr: TStringArray; AIndex: SizeUInt; const AValue: string);
procedure StringsDelete(var AArr: TStringArray; AIndex: SizeUInt);
function StringsSlice(const AArr: TStringArray; AStart, AEnd: SizeUInt): TStringArray;

{ Key-Value parsing utilities }
function StringsParseLines(const AText: string): TStringArray;
function StringsParseKeyValues(const AText: string; ASeparator: Char = '='): TStringPairArray;
function StringPairsGet(const APairs: TStringPairArray; const AKey: string; const ADefault: string = ''): string;
function StringPairsContains(const APairs: TStringPairArray; const AKey: string): Boolean;
function StringPairsKeys(const APairs: TStringPairArray): TStringArray;

{ Batch transform utilities }
function StringsTrimAll(const AArr: TStringArray): TStringArray;
function StringsToUpper(const AArr: TStringArray): TStringArray;
function StringsToLower(const AArr: TStringArray): TStringArray;
function StringsRemoveEmpty(const AArr: TStringArray): TStringArray;

{ Pattern matching }
function GlobMatch(const APattern, AStr: string): Boolean;
function StringsGlob(const AArr: TStringArray; const APattern: string): TStringArray;

{ Additional utilities }
function StringsRepeat(const AValue: string; ACount: SizeUInt): TStringArray;
function StringsChunk(const AArr: TStringArray; ASize: SizeUInt): TStringChunks;

{ Split utilities }
function StringsSplit(const AStr: string; ASep: Char; ARemoveEmpty: Boolean = False): TStringArray;
function StringsSplitEscaped(const AStr: string; ASep: Char): TStringArray;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.text.utils,
  nextpas.core.mem.utils;

function StringsContains(const AArr: TStringArray; const AValue: string): Boolean;
var i: SizeInt;
begin
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Exit(True);
  Result := False;
end;

function StringsIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
var i: SizeInt;
begin
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Exit(i);
  Result := -1;
end;

function StringsLastIndexOf(const AArr: TStringArray; const AValue: string): SizeInt;
var i: SizeInt;
begin
  for i := High(AArr) downto 0 do
    if AArr[i] = AValue then Exit(i);
  Result := -1;
end;

procedure StringsSort(var AArr: TStringArray);

  procedure DoQuickSort(var A: TStringArray; Lo, Hi: SizeInt);
  var i, j: SizeInt; pivot, tmp: string;
  begin
    if Lo >= Hi then Exit;
    i := Lo; j := Hi;
    pivot := A[(Lo + Hi) shr 1];
    while i <= j do
    begin
      while A[i] < pivot do Inc(i);
      while A[j] > pivot do Dec(j);
      if i <= j then
      begin
        tmp := A[i]; A[i] := A[j]; A[j] := tmp;
        Inc(i); Dec(j);
      end;
    end;
    if Lo < j then DoQuickSort(A, Lo, j);
    if i < Hi then DoQuickSort(A, i, Hi);
  end;

begin
  if Length(AArr) > 1 then
    DoQuickSort(AArr, 0, High(AArr));
end;

procedure StringsReverse(var AArr: TStringArray);
var i, j: SizeInt; tmp: string;
begin
  i := 0; j := High(AArr);
  while i < j do
  begin
    tmp := AArr[i]; AArr[i] := AArr[j]; AArr[j] := tmp;
    Inc(i); Dec(j);
  end;
end;

function StringsSplit(const AValue, ADelimiter: string): TStringArray;
var
  LPos: SizeInt;
  LStart: SizeInt;
  LDelimLen: SizeInt;
  LCount: SizeInt;
  LCap: SizeUInt;
  LSegLen: SizeInt;
begin
  Result := nil;
  LDelimLen := Length(ADelimiter);
  if LDelimLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := AValue;
    Exit;
  end;

  LCount := 0;
  LStart := 1;
  repeat
    LPos := Pos(ADelimiter, AValue, LStart);
    if LPos = 0 then
      LPos := Length(AValue) + 1;
    // perf: exponential via bytes.ops.BytesGrowCapacity single source amortized O(1), zero-copy via DynArray poke
    // not inline per red-line 2: BytesGrowCapacity while loop I-Cache bloat; single capacity math + poke avoids O(n) refcount Move jitter on extreme delimiters
    LCap := nextpas.core.bytes.ops.BytesGrowCapacity(SizeUInt(LCount), SizeUInt(LCount + 1));
    if (nextpas.core.mem.dynarray.DynArrayCapacityStr(Result) < LCap) or (nextpas.core.mem.dynarray.DynArrayRefCountStr(Result) <> 1) then
    begin
      if LCap <> SizeUInt(Length(Result)) then
        SetLength(Result, LCap);
    end;
    if SizeUInt(Length(Result)) <> SizeUInt(LCount + 1) then
      nextpas.core.mem.dynarray.DynArraySetLengthStr(Result, SizeUInt(LCount + 1));
    LSegLen := LPos - LStart;
    if LSegLen > 0 then
      SetString(Result[LCount], PChar(@AValue[LStart]), LSegLen)
    else
      Result[LCount] := '';
    Inc(LCount);
    LStart := LPos + LDelimLen;
  until LPos > Length(AValue);
  // Length already poked to LCount; capacity remains geometric slack, no extra SetLength shrink/Move
end;

function StringsJoin(const AArr: TStringArray; const ASep: string): string;
var
  i: SizeInt;
  LTotal, LSepLen, LPos: SizeInt;
begin
  if Length(AArr) = 0 then Exit('');
  if Length(AArr) = 1 then Exit(AArr[0]);
  LSepLen := Length(ASep);
  LTotal := 0;
  for i := 0 to High(AArr) do
    Inc(LTotal, Length(AArr[i]));
  Inc(LTotal, LSepLen * (Length(AArr) - 1));
  SetLength(Result, LTotal);
  LPos := 1;
  if Length(AArr[0]) > 0 then
  begin
    CopyNonOverlap(@AArr[0][1], @Result[LPos], Length(AArr[0]));
    Inc(LPos, Length(AArr[0]));
  end;
  for i := 1 to High(AArr) do
  begin
    if LSepLen > 0 then
    begin
      CopyNonOverlap(@ASep[1], @Result[LPos], LSepLen);
      Inc(LPos, LSepLen);
    end;
    if Length(AArr[i]) > 0 then
    begin
      CopyNonOverlap(@AArr[i][1], @Result[LPos], Length(AArr[i]));
      Inc(LPos, Length(AArr[i]));
    end;
  end;
end;

function StringsFilter(const AArr: TStringArray; APredicate: TStringPredicate): TStringArray;
var i, LCount: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if APredicate(AArr[i]) then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function StringsMap(const AArr: TStringArray; AMapper: TStringMapper): TStringArray;
var i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := AMapper(AArr[i]);
end;

function StringsUnique(const AArr: TStringArray): TStringArray;
var i, LCount: SizeInt; LSorted: TStringArray;
begin
  if Length(AArr) = 0 then Exit(nil);
  LSorted := System.Copy(AArr);
  StringsSort(LSorted);
  SetLength(Result, Length(LSorted));
  Result[0] := LSorted[0];
  LCount := 1;
  for i := 1 to High(LSorted) do
    if LSorted[i] <> LSorted[i - 1] then
    begin
      Result[LCount] := LSorted[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function StringsCount(const AArr: TStringArray; const AValue: string): SizeUInt;
var i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(AArr) do
    if AArr[i] = AValue then Inc(Result);
end;

{ 单源指数增长: via bytes.ops.BytesGrowCapacity (INV-5) amortized O(1), 零拷贝 poke }
procedure EnsureStringsCapacity(var AArr: TStringArray; const AOldLen, AReqLen: SizeUInt);
var
  LCap: SizeUInt;
begin
  // not inline per red-line 2: BytesGrowCapacity while loop I-Cache bloat; pure capacity math single source
  LCap := nextpas.core.bytes.ops.BytesGrowCapacity(AOldLen, AReqLen);
  if (nextpas.core.mem.dynarray.DynArrayCapacityStr(AArr) < LCap) or (nextpas.core.mem.dynarray.DynArrayRefCountStr(AArr) <> 1) then
  begin
    if LCap <> SizeUInt(Length(AArr)) then
      SetLength(AArr, LCap);
  end;
  if SizeUInt(Length(AArr)) <> AReqLen then
    nextpas.core.mem.dynarray.DynArraySetLengthStr(AArr, AReqLen);
end;

procedure StringsAppend(var AArr: TStringArray; const AValue: string);
var
  LOld, LReq: SizeUInt;
begin
  LOld := SizeUInt(Length(AArr));
  if LOld = High(SizeUInt) then
    raise EOutOfMemory.Create('StringsAppend: size overflow');
  LReq := LOld + 1;
  // perf: exponential via bytes.ops.BytesGrowCapacity single source amortized O(1), zero-copy via DynArray poke
  // not inline per red-line 1/2: SetLength+Move would bloat I-Cache; stability: exception-safe, CoW-aware via RefCnt
  EnsureStringsCapacity(AArr, LOld, LReq);
  AArr[LOld] := AValue;
end;

procedure StringsDelete(var AArr: TStringArray; AIndex: SizeUInt); inline;
var
  L: SizeInt;
  LMoveCount: SizeUInt;
begin
  L := Length(AArr);
  if (L = 0) or (AIndex >= SizeUInt(L)) then Exit;
  { 零拷贝: 先释放被删元素, 单次 System.Move 搬移指针块, 尾槽 Pointer:=nil 避免重复 Finalize }
  AArr[AIndex] := '';
  if AIndex < SizeUInt(L) - 1 then
  begin
    LMoveCount := SizeUInt(L) - AIndex - 1;
    System.Move(AArr[AIndex + 1], AArr[AIndex], LMoveCount * SizeOf(string));
    Pointer(AArr[L - 1]) := nil;
  end;
  SetLength(AArr, L - 1);
end;

procedure StringsInsert(var AArr: TStringArray; AIndex: SizeUInt; const AValue: string);
var
  L, LReq: SizeUInt;
  LMoveCount: SizeUInt;
begin
  L := SizeUInt(Length(AArr));
  if AIndex > L then AIndex := L;
  if L = High(SizeUInt) then
    raise EOutOfMemory.Create('StringsInsert: size overflow');
  LReq := L + 1;
  // perf: exponential via bytes.ops.BytesGrowCapacity single source amortized O(1), zero-copy via DynArray poke
  // not inline per red-line 1/2: SetLength+Move I-Cache bloat; stability: exception-safe, CoW-aware
  EnsureStringsCapacity(AArr, L, LReq);
  if AIndex < L then
  begin
    { 零拷贝: 单次 System.Move 右移指针块(handling overlap), 原槽 Pointer:=nil 转移所有权, 避免 O(n) 引用计数 }
    LMoveCount := L - AIndex;
    System.Move(AArr[AIndex], AArr[AIndex + 1], LMoveCount * SizeOf(string));
    Pointer(AArr[AIndex]) := nil;
  end;
  AArr[AIndex] := AValue;
end;

function StringsSlice(const AArr: TStringArray; AStart, AEnd: SizeUInt): TStringArray;
var i, LLen: SizeUInt;
begin
  if AEnd > SizeUInt(Length(AArr)) then AEnd := Length(AArr);
  if AStart >= AEnd then Exit(nil);
  LLen := AEnd - AStart;
  SetLength(Result, LLen);
  for i := 0 to LLen - 1 do
    Result[i] := AArr[AStart + i];
end;

{ Key-Value parsing }

function StringsParseLines(const AText: string): TStringArray;
var
  i, LStart, LCount, LLen: SizeInt;
begin
  LLen := Length(AText);
  if LLen = 0 then Exit(nil);

  LCount := 0;
  for i := 1 to LLen do
    if AText[i] = #10 then Inc(LCount);
  Inc(LCount);

  SetLength(Result, LCount);
  LCount := 0;
  LStart := 1;
  for i := 1 to LLen do
  begin
    if AText[i] = #10 then
    begin
      if (i > LStart) and (AText[i - 1] = #13) then
        Result[LCount] := System.Copy(AText, LStart, i - LStart - 1)
      else
        Result[LCount] := System.Copy(AText, LStart, i - LStart);
      Inc(LCount);
      LStart := i + 1;
    end;
  end;
  if LStart <= LLen then
  begin
    Result[LCount] := System.Copy(AText, LStart, LLen - LStart + 1);
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function StringsParseKeyValues(const AText: string; ASeparator: Char): TStringPairArray;
var
  LLines: TStringArray;
  i, LSepPos: SizeInt;
  LCount: SizeInt;
  LLine: string;
begin
  LLines := StringsParseLines(AText);
  Result := nil;
  SetLength(Result, Length(LLines));
  LCount := 0;
  for i := 0 to High(LLines) do
  begin
    LLine := LLines[i];
    LSepPos := Pos(ASeparator, LLine);
    if LSepPos > 0 then
    begin
      Result[LCount].Key := nextpas.core.text.utils.Trim(
        System.Copy(LLine, 1, LSepPos - 1));
      Result[LCount].Value := nextpas.core.text.utils.Trim(
        System.Copy(LLine, LSepPos + 1, Length(LLine) - LSepPos));
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function StringPairsGet(const APairs: TStringPairArray; const AKey: string; const ADefault: string): string;
var i: SizeInt;
begin
  for i := 0 to High(APairs) do
    if APairs[i].Key = AKey then Exit(APairs[i].Value);
  Result := ADefault;
end;

function StringPairsContains(const APairs: TStringPairArray; const AKey: string): Boolean;
var i: SizeInt;
begin
  for i := 0 to High(APairs) do
    if APairs[i].Key = AKey then Exit(True);
  Result := False;
end;

function StringPairsKeys(const APairs: TStringPairArray): TStringArray;
var i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(APairs));
  for i := 0 to High(APairs) do
    Result[i] := APairs[i].Key;
end;

{ Batch transforms }

function StringsTrimAll(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := nextpas.core.text.utils.Trim(AArr[i]);
end;

function StringsToUpper(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := nextpas.core.text.utils.UpperCase(AArr[i]);
end;

function StringsToLower(const AArr: TStringArray): TStringArray;
var i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for i := 0 to High(AArr) do
    Result[i] := nextpas.core.text.utils.LowerCase(AArr[i]);
end;

function StringsRemoveEmpty(const AArr: TStringArray): TStringArray;
var i, LCount: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if AArr[i] <> '' then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

{ Pattern matching — glob style: * matches any non-sep, ? single non-sep, ** cross-sep, [class] 。
  单源实现：fs.glob 薄转发至此（L1 single source），respack.embed 亦经此（L1），零拷贝 PChar 视图 + O(pat×name) 双追踪器（无指数回溯）；
  热路径 inline 仅限 IsPathSep/MatchOne 叶判定，GlobMatchInternal 按红线2禁 inline 防 I-Cache 复制膨胀。 }
function IsPathSep(C: AnsiChar): Boolean; inline;
begin
  Result := (C = '/') or (C = '\');
end;

function MatchOne(var AP: PChar; AN: PChar): Boolean; inline;
var
  LNegate, LMatched: Boolean;
  P: PChar;
begin
  case AP^ of
    '?':
    begin
      if (AN^ = #0) or IsPathSep(AnsiChar(AN^)) then Exit(False);
      Inc(AP);
      Exit(True);
    end;
    '[':
    begin
      if AN^ = #0 then Exit(False);
      P := AP + 1;
      LNegate := False;
      if (P^ = '^') or (P^ = '!') then begin LNegate := True; Inc(P); end;
      if P^ = ']' then
      begin
        Inc(P);
        while (P^ <> #0) and (P^ <> ']') do Inc(P);
        if P^ = ']' then Inc(P);
        AP := P;
        Exit(LNegate);
      end;
      LMatched := False;
      while (P^ <> #0) and (P^ <> ']') do
      begin
        if ((P+1)^ = '-') and ((P+2)^ <> ']') and ((P+2)^ <> #0) then
        begin
          if (AnsiChar(AN^) >= AnsiChar(P^)) and (AnsiChar(AN^) <= AnsiChar((P+2)^)) then LMatched := True;
          Inc(P,3);
        end else
        begin
          if AN^ = P^ then LMatched := True;
          Inc(P);
        end;
      end;
      if P^ = ']' then Inc(P);
      AP := P;
      if LNegate then Exit(not LMatched) else Exit(LMatched);
    end;
  else
    Result := (AP^ <> #0) and (AN^ = AP^);
    if Result then Inc(AP);
  end;
end;

// not inline per red-line 2: while 双追踪器循环 + 分支会致 I-Cache 复制膨胀；零拷贝 PChar + O(pat×name) 确界
function GlobMatchInternal(AP, AN: PChar): Boolean;
var
  LSStarP, LSStarN, LDStarP, LDStarN: PChar;
  LIsDouble: Boolean;
begin
  if AP^ = #0 then Exit(AN^ = #0);
  LSStarP := nil; LSStarN := nil; LDStarP := nil; LDStarN := nil;
  while AN^ <> #0 do
  begin
    if AP^ = '*' then
    begin
      LIsDouble := False;
      while AP^ = '*' do begin if (AP+1)^ = '*' then LIsDouble := True; Inc(AP); end;
      if LIsDouble then
      begin
        if (AP^ = '/') or (AP^ = '\') then Inc(AP);
        LDStarP := AP; LDStarN := AN; LSStarP := nil; LSStarN := nil;
      end else begin LSStarP := AP; LSStarN := AN; end;
      Continue;
    end;
    if MatchOne(AP, AN) then begin Inc(AN); Continue; end;
    if (LSStarP <> nil) and (not IsPathSep(AnsiChar(LSStarN^))) then
    begin Inc(LSStarN); AN := LSStarN; AP := LSStarP; Continue; end;
    if LDStarP <> nil then
    begin Inc(LDStarN); AN := LDStarN; AP := LDStarP; LSStarP:=nil; LSStarN:=nil; Continue; end;
    Exit(False);
  end;
  while AP^ = '*' do
  begin while AP^ = '*' do Inc(AP); if (AP^ = '/') or (AP^ = '\') then Inc(AP); end;
  Result := AP^ = #0;
end;

// not inline per red-line 2: 委托 GlobMatchInternal 双追踪器循环，禁 inline 避免 I-Cache 膨胀透传；PChar 零拷贝视图无堆分配
function GlobMatch(const APattern, AStr: string): Boolean;
var
  LP, LN: PChar;
  LBuf: AnsiChar;
begin
  if Length(APattern)=0 then Exit(AStr='');
  LP := @APattern[1];
  if Length(AStr)>0 then LN := @AStr[1] else begin LBuf:=#0; LN:=@LBuf; end;
  Result := GlobMatchInternal(LP, LN);
end;

function StringsGlob(const AArr: TStringArray; const APattern: string): TStringArray;
var i, LCount: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  LCount := 0;
  for i := 0 to High(AArr) do
    if GlobMatch(APattern, AArr[i]) then
    begin
      Result[LCount] := AArr[i];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

{ TStringArrayHelper }

procedure TStringArrayHelper.Add(const AValue: string);
begin
  StringsAppend(Self, AValue);
end;

procedure TStringArrayHelper.Insert(AIndex: SizeUInt; const AValue: string);
begin
  StringsInsert(Self, AIndex, AValue);
end;

procedure TStringArrayHelper.Delete(AIndex: SizeUInt);
begin
  StringsDelete(Self, AIndex);
end;

procedure TStringArrayHelper.Clear;
begin
  Self := nil;
end;

procedure TStringArrayHelper.Sort;
begin
  StringsSort(Self);
end;

procedure TStringArrayHelper.Reverse;
begin
  StringsReverse(Self);
end;

function TStringArrayHelper.Contains(const AValue: string): Boolean;
begin
  Result := StringsContains(Self, AValue);
end;

function TStringArrayHelper.IndexOf(const AValue: string): SizeInt;
begin
  Result := StringsIndexOf(Self, AValue);
end;

function TStringArrayHelper.Count: SizeInt;
begin
  Result := Length(Self);
end;

function TStringArrayHelper.IsEmpty: Boolean;
begin
  Result := Length(Self) = 0;
end;

function TStringArrayHelper.Join(const ASep: string): string;
begin
  Result := StringsJoin(Self, ASep);
end;

function TStringArrayHelper.Slice(AStart, AEnd: SizeUInt): TStringArray;
begin
  Result := StringsSlice(Self, AStart, AEnd);
end;

function TStringArrayHelper.Filter(APredicate: TStringPredicate): TStringArray;
begin
  Result := StringsFilter(Self, APredicate);
end;

function TStringArrayHelper.Map(AMapper: TStringMapper): TStringArray;
begin
  Result := StringsMap(Self, AMapper);
end;

function TStringArrayHelper.Unique: TStringArray;
begin
  Result := StringsUnique(Self);
end;

function TStringArrayHelper.TrimAll: TStringArray;
begin
  Result := StringsTrimAll(Self);
end;

function TStringArrayHelper.ToUpper: TStringArray;
begin
  Result := StringsToUpper(Self);
end;

function TStringArrayHelper.ToLower: TStringArray;
begin
  Result := StringsToLower(Self);
end;

function TStringArrayHelper.RemoveEmpty: TStringArray;
begin
  Result := StringsRemoveEmpty(Self);
end;

function StringsRepeat(const AValue: string; ACount: SizeUInt): TStringArray;
var I: SizeUInt;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := AValue;
end;

function StringsChunk(const AArr: TStringArray; ASize: SizeUInt): TStringChunks;
var
  I, LChunkCount, LRemain: SizeUInt;
  J, LStart: SizeUInt;
begin
  if (Length(AArr) = 0) or (ASize = 0) then
  begin
    Result := nil;
    Exit;
  end;
  LChunkCount := (SizeUInt(Length(AArr)) + ASize - 1) div ASize;
  SetLength(Result, LChunkCount);
  LStart := 0;
  for I := 0 to LChunkCount - 1 do
  begin
    LRemain := SizeUInt(Length(AArr)) - LStart;
    if LRemain > ASize then LRemain := ASize;
    SetLength(Result[I], LRemain);
    for J := 0 to LRemain - 1 do
      Result[I][J] := AArr[LStart + J];
    Inc(LStart, LRemain);
  end;
end;

{== Split ==}

function StringsSplit(const AStr: string; ASep: Char; ARemoveEmpty: Boolean): TStringArray;
var
  I, LSegStart, LSegCount, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AStr);
  if LLen = 0 then
  begin
    if not ARemoveEmpty then
    begin
      SetLength(Result, 1);
      Result[0] := '';
    end;
    Exit;
  end;
  // First pass: count segments
  LSegCount := 1;
  for I := 1 to LLen do
    if AStr[I] = ASep then
      Inc(LSegCount);
  // Second pass: fill
  SetLength(Result, LSegCount);
  LSegStart := 1;
  LSegCount := 0;
  for I := 1 to LLen do
    if AStr[I] = ASep then
    begin
      if (I > LSegStart) or not ARemoveEmpty then
      begin
        SetString(Result[LSegCount], PChar(@AStr[LSegStart]), I - LSegStart);
        Inc(LSegCount);
      end;
      LSegStart := I + 1;
    end;
  // Last segment
  if (LLen >= LSegStart) or not ARemoveEmpty then
  begin
    SetString(Result[LSegCount], PChar(@AStr[LSegStart]), LLen - LSegStart + 1);
    Inc(LSegCount);
  end;
  // Trim if remove-empty shrank the array
  if LSegCount < Length(Result) then
    SetLength(Result, LSegCount);
end;

function StringsSplitEscaped(const AStr: string; ASep: Char): TStringArray;
var
  LBuf: string;
  LBufLen, LUsed, LCap, LI: Integer;
begin
  Result := nil;
  if AStr = '' then Exit;
  { 单分配缓冲 O(n)：避免 LItem := LItem + C 的 O(n²) 重分配；LBuf 预分配 Length(AStr) }
  SetLength(LBuf, Length(AStr));
  LBufLen := 0;
  LUsed := 0;
  LCap := 8;
  SetLength(Result, LCap);
  LI := 1;
  while LI <= Length(AStr) do
  begin
    if AStr[LI] = '\' then
    begin
      if LI < Length(AStr) then
      begin
        Inc(LI);
        Inc(LBufLen); LBuf[LBufLen] := AStr[LI];
      end else
      begin
        { 尾部 одино 反斜杠保留为字面量，与测试期望 'a\'→'a\' 一致 }
        Inc(LBufLen); LBuf[LBufLen] := '\';
      end;
    end
    else if AStr[LI] = ASep then
    begin
      if LUsed >= LCap then begin LCap := LCap * 2; SetLength(Result, LCap); end;
      SetString(Result[LUsed], PChar(@LBuf[1]), LBufLen);
      Inc(LUsed);
      LBufLen := 0;
    end
    else
    begin
      Inc(LBufLen); LBuf[LBufLen] := AStr[LI];
    end;
    Inc(LI);
  end;
  if LUsed >= LCap then begin LCap := LCap * 2; SetLength(Result, LCap); end;
  SetString(Result[LUsed], PChar(@LBuf[1]), LBufLen);
  Inc(LUsed);
  SetLength(Result, LUsed);
end;


end.
