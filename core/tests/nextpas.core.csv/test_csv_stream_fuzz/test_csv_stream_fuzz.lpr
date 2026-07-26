program test_csv_stream_fuzz;
{**
 * @desc CSV 流式面差分 fuzz：同一输入下 chunked IReader（1/3/7 字节强制
 *       多次 refill）与整串解析必须产出完全一致的行/字段/错误状态。
 *       流式 refill 是独立代码路径且豁免 bulk cap（Wave S 未覆盖）；
 *       引号/CRLF 跨 chunk 边界是经典撕裂点。种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.csv,
  nextpas.core.test;

type
  { 每次 Read 至多吐 FChunk 字节 — 强制多次 refill }
  TChunkedReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPos: SizeUInt;
    FChunk: SizeUInt;
  public
    constructor Create(const AData: TBytes; AChunk: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TChunkedReader.Create(const AData: TBytes; AChunk: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
  if AChunk = 0 then
    FChunk := 1
  else
    FChunk := AChunk;
end;

function TChunkedReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail, LTake: SizeUInt;
begin
  if FPos >= SizeUInt(Length(FData)) then
    Exit(0);
  LAvail := SizeUInt(Length(FData)) - FPos;
  LTake := ACount;
  if LTake > FChunk then
    LTake := FChunk;
  if LTake > LAvail then
    LTake := LAvail;
  if LTake = 0 then
    Exit(0);
  Move(FData[FPos], ABuf, LTake);
  Inc(FPos, LTake);
  Result := LTake;
end;

function BytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

type
  TCsvRun = record
    Rows: TStringMatrix;
    HasErr: Boolean;
    ErrMsg: string;
    Failed: Boolean; { 契约违规：异常外泄或挂起 }
  end;

var
  T: TTestSuite;
  GSeed: UInt32 = 12345;

function Rng: UInt32;
begin
  { xorshift32 — 与家族 fuzz 套件同款确定性序列 }
  GSeed := GSeed xor (GSeed shl 13);
  GSeed := GSeed xor (GSeed shr 17);
  GSeed := GSeed xor (GSeed shl 5);
  Result := GSeed;
end;

function RngRange(AMax: UInt32): UInt32;
begin
  Result := Rng mod AMax;
end;

function RngChar: AnsiChar;
const
  CCharset: string = 'abc123",;#' + #9 + #10 + #13 + ' "",';
begin
  Result := CCharset[RngRange(Length(CCharset)) + 1];
end;

function GenerateRandom(const ALen: Integer): string;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 1 to ALen do
    Result[LI] := RngChar;
end;

function GenerateSemiValid(const ALen: Integer): string;
var
  LI, LField: Integer;
begin
  Result := '';
  LI := 0;
  while LI < ALen do
  begin
    case RngRange(5) of
      0: { 统一 2 列：TCsvReader 默认执行字段数一致性校验 }
      begin
        for LField := 0 to 1 do
        begin
          if LField > 0 then
            Result := Result + ',';
          Result := Result + 'f' + Chr(Ord('a') + RngRange(26));
        end;
        Result := Result + #10;
        Inc(LI, 12);
      end;
      1:
      begin
        Result := Result + '"a,b",' + Chr(Ord('0') + RngRange(10)) + #10;
        Inc(LI, 9);
      end;
      2:
      begin
        Result := Result + '"say ""hi""",x' + #10;
        Inc(LI, 15);
      end;
      3: { CRLF 行 — #13#10 跨 chunk 撕裂点 }
      begin
        Result := Result + 'p,q' + #13#10;
        Inc(LI, 5);
      end;
      4: { 引号内换行 }
      begin
        Result := Result + '"multi' + #10 + 'line",z' + #10;
        Inc(LI, 14);
      end;
    end;
  end;
end;

function CollectCsv(var AReader: TCsvReader): TCsvRun;
var
  LFields: TStringArray;
  LRow: TStringArray;
  LCount, LI: Integer;
begin
  Result.Rows := nil;
  Result.HasErr := False;
  Result.ErrMsg := '';
  Result.Failed := False;
  LCount := 0;
  try
    while AReader.ReadRow(LFields) do
    begin
      Inc(LCount);
      if LCount > 100000 then
      begin
        Result.Failed := True;
        Exit;
      end;
      { 深拷贝：ReadRow 可能复用底层存储，动态数组无 COW }
      SetLength(LRow, Length(LFields));
      for LI := 0 to High(LFields) do
        LRow[LI] := LFields[LI];
      SetLength(Result.Rows, LCount);
      Result.Rows[LCount - 1] := LRow;
      LRow := nil;
    end;
    Result.HasErr := AReader.HasError;
    if Result.HasErr then
      Result.ErrMsg := AReader.GetError;
  except
    Result.Failed := True;
  end;
end;

function RunWhole(const AInput: string): TCsvRun;
var
  LReader: TCsvReader;
begin
  LReader := TCsvReader.Create(AInput);
  Result := CollectCsv(LReader);
end;

function RunChunked(const AInput: string; AChunk: SizeUInt): TCsvRun;
var
  LReader: TCsvReader;
  LSource: IReader;
begin
  LSource := TChunkedReader.Create(BytesFromString(AInput), AChunk);
  LReader := TCsvReader.Create(LSource);
  Result := CollectCsv(LReader);
end;

function SameRun(const A, B: TCsvRun): Boolean;
var
  LR, LC: Integer;
begin
  if A.Failed or B.Failed then
    Exit(False);
  if (A.HasErr <> B.HasErr) or (A.ErrMsg <> B.ErrMsg) then
    Exit(False);
  if Length(A.Rows) <> Length(B.Rows) then
    Exit(False);
  for LR := 0 to High(A.Rows) do
  begin
    if Length(A.Rows[LR]) <> Length(B.Rows[LR]) then
      Exit(False);
    for LC := 0 to High(A.Rows[LR]) do
      if A.Rows[LR][LC] <> B.Rows[LR][LC] then
        Exit(False);
  end;
  Result := True;
end;

function DifferentialOk(const AInput: string; AChunk: SizeUInt): Boolean;
begin
  Result := SameRun(RunWhole(AInput), RunChunked(AInput, AChunk));
end;

const
  CChunks: array[0..2] of SizeUInt = (1, 3, 7);

procedure TestDifferentialRandom;
var
  LI: Integer;
begin
  for LI := 1 to 500 do
    Check(DifferentialOk(GenerateRandom(RngRange(200) + 1), CChunks[LI mod 3]),
      'random input: chunked == whole-string');
end;

procedure TestDifferentialBinary;
var
  LInput: string;
  LI, LJ: Integer;
begin
  for LI := 1 to 200 do
  begin
    SetLength(LInput, RngRange(100) + 1);
    for LJ := 1 to Length(LInput) do
      LInput[LJ] := AnsiChar(Rng and $FF);
    Check(DifferentialOk(LInput, CChunks[LI mod 3]),
      'binary garbage: chunked == whole-string');
  end;
end;

procedure TestDifferentialSemiValid;
var
  LI, LClean: Integer;
  LInput: string;
  LRun: TCsvRun;
begin
  LClean := 0;
  for LI := 1 to 300 do
  begin
    LInput := GenerateSemiValid(RngRange(400) + 10);
    Check(DifferentialOk(LInput, CChunks[LI mod 3]),
      'semi-valid: chunked == whole-string');
    LRun := RunChunked(LInput, 1);
    if (not LRun.Failed) and (not LRun.HasErr) then
      Inc(LClean);
  end;
  Check(LClean > 200, 'most semi-valid rounds parse clean');
end;

procedure TestQuoteAcrossChunkTorture;
var
  LInput: string;
  LI: Integer;
  LRun: TCsvRun;
begin
  { chunk=1 强制引号转义对/闭合引号逐字节跨 refill 边界 }
  LInput := '';
  for LI := 1 to 50 do
    LInput := LInput + '"a,b","say ""hi""",x' + #10;
  Check(DifferentialOk(LInput, 1), 'quoted fields chunk=1 == whole');
  LRun := RunChunked(LInput, 1);
  Check((not LRun.Failed) and (not LRun.HasErr), 'quoted torture parses clean');
  CheckEqual(Int64(50), Int64(Length(LRun.Rows)), 'quoted torture row count');

  { CRLF 撕裂：#13 落 chunk 尾、#10 落下一 chunk 头 }
  LInput := 'a,b' + #13#10 + 'c,d' + #13#10;
  Check(DifferentialOk(LInput, 1), 'CRLF split across chunks == whole');
  LRun := RunChunked(LInput, 1);
  CheckEqual(Int64(2), Int64(Length(LRun.Rows)), 'CRLF torture row count');

  { 未闭合引号 EOF：两侧错误状态必须一致 }
  Check(DifferentialOk('"never closed', 1), 'unclosed quote chunk=1 == whole');
  { 引号后紧邻 EOF 于 chunk 边界 }
  Check(DifferentialOk('a,"x"', 1), 'quote-then-EOF chunk=1 == whole');
end;

procedure TestLargeDocumentChunked;
var
  LWriter: TCsvWriter;
  LI: Integer;
  LText: string;
  LRun: TCsvRun;
begin
  { writer 产出含逗号/引号/换行字段的 500 行文档，chunk=7 流式差分 }
  LWriter := TCsvWriter.Create;
  for LI := 1 to 500 do
    LWriter.WriteRow(['id' + Chr(Ord('0') + LI mod 10), 'val,ue', '"q"',
      'multi' + #10 + 'line']);
  LText := LWriter.ToString;
  Check(DifferentialOk(LText, 7), 'large doc chunk=7 == whole');
  LRun := RunChunked(LText, 7);
  Check((not LRun.Failed) and (not LRun.HasErr), 'large doc parses clean');
  CheckEqual(Int64(500), Int64(Length(LRun.Rows)), 'large doc row count');
end;

begin
  T := TTestSuite.Create('nextpas.core.csv stream fuzz');
  T.Test('differential random (500)', @TestDifferentialRandom);
  T.Test('differential binary garbage (200)', @TestDifferentialBinary);
  T.Test('differential semi-valid (300)', @TestDifferentialSemiValid);
  T.Test('quote/CRLF across-chunk torture', @TestQuoteAcrossChunkTorture);
  T.Test('large document chunked (500 rows)', @TestLargeDocumentChunked);
  if not T.Run then Halt(1);
end.
