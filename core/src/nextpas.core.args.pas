unit nextpas.core.args;
{**
 * @desc Production-grade CLI argument parser with subcommand routing.
 *       Two-layer architecture: TArgParser (single-command) + TArgApp (router).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.args.base,
  nextpas.core.bytes.ops,
  nextpas.core.text.builder,
  nextpas.core.text.number;

type
  TArgKind = nextpas.core.args.base.TArgKind;
  EArgParseError = nextpas.core.args.base.EArgParseError;
  EArgHelp = nextpas.core.args.base.EArgHelp;
  EArgVersion = nextpas.core.args.base.EArgVersion;
  TStringArray = nextpas.core.args.base.TStringArray;
  TArgPositionalSpec = nextpas.core.args.base.TArgPositionalSpec;

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
    ValueListCap: Integer;
    ValueListLen: Integer;
    Present: Boolean;
  end;

  TArgParser = class
  private
    FAppName: string;
    FDescription: string;
    FVersion: string;
    FOptions: array of TArgOption;
    FOptionsLen: Integer;
    FOptionsCap: Integer;
    FPositionals: array of string;
    FPositionalsLen: Integer;
    FPositionalsCap: Integer;
    FPositionalSpecs: array of TArgPositionalSpec;
    FPositionalSpecsLen: Integer;
    FPositionalSpecsCap: Integer;
    FParsed: Boolean;
    FAutoHelp: Boolean;
    FAutoVersion: Boolean;
    // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1), zero-copy Move for ValueList append, not inline per red-line 2
    procedure EnsureOptionsCapacity(const ARequired: Integer);
    procedure EnsurePositionalsCapacity(const ARequired: Integer);
    procedure EnsurePositionalSpecsCapacity(const ARequired: Integer);
    procedure AppendPositional(const AValue: string); inline;
    procedure AppendValueList(const AOptIdx: Integer; const AValue: string);
    function FindOption(const AName: string): Int32;
    function FindShort(const AShort: AnsiChar): Int32;
    procedure CheckDuplicate(const AName: string; const AShort: AnsiChar);
    procedure DoParseArgs(const AArgs: array of string);
    procedure ParseLong(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
    procedure ValidateRequired;
    procedure ValidatePositionals;
    function IsValidChoice(const AOptIdx: Int32; const AValue: string): Boolean;
    function OptionNeedsValue(const AArg: string): Boolean;
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

  TArgCommandHandler = reference to procedure(const AParser: TArgParser);
  TArgCommandHandlerMethod = procedure(const AParser: TArgParser) of object;
  TArgCommandHandlerProc = procedure(const AParser: TArgParser);

  TArgCommand = record
    Name: string;
    Description: string;
    Parser: TArgParser;
    Handler: TArgCommandHandler;
  end;

  {**
   * @desc Subcommand router. Global options are parsed individually before
   *       the command name (no short-flag clustering at the app level).
   *}
  TArgApp = class
  private
    FAppName: string;
    FDescription: string;
    FVersion: string;
    FGlobalParser: TArgParser;
    FCommands: array of TArgCommand;
    FCommandsLen: Integer;
    FCommandsCap: Integer;
    FTrailingArgs: TStringArray;
    FTrailingLen: Integer;
    FTrailingCap: Integer;
    function FindCommand(const AName: string): Int32;
    function SuggestCommand(const AName: string): string;
    function AppHelpText: string;
    // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1), not inline per red-line 2
    procedure EnsureCommandsCapacity(const ARequired: Integer);
    procedure EnsureTrailingCapacity(const ARequired: Integer);
    procedure AppendTrailing(const AValue: string); inline;
    procedure AppendGlobalArg(var AList: TStringArray; var ACap, ALen: Integer; const AValue: string);
  public
    constructor Create(const AAppName, ADescription, AVersion: string);
    destructor Destroy; override;
    { Global flags — available to all commands }
    procedure AddGlobalFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
    procedure AddGlobalString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
    procedure AddGlobalInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
    { Commands — AddCommand returns a borrowed reference, owned by TArgApp }
    function AddCommand(const AName, ADescription: string): TArgParser;
    procedure SetHandler(const ACommandName: string; const AHandler: TArgCommandHandler); overload;
    procedure SetHandler(const ACommandName: string; const AHandler: TArgCommandHandlerMethod); overload;
    procedure SetHandler(const ACommandName: string; const AHandler: TArgCommandHandlerProc); overload;
    { Execution }
    procedure Run;
    procedure RunFrom(const AArgs: array of string);
    { Accessors }
    function GlobalParser: TArgParser;
    function TrailingArgs: TStringArray;
  end;

implementation

uses
  nextpas.core.platform.args;

{ single source platform args (L0) : zero-copy buffered platform_args_get, inline helper }
function PlatformArgsToArray: TStringArray; inline;
var
  LCount: Int32;
  LIdx: Int32;
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  LCount := platform_args_count;
  if LCount < 0 then LCount := 0;
  SetLength(Result, LCount);
  for LIdx := 1 to LCount do
  begin
    LLen := platform_args_get(LIdx, @LBuf[0], SizeOf(LBuf));
    if (LLen >= 0) and (LLen < SizeOf(LBuf)) then
      SetString(Result[LIdx - 1], PAnsiChar(@LBuf[0]), LLen)
    else if LLen >= SizeOf(LBuf) then
    begin
      SetString(Result[LIdx - 1], PAnsiChar(@LBuf[0]), SizeOf(LBuf) - 1);
    end
    else
      Result[LIdx - 1] := '';
  end;
end;

{ TArgParser }

constructor TArgParser.Create(const AAppName, ADescription: string);
begin
  inherited Create;
  FAppName := AAppName;
  FDescription := ADescription;
  FVersion := '';
  SetLength(FOptions, 0);
  FOptionsLen := 0;
  FOptionsCap := 0;
  SetLength(FPositionals, 0);
  FPositionalsLen := 0;
  FPositionalsCap := 0;
  SetLength(FPositionalSpecs, 0);
  FPositionalSpecsLen := 0;
  FPositionalSpecsCap := 0;
  FParsed := False;
  FAutoHelp := True;
  FAutoVersion := True;
end;

procedure TArgParser.EnsureOptionsCapacity(const ARequired: Integer);
begin
  // not inline per red-line 2: while loop in BytesGrowCapacityInt would bloat I-Cache; single source geometric via bytes.ops
  if ARequired <= FOptionsCap then Exit;
  FOptionsCap := BytesGrowCapacityInt(FOptionsCap, ARequired);
  SetLength(FOptions, FOptionsCap);
end;

procedure TArgParser.EnsurePositionalsCapacity(const ARequired: Integer);
begin
  if ARequired <= FPositionalsCap then Exit;
  FPositionalsCap := BytesGrowCapacityInt(FPositionalsCap, ARequired);
  SetLength(FPositionals, FPositionalsCap);
end;

procedure TArgParser.EnsurePositionalSpecsCapacity(const ARequired: Integer);
begin
  if ARequired <= FPositionalSpecsCap then Exit;
  FPositionalSpecsCap := BytesGrowCapacityInt(FPositionalSpecsCap, ARequired);
  SetLength(FPositionalSpecs, FPositionalSpecsCap);
end;

procedure TArgParser.AppendPositional(const AValue: string); inline;
begin
  // perf: inline thin append, capacity check delegates to bytes.ops single source, amortized O(1), zero-copy via string refcount copy
  EnsurePositionalsCapacity(FPositionalsLen + 1);
  FPositionals[FPositionalsLen] := AValue;
  Inc(FPositionalsLen);
end;

procedure TArgParser.AppendValueList(const AOptIdx: Integer; const AValue: string);
var
  LCap, LLen: Integer;
begin
  // not inline per red-line 2: growth path contains SetLength + BytesGrowCapacityInt loop
  // perf: geometric via BytesGrowCapacityInt single source amortized O(1), zero-copy string assign (refcount), stability: SetLength exception-safe
  LCap := FOptions[AOptIdx].ValueListCap;
  LLen := FOptions[AOptIdx].ValueListLen;
  if LLen >= LCap then
  begin
    LCap := BytesGrowCapacityInt(LCap, LLen + 1);
    SetLength(FOptions[AOptIdx].ValueList, LCap);
    FOptions[AOptIdx].ValueListCap := LCap;
  end;
  FOptions[AOptIdx].ValueList[LLen] := AValue;
  FOptions[AOptIdx].ValueListLen := LLen + 1;
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
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akFlag;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].ValueBool := False;
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akString;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].DefaultStr := ADefault;
  FOptions[LIdx].ValueStr := ADefault;
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddRequiredString(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akString;
  FOptions[LIdx].Required := True;
  FOptions[LIdx].DefaultStr := '';
  FOptions[LIdx].ValueStr := '';
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akInt;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].DefaultInt := ADefault;
  FOptions[LIdx].ValueInt := ADefault;
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddStringList(const AName: string; const AShort: AnsiChar; const AHelp: string);
var
  LIdx: Int32;
begin
  CheckDuplicate(AName, AShort);
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akStringList;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
  FOptions[LIdx].Present := False;
end;

procedure TArgParser.AddChoice(const AName: string; const AShort: AnsiChar; const AHelp: string;
  const AChoices: array of string; const ADefault: string);
var
  LIdx, LI: Int32;
  LValid: Boolean;
begin
  CheckDuplicate(AName, AShort);
  if ADefault <> '' then
  begin
    LValid := False;
    for LI := 0 to High(AChoices) do
      if AChoices[LI] = ADefault then begin LValid := True; Break; end;
    if not LValid then
      raise EArgParseError.Create('invalid default "' + ADefault + '" for choice option: ' + AName);
  end;
  EnsureOptionsCapacity(FOptionsLen + 1);
  LIdx := FOptionsLen;
  Inc(FOptionsLen);
  FOptions[LIdx].Name := AName;
  FOptions[LIdx].Short := AShort;
  FOptions[LIdx].Help := AHelp;
  FOptions[LIdx].Kind := akChoice;
  FOptions[LIdx].Required := False;
  FOptions[LIdx].ValueListCap := 0;
  FOptions[LIdx].ValueListLen := 0;
  SetLength(FOptions[LIdx].ValueList, 0);
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
  EnsurePositionalSpecsCapacity(FPositionalSpecsLen + 1);
  LIdx := FPositionalSpecsLen;
  Inc(FPositionalSpecsLen);
  FPositionalSpecs[LIdx].Name := AName;
  FPositionalSpecs[LIdx].Help := AHelp;
  FPositionalSpecs[LIdx].Required := ARequired;
end;

function TArgParser.FindOption(const AName: string): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FOptionsLen - 1 do
    if FOptions[LI].Name = AName then Exit(LI);
  Result := -1;
end;

function TArgParser.FindShort(const AShort: AnsiChar): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FOptionsLen - 1 do
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
      AppendValueList(LOptIdx, LValue);
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

procedure TArgParser.ParseShort(const AArg: string; const AArgs: array of string; var AIdx: Int32);
var
  LCharIdx: Int32;
  LShort: AnsiChar;
  LOptIdx: Int32;
  LValue: string;
  LIntVal: Int64;
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
          AppendValueList(LOptIdx, LValue);
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

procedure TArgParser.ValidateRequired;
var
  LI: Int32;
begin
  for LI := 0 to FOptionsLen - 1 do
    if FOptions[LI].Required and (not FOptions[LI].Present) then
      raise EArgParseError.Create('missing required option: --' + FOptions[LI].Name);
end;

procedure TArgParser.ValidatePositionals;
var
  LI: Int32;
begin
  for LI := 0 to FPositionalSpecsLen - 1 do
    if FPositionalSpecs[LI].Required and (LI >= FPositionalsLen) then
      raise EArgParseError.Create('missing required argument: ' + FPositionalSpecs[LI].Name);
end;

procedure TArgParser.DoParseArgs(const AArgs: array of string);
var
  LI, LJ: Int32;
  LArg: string;
  LDoubleDash: Boolean;
begin
  FParsed := True;
  // stability: clear positionals keep capacity, finalize strings to avoid leak
  for LI := 0 to FPositionalsLen - 1 do
    FPositionals[LI] := '';
  FPositionalsLen := 0;
  for LI := 0 to FOptionsLen - 1 do
  begin
    FOptions[LI].Present := False;
    FOptions[LI].ValueBool := False;
    FOptions[LI].ValueStr := FOptions[LI].DefaultStr;
    FOptions[LI].ValueInt := FOptions[LI].DefaultInt;
    // stability: finalize previous ValueList strings but keep capacity for reuse
    for LJ := 0 to FOptions[LI].ValueListLen - 1 do
      FOptions[LI].ValueList[LJ] := '';
    FOptions[LI].ValueListLen := 0;
  end;
  LDoubleDash := False;
  LI := 0;
  while LI <= High(AArgs) do
  begin
    LArg := AArgs[LI];
    if LDoubleDash then
    begin
      AppendPositional(LArg);
    end
    else if LArg = '--' then
      LDoubleDash := True
    else if (Length(LArg) > 2) and (LArg[1] = '-') and (LArg[2] = '-') then
      ParseLong(LArg, AArgs, LI)
    else if (Length(LArg) >= 2) and (LArg[1] = '-') and (LArg[2] <> '-') then
      ParseShort(LArg, AArgs, LI)
    else
    begin
      AppendPositional(LArg);
    end;
    Inc(LI);
  end;
  ValidateRequired;
  ValidatePositionals;
end;

procedure TArgParser.Parse;
var
  LArgs: TStringArray;
begin
  LArgs := PlatformArgsToArray;
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
  if LIdx < 0 then
    raise EArgParseError.Create('unknown option: ' + AName);
  if FOptions[LIdx].Kind <> akFlag then
    raise EArgParseError.Create('option ' + AName + ' is not a flag');
  Result := FOptions[LIdx].ValueBool;
end;

function TArgParser.GetString(const AName: string): string;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then
    raise EArgParseError.Create('unknown option: ' + AName);
  if not (FOptions[LIdx].Kind in [akString, akChoice]) then
    raise EArgParseError.Create('option ' + AName + ' is not a string/choice');
  Result := FOptions[LIdx].ValueStr;
end;

function TArgParser.GetInt(const AName: string): Int64;
var
  LIdx: Int32;
begin
  LIdx := FindOption(AName);
  if LIdx < 0 then
    raise EArgParseError.Create('unknown option: ' + AName);
  if FOptions[LIdx].Kind <> akInt then
    raise EArgParseError.Create('option ' + AName + ' is not an int');
  Result := FOptions[LIdx].ValueInt;
end;

function TArgParser.GetStringList(const AName: string): TStringArray;
var
  LIdx, LI: Int32;
begin
  Result := nil;
  LIdx := FindOption(AName);
  if LIdx < 0 then
    raise EArgParseError.Create('unknown option: ' + AName);
  if FOptions[LIdx].Kind <> akStringList then
    raise EArgParseError.Create('option ' + AName + ' is not a string list');
  // perf: trimmed copy via single allocation, zero-copy string refcount, single source geometric via ValueListLen/Cap
  SetLength(Result, FOptions[LIdx].ValueListLen);
  for LI := 0 to FOptions[LIdx].ValueListLen - 1 do
    Result[LI] := FOptions[LIdx].ValueList[LI];
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
  if (AIndex < 0) or (AIndex >= FPositionalsLen) then Exit('');
  Result := FPositionals[AIndex];
end;

function TArgParser.PositionalCount: Int32;
begin
  Result := FPositionalsLen;
end;

function TArgParser.HelpText: string;
var
  LI: Int32;
  LN: Int32;
  LBuilder: IStringBuilder;
begin
  // zero-copy single allocation: IStringBuilder O(n) vs O(n²) Result+; inline AppendStr/AppendInt avoids intermediate strings.
  LBuilder := MakeStringBuilder(512 + Length(FAppName) * 2 + Length(FDescription) + FOptionsLen * 96 + FPositionalSpecsLen * 32);
  LBuilder.AppendStr('Usage: ');
  LBuilder.AppendStr(FAppName);
  LBuilder.AppendStr(' [options]');
  for LI := 0 to FPositionalSpecsLen - 1 do
  begin
    if FPositionalSpecs[LI].Required then
    begin
      LBuilder.AppendStr(' <');
      LBuilder.AppendStr(FPositionalSpecs[LI].Name);
      LBuilder.AppendStr('>');
    end
    else
    begin
      LBuilder.AppendStr(' [');
      LBuilder.AppendStr(FPositionalSpecs[LI].Name);
      LBuilder.AppendStr(']');
    end;
  end;
  LBuilder.AppendStr(LineEnding);
  if FDescription <> '' then
  begin
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr(FDescription);
    LBuilder.AppendStr(LineEnding);
  end;
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('Options:');
  LBuilder.AppendStr(LineEnding);
  for LI := 0 to FOptionsLen - 1 do
  begin
    LBuilder.AppendStr('  ');
    if FOptions[LI].Short <> #0 then
    begin
      LBuilder.AppendStr('-');
      LBuilder.AppendChar(FOptions[LI].Short);
      LBuilder.AppendStr(', ');
    end;
    LBuilder.AppendStr('--');
    LBuilder.AppendStr(FOptions[LI].Name);
    case FOptions[LI].Kind of
      akString: LBuilder.AppendStr(' <string>');
      akInt: LBuilder.AppendStr(' <int>');
      akStringList: LBuilder.AppendStr(' <string>...');
      akChoice: LBuilder.AppendStr(' <choice>');
      akFlag: ;
    end;
    if FOptions[LI].Required then
      LBuilder.AppendStr(' (required)');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('      ');
    LBuilder.AppendStr(FOptions[LI].Help);
    case FOptions[LI].Kind of
      akString:
        if FOptions[LI].DefaultStr <> '' then
        begin
          LBuilder.AppendStr(' (default: "');
          LBuilder.AppendStr(FOptions[LI].DefaultStr);
          LBuilder.AppendStr('")');
        end;
      akInt:
      begin
        LBuilder.AppendStr(' (default: ');
        LBuilder.AppendInt(FOptions[LI].DefaultInt);
        LBuilder.AppendStr(')');
      end;
      akChoice:
      begin
        LBuilder.AppendStr(' [');
        for LN := 0 to Length(FOptions[LI].Choices) - 1 do
        begin
          if LN > 0 then LBuilder.AppendStr(', ');
          LBuilder.AppendStr(FOptions[LI].Choices[LN]);
        end;
        LBuilder.AppendStr(']');
        if FOptions[LI].DefaultStr <> '' then
        begin
          LBuilder.AppendStr(' (default: "');
          LBuilder.AppendStr(FOptions[LI].DefaultStr);
          LBuilder.AppendStr('")');
        end;
      end;
      akFlag, akStringList: ;
    end;
    LBuilder.AppendStr(LineEnding);
  end;
  Result := LBuilder.ToString;
end;

function TArgParser.OptionNeedsValue(const AArg: string): Boolean;
var
  LName: string;
  LIdx: Int32;
begin
  Result := False;
  if (Length(AArg) > 2) and (AArg[1] = '-') and (AArg[2] = '-') then
  begin
    LName := Copy(AArg, 3, Length(AArg) - 2);
    LIdx := FindOption(LName);
    if (LIdx >= 0) and (FOptions[LIdx].Kind <> akFlag) then
      Result := True;
  end
  else if (Length(AArg) = 2) and (AArg[1] = '-') then
  begin
    LIdx := FindShort(AArg[2]);
    if (LIdx >= 0) and (FOptions[LIdx].Kind <> akFlag) then
      Result := True;
  end;
end;

{ TArgApp }

constructor TArgApp.Create(const AAppName, ADescription, AVersion: string);
begin
  inherited Create;
  FAppName := AAppName;
  FDescription := ADescription;
  FVersion := AVersion;
  FGlobalParser := TArgParser.Create(AAppName, ADescription);
  FGlobalParser.SetAutoHelp(False);
  FGlobalParser.SetAutoVersion(False);
  SetLength(FCommands, 0);
  FCommandsLen := 0;
  FCommandsCap := 0;
  SetLength(FTrailingArgs, 0);
  FTrailingLen := 0;
  FTrailingCap := 0;
end;

destructor TArgApp.Destroy;
var
  LI: Int32;
begin
  FGlobalParser.Free;
  for LI := 0 to FCommandsLen - 1 do
    FCommands[LI].Parser.Free;
  inherited Destroy;
end;

procedure TArgApp.EnsureCommandsCapacity(const ARequired: Integer);
begin
  if ARequired <= FCommandsCap then Exit;
  FCommandsCap := BytesGrowCapacityInt(FCommandsCap, ARequired);
  SetLength(FCommands, FCommandsCap);
end;

procedure TArgApp.EnsureTrailingCapacity(const ARequired: Integer);
begin
  if ARequired <= FTrailingCap then Exit;
  FTrailingCap := BytesGrowCapacityInt(FTrailingCap, ARequired);
  SetLength(FTrailingArgs, FTrailingCap);
end;

procedure TArgApp.AppendTrailing(const AValue: string); inline;
begin
  EnsureTrailingCapacity(FTrailingLen + 1);
  FTrailingArgs[FTrailingLen] := AValue;
  Inc(FTrailingLen);
end;

procedure TArgApp.AppendGlobalArg(var AList: TStringArray; var ACap, ALen: Integer; const AValue: string);
begin
  // not inline per red-line 2: growth path; single source geometric via bytes.ops
  if ALen >= ACap then
  begin
    ACap := BytesGrowCapacityInt(ACap, ALen + 1);
    SetLength(AList, ACap);
  end;
  AList[ALen] := AValue;
  Inc(ALen);
end;

procedure TArgApp.AddGlobalFlag(const AName: string; const AShort: AnsiChar; const AHelp: string);
begin
  FGlobalParser.AddFlag(AName, AShort, AHelp);
end;

procedure TArgApp.AddGlobalString(const AName: string; const AShort: AnsiChar; const AHelp, ADefault: string);
begin
  FGlobalParser.AddString(AName, AShort, AHelp, ADefault);
end;

procedure TArgApp.AddGlobalInt(const AName: string; const AShort: AnsiChar; const AHelp: string; const ADefault: Int64);
begin
  FGlobalParser.AddInt(AName, AShort, AHelp, ADefault);
end;

function TArgApp.AddCommand(const AName, ADescription: string): TArgParser;
var
  LIdx: Int32;
begin
  EnsureCommandsCapacity(FCommandsLen + 1);
  LIdx := FCommandsLen;
  Inc(FCommandsLen);
  FCommands[LIdx].Name := AName;
  FCommands[LIdx].Description := ADescription;
  FCommands[LIdx].Parser := TArgParser.Create(FAppName + ' ' + AName, ADescription);
  FCommands[LIdx].Handler := nil;
  Result := FCommands[LIdx].Parser;
end;

procedure TArgApp.SetHandler(const ACommandName: string; const AHandler: TArgCommandHandler);
var
  LIdx: Int32;
begin
  LIdx := FindCommand(ACommandName);
  if LIdx < 0 then
    raise EArgParseError.Create('unknown command: ' + ACommandName);
  FCommands[LIdx].Handler := AHandler;
end;

procedure TArgApp.SetHandler(const ACommandName: string; const AHandler: TArgCommandHandlerMethod);
begin
  SetHandler(ACommandName, TArgCommandHandler(AHandler));
end;

procedure TArgApp.SetHandler(const ACommandName: string; const AHandler: TArgCommandHandlerProc);
begin
  SetHandler(ACommandName, TArgCommandHandler(
    procedure(const AParser: TArgParser) begin AHandler(AParser); end));
end;

function TArgApp.FindCommand(const AName: string): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FCommandsLen - 1 do
    if FCommands[LI].Name = AName then Exit(LI);
  Result := -1;
end;

function TArgApp.SuggestCommand(const AName: string): string;
var
  LI, LJ, LK: Int32;
  LBest: Int32;
  LDist: Int32;
  LPrev, LCurr: array[0..63] of Int32;
  LS: string;
begin
  FillChar(LPrev, SizeOf(LPrev), 0);
  Result := '';
  LBest := MaxInt;
  for LI := 0 to FCommandsLen - 1 do
  begin
    LS := FCommands[LI].Name;
    if (Length(AName) > 64) or (Length(LS) > 64) then Continue;
    for LJ := 0 to Length(LS) do
      LPrev[LJ] := LJ;
    for LJ := 1 to Length(AName) do
    begin
      LCurr[0] := LJ;
      for LK := 1 to Length(LS) do
      begin
        if AName[LJ] = LS[LK] then
          LCurr[LK] := LPrev[LK - 1]
        else
        begin
          LDist := LPrev[LK - 1];
          if LPrev[LK] < LDist then LDist := LPrev[LK];
          if LCurr[LK - 1] < LDist then LDist := LCurr[LK - 1];
          LCurr[LK] := LDist + 1;
        end;
      end;
      for LK := 0 to Length(LS) do
        LPrev[LK] := LCurr[LK];
    end;
    LDist := LPrev[Length(LS)];
    if (LDist < LBest) and (LDist <= 3) then
    begin
      LBest := LDist;
      Result := LS;
    end;
  end;
end;

function TArgApp.AppHelpText: string;
var
  LI: Int32;
  LBuilder: IStringBuilder;
begin
  // zero-copy single allocation: IStringBuilder O(n) vs O(n²) Result+; interface refcount ensures resource release on exception.
  LBuilder := MakeStringBuilder(512 + Length(FAppName) * 2 + Length(FDescription) + Length(FVersion) * 2 + FCommandsLen * 64);
  LBuilder.AppendStr(FAppName);
  if FVersion <> '' then
  begin
    LBuilder.AppendStr(' ');
    LBuilder.AppendStr(FVersion);
  end;
  LBuilder.AppendStr(LineEnding);
  if FDescription <> '' then
  begin
    LBuilder.AppendStr(FDescription);
    LBuilder.AppendStr(LineEnding);
  end;
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('Usage:');
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('  ');
  LBuilder.AppendStr(FAppName);
  LBuilder.AppendStr(' [global options] <command> [command options]');
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('Commands:');
  LBuilder.AppendStr(LineEnding);
  for LI := 0 to FCommandsLen - 1 do
  begin
    LBuilder.AppendStr('  ');
    LBuilder.AppendStr(FCommands[LI].Name);
    LBuilder.AppendStr('      ');
    LBuilder.AppendStr(FCommands[LI].Description);
    LBuilder.AppendStr(LineEnding);
  end;
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('Global Options:');
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('  -h, --help       Show this help');
  LBuilder.AppendStr(LineEnding);
  if FVersion <> '' then
  begin
    LBuilder.AppendStr('  -V, --version    Show version');
    LBuilder.AppendStr(LineEnding);
  end;
  LBuilder.AppendStr(FGlobalParser.HelpText);
  Result := LBuilder.ToString;
end;

procedure TArgApp.Run;
var
  LArgs: TStringArray;
begin
  LArgs := PlatformArgsToArray;
  RunFrom(LArgs);
end;

procedure TArgApp.RunFrom(const AArgs: array of string);
var
  LI, LJ: Int32;
  LGlobalArgs: array of string;
  LGlobalCap, LGlobalLen: Integer;
  LCmdArgs: array of string;
  LCmdCap, LCmdLen: Integer;
  LCmdIdx: Int32;
  LCmdName: string;
  LSuggestion: string;
  LDoubleDash: Boolean;
  LFoundCmd: Boolean;
begin
  // perf: local builders geometric via bytes.ops.BytesGrowCapacityInt amortized O(1), zero-copy via AppendGlobalArg, stability: SetLength exception-safe
  LGlobalCap := 0; LGlobalLen := 0; SetLength(LGlobalArgs, 0);
  LCmdCap := 0; LCmdLen := 0; SetLength(LCmdArgs, 0);
  // stability: clear previous trailing strings but keep capacity for reuse
  for LJ := 0 to FTrailingLen - 1 do
    FTrailingArgs[LJ] := '';
  FTrailingLen := 0;
  LFoundCmd := False;
  LCmdIdx := -1;
  LDoubleDash := False;

  LI := 0;
  while LI <= High(AArgs) do
  begin
    if (not LFoundCmd) and (not LDoubleDash) then
    begin
      if AArgs[LI] = '--help' then
        raise EArgHelp.Create(AppHelpText);
      if AArgs[LI] = '-h' then
        raise EArgHelp.Create(AppHelpText);
      if (FVersion <> '') and ((AArgs[LI] = '--version') or (AArgs[LI] = '-V')) then
        raise EArgVersion.Create(FVersion);

      if (Length(AArgs[LI]) > 0) and (AArgs[LI][1] = '-') then
      begin
        AppendGlobalArg(LGlobalArgs, LGlobalCap, LGlobalLen, AArgs[LI]);
        if (Pos('=', AArgs[LI]) = 0) and (LI + 1 <= High(AArgs)) then
        begin
          if FGlobalParser.OptionNeedsValue(AArgs[LI]) then
          begin
            Inc(LI);
            AppendGlobalArg(LGlobalArgs, LGlobalCap, LGlobalLen, AArgs[LI]);
          end;
        end;
      end
      else
      begin
        LCmdName := AArgs[LI];
        LCmdIdx := FindCommand(LCmdName);
        if LCmdIdx < 0 then
        begin
          LSuggestion := SuggestCommand(LCmdName);
          if LSuggestion <> '' then
            raise EArgParseError.Create('unknown command: ' + LCmdName + '. Did you mean "' + LSuggestion + '"?')
          else
            raise EArgParseError.Create('unknown command: ' + LCmdName);
        end;
        LFoundCmd := True;
      end;
    end
    else if LFoundCmd then
    begin
      if (not LDoubleDash) and (AArgs[LI] = '--') then
      begin
        LDoubleDash := True;
      end
      else if LDoubleDash then
      begin
        AppendTrailing(AArgs[LI]);
      end
      else
      begin
        AppendGlobalArg(LCmdArgs, LCmdCap, LCmdLen, AArgs[LI]);
      end;
    end;
    Inc(LI);
  end;

  if not LFoundCmd then
    raise EArgHelp.Create(AppHelpText);

  // trim local builders to logical len for ParseFrom (single SetLength shrink, zero-copy logical view)
  SetLength(LGlobalArgs, LGlobalLen);
  SetLength(LCmdArgs, LCmdLen);
  // keep FTrailingArgs capacity retained; logical len already tracked via FTrailingLen
  FGlobalParser.ParseFrom(LGlobalArgs);
  FCommands[LCmdIdx].Parser.ParseFrom(LCmdArgs);

  if FCommands[LCmdIdx].Handler <> nil then
    FCommands[LCmdIdx].Handler(FCommands[LCmdIdx].Parser);
end;

function TArgApp.GlobalParser: TArgParser;
begin
  Result := FGlobalParser;
end;

function TArgApp.TrailingArgs: TStringArray;
var
  LI: Integer;
begin
  // perf: trimmed copy via single allocation, zero-copy string refcount, geometric cap retained in FTrailingArgs
  Result := nil;
  SetLength(Result, FTrailingLen);
  for LI := 0 to FTrailingLen - 1 do
    Result[LI] := FTrailingArgs[LI];
end;

end.
