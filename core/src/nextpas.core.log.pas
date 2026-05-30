unit nextpas.core.log;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf;

type
  TLogLevel = nextpas.core.log.intf.TLogLevel;

  TAttrKind = (akString, akInt, akFloat, akBool);

  TAttr = record
    Key: string;
    Kind: TAttrKind;
    SVal: string;
    IVal: Int64;
    FVal: Double;
    BVal: Boolean;
  end;

  TLogRecord = record
    Level: TLogLevel;
    Message: string;
    TimestampNs: Int64;
    Attrs: array of TAttr;
    AttrCount: Int32;
    Group: string;
  end;

  ILogHandler = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-FA2345678901}']
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(var ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

  PLogEvent = ^TLogEvent;
  TLogEvent = record
  private
    FRec: TLogRecord;
    FHandler: ILogHandler;
    FEnabled: Boolean;
    procedure AddAttr(const AKey: string; AKind: TAttrKind;
      const ASVal: string; AIVal: Int64; AFVal: Double; ABVal: Boolean);
  public
    function Str(const AKey, AVal: string): PLogEvent;
    function Int(const AKey: string; AVal: Int64): PLogEvent;
    function Float(const AKey: string; AVal: Double): PLogEvent;
    function Bool(const AKey: string; AVal: Boolean): PLogEvent;
    function Err(const AErr: string): PLogEvent;
    procedure Msg(const AText: string);
    procedure Send;
  end;

  TLogger = record
  private
    FHandler: ILogHandler;
    FLevel: TLogLevel;
  public
    class function New(const AHandler: ILogHandler; ALevel: TLogLevel = llInfo): TLogger; static;
    function With_(const AKey, AVal: string): TLogger;
    function WithInt(const AKey: string; AVal: Int64): TLogger;
    function WithGroup(const AName: string): TLogger;
    function Enabled(const ALevel: TLogLevel): Boolean; inline;
    function Trace: PLogEvent;
    function Debug: PLogEvent;
    function Info: PLogEvent;
    function Warn: PLogEvent;
    function Error: PLogEvent;
    function Fatal: PLogEvent;
  end;

function AttrStr(const AKey, AVal: string): TAttr; inline;
function AttrInt(const AKey: string; AVal: Int64): TAttr; inline;
function AttrFloat(const AKey: string; AVal: Double): TAttr; inline;
function AttrBool(const AKey: string; AVal: Boolean): TAttr; inline;

function NewConsoleHandler(AMinLevel: TLogLevel = llDebug): ILogHandler;
function NewJsonHandler(AMinLevel: TLogLevel = llDebug): ILogHandler;

procedure SetDefaultLogger(const ALogger: TLogger);
function DefaultLogger: TLogger;

procedure LogTrace(const AMsg: string);
procedure LogDebug(const AMsg: string);
procedure LogInfo(const AMsg: string);
procedure LogWarn(const AMsg: string);
procedure LogError(const AMsg: string);

implementation

uses
  SysUtils, Math,
  nextpas.core.time.base;

const
  LEVEL_NAMES: array[TLogLevel] of string = (
    'TRC', 'DBG', 'INF', 'WRN', 'ERR', 'FTL'
  );
  LEVEL_COLORS: array[TLogLevel] of string = (
    #27'[90m', #27'[36m', #27'[32m', #27'[33m', #27'[31m', #27'[35;1m'
  );
  RESET = #27'[0m';
  DIM = #27'[90m';

{ Attr constructors }

function AttrStr(const AKey, AVal: string): TAttr;
begin
  Result.Key := AKey; Result.Kind := akString; Result.SVal := AVal;
end;

function AttrInt(const AKey: string; AVal: Int64): TAttr;
begin
  Result.Key := AKey; Result.Kind := akInt; Result.IVal := AVal;
end;

function AttrFloat(const AKey: string; AVal: Double): TAttr;
begin
  Result.Key := AKey; Result.Kind := akFloat; Result.FVal := AVal;
end;

function AttrBool(const AKey: string; AVal: Boolean): TAttr;
begin
  Result.Key := AKey; Result.Kind := akBool; Result.BVal := AVal;
end;

{ TLogEvent }

procedure TLogEvent.AddAttr(const AKey: string; AKind: TAttrKind;
  const ASVal: string; AIVal: Int64; AFVal: Double; ABVal: Boolean);
var
  LIdx: Int32;
begin
  LIdx := FRec.AttrCount;
  if LIdx >= Length(FRec.Attrs) then
    SetLength(FRec.Attrs, Length(FRec.Attrs) + 8);
  FRec.Attrs[LIdx].Key := AKey;
  FRec.Attrs[LIdx].Kind := AKind;
  FRec.Attrs[LIdx].SVal := ASVal;
  FRec.Attrs[LIdx].IVal := AIVal;
  FRec.Attrs[LIdx].FVal := AFVal;
  FRec.Attrs[LIdx].BVal := ABVal;
  Inc(FRec.AttrCount);
end;

function TLogEvent.Str(const AKey, AVal: string): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akString, AVal, 0, 0, False);
  Result := @Self;
end;

function TLogEvent.Int(const AKey: string; AVal: Int64): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akInt, '', AVal, 0, False);
  Result := @Self;
end;

function TLogEvent.Float(const AKey: string; AVal: Double): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akFloat, '', 0, AVal, False);
  Result := @Self;
end;

function TLogEvent.Bool(const AKey: string; AVal: Boolean): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akBool, '', 0, 0, AVal);
  Result := @Self;
end;

function TLogEvent.Err(const AErr: string): PLogEvent;
begin
  if FEnabled then AddAttr('error', akString, AErr, 0, 0, False);
  Result := @Self;
end;

procedure TLogEvent.Msg(const AText: string);
begin
  if not FEnabled then Exit;
  FRec.Message := AText;
  FRec.TimestampNs := TInstant.Now.Elapsed.AsNanoseconds;
  FHandler.Handle(FRec);
end;

procedure TLogEvent.Send;
begin
  Msg('');
end;

{ TLogger }

var
  GEventPool: array[0..15] of TLogEvent;
  GEventIdx: Int32 = 0;

class function TLogger.New(const AHandler: ILogHandler; ALevel: TLogLevel): TLogger;
begin
  Result.FHandler := AHandler;
  Result.FLevel := ALevel;
end;

function TLogger.With_(const AKey, AVal: string): TLogger;
begin
  Result.FHandler := FHandler.WithAttrs([AttrStr(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithInt(const AKey: string; AVal: Int64): TLogger;
begin
  Result.FHandler := FHandler.WithAttrs([AttrInt(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithGroup(const AName: string): TLogger;
begin
  Result.FHandler := FHandler.WithGroup(AName);
  Result.FLevel := FLevel;
end;

function TLogger.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := (ALevel >= FLevel) and ((FHandler = nil) or FHandler.Enabled(ALevel));
end;

function TLogger.Trace: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llTrace);
  Result^.FRec.Level := llTrace;
  SetLength(Result^.FRec.Attrs, 8);
end;

function TLogger.Debug: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llDebug);
  Result^.FRec.Level := llDebug;
  SetLength(Result^.FRec.Attrs, 8);
end;

function TLogger.Info: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llInfo);
  Result^.FRec.Level := llInfo;
  SetLength(Result^.FRec.Attrs, 8);
end;

function TLogger.Warn: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llWarn);
  Result^.FRec.Level := llWarn;
  SetLength(Result^.FRec.Attrs, 8);
end;

function TLogger.Error: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llError);
  Result^.FRec.Level := llError;
  SetLength(Result^.FRec.Attrs, 8);
end;

function TLogger.Fatal: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llFatal);
  Result^.FRec.Level := llFatal;
  SetLength(Result^.FRec.Attrs, 8);
end;

{ Console Handler }

type
  TConsoleHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    FGroup: string;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(var ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TConsoleHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
end;

function TConsoleHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TConsoleHandler.Handle(var ARecord: TLogRecord);
var
  LI: Int32;
  LA: TAttr;
begin
  Write(StdErr, LEVEL_COLORS[ARecord.Level], LEVEL_NAMES[ARecord.Level], RESET, ' ');
  if ARecord.Message <> '' then
    Write(StdErr, ARecord.Message);
  // Prefix attrs (from WithAttrs)
  for LI := 0 to FPrefixCount - 1 do
  begin
    LA := FPrefix[LI];
    Write(StdErr, ' ', DIM, LA.Key, '=', RESET);
    case LA.Kind of
      akString: Write(StdErr, LA.SVal);
      akInt: Write(StdErr, LA.IVal);
      akFloat: Write(StdErr, LA.FVal:0:2);
      akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
    end;
  end;
  // Event attrs
  for LI := 0 to ARecord.AttrCount - 1 do
  begin
    LA := ARecord.Attrs[LI];
    Write(StdErr, ' ', DIM, LA.Key, '=', RESET);
    case LA.Kind of
      akString: Write(StdErr, LA.SVal);
      akInt: Write(StdErr, LA.IVal);
      akFloat: Write(StdErr, LA.FVal:0:2);
      akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
    end;
  end;
  WriteLn(StdErr);
end;

function TConsoleHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TConsoleHandler;
  LI: Int32;
begin
  LNew := TConsoleHandler.Create(FMinLevel);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TConsoleHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TConsoleHandler;
  LI: Int32;
begin
  LNew := TConsoleHandler.Create(FMinLevel);
  SetLength(LNew.FPrefix, FPrefixCount);
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  LNew.FPrefixCount := FPrefixCount;
  if FGroup <> '' then
    LNew.FGroup := FGroup + '.' + AName
  else
    LNew.FGroup := AName;
  Result := LNew;
end;

{ JSON Handler }

type
  TJsonLogHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(var ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TJsonLogHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
end;

function TJsonLogHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure WriteJsonAttr(var AFirst: Boolean; const LA: TAttr);
begin
  if not AFirst then Write(StdErr, ',');
  AFirst := False;
  Write(StdErr, '"', LA.Key, '":');
  case LA.Kind of
    akString: Write(StdErr, '"', LA.SVal, '"');
    akInt: Write(StdErr, LA.IVal);
    akFloat: Write(StdErr, LA.FVal:0:6);
    akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
  end;
end;

procedure TJsonLogHandler.Handle(var ARecord: TLogRecord);
var
  LI: Int32;
  LFirst: Boolean;
begin
  Write(StdErr, '{"level":"', LEVEL_NAMES[ARecord.Level], '"');
  if ARecord.Message <> '' then
    Write(StdErr, ',"msg":"', ARecord.Message, '"');
  Write(StdErr, ',"ts":', ARecord.TimestampNs);
  LFirst := False;
  for LI := 0 to FPrefixCount - 1 do
  begin
    Write(StdErr, ',');
    WriteJsonAttr(LFirst, FPrefix[LI]);
    LFirst := False;
  end;
  for LI := 0 to ARecord.AttrCount - 1 do
  begin
    Write(StdErr, ',');
    WriteJsonAttr(LFirst, ARecord.Attrs[LI]);
    LFirst := False;
  end;
  WriteLn(StdErr, '}');
end;

function TJsonLogHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TJsonLogHandler;
  LI: Int32;
begin
  LNew := TJsonLogHandler.Create(FMinLevel);
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TJsonLogHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self; // JSON handler doesn't nest groups for simplicity
end;

{ Factory }

function NewConsoleHandler(AMinLevel: TLogLevel): ILogHandler;
begin
  Result := TConsoleHandler.Create(AMinLevel);
end;

function NewJsonHandler(AMinLevel: TLogLevel): ILogHandler;
begin
  Result := TJsonLogHandler.Create(AMinLevel);
end;

{ Global }

var
  GDefault: TLogger;
  GDefaultInit: Boolean = False;

procedure SetDefaultLogger(const ALogger: TLogger);
begin
  GDefault := ALogger;
  GDefaultInit := True;
end;

function DefaultLogger: TLogger;
begin
  if not GDefaultInit then
  begin
    GDefault := TLogger.New(NewConsoleHandler(llInfo), llInfo);
    GDefaultInit := True;
  end;
  Result := GDefault;
end;

procedure LogTrace(const AMsg: string);
begin DefaultLogger.Trace^.Msg(AMsg); end;

procedure LogDebug(const AMsg: string);
begin DefaultLogger.Debug^.Msg(AMsg); end;

procedure LogInfo(const AMsg: string);
begin DefaultLogger.Info^.Msg(AMsg); end;

procedure LogWarn(const AMsg: string);
begin DefaultLogger.Warn^.Msg(AMsg); end;

procedure LogError(const AMsg: string);
begin DefaultLogger.Error^.Msg(AMsg); end;

end.
