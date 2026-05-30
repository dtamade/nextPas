unit nextpas.core.json.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.json.types;

type
  TJsonReader = record
  private
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
    function ReadString(out AStr: TStringView): Boolean;
    function ReadNumber: Boolean;
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
  nextpas.core.text.escape,
  nextpas.core.text.number,
  nextpas.core.text.char;

procedure TJsonReader.Init(const AInput: TStringView);
begin
  FInput := AInput;
  FOrigLen := AInput.Len;
  FTokenKind := jtkNone;
  FDepth := 0;
  FError.Offset := 0;
end;

procedure TJsonReader.SkipWS;
var
  LSkipped: SizeUInt;
begin
  LSkipped := ScanSkipWhitespace(FInput.Data, FInput.Len);
  if LSkipped > 0 then
    FInput.Advance(LSkipped);
end;

function TJsonReader.ReadString(out AStr: TStringView): Boolean;
var
  LEnd: PtrInt;
begin
  LEnd := JsonFindStringEnd(FInput.Data + 1, FInput.Len - 1);
  if LEnd < 0 then
  begin
    FError.Message := TStringView.Create(PAnsiChar('unterminated string'), 19);
    FError.Offset := FInput.Len;
    Exit(False);
  end;
  AStr := TStringView.Create(FInput.Data + 1, SizeUInt(LEnd));
  FInput.Advance(SizeUInt(LEnd) + 2);
  Result := True;
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
    FError.Message := TStringView.Create(PAnsiChar('invalid number'), 14);
    Exit(False);
  end;
  LNumView := FInput.Left(LNumLen);
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
      FError.Message := TStringView.Create(PAnsiChar('invalid float'), 13);
      Exit(False);
    end;
    FTokenKind := jtkFloat;
  end
  else
  begin
    if not ParseInt64(LNumView.Data, LNumView.Len, FTokenInt) then
    begin
      if not ParseDouble(LNumView.Data, LNumView.Len, FTokenFloat) then
      begin
        FError.Message := TStringView.Create(PAnsiChar('number overflow'), 15);
        Exit(False);
      end;
      FTokenKind := jtkFloat;
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
        FError.Message := TStringView.Create(PAnsiChar('max depth exceeded'), 18);
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
        FError.Message := TStringView.Create(PAnsiChar('max depth exceeded'), 18);
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
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('true'), 4) then
      begin
        FTokenKind := jtkBool;
        FTokenBool := True;
        FInput.Advance(4);
      end
      else
      begin
        FTokenKind := jtkError;
        FError.Message := TStringView.Create(PAnsiChar('invalid literal'), 15);
        Exit(False);
      end;
    end;
    Ord('f'):
    begin
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('false'), 5) then
      begin
        FTokenKind := jtkBool;
        FTokenBool := False;
        FInput.Advance(5);
      end
      else
      begin
        FTokenKind := jtkError;
        FError.Message := TStringView.Create(PAnsiChar('invalid literal'), 15);
        Exit(False);
      end;
    end;
    Ord('n'):
    begin
      if ScanMatchLiteral(FInput.Data, FInput.Len, PAnsiChar('null'), 4) then
      begin
        FTokenKind := jtkNull;
        FInput.Advance(4);
      end
      else
      begin
        FTokenKind := jtkError;
        FError.Message := TStringView.Create(PAnsiChar('invalid literal'), 15);
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
    FError.Message := TStringView.Create(PAnsiChar('unexpected character'), 20);
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
