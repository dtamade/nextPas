program test_yaml_fuzz;
{**
 * @desc YAML 确定性 fuzz：随机/二进制/半合法输入下不崩溃、不挂起、不泄漏；
 *       in-band HasError 契约；flow 深度洪水撞 256 上限；锚点/别名碎片
 *       （未定义别名、自引用）不崩溃。种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.yaml,
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
  { YAML 敏感字符加权：缩进/冒号/横线/锚点/别名/flow/块标量 }
  CCharset: string = 'ab01:- &*[]{}#|>"' + #10 + '  :-';
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
  Result := '';
  LI := 0;
  while LI < ALen do
  begin
    case RngRange(9) of
      0: { 顶层键值 }
      begin
        Result := Result + 'k' + Chr(Ord('a') + RngRange(26)) + ': v'
          + Chr(Ord('0') + RngRange(10)) + #10;
        Inc(LI, 8);
      end;
      1: { 列表项 }
      begin
        Result := Result + '- item' + Chr(Ord('a') + RngRange(26)) + #10;
        Inc(LI, 8);
      end;
      2: { 嵌套映射 }
      begin
        Result := Result + 'm' + Chr(Ord('a') + RngRange(26)) + ':' + #10
          + '  x: 1' + #10;
        Inc(LI, 11);
      end;
      3: { flow 序列 }
      begin
        Result := Result + 'f' + Chr(Ord('a') + RngRange(26)) + ': [1, 2, 3]' + #10;
        Inc(LI, 13);
      end;
      4: { flow 映射 }
      begin
        Result := Result + 'g' + Chr(Ord('a') + RngRange(26)) + ': {x: 1}' + #10;
        Inc(LI, 11);
      end;
      5: { 锚点+别名对 }
      begin
        Result := Result + 'a' + Chr(Ord('a') + RngRange(26)) + ': &anc val' + #10
          + 'b' + Chr(Ord('a') + RngRange(26)) + ': *anc' + #10;
        Inc(LI, 20);
      end;
      6: { 注释 }
      begin
        Result := Result + '# comment' + #10;
        Inc(LI, 10);
      end;
      7: { 引号标量（含转义） }
      begin
        Result := Result + 'q' + Chr(Ord('a') + RngRange(26)) + ': "s\"t"' + #10;
        Inc(LI, 11);
      end;
      8: { 未定义别名（错误路径） }
      begin
        Result := Result + 'u' + Chr(Ord('a') + RngRange(26)) + ': *nowhere' + #10;
        Inc(LI, 12);
      end;
    end;
  end;
end;

{ FuzzOneInput — in-band 契约：YamlParse 不抛异常；失败时 Error 可查询。 }
function FuzzOneInput(const AInput: string): Boolean;
var
  LDoc: IYamlDocument;
begin
  Result := True;
  try
    LDoc := YamlParse(AInput);
    if LDoc.HasError then
      LDoc.Error;
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

procedure TestSemiValidNoCrash;
var
  LI, LClean: Integer;
  LDoc: IYamlDocument;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LDoc := YamlParse(GenerateSemiValid(RngRange(500) + 10));
    if not LDoc.HasError then
      Inc(LClean);
  end;
  Check(LClean > 0, 'some semi-valid inputs parse clean');
  Check(True, '500 semi-valid inputs no crash');
end;

procedure TestFlowDepthFlood;
var
  LInput: string;
  LDoc: IYamlDocument;
  LI: Integer;
begin
  { 300 层 flow 嵌套超过 256 上限：必须 in-band 报错，不崩栈 }
  LInput := 'k: ';
  for LI := 1 to 300 do
    LInput := LInput + '[';
  LDoc := YamlParse(LInput);
  Check(LDoc.HasError, '300-deep flow flood rejected in-band');

  LInput := 'k: ';
  for LI := 1 to 300 do
    LInput := LInput + '{a: ';
  LDoc := YamlParse(LInput);
  Check(LDoc.HasError, '300-deep flow map flood rejected in-band');
end;

procedure TestAliasFragments;
var
  LInput: string;
  LI: Integer;
begin
  { 锚点/别名边界碎片：自引用、重复锚点、别名洪水 }
  Check(FuzzOneInput('a: &x *x' + #10), 'self-referential anchor no crash');

  LInput := '';
  for LI := 1 to 200 do
    LInput := LInput + 'k' + Chr(Ord('a') + (LI mod 26)) + ': &a v' + #10;
  Check(FuzzOneInput(LInput), '200 duplicate anchors no crash');

  LInput := 'base: &b [1, 2]' + #10;
  for LI := 1 to 200 do
    LInput := LInput + 'r' + Chr(Ord('a') + (LI mod 26))
      + Chr(Ord('0') + (LI mod 10)) + ': *b' + #10;
  Check(FuzzOneInput(LInput), '200 alias fan-out no crash');
end;

procedure TestRepeatedStructures;
var
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '- ';
  Check(FuzzOneInput(LInput), '500 dash prefixes no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + ': ';
  Check(FuzzOneInput(LInput), '500 colons no crash');

  LInput := '';
  for LI := 1 to 200 do
    LInput := LInput + '  ';
  Check(FuzzOneInput(LInput + 'k: v'), 'deep indent ladder no crash');
end;

procedure TestLargeValidDocument;
var
  LInput: string;
  LDoc: IYamlDocument;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + 'key_' + Chr(Ord('a') + (LI mod 26))
      + Chr(Ord('a') + (LI div 26) mod 26) + Chr(Ord('0') + LI mod 10)
      + ': value' + Chr(Ord('0') + LI mod 10) + #10;
  LDoc := YamlParse(LInput);
  Check(not LDoc.HasError, 'large valid document ok');
end;

begin
  T := TTestSuite.Create('nextpas.core.yaml fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid no crash (500)', @TestSemiValidNoCrash);
  T.Test('flow depth flood in-band', @TestFlowDepthFlood);
  T.Test('alias fragments', @TestAliasFragments);
  T.Test('repeated structures', @TestRepeatedStructures);
  T.Test('large valid document (500 keys)', @TestLargeValidDocument);
  if not T.Run then Halt(1);
end.
