unit nextpas.core.xml.base;
{**
 * @desc XML 基础类型定义：token、名称、属性、命名空间、实体编解码。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

type
  TXmlTokenKind = (
    xtkNone,
    xtkStartElement,
    xtkEndElement,
    xtkEmptyElement,
    xtkText,
    xtkCData,
    xtkComment,
    xtkProcessingInstr,
    xtkXmlDecl,
    xtkDoctype
  );

  TXmlName = record
    Prefix: string;
    Local: string;
    function Full: string;
  end;

  TXmlAttribute = record
    Name: TXmlName;
    Value: string;
  end;
  TXmlAttributeArray = array of TXmlAttribute;

  TXmlToken = record
    Kind: TXmlTokenKind;
    Name: TXmlName;
    Attributes: TXmlAttributeArray;
    Value: string;
    IsSelfClosing: Boolean;
  end;
  TXmlTokenArray = array of TXmlToken;

  TXmlPosition = record
    ByteOffset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;

  TXmlNamespace = record
    Prefix: string;
    URI: string;
  end;
  TXmlNamespaceArray = array of TXmlNamespace;

  EXmlError = class(EParseError)
  public
    Pos: TXmlPosition;
    constructor Create(const AMsg: string; const APos: TXmlPosition); overload;
  end;

function XmlDecodeEntities(const AStr: string): string;
function XmlEncodeText(const AStr: string): string;
function XmlEncodeAttr(const AStr: string): string;

implementation

{ TXmlName }

function TXmlName.Full: string;
begin
  if Prefix = '' then
    Result := Local
  else
    Result := Prefix + ':' + Local;
end;

{ EXmlError }

constructor EXmlError.Create(const AMsg: string; const APos: TXmlPosition);
begin
  inherited Create(AMsg);
  Pos := APos;
end;

{ XmlDecodeEntities }

function XmlDecodeEntities(const AStr: string): string;
var
  LLen, LI, LSemiPos, LCodeLen: Integer;
  LCh: Char;
  LCode: Int64;
  LValCode: Integer;
  LEntity: string;
  LBuf: string;
  LBufPos: Integer;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  { Fast path: no ampersand }
  LI := 1;
  while (LI <= LLen) and (AStr[LI] <> '&') do Inc(LI);
  if LI > LLen then Exit(AStr);

  SetLength(LBuf, LLen * 2);
  LBufPos := 0;
  { Copy prefix before first & }
  if LI > 1 then
  begin
    Move(AStr[1], LBuf[1], (LI - 1));
    LBufPos := LI - 1;
  end;

  while LI <= LLen do
  begin
    if AStr[LI] = '&' then
    begin
      { Find semicolon }
      LSemiPos := LI + 1;
      while (LSemiPos <= LLen) and (AStr[LSemiPos] <> ';') and (LSemiPos - LI < 12) do
        Inc(LSemiPos);
      if (LSemiPos > LLen) or (AStr[LSemiPos] <> ';') then
      begin
        { Not a valid entity, copy literal & }
        Inc(LBufPos);
        if LBufPos > Length(LBuf) then SetLength(LBuf, Length(LBuf) * 2);
        LBuf[LBufPos] := '&';
        Inc(LI);
        Continue;
      end;
      LEntity := Copy(AStr, LI + 1, LSemiPos - LI - 1);
      LCh := #0;
      if LEntity = 'amp' then LCh := '&'
      else if LEntity = 'lt' then LCh := '<'
      else if LEntity = 'gt' then LCh := '>'
      else if LEntity = 'quot' then LCh := '"'
      else if LEntity = 'apos' then LCh := ''''
      else if (Length(LEntity) >= 2) and (LEntity[1] = '#') then
      begin
        if (Length(LEntity) >= 3) and ((LEntity[2] = 'x') or (LEntity[2] = 'X')) then
        begin
          Val('$' + Copy(LEntity, 3, Length(LEntity) - 2), LCode, LValCode);
          if LValCode = 0 then LCh := Char(LCode);
        end
        else
        begin
          Val(Copy(LEntity, 2, Length(LEntity) - 1), LCode, LValCode);
          if LValCode = 0 then LCh := Char(LCode);
        end;
      end;
      if LCh <> #0 then
      begin
        Inc(LBufPos);
        if LBufPos > Length(LBuf) then SetLength(LBuf, Length(LBuf) * 2);
        LBuf[LBufPos] := LCh;
      end
      else
      begin
        { Unknown entity, copy verbatim }
        LCodeLen := LSemiPos - LI + 1;
        while LBufPos + LCodeLen > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move(AStr[LI], LBuf[LBufPos + 1], LCodeLen);
        Inc(LBufPos, LCodeLen);
      end;
      LI := LSemiPos + 1;
    end
    else
    begin
      Inc(LBufPos);
      if LBufPos > Length(LBuf) then SetLength(LBuf, Length(LBuf) * 2);
      LBuf[LBufPos] := AStr[LI];
      Inc(LI);
    end;
  end;
  SetLength(LBuf, LBufPos);
  Result := LBuf;
end;

{ XmlEncodeText }

function XmlEncodeText(const AStr: string): string;
var
  LLen, LI, LBufPos: Integer;
  LBuf: string;
  LCh: Char;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  SetLength(LBuf, LLen * 4);
  LBufPos := 0;
  for LI := 1 to LLen do
  begin
    LCh := AStr[LI];
    case LCh of
      '<': begin
        while LBufPos + 4 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&lt;', LBuf[LBufPos + 1], 4);
        Inc(LBufPos, 4);
      end;
      '>': begin
        while LBufPos + 4 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&gt;', LBuf[LBufPos + 1], 4);
        Inc(LBufPos, 4);
      end;
      '&': begin
        while LBufPos + 5 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&amp;', LBuf[LBufPos + 1], 5);
        Inc(LBufPos, 5);
      end;
    else
      Inc(LBufPos);
      if LBufPos > Length(LBuf) then SetLength(LBuf, Length(LBuf) * 2);
      LBuf[LBufPos] := LCh;
    end;
  end;
  SetLength(LBuf, LBufPos);
  Result := LBuf;
end;

{ XmlEncodeAttr }

function XmlEncodeAttr(const AStr: string): string;
var
  LLen, LI, LBufPos: Integer;
  LBuf: string;
  LCh: Char;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  SetLength(LBuf, LLen * 6);
  LBufPos := 0;
  for LI := 1 to LLen do
  begin
    LCh := AStr[LI];
    case LCh of
      '<': begin
        while LBufPos + 4 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&lt;', LBuf[LBufPos + 1], 4);
        Inc(LBufPos, 4);
      end;
      '>': begin
        while LBufPos + 4 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&gt;', LBuf[LBufPos + 1], 4);
        Inc(LBufPos, 4);
      end;
      '&': begin
        while LBufPos + 5 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&amp;', LBuf[LBufPos + 1], 5);
        Inc(LBufPos, 5);
      end;
      '"': begin
        while LBufPos + 6 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&quot;', LBuf[LBufPos + 1], 6);
        Inc(LBufPos, 6);
      end;
      '''': begin
        while LBufPos + 6 > Length(LBuf) do SetLength(LBuf, Length(LBuf) * 2);
        Move('&apos;', LBuf[LBufPos + 1], 6);
        Inc(LBufPos, 6);
      end;
    else
      Inc(LBufPos);
      if LBufPos > Length(LBuf) then SetLength(LBuf, Length(LBuf) * 2);
      LBuf[LBufPos] := LCh;
    end;
  end;
  SetLength(LBuf, LBufPos);
  Result := LBuf;
end;

end.
