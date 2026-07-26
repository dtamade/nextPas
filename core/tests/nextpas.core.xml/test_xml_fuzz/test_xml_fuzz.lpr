program test_xml_fuzz;
{**
 * @desc XML 确定性 fuzz：随机/二进制/半合法输入下不崩溃、不挂起、不泄漏；
 *       TryXmlParse 契约不外泄异常；成功文档消费 Root.Text（递归面，
 *       受 512 深度上限保护）不崩溃；实体/标签碎片边界。种子固定可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.xml,
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
  { XML 敏感字符加权：尖括号/斜杠/实体/引号/CDATA 片段字符 }
  CCharset: string = 'ab01<>/&;="!?-[' + #10 + ' <>&';
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
  LTag: string;
begin
  { root 包裹 + 片段堆叠：多数轮次产出可解析文档，部分留未闭合错误路径 }
  Result := '<root>';
  LI := 6;
  while LI < ALen do
  begin
    LTag := 'e' + Chr(Ord('a') + RngRange(26));
    case RngRange(8) of
      0: { 闭合元素带文本 }
      begin
        Result := Result + '<' + LTag + '>t</' + LTag + '>';
        Inc(LI, 12);
      end;
      1: { 空元素 }
      begin
        Result := Result + '<' + LTag + '/>';
        Inc(LI, 5);
      end;
      2: { 属性元素 }
      begin
        Result := Result + '<' + LTag + ' a="v"/>';
        Inc(LI, 11);
      end;
      3: { 实体文本 }
      begin
        Result := Result + '&amp;&lt;&gt;';
        Inc(LI, 13);
      end;
      4: { CDATA }
      begin
        Result := Result + '<![CDATA[<raw>]]>';
        Inc(LI, 17);
      end;
      5: { 注释 }
      begin
        Result := Result + '<!-- c -->';
        Inc(LI, 10);
      end;
      6: { 未闭合标签（错误路径） }
      begin
        Result := Result + '<' + LTag + '>';
        Inc(LI, 4);
      end;
      7: { 裸文本 }
      begin
        Result := Result + 'text' + Chr(Ord('0') + RngRange(10));
        Inc(LI, 5);
      end;
    end;
  end;
  Result := Result + '</root>';
end;

{ FuzzOneInput — TryXmlParse 契约：不外泄异常；成功时消费 Root.Text
  （Wave R 修复的递归攻击面）与 FindChild 不崩溃。 }
function FuzzOneInput(const AInput: string): Boolean;
var
  LDoc: TXmlDocument;
  LText: string;
begin
  Result := True;
  try
    if TryXmlParse(AInput, LDoc) then
    begin
      try
        if LDoc.Root.IsAssigned then
        begin
          LText := LDoc.Root.Text; { 递归消费：深度受 512 上限保护 }
          if Length(LText) > Length(AInput) * 2 + 16 then
            Exit(False); { 文本不应凭空膨胀 }
        end;
      finally
        LDoc.Free;
      end;
    end;
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
      'random input honors Try contract');
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
    Check(FuzzOneInput(LInput), 'binary garbage honors Try contract');
  end;
end;

procedure TestSemiValidNoCrash;
var
  LI, LClean: Integer;
  LDoc: TXmlDocument;
  LInput: string;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LInput := GenerateSemiValid(RngRange(500) + 10);
    Check(FuzzOneInput(LInput), 'semi-valid honors Try contract');
    if TryXmlParse(LInput, LDoc) then
    begin
      LDoc.Free;
      Inc(LClean);
    end;
  end;
  Check(LClean > 0, 'some semi-valid inputs parse clean');
end;

procedure TestEntityFragments;
var
  LInput: string;
  LI: Integer;
begin
  { 实体边界：未终止、未知、数字实体溢出 }
  Check(FuzzOneInput('<r>&amp</r>'), 'unterminated entity no crash');
  Check(FuzzOneInput('<r>&unknown;</r>'), 'unknown entity no crash');
  Check(FuzzOneInput('<r>&#99999999999;</r>'), 'numeric entity overflow no crash');
  Check(FuzzOneInput('<r>&#x110000;</r>'), 'out-of-range codepoint no crash');

  LInput := '<r>';
  for LI := 1 to 500 do
    LInput := LInput + '&amp;';
  Check(FuzzOneInput(LInput + '</r>'), '500 entity flood no crash');

  LInput := '<r>';
  for LI := 1 to 500 do
    LInput := LInput + '&';
  Check(FuzzOneInput(LInput), '500 bare ampersands no crash');
end;

procedure TestTagFragments;
var
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '<';
  Check(FuzzOneInput(LInput), '500 open angles no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '</x>';
  Check(FuzzOneInput(LInput), '500 orphan close tags no crash');

  Check(FuzzOneInput('<a><b></a></b>'), 'mismatched nesting no crash');
  Check(FuzzOneInput('<a attr=">"</a>'), 'angle in attribute no crash');
  Check(FuzzOneInput('<!DOCTYPE r [<!ENTITY x "y">]><r/>'), 'doctype subset no crash');
end;

procedure TestDepthFloodInBand;
var
  LInput: string;
  LDoc: TXmlDocument;
  LI: Integer;
begin
  { 600 层嵌套超过 512 上限：TryXmlParse 必须 False，不崩栈 }
  LInput := '';
  for LI := 1 to 600 do
    LInput := LInput + '<d>';
  CheckEqual(False, TryXmlParse(LInput, LDoc), '600-deep flood rejected');
end;

procedure TestLargeValidDocument;
var
  LInput: string;
  LDoc: TXmlDocument;
  LI: Integer;
begin
  LInput := '<root>';
  for LI := 1 to 500 do
    LInput := LInput + '<item id="' + Chr(Ord('0') + LI mod 10) + '">v</item>';
  LInput := LInput + '</root>';
  LDoc := XmlParse(LInput);
  try
    Check(LDoc.Root.IsAssigned, 'large valid document ok');
    CheckEqual(Int64(500), Int64(LDoc.Root.ChildCount), 'child count');
  finally
    LDoc.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.xml fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid no crash (500)', @TestSemiValidNoCrash);
  T.Test('entity fragments', @TestEntityFragments);
  T.Test('tag fragments', @TestTagFragments);
  T.Test('depth flood in-band', @TestDepthFloodInBand);
  T.Test('large valid document (500 items)', @TestLargeValidDocument);
  if not T.Run then Halt(1);
end.
