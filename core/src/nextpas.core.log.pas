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
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

  {** PLogEvent points into a global ring buffer (16 slots).
   *  MUST be used immediately in a single chain: Logger.Info^.Str(...)^.Msg(...)
   *  Do NOT store PLogEvent across multiple statements or log calls. *}
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
function NewFileHandler(const APath: string; AMinLevel: TLogLevel = llDebug;
  AMaxBytes: Int64 = 10 * 1024 * 1024; AMaxFiles: Int32 = 5): ILogHandler;
function NewMultiHandler(const AHandlers: array of ILogHandler): ILogHandler;

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
  FEnabled := False;
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
  GEventIdx: UInt32 = 0;

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
  Result := (FHandler <> nil) and (ALevel >= FLevel) and FHandler.Enabled(ALevel);
end;

function TLogger.Trace: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llTrace);
  Result^.FRec.Level := llTrace;
end;

function TLogger.Debug: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llDebug);
  Result^.FRec.Level := llDebug;
end;

function TLogger.Info: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llInfo);
  Result^.FRec.Level := llInfo;
end;

function TLogger.Warn: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llWarn);
  Result^.FRec.Level := llWarn;
end;

function TLogger.Error: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llError);
  Result^.FRec.Level := llError;
end;

function TLogger.Fatal: PLogEvent;
begin
  Result := @GEventPool[GEventIdx and 15];
  Inc(GEventIdx);
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llFatal);
  Result^.FRec.Level := llFatal;
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
    procedure Handle(const ARecord: TLogRecord);
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

procedure TConsoleHandler.Handle(const ARecord: TLogRecord);
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
    procedure Handle(const ARecord: TLogRecord);
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

procedure WriteJsonStr(const AStr: string);
var
  LI: Int32;
  LCh: Char;
begin
  Write(StdErr, '"');
  for LI := 1 to Length(AStr) do
  begin
    LCh := AStr[LI];
    case LCh of
      '"': Write(StdErr, '\"');
      '\': Write(StdErr, '\\');
      #8: Write(StdErr, '\b');
      #9: Write(StdErr, '\t');
      #10: Write(StdErr, '\n');
      #12: Write(StdErr, '\f');
      #13: Write(StdErr, '\r');
    else
      if LCh < #32 then
        Write(StdErr, '\u00', HexStr(Ord(LCh), 2))
      else
        Write(StdErr, LCh);
    end;
  end;
  Write(StdErr, '"');
end;

procedure WriteJsonAttr(var AFirst: Boolean; const LA: TAttr);
begin
  if not AFirst then Write(StdErr, ',');
  AFirst := False;
  WriteJsonStr(LA.Key);
  Write(StdErr, ':');
  case LA.Kind of
    akString: WriteJsonStr(LA.SVal);
    akInt: Write(StdErr, LA.IVal);
    akFloat: Write(StdErr, LA.FVal:0:6);
    akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
  end;
end;

procedure TJsonLogHandler.Handle(const ARecord: TLogRecord);
var
  LI: Int32;
  LFirst: Boolean;
begin
  Write(StdErr, '{"level":"', LEVEL_NAMES[ARecord.Level], '"');
  if ARecord.Message <> '' then
  begin
    Write(StdErr, ',"msg":');
    WriteJsonStr(ARecord.Message);
  end;
  Write(StdErr, ',"ts":', ARecord.TimestampNs);
  LFirst := False;
  for LI := 0 to FPrefixCount - 1 do
    WriteJsonAttr(LFirst, FPrefix[LI]);
  for LI := 0 to ARecord.AttrCount - 1 do
    WriteJsonAttr(LFirst, ARecord.Attrs[LI]);
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

{ TFileHandler }

type
  TFileHandler = class(TInterfacedObject, ILogHandler)
  private
    FPath: string;
    FMinLevel: TLogLevel;
    FMaxBytes: Int64;
    FMaxFiles: Int32;
    FFile: TextFile;
    FCurrentSize: Int64;
    FOpened: Boolean;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    procedure EnsureOpen;
    procedure Rotate;
  public
    constructor Create(const APath: string; AMinLevel: TLogLevel;
      AMaxBytes: Int64; AMaxFiles: Int32);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TFileHandler.Create(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32);
begin
  inherited Create;
  FPath := APath;
  FMinLevel := AMinLevel;
  FMaxBytes := AMaxBytes;
  FMaxFiles := AMaxFiles;
  FOpened := False;
  FCurrentSize := 0;
  FPrefixCount := 0;
end;

destructor TFileHandler.Destroy;
begin
  if FOpened then
    System.Close(FFile);
  inherited;
end;

procedure TFileHandler.EnsureOpen;
begin
  if FOpened then Exit;
  AssignFile(FFile, FPath);
  if FileExists(FPath) then
    Append(FFile)
  else
    Rewrite(FFile);
  FOpened := True;
end;

procedure TFileHandler.Rotate;
var
  LI: Int32;
  LSrc, LDst: string;
begin
  if FOpened then
  begin
    System.Close(FFile);
    FOpened := False;
  end;
  LDst := FPath + '.' + IntToStr(FMaxFiles);
  if FileExists(LDst) then DeleteFile(LDst);
  for LI := FMaxFiles - 1 downto 1 do
  begin
    LSrc := FPath + '.' + IntToStr(LI);
    LDst := FPath + '.' + IntToStr(LI + 1);
    if FileExists(LSrc) then RenameFile(LSrc, LDst);
  end;
  if FileExists(FPath) then RenameFile(FPath, FPath + '.1');
  FCurrentSize := 0;
end;

function TFileHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TFileHandler.Handle(const ARecord: TLogRecord);
var
  LI: Int32;
begin
  if FCurrentSize >= FMaxBytes then Rotate;
  EnsureOpen;
  Write(FFile, LEVEL_NAMES[ARecord.Level], ' ', ARecord.Message);
  for LI := 0 to FPrefixCount - 1 do
  begin
    Write(FFile, ' ', FPrefix[LI].Key, '=');
    case FPrefix[LI].Kind of
      akString: Write(FFile, FPrefix[LI].SVal);
      akInt: Write(FFile, FPrefix[LI].IVal);
      akFloat: Write(FFile, FPrefix[LI].FVal:0:2);
      akBool: if FPrefix[LI].BVal then Write(FFile, 'true') else Write(FFile, 'false');
    end;
  end;
  for LI := 0 to ARecord.AttrCount - 1 do
  begin
    Write(FFile, ' ', ARecord.Attrs[LI].Key, '=');
    case ARecord.Attrs[LI].Kind of
      akString: Write(FFile, ARecord.Attrs[LI].SVal);
      akInt: Write(FFile, ARecord.Attrs[LI].IVal);
      akFloat: Write(FFile, ARecord.Attrs[LI].FVal:0:2);
      akBool: if ARecord.Attrs[LI].BVal then Write(FFile, 'true') else Write(FFile, 'false');
    end;
  end;
  WriteLn(FFile);
  System.Flush(FFile);
  Inc(FCurrentSize, Int64(Length(ARecord.Message)) + Int64(ARecord.AttrCount + FPrefixCount) * 20 + 10);
end;

function TFileHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TFileHandler;
  LI: Int32;
begin
  // Note: child shares same path but opens independently (append mode).
  // Rotation tracking is per-instance. For production use with child loggers,
  // prefer MultiHandler with a single FileHandler + ConsoleHandler for children.
  LNew := TFileHandler.Create(FPath, FMinLevel, FMaxBytes, FMaxFiles);
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TFileHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

function NewFileHandler(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32): ILogHandler;
begin
  Result := TFileHandler.Create(APath, AMinLevel, AMaxBytes, AMaxFiles);
end;

{ TMultiHandler }

type
  TMultiHandler = class(TInterfacedObject, ILogHandler)
  private
    FHandlers: array of ILogHandler;
    FCount: Int32;
  public
    constructor Create(const AHandlers: array of ILogHandler);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TMultiHandler.Create(const AHandlers: array of ILogHandler);
var LI: Int32;
begin
  inherited Create;
  FCount := Length(AHandlers);
  SetLength(FHandlers, FCount);
  for LI := 0 to FCount - 1 do FHandlers[LI] := AHandlers[LI];
end;

function TMultiHandler.Enabled(const ALevel: TLogLevel): Boolean;
var LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FHandlers[LI].Enabled(ALevel) then begin Result := True; Exit; end;
  Result := False;
end;

procedure TMultiHandler.Handle(const ARecord: TLogRecord);
var LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FHandlers[LI].Enabled(ARecord.Level) then
      FHandlers[LI].Handle(ARecord);
end;

function TMultiHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var LNew: array of ILogHandler; LI: Int32;
begin
  SetLength(LNew, FCount);
  for LI := 0 to FCount - 1 do LNew[LI] := FHandlers[LI].WithAttrs(AAttrs);
  Result := TMultiHandler.Create(LNew);
end;

function TMultiHandler.WithGroup(const AName: string): ILogHandler;
var LNew: array of ILogHandler; LI: Int32;
begin
  SetLength(LNew, FCount);
  for LI := 0 to FCount - 1 do LNew[LI] := FHandlers[LI].WithGroup(AName);
  Result := TMultiHandler.Create(LNew);
end;

function NewMultiHandler(const AHandlers: array of ILogHandler): ILogHandler;
begin
  Result := TMultiHandler.Create(AHandlers);
end;

end.
