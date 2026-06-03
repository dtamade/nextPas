unit nextpas.core.yaml.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.yaml.types,
  nextpas.core.yaml.parser;

function YamlStringify(var ADoc: TYamlDocument; ANodeIdx: UInt32): string;
function YamlStringifyPretty(var ADoc: TYamlDocument; ANodeIdx: UInt32;
  const AIndent: Int32 = 2): string;

implementation

uses
  Math, nextpas.core.text.conv;

const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';

type
  TYamlStringBuilder = nextpas.core.text.builder.TStringBuilder;

function NeedsQuoting(const AView: TStringView): Boolean;
var
  LStr: string;
  LCh: Byte;
  LI: SizeUInt;
begin
  if AView.IsEmpty then begin Result := True; Exit; end;
  LStr := AView.ToString;
  if (LStr = 'null') or (LStr = 'Null') or (LStr = 'NULL') or (LStr = '~') or
     (LStr = 'true') or (LStr = 'True') or (LStr = 'TRUE') or
     (LStr = 'false') or (LStr = 'False') or (LStr = 'FALSE') or
     (LStr = '.inf') or (LStr = '.Inf') or (LStr = '.INF') or
     (LStr = '-.inf') or (LStr = '-.Inf') or (LStr = '-.INF') or
     (LStr = '+.inf') or (LStr = '+.Inf') or (LStr = '+.INF') or
     (LStr = '.nan') or (LStr = '.NaN') or (LStr = '.NAN') then
  begin
    Result := True;
    Exit;
  end;
  LCh := Byte(AView.Data[0]);
  if (LCh = Byte('{')) or (LCh = Byte('[')) or
     (LCh = Byte('&')) or (LCh = Byte('*')) or
     (LCh = Byte('#')) or (LCh = Byte('''')) or
     (LCh = Byte('"')) or (LCh = Byte('|')) or
     (LCh = Byte('>')) or (LCh = Byte('%')) or
     (LCh = Byte('@')) or (LCh = Byte('`')) or
     (LCh = Byte('!')) or (LCh = Byte(',')) or
     (LCh = Byte(' ')) or (LCh = Byte(#9)) then
  begin
    Result := True;
    Exit;
  end;
  // Numeric-looking strings need quoting to prevent type coercion
  if ((LCh >= Byte('0')) and (LCh <= Byte('9'))) or
     (LCh = Byte('+')) or (LCh = Byte('-')) or (LCh = Byte('.')) then
  begin
    Result := True;
    Exit;
  end;
  for LI := 0 to AView.Len - 1 do
  begin
    LCh := Byte(AView.Data[LI]);
    if (LCh = Byte(':')) or (LCh = Byte('#')) or (LCh = Byte('"')) or
       (LCh = Byte('\')) or (LCh = Byte(',')) or (LCh = Byte('[')) or
       (LCh = Byte(']')) or (LCh = Byte('{')) or (LCh = Byte('}')) or
       (LCh < 32) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

procedure WriteQuotedStr(var AW: TYamlStringBuilder; const AView: TStringView);
var
  LI: SizeUInt;
  LCh: Byte;
begin
  AW.AppendChar('"');
  if AView.Len > 0 then
    for LI := 0 to AView.Len - 1 do
    begin
      LCh := Byte(AView.Data[LI]);
      case LCh of
        Byte('\'): begin AW.AppendChar('\'); AW.AppendChar('\'); end;
        Byte('"'): begin AW.AppendChar('\'); AW.AppendChar('"'); end;
        10: begin AW.AppendChar('\'); AW.AppendChar('n'); end;
        13: begin AW.AppendChar('\'); AW.AppendChar('r'); end;
        9: begin AW.AppendChar('\'); AW.AppendChar('t'); end;
        0..8, 11, 12, 14..31:
          begin
            AW.AppendChar('\'); AW.AppendChar('x');
            AW.AppendChar(AnsiChar(HEX_CHARS[LCh shr 4]));
            AW.AppendChar(AnsiChar(HEX_CHARS[LCh and $F]));
          end;
      else
        AW.AppendByte(LCh);
      end;
    end;
  AW.AppendChar('"');
end;

procedure WriteScalar(var AW: TYamlStringBuilder; const ANode: PYamlNode);
begin
  case ANode^.Kind of
    ynkNull: AW.AppendStr('null');
    ynkBool:
      if ANode^.BoolVal then AW.AppendStr('true')
      else AW.AppendStr('false');
    ynkInt: AW.AppendInt(ANode^.IntVal);
    ynkFloat:
    begin
      if IsNan(ANode^.RealVal) then
        AW.AppendStr('.nan')
      else if IsInfinite(ANode^.RealVal) then
      begin
        if ANode^.RealVal > 0 then AW.AppendStr('.inf')
        else AW.AppendStr('-.inf');
      end
      else
        AW.AppendFloat(ANode^.RealVal);
    end;
    ynkString:
    begin
      if NeedsQuoting(ANode^.Str) then
        WriteQuotedStr(AW, ANode^.Str)
      else
        AW.AppendView(ANode^.Str);
    end;
  else
    { 兼容降级，非正确序列化：调用方 (StringifyFlow/Block) 保证只把标量
      (null/bool/int/float/string) 送入此处，容器类型 (seq/map/alias)
      不应到达。若内部不变量被破坏则降级为 null，避免崩溃。 }
    AW.AppendStr('null');
  end;
end;

{ Flow-style stringify (compact, single line) }

procedure StringifyFlow(var ADoc: TYamlDocument; AIdx: UInt32; var AW: TYamlStringBuilder); forward;

procedure StringifyFlow(var ADoc: TYamlDocument; AIdx: UInt32; var AW: TYamlStringBuilder);
var
  LNode: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
begin
  if AIdx = YAML_NODE_NONE then begin AW.AppendStr('null'); Exit; end;
  LNode := @ADoc.Nodes[AIdx];
  case LNode^.Kind of
    ynkNull, ynkBool, ynkInt, ynkFloat, ynkString:
      WriteScalar(AW, LNode);
    ynkAlias:
      if LNode^.AliasTarget < ADoc.NodeCount then
        StringifyFlow(ADoc, LNode^.AliasTarget, AW)
      else
        AW.AppendStr('null');
    ynkSequence:
    begin
      AW.AppendChar('[');
      LCur := LNode^.Container.FirstChild;
      for LI := 1 to LNode^.Container.Count do
      begin
        if LI > 1 then AW.AppendStr(', ');
        StringifyFlow(ADoc, LCur, AW);
        LCur := ADoc.Nodes[LCur].Next;
      end;
      AW.AppendChar(']');
    end;
    ynkMapping:
    begin
      AW.AppendChar('{');
      LCur := LNode^.Container.FirstChild;
      for LI := 1 to LNode^.Container.Count do
      begin
        if LI > 1 then AW.AppendStr(', ');
        StringifyFlow(ADoc, LCur, AW);
        AW.AppendStr(': ');
        LCur := ADoc.Nodes[LCur].Next;
        StringifyFlow(ADoc, LCur, AW);
        LCur := ADoc.Nodes[LCur].Next;
      end;
      AW.AppendChar('}');
    end;
  end;
end;

function YamlStringify(var ADoc: TYamlDocument; ANodeIdx: UInt32): string;
var
  LW: TYamlStringBuilder;
begin
  LW.Init(256);
  try
    StringifyFlow(ADoc, ANodeIdx, LW);
    Result := LW.ToString;
  finally
    LW.Done;
  end;
end;

{ Block-style stringify (pretty, indented) }

procedure StringifyBlock(var ADoc: TYamlDocument; AIdx: UInt32;
  var AW: TYamlStringBuilder; ADepth: Int32; AIndent: Int32); forward;

procedure WriteIndent(var AW: TYamlStringBuilder; ADepth, AIndent: Int32);
begin
  AW.AppendChars(' ', ADepth * AIndent);
end;

procedure StringifyBlock(var ADoc: TYamlDocument; AIdx: UInt32;
  var AW: TYamlStringBuilder; ADepth: Int32; AIndent: Int32);
var
  LNode: PYamlNode;
  LCur: UInt32;
  LI: UInt32;
begin
  if AIdx = YAML_NODE_NONE then begin AW.AppendStr('null'); Exit; end;
  LNode := @ADoc.Nodes[AIdx];
  case LNode^.Kind of
    ynkNull, ynkBool, ynkInt, ynkFloat, ynkString:
      WriteScalar(AW, LNode);
    ynkAlias:
      if LNode^.AliasTarget < ADoc.NodeCount then
        StringifyBlock(ADoc, LNode^.AliasTarget, AW, ADepth, AIndent)
      else
        AW.AppendStr('null');
    ynkSequence:
    begin
      if LNode^.Container.Count = 0 then
      begin
        AW.AppendStr('[]');
        Exit;
      end;
      LCur := LNode^.Container.FirstChild;
      for LI := 1 to LNode^.Container.Count do
      begin
        if LI > 1 then
          WriteIndent(AW, ADepth, AIndent);
        AW.AppendStr('- ');
        if (ADoc.Nodes[LCur].Kind = ynkMapping) or
           (ADoc.Nodes[LCur].Kind = ynkSequence) then
        begin
          AW.AppendChar(#10);
          WriteIndent(AW, ADepth + 1, AIndent);
          StringifyBlock(ADoc, LCur, AW, ADepth + 1, AIndent);
        end
        else
          StringifyBlock(ADoc, LCur, AW, ADepth + 1, AIndent);
        if LI < LNode^.Container.Count then
          AW.AppendChar(#10);
        LCur := ADoc.Nodes[LCur].Next;
      end;
    end;
    ynkMapping:
    begin
      if LNode^.Container.Count = 0 then
      begin
        AW.AppendStr('{}');
        Exit;
      end;
      LCur := LNode^.Container.FirstChild;
      for LI := 1 to LNode^.Container.Count do
      begin
        if LI > 1 then
          WriteIndent(AW, ADepth, AIndent);
        // Key
        WriteScalar(AW, @ADoc.Nodes[LCur]);
        AW.AppendStr(': ');
        LCur := ADoc.Nodes[LCur].Next;
        // Value
        if (ADoc.Nodes[LCur].Kind = ynkMapping) or
           (ADoc.Nodes[LCur].Kind = ynkSequence) then
          StringifyFlow(ADoc, LCur, AW)
        else
          StringifyBlock(ADoc, LCur, AW, ADepth + 1, AIndent);
        if LI < LNode^.Container.Count then
          AW.AppendChar(#10);
        LCur := ADoc.Nodes[LCur].Next;
      end;
    end;
  end;
end;

function YamlStringifyPretty(var ADoc: TYamlDocument; ANodeIdx: UInt32;
  const AIndent: Int32): string;
var
  LW: TYamlStringBuilder;
begin
  LW.Init(512);
  try
    StringifyBlock(ADoc, ANodeIdx, LW, 0, AIndent);
    Result := LW.ToString;
  finally
    LW.Done;
  end;
end;

end.
