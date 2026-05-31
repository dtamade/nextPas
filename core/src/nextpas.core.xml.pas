unit nextpas.core.xml;
{**
 * @desc SAX-style event-driven XML parser. Zero SysUtils dependency.
 *       Supports elements, attributes, text, CDATA, comments, PIs, DOCTYPE.
 *       Entity decoding: &amp; &lt; &gt; &quot; &apos; &#NNN; &#xHHH;
 *}

{$I nextpas.core.settings.inc}

interface

type
  TXmlEventKind = (
    xekStartElement,
    xekEndElement,
    xekText,
    xekCData,
    xekComment,
    xekProcessingInstruction,
    xekDoctype
  );

  TXmlAttribute = record
    Name: string;
    Value: string;
  end;
  TXmlAttributeArray = array of TXmlAttribute;

  TXmlEvent = record
    Kind: TXmlEventKind;
    Name: string;
    Value: string;
    Attributes: TXmlAttributeArray;
  end;
  TXmlEventArray = array of TXmlEvent;

  TXmlReader = record
  private
    FData: PAnsiChar;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FHasPending: Boolean;
    FPendingEvent: TXmlEvent;
    function Peek: AnsiChar; inline;
    function PeekAt(AOffset: SizeUInt): AnsiChar; inline;
    function Advance: AnsiChar; inline;
    function AtEnd: Boolean; inline;
    function Match(const AStr: string): Boolean;
    procedure SkipWhitespace; inline;
    function ReadName: string;
    function ReadQuotedValue: string;
    procedure ParseAttributes(out AAttrs: TXmlAttributeArray; out ASelfClose: Boolean);
    function ParseTag(out AEvent: TXmlEvent): Boolean;
    function ParseText(out AEvent: TXmlEvent): Boolean;
  public
    class function Create(const AInput: string): TXmlReader; static;
    function Next(out AEvent: TXmlEvent): Boolean;
    function ReadAll: TXmlEventArray;
  end;

function XmlDecodeEntities(const AStr: string): string;
function XmlEncodeEntities(const AStr: string): string;

implementation

uses
  nextpas.core.text.conv;

{ XmlDecodeEntities }

function XmlDecodeEntities(const AStr: string): string;
var
  LI, LLen, LStart: Integer;
  LEntity: string;
  LCode: Integer;
  LVal: Int64;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  Result := '';
  LI := 1;
  while LI <= LLen do
  begin
    if AStr[LI] = '&' then
    begin
      LStart := LI;
      Inc(LI);
      while (LI <= LLen) and (AStr[LI] <> ';') and (LI - LStart < 12) do
        Inc(LI);
      if (LI <= LLen) and (AStr[LI] = ';') then
      begin
        LEntity := Copy(AStr, LStart + 1, LI - LStart - 1);
        Inc(LI);
        if LEntity = 'amp' then
          Result := Result + '&'
        else if LEntity = 'lt' then
          Result := Result + '<'
        else if LEntity = 'gt' then
          Result := Result + '>'
        else if LEntity = 'quot' then
          Result := Result + '"'
        else if LEntity = 'apos' then
          Result := Result + ''''
        else if (Length(LEntity) >= 2) and (LEntity[1] = '#') then
        begin
          if (Length(LEntity) >= 3) and ((LEntity[2] = 'x') or (LEntity[2] = 'X')) then
          begin
            Val('$' + Copy(LEntity, 3, Length(LEntity) - 2), LVal, LCode);
            if (LCode = 0) and (LVal >= 0) and (LVal <= 127) then
              Result := Result + Chr(LVal)
            else
              Result := Result + '&' + LEntity + ';';
          end
          else
          begin
            Val(Copy(LEntity, 2, Length(LEntity) - 1), LVal, LCode);
            if (LCode = 0) and (LVal >= 0) and (LVal <= 127) then
              Result := Result + Chr(LVal)
            else
              Result := Result + '&' + LEntity + ';';
          end;
        end
        else
          Result := Result + '&' + LEntity + ';';
      end
      else
      begin
        Result := Result + AStr[LStart];
        LI := LStart + 1;
      end;
    end
    else
    begin
      Result := Result + AStr[LI];
      Inc(LI);
    end;
  end;
end;

{ XmlEncodeEntities }

function XmlEncodeEntities(const AStr: string): string;
var
  LI, LLen: Integer;
  LCh: AnsiChar;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  Result := '';
  for LI := 1 to LLen do
  begin
    LCh := AStr[LI];
    case LCh of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      '''': Result := Result + '&apos;';
    else
      Result := Result + LCh;
    end;
  end;
end;

{ TXmlReader - helpers }

function TXmlReader.Peek: AnsiChar;
begin
  if FPos < FLen then
    Result := FData[FPos]
  else
    Result := #0;
end;

function TXmlReader.PeekAt(AOffset: SizeUInt): AnsiChar;
begin
  if FPos + AOffset < FLen then
    Result := FData[FPos + AOffset]
  else
    Result := #0;
end;

function TXmlReader.Advance: AnsiChar;
begin
  if FPos < FLen then
  begin
    Result := FData[FPos];
    Inc(FPos);
  end
  else
    Result := #0;
end;

function TXmlReader.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

function TXmlReader.Match(const AStr: string): Boolean;
var
  LI, LMatchLen: Integer;
begin
  LMatchLen := Length(AStr);
  if FPos + SizeUInt(LMatchLen) > FLen then Exit(False);
  for LI := 1 to LMatchLen do
    if FData[FPos + SizeUInt(LI - 1)] <> AStr[LI] then Exit(False);
  Inc(FPos, LMatchLen);
  Result := True;
end;

procedure TXmlReader.SkipWhitespace;
begin
  while (FPos < FLen) and (FData[FPos] in [' ', #9, #10, #13]) do
    Inc(FPos);
end;

function TXmlReader.ReadName: string;
var
  LStart: SizeUInt;
begin
  LStart := FPos;
  while (FPos < FLen) and (FData[FPos] in
    ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.', ':']) do
    Inc(FPos);
  if FPos > LStart then
    SetString(Result, @FData[LStart], FPos - LStart)
  else
    Result := '';
end;

function TXmlReader.ReadQuotedValue: string;
var
  LQuote: AnsiChar;
  LStart: SizeUInt;
begin
  if (FPos < FLen) and (FData[FPos] in ['"', '''']) then
  begin
    LQuote := FData[FPos];
    Inc(FPos);
    LStart := FPos;
    while (FPos < FLen) and (FData[FPos] <> LQuote) do
      Inc(FPos);
    SetString(Result, @FData[LStart], FPos - LStart);
    if (FPos < FLen) and (FData[FPos] = LQuote) then
      Inc(FPos);
    Result := XmlDecodeEntities(Result);
  end
  else
    Result := '';
end;

procedure TXmlReader.ParseAttributes(out AAttrs: TXmlAttributeArray; out ASelfClose: Boolean);
var
  LName: string;
  LCount: Integer;
begin
  LCount := 0;
  SetLength(AAttrs, 0);
  ASelfClose := False;
  while not AtEnd do
  begin
    SkipWhitespace;
    if AtEnd then Break;
    if Peek = '/' then
    begin
      Inc(FPos);
      ASelfClose := True;
      if (FPos < FLen) and (FData[FPos] = '>') then
        Inc(FPos);
      SetLength(AAttrs, LCount);
      Exit;
    end;
    if Peek = '>' then
    begin
      Inc(FPos);
      SetLength(AAttrs, LCount);
      Exit;
    end;
    LName := ReadName;
    if LName = '' then
    begin
      Inc(FPos);
      Continue;
    end;
    if LCount >= Length(AAttrs) then
      SetLength(AAttrs, LCount + 8);
    AAttrs[LCount].Name := LName;
    SkipWhitespace;
    if (FPos < FLen) and (FData[FPos] = '=') then
    begin
      Inc(FPos);
      SkipWhitespace;
      AAttrs[LCount].Value := ReadQuotedValue;
    end
    else
      AAttrs[LCount].Value := '';
    Inc(LCount);
  end;
  SetLength(AAttrs, LCount);
end;

function TXmlReader.ParseTag(out AEvent: TXmlEvent): Boolean;
var
  LSelfClose: Boolean;
  LStart: SizeUInt;
begin
  Result := True;
  Inc(FPos); // skip '<'

  // Comment: <!-- ... -->
  if Match('!--') then
  begin
    AEvent.Kind := xekComment;
    AEvent.Name := '';
    AEvent.Attributes := nil;
    LStart := FPos;
    while not AtEnd do
    begin
      if (FPos + 2 < FLen) and (FData[FPos] = '-') and
         (FData[FPos+1] = '-') and (FData[FPos+2] = '>') then
      begin
        SetString(AEvent.Value, @FData[LStart], FPos - LStart);
        Inc(FPos, 3);
        Exit;
      end;
      Inc(FPos);
    end;
    SetString(AEvent.Value, @FData[LStart], FPos - LStart);
    Exit;
  end;

  // CDATA: <![CDATA[ ... ]]>
  if Match('![CDATA[') then
  begin
    AEvent.Kind := xekCData;
    AEvent.Name := '';
    AEvent.Attributes := nil;
    LStart := FPos;
    while not AtEnd do
    begin
      if (FPos + 2 < FLen) and (FData[FPos] = ']') and
         (FData[FPos+1] = ']') and (FData[FPos+2] = '>') then
      begin
        SetString(AEvent.Value, @FData[LStart], FPos - LStart);
        Inc(FPos, 3);
        Exit;
      end;
      Inc(FPos);
    end;
    SetString(AEvent.Value, @FData[LStart], FPos - LStart);
    Exit;
  end;

  // DOCTYPE: <!DOCTYPE ... >
  if Match('!DOCTYPE') or Match('!doctype') then
  begin
    AEvent.Kind := xekDoctype;
    AEvent.Name := '';
    AEvent.Attributes := nil;
    SkipWhitespace;
    LStart := FPos;
    while (FPos < FLen) and (FData[FPos] <> '>') do
      Inc(FPos);
    SetString(AEvent.Value, @FData[LStart], FPos - LStart);
    if FPos < FLen then Inc(FPos);
    Exit;
  end;

  // Processing instruction: <? ... ?>
  if (FPos < FLen) and (FData[FPos] = '?') then
  begin
    Inc(FPos);
    AEvent.Kind := xekProcessingInstruction;
    AEvent.Attributes := nil;
    AEvent.Name := ReadName;
    SkipWhitespace;
    LStart := FPos;
    while not AtEnd do
    begin
      if (FPos + 1 < FLen) and (FData[FPos] = '?') and (FData[FPos+1] = '>') then
      begin
        SetString(AEvent.Value, @FData[LStart], FPos - LStart);
        Inc(FPos, 2);
        Exit;
      end;
      Inc(FPos);
    end;
    SetString(AEvent.Value, @FData[LStart], FPos - LStart);
    Exit;
  end;

  // End tag: </name>
  if (FPos < FLen) and (FData[FPos] = '/') then
  begin
    Inc(FPos);
    AEvent.Kind := xekEndElement;
    AEvent.Name := ReadName;
    AEvent.Value := '';
    AEvent.Attributes := nil;
    while (FPos < FLen) and (FData[FPos] <> '>') do
      Inc(FPos);
    if FPos < FLen then Inc(FPos);
    Exit;
  end;

  // Start tag: <name attrs... > or <name attrs... />
  AEvent.Kind := xekStartElement;
  AEvent.Name := ReadName;
  AEvent.Value := '';
  ParseAttributes(AEvent.Attributes, LSelfClose);
  if LSelfClose then
  begin
    FHasPending := True;
    FPendingEvent.Kind := xekEndElement;
    FPendingEvent.Name := AEvent.Name;
    FPendingEvent.Value := '';
    FPendingEvent.Attributes := nil;
  end;
end;

function TXmlReader.ParseText(out AEvent: TXmlEvent): Boolean;
var
  LStart: SizeUInt;
begin
  LStart := FPos;
  while (FPos < FLen) and (FData[FPos] <> '<') do
    Inc(FPos);
  if FPos > LStart then
  begin
    AEvent.Kind := xekText;
    AEvent.Name := '';
    AEvent.Attributes := nil;
    SetString(AEvent.Value, @FData[LStart], FPos - LStart);
    AEvent.Value := XmlDecodeEntities(AEvent.Value);
    Result := True;
  end
  else
    Result := False;
end;

{ TXmlReader - public }

class function TXmlReader.Create(const AInput: string): TXmlReader;
begin
  if Length(AInput) > 0 then
  begin
    Result.FData := @AInput[1];
    Result.FLen := Length(AInput);
  end
  else
  begin
    Result.FData := nil;
    Result.FLen := 0;
  end;
  Result.FPos := 0;
  Result.FHasPending := False;
end;

function TXmlReader.Next(out AEvent: TXmlEvent): Boolean;
begin
  if FHasPending then
  begin
    AEvent := FPendingEvent;
    FHasPending := False;
    Exit(True);
  end;
  AEvent.Name := '';
  AEvent.Value := '';
  AEvent.Attributes := nil;
  if AtEnd then Exit(False);
  if Peek = '<' then
    Result := ParseTag(AEvent)
  else
    Result := ParseText(AEvent);
end;

function TXmlReader.ReadAll: TXmlEventArray;
var
  LCount, LCap: Integer;
  LEvent: TXmlEvent;
begin
  LCount := 0;
  LCap := 32;
  SetLength(Result, LCap);
  while Next(LEvent) do
  begin
    if LCount >= LCap then
    begin
      LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
    Result[LCount] := LEvent;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

end.
