unit nextpas.core.args;
{ Command-line argument parser.
  Supports flags (--verbose/-v), string/int options (--port=8080 or --port 8080),
  and positional arguments. Auto-generates help text.

  Usage:
    var Args: TArgParser;
    Args.Init('myapp', 'My application');
    Args.AddFlag('verbose', 'v', 'Enable verbose output');
    Args.AddString('output', 'o', 'Output file', 'out.txt');
    Args.AddInt('port', 'p', 'Port number', 8080);
    Args.Parse;
    if Args.GetBool('verbose') then ...
    WriteLn(Args.GetString('output'));
    WriteLn(Args.Positional(0)); }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

const
  ARGS_MAX_OPTIONS = 64;
  ARGS_MAX_POSITIONAL = 64;

type
  TArgKind = (akFlag, akString, akInt);

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

  TArgParser = record
  private
    FAppName: string;
    FDescription: string;
    FOptions: array[0..ARGS_MAX_OPTIONS - 1] of TArgOption;
    FOptionCount: Int32;
    FPositionals: array[0..ARGS_MAX_POSITIONAL - 1] of string;
    FPositionalCount: Int32;
    FParsed: Boolean;
    FError: string;
    function FindOption(const AName: string): Int32;
    function FindShort(AShort: AnsiChar): Int32;
    procedure ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
  public
    procedure Init(const AAppName, ADescription: string);
    procedure AddFlag(const AName: string; AShort: AnsiChar; const AHelp: string);
    procedure AddString(const AName: string; AShort: AnsiChar; const AHelp, ADefault: string);
    procedure AddInt(const AName: string; AShort: AnsiChar; const AHelp: string; ADefault: Int64);
    function Parse: Boolean;
    function ParseFrom(const AArgs: array of string): Boolean;
    function GetBool(const AName: string): Boolean;
    function GetString(const AName: string): string;
    function GetInt(const AName: string): Int64;
    function IsPresent(const AName: string): Boolean;
    function Positional(AIndex: Int32): string;
    function PositionalCount: Int32;
    function HasError: Boolean;
    function Error: string;
    function HelpText: string;
  end;

implementation

uses
  SysUtils;

{ TArgParser }

procedure TArgParser.Init(const AAppName, ADescription: string);
begin
  FAppName := AAppName;
  FDescription := ADescription;
  FOptionCount := 0;
  FPositionalCount := 0;
  FParsed := False;
  FError := '';
end;

procedure TArgParser.AddFlag(const AName: string; AShort: AnsiChar; const AHelp: string);
begin
  if FOptionCount >= ARGS_MAX_OPTIONS then Exit;
  FOptions[FOptionCount].Name := AName;
  FOptions[FOptionCount].Short := AShort;
  FOptions[FOptionCount].Help := AHelp;
  FOptions[FOptionCount].Kind := akFlag;
  FOptions[FOptionCount].ValueBool := False;
  FOptions[FOptionCount].Present := False;
  Inc(FOptionCount);
end;

procedure TArgParser.AddString(const AName: string; AShort: AnsiChar; const AHelp, ADefault: string);
begin
  if FOptionCount >= ARGS_MAX_OPTIONS then Exit;
  FOptions[FOptionCount].Name := AName;
  FOptions[FOptionCount].Short := AShort;
  FOptions[FOptionCount].Help := AHelp;
  FOptions[FOptionCount].Kind := akString;
  FOptions[FOptionCount].DefaultStr := ADefault;
  FOptions[FOptionCount].ValueStr := ADefault;
  FOptions[FOptionCount].Present := False;
  Inc(FOptionCount);
end;

procedure TArgParser.AddInt(const AName: string; AShort: AnsiChar; const AHelp: string; ADefault: Int64);
begin
  if FOptionCount >= ARGS_MAX_OPTIONS then Exit;
  FOptions[FOptionCount].Name := AName;
  FOptions[FOptionCount].Short := AShort;
  FOptions[FOptionCount].Help := AHelp;
  FOptions[FOptionCount].Kind := akInt;
  FOptions[FOptionCount].DefaultInt := ADefault;
  FOptions[FOptionCount].ValueInt := ADefault;
  FOptions[FOptionCount].Present := False;
  Inc(FOptionCount);
end;

function TArgParser.FindOption(const AName: string): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FOptionCount - 1 do
    if FOptions[LI].Name = AName then Exit(LI);
  Result := -1;
end;

function TArgParser.FindShort(AShort: AnsiChar): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FOptionCount - 1 do
    if FOptions[LI].Short = AShort then Exit(LI);
  Result := -1;
end;

procedure TArgParser.ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LName, LValue: string;
  LEqPos, LOptIdx: Int32;
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
  begin
    FError := 'unknown option: --' + LName;
    Exit;
  end;

  FOptions[LOptIdx].Present := True;
  case FOptions[LOptIdx].Kind of
    akFlag:
      FOptions[LOptIdx].ValueBool := True;
    akString:
    begin
      if LValue = '' then
      begin
        if AIdx + 1 > High(AArgs) then
        begin
          FError := '--' + LName + ' requires a value';
          Exit;
        end;
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
        begin
          FError := '--' + LName + ' requires a value';
          Exit;
        end;
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      if not TryStrToInt64(LValue, LIntVal) then
      begin
        FError := '--' + LName + ': invalid integer "' + LValue + '"';
        Exit;
      end;
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
  begin
    FError := 'invalid short option: ' + AArg;
    Exit;
  end;
  LShort := AArg[2];
  LOptIdx := FindShort(LShort);
  if LOptIdx < 0 then
  begin
    FError := 'unknown option: -' + LShort;
    Exit;
  end;

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
        begin
          FError := '-' + LShort + ' requires a value';
          Exit;
        end;
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
        begin
          FError := '-' + LShort + ' requires a value';
          Exit;
        end;
        Inc(AIdx);
        LValue := AArgs[AIdx];
      end;
      if not TryStrToInt64(LValue, LIntVal) then
      begin
        FError := '-' + LShort + ': invalid integer "' + LValue + '"';
        Exit;
      end;
      FOptions[LOptIdx].ValueInt := LIntVal;
    end;
  end;
end;

function TArgParser.Parse: Boolean;
var
  LArgs: array of string;
  LI: Int32;
begin
  SetLength(LArgs, ParamCount);
  for LI := 1 to ParamCount do
    LArgs[LI - 1] := ParamStr(LI);
  Result := ParseFrom(LArgs);
end;

function TArgParser.ParseFrom(const AArgs: array of string): Boolean;
var
  LI: Int32;
  LArg: string;
  LDoubleDash: Boolean;
begin
  FParsed := True;
  FError := '';
  FPositionalCount := 0;
  LDoubleDash := False;
  LI := 0;
  while LI <= High(AArgs) do
  begin
    LArg := AArgs[LI];
    if LDoubleDash then
    begin
      if FPositionalCount < ARGS_MAX_POSITIONAL then
      begin
        FPositionals[FPositionalCount] := LArg;
        Inc(FPositionalCount);
      end;
    end
    else if LArg = '--' then
      LDoubleDash := True
    else if (Length(LArg) > 2) and (LArg[1] = '-') and (LArg[2] = '-') then
    begin
      ParseLong(LArg, AArgs, LI);
      if FError <> '' then Exit(False);
    end
    else if (Length(LArg) >= 2) and (LArg[1] = '-') and (LArg[2] <> '-') then
    begin
      ParseShort(LArg, AArgs, LI);
      if FError <> '' then Exit(False);
    end
    else
    begin
      if FPositionalCount < ARGS_MAX_POSITIONAL then
      begin
        FPositionals[FPositionalCount] := LArg;
        Inc(FPositionalCount);
      end;
    end;
    Inc(LI);
  end;
  Result := True;
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

function TArgParser.Positional(AIndex: Int32): string;
begin
  if (AIndex < 0) or (AIndex >= FPositionalCount) then Exit('');
  Result := FPositionals[AIndex];
end;

function TArgParser.PositionalCount: Int32;
begin
  Result := FPositionalCount;
end;

function TArgParser.HasError: Boolean;
begin
  Result := FError <> '';
end;

function TArgParser.Error: string;
begin
  Result := FError;
end;

function TArgParser.HelpText: string;
var
  LI: Int32;
begin
  Result := 'Usage: ' + FAppName + ' [options] [arguments]' + LineEnding;
  if FDescription <> '' then
    Result := Result + LineEnding + FDescription + LineEnding;
  Result := Result + LineEnding + 'Options:' + LineEnding;
  for LI := 0 to FOptionCount - 1 do
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
        Result := Result + ' (default: ' + IntToStr(FOptions[LI].DefaultInt) + ')';
    end;
    Result := Result + LineEnding;
  end;
end;

end.
