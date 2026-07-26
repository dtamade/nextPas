program test_xml_pull_fuzz;
{**
 * @desc XML pull 面（TXmlReader）差分 fuzz：DOM 解析成功的文档，pull 必须
 *       同样成功且 start/empty 元素先序序列与 DOM 树先序完全一致；
 *       深度豁免两面验证（600 层 DOM 拒 / pull 通过，5000 层无隐藏递归）；
 *       随机/二进制/碎片输入下 Next 循环不崩溃不挂起。种子固定可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.xml,
  nextpas.core.test;

type
  TPullRun = record
    Ok: Boolean;       { 无异常外泄、无挂起 }
    HasErr: Boolean;
    ErrMsg: string;
    ElemSeq: string;   { start/empty 元素 Full 名先序，'/' 连接 }
    ElemCount: Integer;
    MaxDepth: Integer;
  end;

  TWalkFrame = record
    Node: TXmlNode;
    Next: Integer;
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
  CCharset: string = 'abc<>/&;="''!-[]?' + #9 + #10 + #13 + ' ';
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
  { root 包裹 + 片段堆叠：多数轮次可解析，部分留未闭合错误路径 }
  Result := '<root>';
  LI := 6;
  while LI < ALen do
  begin
    LTag := 'e' + Chr(Ord('a') + RngRange(26));
    case RngRange(8) of
      0:
      begin
        Result := Result + '<' + LTag + '>t</' + LTag + '>';
        Inc(LI, 12);
      end;
      1:
      begin
        Result := Result + '<' + LTag + '/>';
        Inc(LI, 5);
      end;
      2:
      begin
        Result := Result + '<' + LTag + ' a="v"/>';
        Inc(LI, 11);
      end;
      3:
      begin
        Result := Result + '&amp;&lt;&gt;';
        Inc(LI, 13);
      end;
      4:
      begin
        Result := Result + '<![CDATA[<raw>]]>';
        Inc(LI, 17);
      end;
      5:
      begin
        Result := Result + '<!-- c -->';
        Inc(LI, 10);
      end;
      6: { 未闭合标签（错误路径） }
      begin
        Result := Result + '<' + LTag + '>';
        Inc(LI, 4);
      end;
      7:
      begin
        Result := Result + 'text' + Chr(Ord('0') + RngRange(10));
        Inc(LI, 5);
      end;
    end;
  end;
  Result := Result + '</root>';
end;

function RunPull(const AInput: string): TPullRun;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LTokens: Integer;
begin
  Result.Ok := True;
  Result.HasErr := False;
  Result.ErrMsg := '';
  Result.ElemSeq := '';
  Result.ElemCount := 0;
  Result.MaxDepth := 0;
  LTokens := 0;
  LReader := TXmlReader.Create(AInput);
  try
    try
      while LReader.Next(LTok) do
      begin
        Inc(LTokens);
        if LTokens > 200000 then
        begin
          Result.Ok := False;
          Exit;
        end;
        if LTok.Kind in [xtkStartElement, xtkEmptyElement] then
        begin
          Inc(Result.ElemCount);
          Result.ElemSeq := Result.ElemSeq + '/' + LTok.Name.Full;
        end;
        if LReader.Depth > Result.MaxDepth then
          Result.MaxDepth := LReader.Depth;
      end;
      Result.HasErr := LReader.HasError;
      if Result.HasErr then
      begin
        Result.ErrMsg := LReader.GetError;
        if Result.ErrMsg = '' then
          Result.Ok := False; { 报错必须携带非空消息 }
      end;
    except
      Result.Ok := False; { pull 契约：Next 不允许异常外泄 }
    end;
  finally
    LReader.Free;
  end;
end;

procedure DomElemSeq(const ARoot: TXmlNode; out ASeq: string; out ACount: Integer);
var
  LStack: array of TWalkFrame;
  LTop: Integer;
  LChild: TXmlNode;
begin
  { 迭代先序遍历（显式栈）：只收集元素节点，与 pull 的文档序一致 }
  ASeq := '';
  ACount := 0;
  if (not ARoot.IsAssigned) or (ARoot.Kind <> xnkElement) then
    Exit;
  SetLength(LStack, 16);
  LTop := 0;
  LStack[0].Node := ARoot;
  LStack[0].Next := 0;
  Inc(ACount);
  ASeq := ASeq + '/' + ARoot.Name.Full;
  while LTop >= 0 do
  begin
    if LStack[LTop].Next < LStack[LTop].Node.ChildCount then
    begin
      LChild := LStack[LTop].Node.Child(LStack[LTop].Next);
      Inc(LStack[LTop].Next);
      if LChild.Kind = xnkElement then
      begin
        Inc(ACount);
        ASeq := ASeq + '/' + LChild.Name.Full;
        Inc(LTop);
        if LTop >= Length(LStack) then
          SetLength(LStack, Length(LStack) * 2);
        LStack[LTop].Node := LChild;
        LStack[LTop].Next := 0;
      end;
    end
    else
      Dec(LTop);
  end;
end;

procedure TestRandomInputNoCrash;
var
  LI: Integer;
  LRun: TPullRun;
begin
  for LI := 1 to 1000 do
  begin
    LRun := RunPull(GenerateRandom(RngRange(200) + 1));
    Check(LRun.Ok, 'random input: pull contract holds');
  end;
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
    Check(RunPull(LInput).Ok, 'binary garbage: pull contract holds');
  end;
end;

procedure TestSemiValidPullVsDom;
var
  LI, LClean: Integer;
  LInput, LSeq: string;
  LDoc: TXmlDocument;
  LPull: TPullRun;
  LCount: Integer;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LInput := GenerateSemiValid(RngRange(400) + 20);
    if TryXmlParse(LInput, LDoc) then
    begin
      Inc(LClean);
      LPull := RunPull(LInput);
      Check(LPull.Ok and (not LPull.HasErr), 'DOM-clean doc pulls clean');
      DomElemSeq(LDoc.Root, LSeq, LCount);
      CheckEqual(LSeq, LPull.ElemSeq, 'pull preorder == DOM preorder');
      CheckEqual(Int64(LCount), Int64(LPull.ElemCount), 'pull elem count == DOM');
      LDoc.Free;
    end
    else
      Check(RunPull(LInput).Ok, 'DOM-reject doc: pull no crash');
  end;
  Check(LClean > 50, 'enough semi-valid rounds parse clean');
end;

procedure TestDeepNestingStreamExempt;
var
  LInput: string;
  LI: Integer;
  LDoc: TXmlDocument;
  LPull: TPullRun;
begin
  { 两面：600 层 DOM 512 上限拒绝；pull 流式无树、必须完整读完 }
  LInput := '';
  for LI := 1 to 600 do
    LInput := LInput + '<a>';
  for LI := 1 to 600 do
    LInput := LInput + '</a>';
  CheckEqual(False, TryXmlParse(LInput, LDoc), 'DOM rejects 600-deep (512 cap)');
  LPull := RunPull(LInput);
  Check(LPull.Ok and (not LPull.HasErr), 'pull reads 600-deep clean (exempt)');
  CheckEqual(Int64(600), Int64(LPull.ElemCount), 'pull sees all 600 elements');
  Check(LPull.MaxDepth > 512, 'pull depth exceeds DOM cap');

  { 5000 层：确认 pull 无隐藏递归（tag 栈在堆上） }
  LInput := '';
  for LI := 1 to 5000 do
    LInput := LInput + '<b>';
  for LI := 1 to 5000 do
    LInput := LInput + '</b>';
  LPull := RunPull(LInput);
  Check(LPull.Ok and (not LPull.HasErr), 'pull reads 5000-deep clean');
  CheckEqual(Int64(5000), Int64(LPull.ElemCount), 'pull sees all 5000 elements');
end;

procedure TestTagEntityFragments;
var
  LInput: string;
  LI: Integer;
  LRun: TPullRun;
begin
  { 失配闭合：pull 维护 tag 栈，必须 in-band 报错 }
  LRun := RunPull('<a></b>');
  Check(LRun.Ok, 'mismatched close: contract holds');
  Check(LRun.HasErr, 'mismatched close: reports error');

  LRun := RunPull('</orphan>');
  Check(LRun.Ok, 'orphan close: contract holds');
  Check(LRun.HasErr, 'orphan close: reports error');

  { 截断标签 EOF }
  Check(RunPull('<a').Ok, 'truncated tag: no crash');
  Check(RunPull('<a attr="v').Ok, 'truncated attr: no crash');
  Check(RunPull('<').Ok, 'lone <: no crash');

  { 500 个孤立 < 洪水 }
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '<';
  Check(RunPull(LInput).Ok, '500 lone < flood: no crash');

  { 裸 & 洪水与实体碎片 }
  LInput := '<r>';
  for LI := 1 to 500 do
    LInput := LInput + '&';
  Check(RunPull(LInput + '</r>').Ok, '500 bare & flood: no crash');
  Check(RunPull('<r>&unterminated</r>').Ok, 'unterminated entity: no crash');
  Check(RunPull('<r>&#99999999999;</r>').Ok, 'numeric entity overflow: no crash');

  { DOCTYPE / PI / 注释碎片 }
  Check(RunPull('<!DOCTYPE r [<!ELEMENT r ANY>]><r/>').Ok, 'doctype subset: no crash');
  Check(RunPull('<?pi data').Ok, 'truncated PI: no crash');
  Check(RunPull('<!-- never closed').Ok, 'unclosed comment: no crash');
end;

procedure TestLargeFlatDocument;
var
  LInput, LSeq: string;
  LI, LCount: Integer;
  LDoc: TXmlDocument;
  LPull: TPullRun;
begin
  LInput := '<r>';
  for LI := 1 to 500 do
    LInput := LInput + '<e/>';
  LInput := LInput + '</r>';
  LDoc := XmlParse(LInput);
  try
    DomElemSeq(LDoc.Root, LSeq, LCount);
    LPull := RunPull(LInput);
    Check(LPull.Ok and (not LPull.HasErr), 'large flat doc pulls clean');
    CheckEqual(Int64(501), Int64(LPull.ElemCount), 'pull sees root + 500 elements');
    CheckEqual(LSeq, LPull.ElemSeq, 'large flat preorder == DOM');
  finally
    LDoc.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.xml pull fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid pull vs DOM differential (500)', @TestSemiValidPullVsDom);
  T.Test('deep nesting stream exempt (600/5000)', @TestDeepNestingStreamExempt);
  T.Test('tag/entity fragments', @TestTagEntityFragments);
  T.Test('large flat document (500)', @TestLargeFlatDocument);
  if not T.Run then Halt(1);
end.
