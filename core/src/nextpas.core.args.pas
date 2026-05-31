unit nextpas.core.args;
{**
 * @desc 命令行参数解析器。支持 flags、string/int 选项、positional 参数。
 *       默认用异常报错，TryParse/TryParseFrom 作为便利补充。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.text.view,
  nextpas.core.text.number;

type
  TArgKind = (akFlag, akString, akInt);

  EArgParseError = class(ENextPasError);

  TArgOption = record
    Name: string;
    Short: AnsiChar;
    Help: string;
    Kind: TArgKind;
    DefaultStr: string;
    DefaultInt: Int64;
    ValueStr: string;
    ValueInt: Int64;
    ValueBool: Boolean;
    Present: Boolean;
  end;

  TArgParser = class
  private
    FAppName: string;
    FDescription: string;
    FOptions: array of TArgOption;
    FPositionals: array of string;
    FParsed: Boolean;
    function FindOption(const AName: string): Int32;
    function FindShort(const AShort: AnsiChar): Int32;
    procedure DoParseArgs(const AArgs: array of string);
    procedure ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
  public
    constructor Create(const AAppName, ADescription: string);
    procedure AddFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
    procedure AddString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
    procedure AddInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
    procedure Parse;
    procedure ParseFrom(const AArgs: array of string);
    function TryParse: Boolean;
    function TryParseFrom(const AArgs: array of string): Boolean;
    function GetBool(const AName: string): Boolean;
    function GetString(const AName: string): string;
    function GetInt(const AName: string): Int64;
    function IsPresent(const AName: string): Boolean;
    function Positional(const AIndex: Int32): string;
    function PositionalCount: Int32;
    function HelpText: string;
  end;

implementation

{ TArgParser }

constructor TArgParser.Create(const AAppName, ADescription: string);
begin
  inherited Create;
  FAppName := AAppName;
  FDescription := ADescription;
  SetLength(FOptions, 0);
  SetLength(FPositionals, 0);
  FParsed := False;
end;

procedure TArgParser.AddFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akFlag;
  FOptions[LIdx].ValueBool := False;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
var
  LIdx: Int32;
begin
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akString;
  FOptions[LIdx].DefaultStr := ADefault;
  FOptions[LIdx].ValueStr := ADefault;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
var
  LIdx: Int32;
begin
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akInt;
  FOptions[LIdx].DefaultInt := ADefault;
  FOptions[LIdx].ValueInt := ADefault;
  FOptions[LIdx].Present := False;
end;

function TArgParser.FindOption(const AName: string): Int32;
var
  LI: Int32;
begin
  for LI := 0 to Length(FOptions) - 1 do
    if FOptions[LI].Name = AName then Exit(LI);
  Result := -1;
end;

function TArgParser.FindShort(const AShort: AnsiChar): Int32;
var
  LI: Int32;
begin
  for LI := 0 to Length(FOptions) - 1 do
    if FOptions[LI].Short = AShort then Exit(LI);
  Result := -1;
end;

procedure TArgParser.ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LName: string;
  LValue: string;
  LEqPos: Int32;
  LOptIdx: Int32;
  LIntVal: Int64;
begin
  LEqPos := Pos('=', AArg);
  if LEqPos > 0 then
  begin
    LName := Copy(AArg, 3, LEqPos - 3);
    LValue := Copy(AArg, LEqPos + 1, Length(AArg) - LEqPos);
  end
  else
  begin
    LName := Copy(AArg, 3, Length(AArg) - 2);
    LValue := '';
  end;

  LOptIdx := FindOption(LName);
  if LOptIdx < 0 then
    raise EArgParseError.Create('unknown option: --' + LName);

  FOptions[LOptIdx].Present := True;
  case FOptions[LOptIdx].Kind of
    akFlag:
    begin
      if LEqPos > 0 then
        raise EArgParseError.Create('--' + LName + ' is a flag and does not accept a value');
      FOptions[LOptIdx].ValueBool := True;
    end;
    akString:
    begin
      if LValue = '' then
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('--' + LName + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      FOptions[LOptIdx].ValueStr := LValue;
    end;
    akInt:
    begin
      if LValue = '' then
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('--' + LName + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      if not ParseInt64(PAnsiChar(LValue), SizeUInt(Length(LValue)), LIntVal) then
        raise EArgParseError.Create('--' + LName + ': invalid integer "' + LValue + '"');
      FOptions[LOptIdx].ValueInt := LIntVal;
    end;
  end;
end;

procedure TArgParser.ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LShort: AnsiChar;
  LOptIdx: Int32;
  LValue: string;
  LIntVal: Int64;
begin
  if Length(AArg) < 2 then
    raise EArgParseError.Create('invalid short option: ' + AArg);
  LShort := AArg[2];
  LOptIdx := FindShort(LShort);
  if LOptIdx < 0 then
    raise EArgParseError.Create('unknown option: -' + LShort);

  FOptions[LOptIdx].Present := True;
  case FOptions[LOptIdx].Kind of
    akFlag:
      FOptions[LOptIdx].ValueBool := True;
    akString:
    begin
      if Length(AArg) > 2 then
        LValue := Copy(AArg, 3, Length(AArg) - 2)
      else
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('-' + LShort + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      FOptions[LOptIdx].ValueStr := LValue;
    end;
    akInt:
    begin
      if Length(AArg) > 2 then
        LValue := Copy(AArg, 3, Length(AArg) - 2)
      else
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('-' + LShort + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      if not ParseInt64(PAnsiChar(LValue), SizeUInt(Length(LValue)), LIntVal) then
        raise EArgParseError.Create('-' + LShort + ': invalid integer "' + LValue + '"');
      FOptions[LOptIdx].ValueInt := LIntVal;
    end;
  end;
end;

procedure TArgParser.DoParseArgs(const AArgs: array of string);
var
  LI: Int32;
  LArg: string;
  LDoubleDash: Boolean;
begin
  FParsed := True;
  SetLength(FPositionals, 0);
  for LI := 0 to Length(FOptions) - 1 do
  begin
    FOptions[LI].Present := False;
    FOptions[LI].ValueBool := False;
    FOptions[LI].ValueStr := FOptions[LI].DefaultStr;
    FOptions[LI].ValueInt := FOptions[LI].DefaultInt;
  end;
  LDoubleDash := False;
  LI := 0;
  while LI <= High(AArgs) do
  begin
    LArg := AArgs[LI];
    if LDoubleDash then
    begin
      SetLength(FPositionals, Length(FPositionals) + 1);
      FPositionals[High(FPositionals)] := LArg;
    end
    else if LArg = '--' then
      LDoubleDash := True
    else if (Length(LArg) > 2) and (LArg[1] = '-') and (LArg[2] = '-') then
      ParseLong(LArg, AArgs, LI)
    else if (Length(LArg) >= 2) and (LArg[1] = '-') and (LArg[2] <> '-') then
      ParseShort(LArg, AArgs, LI)
    else
    begin
      SetLength(FPositionals, Length(FPositionals) + 1);
      FPositionals[High(FPositionals)] := LArg;
    end;
    Inc(LI);
  end;
end;

procedure TArgParser.Parse;
var
  LArgs: array of string;
  LI: Int32;
begin
  SetLength(LArgs, ParamCount);
  for LI := 1 to ParamCount do
    LArgs[LI - 1] := ParamStr(LI);
  DoParseArgs(LArgs);
end;

procedure TArgParser.ParseFrom(const AArgs: array of string);
begin
  DoParseArgs(AArgs);
end;

function TArgParser.TryParse: Boolean;
begin
  try
    Parse;
    Result := True;
  except
    on EArgParseError do Result := False;
  end;
end;

function TArgParser.TryParseFrom(const AArgs: array of string): Boolean;
begin
  try
    ParseFrom(AArgs);
    Result := True;
  except
    on EArgParseError do Result := False;
  end;
end;

function TArgParser.GetBool(const AName: string): Boolean;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then Exit(False);
  Result := FOptions[LIdx].ValueBool;
end;

function TArgParser.GetString(const AName: string): string;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then Exit('');
  Result := FOptions[LIdx].ValueStr;
end;

function TArgParser.GetInt(const AName: string): Int64;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then Exit(0);
  Result := FOptions[LIdx].ValueInt;
end;

function TArgParser.IsPresent(const AName: string): Boolean;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then Exit(False);
  Result := FOptions[LIdx].Present;
end;

function TArgParser.Positional(const AIndex: Int32): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FPositionals)) then Exit('');
  Result := FPositionals[AIndex];
end;

function TArgParser.PositionalCount: Int32;
begin
  Result := Length(FPositionals);
end;

function TArgParser.HelpText: string;
var
  LI: Int32;
  LBuf: array[0..31] of AnsiChar;
  LN: Int32;
  LDefStr: string;
begin
  Result := 'Usage: ' + FAppName + ' [options] [arguments]' + LineEnding;
  if FDescription <> '' then
    Result := Result + LineEnding + FDescription + LineEnding;
  Result := Result + LineEnding + 'Options:' + LineEnding;
  for LI := 0 to Length(FOptions) - 1 do
  begin
    Result := Result + '  ';
    if FOptions[LI].Short <> #0 then
      Result := Result + '-' + FOptions[LI].Short + ', ';
    Result := Result + '--' + FOptions[LI].Name;
    case FOptions[LI].Kind of
      akString: Result := Result + ' <string>';
      akInt: Result := Result + ' <int>';
    end;
    Result := Result + LineEnding + '      ' + FOptions[LI].Help;
    case FOptions[LI].Kind of
      akString:
        if FOptions[LI].DefaultStr <> '' then
          Result := Result + ' (default: "' + FOptions[LI].DefaultStr + '")';
      akInt:
      begin
        LN := IntToBuffer(FOptions[LI].DefaultInt, @LBuf[0]);
        SetString(LDefStr, @LBuf[0], LN);
        Result := Result + ' (default: ' + LDefStr + ')';
      end;
    end;
    Result := Result + LineEnding;
  end;
end;

end.
