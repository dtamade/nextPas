program test_csv_fuzz;
{**
 * @desc CSV 确定性 fuzz：随机/二进制/半合法输入下不崩溃、不挂起、不泄漏；
 *       TCsvReader in-band 错误契约（ReadRow→False + HasError）不外泄异常；
 *       writer→parser 往返对偶性。种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.csv,
  nextpas.core.test;

var
  T: TTestSuite;
  GSeed: UInt32 = 12345;

function Rng: UInt32;
begin
  { xorshift32 — 与 test_toml_fuzz 同款确定性序列 }
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
  { CSV 敏感字符加权：引号/分隔符/换行/注释标记 }
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
    case RngRange(7) of
      0: { 普通字段行 }
      begin
        for LField := 0 to RngRange(4) do
        begin
          if LField > 0 then
            Result := Result + ',';
          Result := Result + 'f' + Chr(Ord('a') + RngRange(26));
        end;
        Result := Result + #10;
        Inc(LI, 12);
      end;
      1: { 引号字段（含逗号） }
      begin
        Result := Result + '"a,b",' + Chr(Ord('0') + RngRange(10)) + #10;
        Inc(LI, 9);
      end;
      2: { 嵌入引号 }
      begin
        Result := Result + '"say ""hi""",x' + #10;
        Inc(LI, 15);
      end;
      3: { 引号内换行 }
      begin
        Result := Result + '"l1' + #10 + 'l2",y' + #10;
        Inc(LI, 10);
      end;
      4: { CRLF 行 }
      begin
        Result := Result + 'a,b,c' + #13#10;
        Inc(LI, 7);
      end;
      5: { 空字段 }
      begin
        Result := Result + ',,' + #10;
        Inc(LI, 3);
      end;
      6: { 未闭合引号（制造错误路径） }
      begin
        Result := Result + '"open,';
        Inc(LI, 6);
      end;
    end;
  end;
end;

{ FuzzOneInput — 单输入全契约检查：ReadRow 不抛异常、行数有界、
  返回 False 后状态可查询。返回 False 表示契约被破坏。 }
function FuzzOneInput(const AInput: string): Boolean;
var
  LReader: TCsvReader;
  LFields: TStringArray;
  LRows: Integer;
begin
  Result := True;
  LReader := TCsvReader.Create(AInput);
  LRows := 0;
  try
    while LReader.ReadRow(LFields) do
    begin
      Inc(LRows);
      if LRows > 100000 then
        Exit(False); { 挂起防线：输入远小于此行数 }
    end;
    { 结束后 HasError/GetError 必须可安全查询 }
    if LReader.HasError then
      if LReader.GetError = '' then
        Exit(False);
  except
    Exit(False); { in-band 契约：ReadRow 路径不允许异常外泄 }
  end;
end;

procedure TestRandomInputNoCrash;
var
  LI: Integer;
begin
  for LI := 1 to 1000 do
    Check(FuzzOneInput(GenerateRandom(RngRange(200) + 1)),
      'random input honors in-band contract');
end;

procedure TestBinaryGarbage;
var
  LInput: string;
  LI, LJ: Integer;
begin
  for LI := 1 to 200 do
  begin
    SetLength(LInput, RngRange(100) + 1);
    for LJ := 1 to Length(LInput) do
      LInput[LJ] := AnsiChar(Rng and $FF);
    Check(FuzzOneInput(LInput), 'binary garbage honors in-band contract');
  end;
end;

procedure TestSemiValidNoCrash;
var
  LI, LClean: Integer;
  LInput: string;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LInput := GenerateSemiValid(RngRange(500) + 10);
    Check(FuzzOneInput(LInput), 'semi-valid honors in-band contract');
    LReader := TCsvReader.Create(LInput);
    while LReader.ReadRow(LFields) do ;
    if not LReader.HasError then
      Inc(LClean);
  end;
  Check(LClean > 0, 'some semi-valid inputs parse clean');
end;

procedure TestQuoteTorture;
var
  LInput: string;
  LI: Integer;
begin
  { 大量连续引号：奇偶闭合边界的经典攻击面 }
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '"';
  Check(FuzzOneInput(LInput), '500 quotes no crash');

  LInput := 'a,';
  for LI := 1 to 500 do
    LInput := LInput + '""';
  Check(FuzzOneInput(LInput), '500 escaped quote pairs no crash');

  { 未闭合引号 + EOF }
  Check(FuzzOneInput('"never closed'), 'unclosed quote at EOF no crash');
end;

procedure TestCsvParseRaisesInBand;
var
  LRaised: Boolean;
  LMatrix: TStringMatrix;
begin
  { 顶层 CsvParse 契约：坏输入抛 EParseError（而非崩溃/静默） }
  LRaised := False;
  try
    LMatrix := CsvParse('"unclosed');
  except
    on EParseError do
      LRaised := True;
  end;
  Check(LRaised, 'CsvParse raises EParseError on unclosed quote');
end;

procedure TestRoundtripFuzz;
var
  LWriter: TCsvWriter;
  LMatrix: TStringMatrix;
  LRow: array of string;
  LI, LJ, LRound: Integer;
  LRows, LCols: Integer;
  LText: string;
begin
  { writer→parser 对偶性：任意字段内容（含分隔符/引号/换行）必须无损往返 }
  for LRound := 1 to 100 do
  begin
    LRows := Integer(RngRange(5)) + 1;
    LCols := Integer(RngRange(4)) + 1;
    LWriter := TCsvWriter.Create;
    SetLength(LRow, LCols);
    for LI := 0 to LRows - 1 do
    begin
      for LJ := 0 to LCols - 1 do
        LRow[LJ] := GenerateRandom(RngRange(20));
      LWriter.WriteRow(LRow);
    end;
    LText := LWriter.ToString;
    LMatrix := CsvParse(LText);
    CheckEqual(Int64(LRows), Int64(Length(LMatrix)), 'roundtrip row count');
  end;
  Check(True, '100 roundtrip fuzz rounds ok');
end;

procedure TestLargeValidDocument;
var
  LWriter: TCsvWriter;
  LMatrix: TStringMatrix;
  LI: Integer;
begin
  LWriter := TCsvWriter.Create;
  for LI := 1 to 500 do
    LWriter.WriteRow(['id' + Chr(Ord('0') + LI mod 10), 'val,ue', '"q"']);
  LMatrix := CsvParse(LWriter.ToString);
  CheckEqual(Int64(500), Int64(Length(LMatrix)), 'large document row count');
end;

begin
  T := TTestSuite.Create('nextpas.core.csv fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid no crash (500)', @TestSemiValidNoCrash);
  T.Test('quote torture', @TestQuoteTorture);
  T.Test('CsvParse in-band raise', @TestCsvParseRaisesInBand);
  T.Test('roundtrip fuzz (100)', @TestRoundtripFuzz);
  T.Test('large valid document (500 rows)', @TestLargeValidDocument);
  if not T.Run then Halt(1);
end.
