unit nextpas.core.args;
{**
 * @desc Production-grade CLI argument parser.
 *       Supports flags, string/int/stringlist/choice options, required flags,
 *       named positionals, short flag clustering, duplicate detection,
 *       auto --help/--version, and subcommand routing via TArgApp.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.text.number;

type
  TArgKind = (akFlag, akString, akInt, akStringList, akChoice);

  EArgParseError = class(ENextPasError);
  EArgHelp = class(ENextPasError);
  EArgVersion = class(ENextPasError);

  TStringArray = array of string;

  TArgOption = record
    Name: string;
    Short: AnsiChar;
    Help: string;
    Kind: TArgKind;
    Required: Boolean;
    DefaultStr: string;
    DefaultInt: Int64;
    Choices: TStringArray;
    ValueStr: string;
    ValueInt: Int64;
    ValueBool: Boolean;
    ValueList: TStringArray;
    Present: Boolean;
  end;

  TArgPositionalSpec = record
    Name: string;
    Help: string;
    Required: Boolean;
  end;

  TArgParser = class
  private
    FAppName: string;
    FDescription: string;
    FVersion: string;
    FOptions: array of TArgOption;
    FPositionals: array of string;
    FPositionalSpecs: array of TArgPositionalSpec;
    FParsed: Boolean;
    FAutoHelp: Boolean;
    FAutoVersion: Boolean;
    function FindOption(const AName: string): Int32;
    function FindShort(const AShort: AnsiChar): Int32;
    procedure CheckDuplicate(const AName: string; const AShort: AnsiChar);
    procedure DoParseArgs(const AArgs: array of string);
    procedure ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ValidateRequired;
    procedure ValidatePositionals;
    function IsValidChoice(const AOptIdx: Int32; const AValue: string): Boolean;
  public
    constructor Create(const AAppName, ADescription: string);
    procedure SetVersion(const AVersion: string);
    procedure SetAutoHelp(const AEnabled: Boolean);
    procedure SetAutoVersion(const AEnabled: Boolean);
    { Flag options }
    procedure AddFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
    { String options }
    procedure AddString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
    procedure AddRequiredString(const AName: string; const AShort: AnsiChar; const AHelp: string);
    { Int options }
    procedure AddInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
    { StringList (repeatable) options }
    procedure AddStringList(const AName: string; const AShort: AnsiChar; const AHelp: string);
    { Choice (enum-constrained) options }
    procedure AddChoice(const AName: string; const AShort: AnsiChar; const AHelp: string;
      const AChoices: array of string; const ADefault: string);
    { Positional specs }
    procedure AddPositional(const AName, AHelp: string; const ARequired: Boolean);
    { Parsing }
    procedure Parse;
    procedure ParseFrom(const AArgs: array of string);
    function TryParse: Boolean;
    function TryParseFrom(const AArgs: array of string): Boolean;
    { Accessors }
    function GetBool(const AName: string): Boolean;
    function GetString(const AName: string): string;
    function GetInt(const AName: string): Int64;
    function GetStringList(const AName: string): TStringArray;
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
  FVersion := '';
  SetLength(FOptions, 0);
  SetLength(FPositionals, 0);
  SetLength(FPositionalSpecs, 0);
  FParsed := False;
  FAutoHelp := True;
  FAutoVersion := True;
end;

procedure TArgParser.SetVersion(const AVersion: string);
begin
  FVersion := AVersion;
end;

procedure TArgParser.SetAutoHelp(const AEnabled: Boolean);
begin
  FAutoHelp := AEnabled;
end;

procedure TArgParser.SetAutoVersion(const AEnabled: Boolean);
begin
  FAutoVersion := AEnabled;
end;
// PLACEHOLDER_METHODS_1

procedure TArgParser.CheckDuplicate(const AName: string; const AShort: AnsiChar);
begin
  if FindOption(AName) >= 0 then
    raise EArgParseError.Create('duplicate option name: ' + AName);
  if (AShort <> #0) and (FindShort(AShort) >= 0) then
    raise EArgParseError.Create('duplicate short option: -' + AShort);
end;

procedure TArgParser.AddFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akFlag;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].ValueBool := False;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akString;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].DefaultStr := ADefault;
  FOptions[LIdx].ValueStr := ADefault;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddRequiredString(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akString;
  FOptions[LIdx].Required := True;
  FOptions[LIdx].DefaultStr := '';
  FOptions[LIdx].ValueStr := '';
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akInt;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].DefaultInt := ADefault;
  FOptions[LIdx].ValueInt := ADefault;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddStringList(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akStringList;
  FOptions[LIdx].Required := False;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;
// PLACEHOLDER_METHODS_2

procedure TArgParser.AddChoice(const AName: string; const AShort: AnsiChar; const AHelp: string;
  const AChoices: array of string; const ADefault: string);
var
  LIdx, LI: Int32;
begin
  CheckDuplicate(AName, AShort);
  LIdx := Length(FOptions);
  SetLength(FOptions, LIdx + 1);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akChoice;
  FOptions[LIdx].Required := False;
  SetLength(FOptions[LIdx].Choices, Length(AChoices));
  for LI := 0 to High(AChoices) do
    FOptions[LIdx].Choices[LI] := AChoices[LI];
  FOptions[LIdx].DefaultStr := ADefault;
  FOptions[LIdx].ValueStr := ADefault;
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddPositional(const AName, AHelp: string; const ARequired: Boolean);
var
  LIdx: Int32;
begin
  LIdx := Length(FPositionalSpecs);
  SetLength(FPositionalSpecs, LIdx + 1);
  FPositionalSpecs[LIdx].Name := AName;
  FPositionalSpecs[LIdx].Help := AHelp;
  FPositionalSpecs[LIdx].Required := ARequired;
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

function TArgParser.IsValidChoice(const AOptIdx: Int32; const AValue: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to Length(FOptions[AOptIdx].Choices) - 1 do
    if FOptions[AOptIdx].Choices[LI] = AValue then Exit(True);
  Result := False;
end;
// PLACEHOLDER_METHODS_3

procedure TArgParser.ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LName: string;
  LValue: string;
  LEqPos: Int32;
  LOptIdx: Int32;
  LIntVal: Int64;
  LListLen: Int32;
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

  if FAutoHelp and (LName = 'help') then
    raise EArgHelp.Create(HelpText);
  if FAutoVersion and (LName = 'version') and (FVersion <> '') then
    raise EArgVersion.Create(FVersion);

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
    akStringList:
    begin
      if LValue = '' then
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('--' + LName + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      LListLen := Length(FOptions[LOptIdx].ValueList);
      SetLength(FOptions[LOptIdx].ValueList, LListLen + 1);
      FOptions[LOptIdx].ValueList[LListLen] := LValue;
    end;
    akChoice:
    begin
      if LValue = '' then
      begin
        if AIdx + 1 > High(AArgs) then
          raise EArgParseError.Create('--' + LName + ' requires a value');
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      if not IsValidChoice(LOptIdx, LValue) then
        raise EArgParseError.Create('--' + LName + ': invalid value "' + LValue + '"');
      FOptions[LOptIdx].ValueStr := LValue;
    end;
  end;
end;
// PLACEHOLDER_METHODS_4

procedure TArgParser.ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LCharIdx: Int32;
  LShort: AnsiChar;
  LOptIdx: Int32;
  LValue: string;
  LIntVal: Int64;
  LListLen: Int32;
begin
  if Length(AArg) < 2 then
    raise EArgParseError.Create('invalid short option: ' + AArg);

  LCharIdx := 2;
  while LCharIdx <= Length(AArg) do
  begin
    LShort := AArg[LCharIdx];

    if FAutoHelp and (LShort = 'h') then
      raise EArgHelp.Create(HelpText);
    if FAutoVersion and (LShort = 'V') and (FVersion <> '') then
      raise EArgVersion.Create(FVersion);

    LOptIdx := FindShort(LShort);
    if LOptIdx < 0 then
      raise EArgParseError.Create('unknown option: -' + LShort);

    FOptions[LOptIdx].Present := True;
    case FOptions[LOptIdx].Kind of
      akFlag:
      begin
        FOptions[LOptIdx].ValueBool := True;
        Inc(LCharIdx);
      end;
      akString, akChoice, akStringList:
      begin
        if LCharIdx < Length(AArg) then
          LValue := Copy(AArg, LCharIdx + 1, Length(AArg) - LCharIdx)
        else
        begin
          if AIdx + 1 > High(AArgs) then
            raise EArgParseError.Create('-' + LShort + ' requires a value');
          Inc(AIdx);
          LValue := AArgs[AIdx];
        end;
        if FOptions[LOptIdx].Kind = akChoice then
        begin
          if not IsValidChoice(LOptIdx, LValue) then
            raise EArgParseError.Create('-' + LShort + ': invalid value "' + LValue + '"');
          FOptions[LOptIdx].ValueStr := LValue;
        end
        else if FOptions[LOptIdx].Kind = akStringList then
        begin
          LListLen := Length(FOptions[LOptIdx].ValueList);
          SetLength(FOptions[LOptIdx].ValueList, LListLen + 1);
          FOptions[LOptIdx].ValueList[LListLen] := LValue;
        end
        else
          FOptions[LOptIdx].ValueStr := LValue;
        Break;
      end;
      akInt:
      begin
        if LCharIdx < Length(AArg) then
          LValue := Copy(AArg, LCharIdx + 1, Length(AArg) - LCharIdx)
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
        Break;
      end;
    end;
  end;
end;
// PLACEHOLDER_METHODS_5

procedure TArgParser.ValidateRequired;
var
  LI: Int32;
begin
  for LI := 0 to Length(FOptions) - 1 do
    if FOptions[LI].Required and (not FOptions[LI].Present) then
      raise EArgParseError.Create('missing required option: --' + FOptions[LI].Name);
end;

procedure TArgParser.ValidatePositionals;
var
  LI: Int32;
begin
  for LI := 0 to Length(FPositionalSpecs) - 1 do
    if FPositionalSpecs[LI].Required and (LI >= Length(FPositionals)) then
      raise EArgParseError.Create('missing required argument: ' + FPositionalSpecs[LI].Name);
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
    SetLength(FOptions[LI].ValueList, 0);
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
  ValidateRequired;
  ValidatePositionals;
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
// PLACEHOLDER_METHODS_6

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

function TArgParser.GetStringList(const AName: string): TStringArray;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  Result := FOptions[LIdx].ValueList;
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
  LChoicesStr: string;
begin
  Result := 'Usage: ' + FAppName + ' [options]';
  for LI := 0 to Length(FPositionalSpecs) - 1 do
  begin
    if FPositionalSpecs[LI].Required then
      Result := Result + ' <' + FPositionalSpecs[LI].Name + '>'
    else
      Result := Result + ' [' + FPositionalSpecs[LI].Name + ']';
  end;
  Result := Result + LineEnding;
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
      akStringList: Result := Result + ' <string>...';
      akChoice: Result := Result + ' <choice>';
    end;
    if FOptions[LI].Required then
      Result := Result + ' (required)';
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
      akChoice:
      begin
        LChoicesStr := '';
        for LN := 0 to Length(FOptions[LI].Choices) - 1 do
        begin
          if LN > 0 then LChoicesStr := LChoicesStr + ', ';
          LChoicesStr := LChoicesStr + FOptions[LI].Choices[LN];
        end;
        Result := Result + ' [' + LChoicesStr + ']';
        if FOptions[LI].DefaultStr <> '' then
          Result := Result + ' (default: "' + FOptions[LI].DefaultStr + '")';
      end;
    end;
    Result := Result + LineEnding;
  end;
end;

end.
