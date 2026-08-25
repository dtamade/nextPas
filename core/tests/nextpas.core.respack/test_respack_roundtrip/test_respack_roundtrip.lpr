program test_respack_roundtrip;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.respack,
  nextpas.core.respack.base,
  nextpas.core.stopwatch;

var
  T: TTestSuite;

type
  { 内容生命期锚点：输入条目指向 Store 内的缓冲 }
  THolder = record
    Store: array of TBytes;
    Inputs: TResPackInputArray;
  end;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function PtrToBytes(const AP: PByte; const ALen: SizeUInt): TBytes;
begin
  Result := nil;
  SetLength(Result, ALen);
  if ALen > 0 then
    Move(AP^, Result[0], ALen);
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then Exit;
  if Length(AA) = 0 then Exit(True);
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then Exit;
  Result := True;
end;

procedure HoldAdd(var AH: THolder; const APath: string; const AData: TBytes);
var
  N, M: SizeUInt;
begin
  M := SizeUInt(Length(AH.Store));
  SetLength(AH.Store, M + 1);
  AH.Store[M] := AData;
  N := SizeUInt(Length(AH.Inputs));
  SetLength(AH.Inputs, N + 1);
  AH.Inputs[N] := Default(TResPackInputEntry);
  AH.Inputs[N].Path := APath;
  if Length(AH.Store[M]) > 0 then
    AH.Inputs[N].Data := @AH.Store[M][0]
  else
    AH.Inputs[N].Data := nil;
  AH.Inputs[N].DataSize := SizeUInt(Length(AH.Store[M]));
end;

{ 无 SysUtils 的十进制格式化：固定宽度 3 前导零 }
function Num3(AValue: Integer): string;
var
  D: string;
begin
  D := '';
  repeat
    D := Char(Ord('0') + AValue mod 10) + D;
    AValue := AValue div 10;
  until AValue = 0;
  while Length(D) < 3 do
    D := '0' + D;
  Result := D;
end;

{ 固定宽度 4 前导零（perf smoke 用） }
function Num4(AValue: Integer): string;
begin
  Result := '0' + Num3(AValue);
end;

{ ── 用例 ── }

procedure TestBasicRoundtrip;
var
  H: THolder;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
begin
  HoldAdd(H, 'index.html', BytesOf('<html>hello</html>'));
  HoldAdd(H, 'assets/app.js', BytesOf('alert("hi");'));
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 2, 'basic count');
    Check(RP.Find('index.html', E), 'rt find index.html');
    Check(SameBytes(BytesOf('<html>hello</html>'), PtrToBytes(RP.ContentPtr(E), E.Size)),
      'rt index.html content');
    Check(RP.Find('assets/app.js', E), 'rt find app.js');
    Check(SameBytes(BytesOf('alert("hi");'), PtrToBytes(RP.ContentPtr(E), E.Size)),
      'rt app.js content');
    Check(RP.PathOf(E) = 'assets/app.js', 'rt PathOf');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestUnicodeNames;
var
  H: THolder;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
begin
  HoldAdd(H, '图片/样式.css', BytesOf('body{}'));
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 1, 'unicode count');
    Check(RP.Find('图片/样式.css', E), 'unicode find');
    Check(RP.PathOf(E) = '图片/样式.css', 'unicode PathOf');
    Check(SameBytes(BytesOf('body{}'), PtrToBytes(RP.ContentPtr(E), E.Size)),
      'unicode content');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestDeepNesting;
var
  H: THolder;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
const
  DEEP = 'a/b/c/d/e/f/g.txt';
begin
  HoldAdd(H, DEEP, BytesOf('deep'));
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Find(DEEP, E), 'deep find');
    Check(RP.Stat(DEEP).Size = 4, 'deep stat size');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestManyEntriesSorted;
var
  H: THolder;
  B: TResPackBlob;
  RP: TResPack;
  I: SizeUInt;
  Ordered: Boolean;
begin
  for I := 199 downto 0 do
    HoldAdd(H, 'gen/' + Num3(Integer(I)) + '.dat',
      BytesOf(Num3(Integer(I)) + '-payload'));
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Count = 200, 'many count');
    Ordered := True;
    for I := 1 to RP.Count - 1 do
      if RP.PathOf(RP.EntryAt(I - 1)) >= RP.PathOf(RP.EntryAt(I)) then
        Ordered := False;
    Check(Ordered, 'many strictly ordered');
    Check(RP.PathOf(RP.EntryAt(0)) = 'gen/000.dat', 'many first');
    Check(RP.PathOf(RP.EntryAt(199)) = 'gen/199.dat', 'many last');
    Check(SameBytes(BytesOf('042-payload'),
      PtrToBytes(RP.ContentPtr(RP.Stat('gen/042.dat')), 11)), 'many spot content');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestBinaryPattern;
var
  H: THolder;
  Pat: TBytes;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
  I: Integer;
begin
  SetLength(Pat, 256);
  for I := 0 to 255 do
    Pat[I] := Byte(I);
  HoldAdd(H, 'bin/all256.bin', Pat);
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Find('bin/all256.bin', E), 'binary find');
    Check(E.Size = 256, 'binary size');
    Check(SameBytes(Pat, PtrToBytes(RP.ContentPtr(E), 256)), 'binary bytes');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestDedupeRoundtrip;
var
  H: THolder;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  EA, EB: TResPackEntry;
begin
  HoldAdd(H, 'copy1.txt', BytesOf('identical-data'));
  HoldAdd(H, 'copy2.txt', BytesOf('identical-data'));
  Opts := ResPackDefaultOptions;
  Opts.Deduplicate := True;
  B := ResPackBuild(H.Inputs, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.Find('copy1.txt', EA) and RP.Find('copy2.txt', EB),
      'dedupe both found');
    Check(EA.DataOffset = EB.DataOffset, 'dedupe same slot after reopen');
    Check(SameBytes(BytesOf('identical-data'),
      PtrToBytes(RP.ContentPtr(EA), EA.Size)), 'dedupe content intact');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure DigestFiller(const AData: PByte; const ASize: SizeUInt;
  const ADigestOut: PByte);
var
  H: UInt32;
  I: Integer;
begin
  { 测试注入：fnv32 的 LE 字节铺满 32 字节摘要 }
  H := ResPackFnv1a32(AData, ASize);
  for I := 0 to RESPACK_DIGEST_SIZE - 1 do
    ADigestOut[I] := Byte(H shr (8 * (I mod 4)));
end;

procedure TestDigestRoundtrip;
var
  H: THolder;
  Opts: TResPackBuildOptions;
  B: TResPackBlob;
  RP: TResPack;
  E: TResPackEntry;
  D: PByte;
  Expect: UInt32;
  OK: Boolean;
  I: Integer;
begin
  HoldAdd(H, 'd/file.bin', BytesOf('digest me'));
  Opts := ResPackDefaultOptions;
  Opts.DigestFunc :=
    procedure(const AData: PByte; const ASize: SizeUInt; const ADigestOut: PByte)
    begin
      DigestFiller(AData, ASize, ADigestOut);
    end;
  B := ResPackBuild(H.Inputs, Opts);
  try
    RP := ResPackOpen(B.Data, B.Size);
    Check(RP.HasDigests, 'digest rt has section');
    E := RP.Stat('d/file.bin');
    Expect := ResPackFnv1a32(RP.ContentPtr(E), E.Size);
    D := RP.DigestPtr(0);
    OK := True;
    for I := 0 to RESPACK_DIGEST_SIZE - 1 do
      if D[I] <> Byte(Expect shr (8 * (I mod 4))) then
        OK := False;
    Check(OK, 'digest matches recomputed fnv over stored bytes');
  finally
    ResPackFreeBlob(B);
  end;
end;

procedure TestPerfSmoke10k;
{ Smoke 属性：防回归预算而非精度断言。10k 条目 build + 全量 Find 的总耗时
  必须落在宽松硬上限内；若实现退化为 O(n²)（索引查找、排序、去重）会远超
  该预算。阈值按 heaptrc 开启下的慢路径留足余量，勿收紧当作基准测试。
  实测参考：本机 heaptrc -O2 约 350ms。 }
const
  ENTRY_COUNT = 10000;
  BUDGET_MS = 1000;
var
  H: THolder;
  B: TResPackBlob;
  RP: TResPack;
  SW: TStopwatch;
  C: TBytes;
  E: TResPackEntry;
  I: Integer;
  Ordered, FoundAll: Boolean;
begin
  { 预分配持活数组：避免 HoldAdd 逐条 SetLength 的 O(n²) 搬运污染计时 }
  SetLength(H.Store, ENTRY_COUNT);
  SetLength(H.Inputs, ENTRY_COUNT);
  for I := 0 to ENTRY_COUNT - 1 do
  begin
    C := BytesOf(Num4(I) + '-0123456789abcdef0123456789abcdef' +
      '0123456789abcdef0123456789abcdef');
    H.Store[I] := C;
    H.Inputs[I] := Default(TResPackInputEntry);
    H.Inputs[I].Path := 'gen/pack/' + Num4(I) + '.dat';
    H.Inputs[I].Data := @H.Store[I][0];
    H.Inputs[I].DataSize := SizeUInt(Length(H.Store[I]));
  end;

  FoundAll := True;
  SW := TStopwatch.StartNew;
  B := ResPackBuild(H.Inputs, ResPackDefaultOptions);
  try
    RP := ResPackOpen(B.Data, B.Size);
    for I := 0 to ENTRY_COUNT - 1 do
      if not RP.Find('gen/pack/' + Num4(I) + '.dat', E) then
        FoundAll := False;
    SW.Stop;
    Check(RP.Count = ENTRY_COUNT, 'perf smoke count');
    Check(FoundAll, 'perf smoke all found');

    { 正确性抽查（不计入耗时）：全量严格有序 + 内容锚点 }
    Ordered := True;
    for I := 1 to ENTRY_COUNT - 1 do
      if RP.PathOf(RP.EntryAt(I - 1)) >= RP.PathOf(RP.EntryAt(I)) then
        Ordered := False;
    Check(Ordered, 'perf pack strictly ordered');
    Check(SameBytes(BytesOf('0042-'), PtrToBytes(
      RP.ContentPtr(RP.Stat('gen/pack/0042.dat')), 5)), 'perf spot content');
    Check(SW.ElapsedMs <= BUDGET_MS,
      'perf smoke build+find within budget (smoke)');
  finally
    ResPackFreeBlob(B);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.respack.roundtrip');
  T.Test('basic two files', @TestBasicRoundtrip);
  T.Test('unicode names', @TestUnicodeNames);
  T.Test('deep nesting', @TestDeepNesting);
  T.Test('200 entries sorted', @TestManyEntriesSorted);
  T.Test('binary pattern 256', @TestBinaryPattern);
  T.Test('dedupe roundtrip', @TestDedupeRoundtrip);
  T.Test('digest roundtrip', @TestDigestRoundtrip);
  T.Test('perf smoke 10k', @TestPerfSmoke10k);
  if not T.Run then Halt(1);
end.
