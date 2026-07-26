program test_json_fuzz;
{**
 * @desc JSON 确定性 fuzz：随机/二进制/半合法输入下不崩溃、不挂起、不泄漏；
 *       in-band HasError 契约（JsonParse 不抛异常）；深度洪水撞 512 上限；
 *       成功解析 → Stringify → reparse 幂等。种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.json,
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
  { JSON 敏感字符加权：括号/引号/转义/分隔 }
  CCharset: string = 'ab01{}[]",:\-.et' + #10 + ' {}[]""';
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
  LI: Integer;
begin
  { 从合法骨架出发按预算堆片段：多数轮次产出可解析文档 }
  Result := '{';
  LI := 1;
  while LI < ALen do
  begin
    if LI > 1 then
      Result := Result + ',';
    case RngRange(6) of
      0:
      begin
        Result := Result + '"k' + Chr(Ord('a') + RngRange(26)) + '":'
          + Chr(Ord('0') + RngRange(10));
        Inc(LI, 6);
      end;
      1:
      begin
        Result := Result + '"s' + Chr(Ord('a') + RngRange(26)) + '":"v\"qA"';
        Inc(LI, 14);
      end;
      2:
      begin
        Result := Result + '"a' + Chr(Ord('a') + RngRange(26)) + '":[1,2,[3]]';
        Inc(LI, 13);
      end;
      3:
      begin
        Result := Result + '"o' + Chr(Ord('a') + RngRange(26)) + '":{"x":true}';
        Inc(LI, 14);
      end;
      4:
      begin
        Result := Result + '"n' + Chr(Ord('a') + RngRange(26)) + '":null';
        Inc(LI, 9);
      end;
      5:
      begin
        Result := Result + '"f' + Chr(Ord('a') + RngRange(26)) + '":-1.5e2';
        Inc(LI, 10);
      end;
    end;
  end;
  Result := Result + '}';
end;

{ FuzzOneInput — in-band 契约：JsonParse 不抛异常；失败时 Error 可查询。
  返回 False 表示契约被破坏。 }
function FuzzOneInput(const AInput: string): Boolean;
var
  LDoc: IJsonDocument;
begin
  Result := True;
  try
    LDoc := JsonParse(AInput);
    if LDoc.HasError then
      LDoc.Error; { 错误对象必须可安全查询 }
  except
    Exit(False);
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

procedure TestSemiValidRoundtrip;
var
  LI, LClean: Integer;
  LDoc, LReparsed: IJsonDocument;
  LInput: string;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LInput := GenerateSemiValid(RngRange(400) + 10);
    LDoc := JsonParse(LInput);
    if not LDoc.HasError then
    begin
      Inc(LClean);
      { 幂等性：成功文档 Stringify 后必须可无错 reparse }
      LReparsed := JsonParse(LDoc.Stringify);
      Check(not LReparsed.HasError, 'stringify output reparses clean');
    end;
  end;
  Check(LClean > 0, 'some semi-valid inputs parse clean');
end;

procedure TestDepthFlood;
var
  LInput: string;
  LDoc: IJsonDocument;
  LI: Integer;
begin
  { 600 层 [ 超过 512 上限：必须 in-band 报错，不崩栈 }
  LInput := '';
  for LI := 1 to 600 do
    LInput := LInput + '[';
  LDoc := JsonParse(LInput);
  Check(LDoc.HasError, '600-deep array flood rejected in-band');

  LInput := '';
  for LI := 1 to 600 do
    LInput := LInput + '{"a":';
  LDoc := JsonParse(LInput);
  Check(LDoc.HasError, '600-deep object flood rejected in-band');
end;

procedure TestRepeatedStructures;
var
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '"';
  Check(FuzzOneInput(LInput), '500 quotes no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '\u';
  Check(FuzzOneInput('"' + LInput + '"'), 'truncated unicode escapes no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '-';
  Check(FuzzOneInput(LInput), '500 minus signs no crash');
end;

procedure TestLargeValidDocument;
var
  LInput: string;
  LDoc: IJsonDocument;
  LI: Integer;
begin
  LInput := '[';
  for LI := 1 to 500 do
  begin
    if LI > 1 then
      LInput := LInput + ',';
    LInput := LInput + '{"id":' + Chr(Ord('0') + LI mod 10) + ',"v":"x"}';
  end;
  LInput := LInput + ']';
  LDoc := JsonParse(LInput);
  Check(not LDoc.HasError, 'large valid document ok');
  CheckEqual(Int64(500), Int64(LDoc.Root.ArrayLen), 'element count');
end;

begin
  T := TTestSuite.Create('nextpas.core.json fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid roundtrip (500)', @TestSemiValidRoundtrip);
  T.Test('depth flood in-band', @TestDepthFlood);
  T.Test('repeated structures', @TestRepeatedStructures);
  T.Test('large valid document (500 elems)', @TestLargeValidDocument);
  if not T.Run then Halt(1);
end.
