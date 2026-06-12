unit nextpas.core.json.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.json.types;

type
  TJsonReader = record
  private
    FOriginalInput: TStringView;
    FInput: TStringView;
    FOrigLen: SizeUInt;
    FTokenKind: TJsonTokenKind;
    FTokenStr: TStringView;
    FTokenInt: Int64;
    FTokenFloat: Double;
    FTokenBool: Boolean;
    FError: TJsonError;
    FDepth: Int32;
    procedure SkipWS; inline;
    procedure SetError(const AMsg: PAnsiChar; ALen: SizeUInt; AOffset: SizeUInt);
    function HasTokenBoundary(const AConsumed: SizeUInt): Boolean;
    function ReadString(out AStr: TStringView): Boolean;
    function ReadNumber: Boolean;
    function ValidateStringToken(const AStr: TStringView;
      AContentOffset: SizeUInt): Boolean;
  public
    procedure Init(const AInput: TStringView);
    function Next: Boolean;
    function TokenKind: TJsonTokenKind; inline;
    function TokenStr: TStringView; inline;
    function TokenInt: Int64; inline;
    function TokenFloat: Double; inline;
    function TokenBool: Boolean; inline;
    function Error: TJsonError; inline;
    function Offset: SizeUInt; inline;
  end;

implementation

uses
  nextpas.core.text.scan,
  nextpas.core.text.char,
  nextpas.core.text.escape,
  nextpas.core.text.number;

procedure TJsonReader.Init(const AInput: TStringView);
begin
  FOriginalInput := AInput;
  FInput := AInput;
  FOrigLen := AInput.Len;
  FTokenKind := jtkNone;
  FDepth := 0;
  FError.Message := TStringView.Create(nil, 0);
  JsonErrorSetPosition(FError, FOriginalInput, 0);
end;

procedure TJsonReader.SkipWS;
var
  LSkipped: SizeUInt;
begin
  LSkipped := ScanSkipWhitespace(FInput.Data, FInput.Len);
  if LSkipped > 0 then
    FInput.Advance(LSkipped);
end;

procedure TJsonReader.SetError(const AMsg: PAnsiChar; ALen: SizeUInt; AOffset: SizeUInt);
begin
  FError.Message := TStringView.Create(AMsg, ALen);
  JsonErrorSetPosition(FError, FOriginalInput, AOffset);
end;

function TJsonReader.HasTokenBoundary(const AConsumed: SizeUInt): Boolean;
var
  LCh: Byte;
begin
  if AConsumed >= FInput.Len then
    Exit(True);
  LCh := Byte(FInput.Data[AConsumed]);
  Result := IsWhitespace(LCh) or
    (LCh = Ord(',')) or (LCh = Ord(':')) or
    (LCh = Ord(']')) or (LCh = Ord('}'));
end;

function TJsonReader.ReadString(out AStr: TStringView): Boolean;
var
  LEnd: PtrInt;
  LStringOffset: SizeUInt;
  LRaw: TStringView;
begin
  LStringOffset := Offset;
  LEnd := JsonFindStringEnd(FInput.Data + 1, FInput.Len - 1);
  if LEnd < 0 then
  begin
    SetError(PAnsiChar('unterminated string'), 19, FOrigLen);
    Exit(False);
  end;
  LRaw := TStringView.Create(FInput.Data + 1, SizeUInt(LEnd));
  if not ValidateStringToken(LRaw, LStringOffset + 1) then
    Exit(False);
  AStr := LRaw;
  FInput.Advance(SizeUInt(LEnd) + 2);
  Result := True;
end;

function TJsonReader.ValidateStringToken(const AStr: TStringView;
  AContentOffset: SizeUInt): Boolean;
var
  LError: TJsonStringValidationError;
  LErrorOffset: SizeUInt;
begin
  if JsonValidateStringToken(AStr.Data, AStr.Len, LError, LErrorOffset) then
    Exit(True);
  case LError of
    jsveControlChar:
      SetError(PAnsiChar('control char in string'), 22,
        AContentOffset + LErrorOffset);
  else
    SetError(PAnsiChar('invalid escape sequence'), 23,
      AContentOffset + LErrorOffset);
  end;
  Result := False;
end;

function TJsonReader.ReadNumber: Boolean;
var
  LNumLen: SizeUInt;
  LNumView: TStringView;
  LHasDot, LHasExp: Boolean;
  I: SizeUInt;
begin
  LNumLen := ScanJsonNumber(FInput.Data, FInput.Len);
  if LNumLen = 0 then
  begin
    SetError(PAnsiChar('invalid number'), 14, Offset);
    Exit(False);
  end;
  LNumView := FInput.Left(LNumLen);
  if not ScanIsJsonNumberToken(LNumView.Data, LNumView.Len) then
  begin
    if (LNumLen < FInput.Len) and HasTokenBoundary(LNumLen) and
      ScanJsonNumberHasIncompleteExponent(LNumView.Data, LNumView.Len) then
      SetError(PAnsiChar('invalid number'), 14, Offset + LNumLen)
    else
      SetError(PAnsiChar('invalid number'), 14, Offset);
    Exit(False);
  end;
  if not HasTokenBoundary(LNumLen) then
  begin
    SetError(PAnsiChar('invalid number'), 14, Offset);
    Exit(False);
  end;
  LHasDot := False;
  LHasExp := False;
  for I := 0 to LNumLen - 1 do
  begin
    if FInput.Data[I] = '.' then LHasDot := True;
    if (FInput.Data[I] = 'e') or (FInput.Data[I] = 'E') then LHasExp := True;
  end;
  if LHasDot or LHasExp then
  begin
    if not ParseDouble(LNumView.Data, LNumView.Len, FTokenFloat) then
    begin
      SetError(PAnsiChar('number overflow'), 15, Offset);
      Exit(False);
    end;
    FTokenKind := jtkFloat;
  end
  else
  begin
    if not ParseInt64(LNumView.Data, LNumView.Len, FTokenInt) then
    begin
      SetError(PAnsiChar('number overflow'), 15, Offset);
      Exit(False);
    end
    else
      FTokenKind := jtkInt;
  end;
  FTokenStr := LNumView;
  FInput.Advance(LNumLen);
  Result := True;
end;

function TJsonReader.Next: Boolean;
var
  LCh: Byte;
label
  LAgain;
begin
LAgain:
  SkipWS;
  if FInput.IsEmpty then
  begin
    FTokenKind := jtkNone;
    Exit(False);
  end;

  LCh := FInput.PeekByte;
  case LCh of
    Ord('{'):
    begin
      if FDepth >= 512 then
      begin
        FTokenKind := jtkError;
        SetError(PAnsiChar('max depth exceeded'), 18, Offset);
        Exit(False);
      end;
      FTokenKind := jtkBeginObject;
      FInput.Advance(1);
      Inc(FDepth);
    end;
    Ord('}'):
    begin
      FTokenKind := jtkEndObject;
      FInput.Advance(1);
      if FDepth > 0 then Dec(FDepth);
    end;
    Ord('['):
    begin
      if FDepth >= 512 then
      begin
        FTokenKind := jtkError;
        SetError(PAnsiChar('max depth exceeded'), 18, Offset);
        Exit(False);
      end;
      FTokenKind := jtkBeginArray;
      FInput.Advance(1);
      Inc(FDepth);
    end;
    Ord(']'):
    begin
      FTokenKind := jtkEndArray;
      FInput.Advance(1);
      if FDepth > 0 then Dec(FDepth);
    end;
    Ord(','), Ord(':'):
    begin
      FInput.Advance(1);
      goto LAgain;
    end;
    Ord('"'):
    begin
      if not ReadString(FTokenStr) then
      begin
        FTokenKind := jtkError;
        Exit(False);
      end;
      FTokenKind := jtkString;
    end;
    Ord('t'):
    begin
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('true'), 4) and
        HasTokenBoundary(4) then
      begin
        FTokenKind := jtkBool;
        FTokenBool := True;
        FInput.Advance(4);
      end
      else
      begin
        FTokenKind := jtkError;
        SetError(PAnsiChar('invalid literal'), 15, Offset);
        Exit(False);
      end;
    end;
    Ord('f'):
    begin
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('false'), 5) and
        HasTokenBoundary(5) then
      begin
        FTokenKind := jtkBool;
        FTokenBool := False;
        FInput.Advance(5);
      end
      else
      begin
        FTokenKind := jtkError;
        SetError(PAnsiChar('invalid literal'), 15, Offset);
        Exit(False);
      end;
    end;
    Ord('n'):
    begin
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('null'), 4) and
        HasTokenBoundary(4) then
      begin
        FTokenKind := jtkNull;
        FInput.Advance(4);
      end
      else
      begin
        FTokenKind := jtkError;
        SetError(PAnsiChar('invalid literal'), 15, Offset);
        Exit(False);
      end;
    end;
    Ord('-'), Ord('0')..Ord('9'):
    begin
      if not ReadNumber then
      begin
        FTokenKind := jtkError;
        Exit(False);
      end;
    end;
  else
    FTokenKind := jtkError;
    SetError(PAnsiChar('unexpected character'), 20, Offset);
    Exit(False);
  end;
  Result := True;
end;

function TJsonReader.TokenKind: TJsonTokenKind;
begin
  Result := FTokenKind;
end;

function TJsonReader.TokenStr: TStringView;
begin
  Result := FTokenStr;
end;

function TJsonReader.TokenInt: Int64;
begin
  Result := FTokenInt;
end;

function TJsonReader.TokenFloat: Double;
begin
  Result := FTokenFloat;
end;

function TJsonReader.TokenBool: Boolean;
begin
  Result := FTokenBool;
end;

function TJsonReader.Error: TJsonError;
begin
  Result := FError;
end;

function TJsonReader.Offset: SizeUInt;
begin
  Result := FOrigLen - FInput.Len;
end;

end.
