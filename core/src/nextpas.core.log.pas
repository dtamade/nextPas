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
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

  {** PLogEvent points into a global ring buffer (256 slots).
   *  Event pool: 256 slots, round-robin. Safe for single-threaded use and
   *  for multi-threaded use when each log call is a single chained expression
   *  (Logger.Info^.Str('k','v')^.Msg('text')). Do NOT store PLogEvent across
   *  multiple statements or yield points. *}
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
    function WithAttrs(const AAttrs: array of TAttr): TLogger;
    function WithGroup(const AName: string): TLogger;
    function WithLevel(ALevel: TLogLevel): TLogger;
    function AsILogger: ILogger;
    procedure Flush;
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

procedure SetLogContext(ACtx: Pointer);
function GetLogContext: Pointer;

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

var
  GLogDepth: Int32 = 0; // TODO: threadvar when FPC supports threadvar initialization

procedure TLogEvent.Msg(const AText: string);
begin
  if not FEnabled then Exit;
  FEnabled := False;
  FRec.Message := AText;
  FRec.TimestampNs := TInstant.Now.Elapsed.AsNanoseconds;
  Inc(GLogDepth);
  try
    if GLogDepth > 1 then
      WriteLn(StdErr, '[REENTRANT] ', LEVEL_NAMES[FRec.Level], ' ', AText)
    else
      FHandler.Handle(FRec);
  finally
    Dec(GLogDepth);
  end;
end;

procedure TLogEvent.Send;
begin
  Msg('');
end;

{ TLogger }

var
  GEventPool: array[0..255] of TLogEvent;
  GEventIdx: Int32 = 0;

function NextEventSlot: PLogEvent; inline;
var LIdx: Int32;
begin
  LIdx := InterlockedIncrement(GEventIdx) - 1;
  Result := @GEventPool[LIdx and 255];
end;

class function TLogger.New(const AHandler: ILogHandler; ALevel: TLogLevel): TLogger;
begin
  Result.FHandler := AHandler;
  Result.FLevel := ALevel;
end;

function TLogger.With_(const AKey, AVal: string): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs([AttrStr(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithInt(const AKey: string; AVal: Int64): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs([AttrInt(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithAttrs(const AAttrs: array of TAttr): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs(AAttrs);
  Result.FLevel := FLevel;
end;

function TLogger.WithGroup(const AName: string): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithGroup(AName);
  Result.FLevel := FLevel;
end;

function TLogger.WithLevel(ALevel: TLogLevel): TLogger;
begin
  Result.FHandler := FHandler;
  Result.FLevel := ALevel;
end;

procedure TLogger.Flush;
begin
  if FHandler <> nil then
    FHandler.Flush;
end;

function TLogger.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := (FHandler <> nil) and (ALevel >= FLevel) and FHandler.Enabled(ALevel);
end;

function TLogger.Trace: PLogEvent;
begin
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llTrace);
  Result^.FRec.Level := llTrace;
end;

function TLogger.Debug: PLogEvent;
begin
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llDebug);
  Result^.FRec.Level := llDebug;
end;

function TLogger.Info: PLogEvent;
begin
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llInfo);
  Result^.FRec.Level := llInfo;
end;

function TLogger.Warn: PLogEvent;
begin
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llWarn);
  Result^.FRec.Level := llWarn;
end;

function TLogger.Error: PLogEvent;
begin
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := FHandler;
  Result^.FEnabled := Enabled(llError);
  Result^.FRec.Level := llError;
end;

function TLogger.Fatal: PLogEvent;
begin
  Result := NextEventSlot;
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
    FLock: TRTLCriticalSection;
  public
    constructor Create(AMinLevel: TLogLevel);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TConsoleHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
  InitCriticalSection(FLock);
end;

destructor TConsoleHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TConsoleHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TConsoleHandler.Handle(const ARecord: TLogRecord);
var
  LI: Int32;
  LA: TAttr;
  LKeyPrefix: string;
begin
  EnterCriticalSection(FLock);
  try
    if FGroup <> '' then LKeyPrefix := FGroup + '.' else LKeyPrefix := '';
    Write(StdErr, LEVEL_COLORS[ARecord.Level], LEVEL_NAMES[ARecord.Level], RESET, ' ');
    if ARecord.Message <> '' then
      Write(StdErr, ARecord.Message);
    for LI := 0 to FPrefixCount - 1 do
    begin
      LA := FPrefix[LI];
      Write(StdErr, ' ', DIM, LKeyPrefix, LA.Key, '=', RESET);
      case LA.Kind of
        akString: Write(StdErr, LA.SVal);
        akInt: Write(StdErr, LA.IVal);
        akFloat: Write(StdErr, LA.FVal:0:2);
        akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
      end;
    end;
    for LI := 0 to ARecord.AttrCount - 1 do
    begin
      LA := ARecord.Attrs[LI];
      Write(StdErr, ' ', DIM, LKeyPrefix, LA.Key, '=', RESET);
      case LA.Kind of
        akString: Write(StdErr, LA.SVal);
        akInt: Write(StdErr, LA.IVal);
        akFloat: Write(StdErr, LA.FVal:0:2);
        akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
      end;
    end;
    WriteLn(StdErr);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TConsoleHandler.Flush;
begin
  System.Flush(StdErr);
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
    FGroup: string;
    FLock: TRTLCriticalSection;
  public
    constructor Create(AMinLevel: TLogLevel);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TJsonLogHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
  InitCriticalSection(FLock);
end;

destructor TJsonLogHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TJsonLogHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure WriteJsonStr(const AStr: string);
var
  LI: Int32;
  LCh: Char;
  LBuf: string;
begin
  LBuf := '"';
  for LI := 1 to Length(AStr) do
  begin
    LCh := AStr[LI];
    case LCh of
      '"': LBuf := LBuf + '\"';
      '\': LBuf := LBuf + '\\';
      #8: LBuf := LBuf + '\b';
      #9: LBuf := LBuf + '\t';
      #10: LBuf := LBuf + '\n';
      #12: LBuf := LBuf + '\f';
      #13: LBuf := LBuf + '\r';
    else
      if LCh < #32 then
        LBuf := LBuf + '\u00' + HexStr(Ord(LCh), 2)
      else
        LBuf := LBuf + LCh;
    end;
  end;
  LBuf := LBuf + '"';
  Write(StdErr, LBuf);
end;

procedure WriteJsonAttr(var AFirst: Boolean; const AGroup: string; const LA: TAttr);
var LKey: string;
begin
  if not AFirst then Write(StdErr, ',');
  AFirst := False;
  if AGroup <> '' then LKey := AGroup + '.' + LA.Key else LKey := LA.Key;
  WriteJsonStr(LKey);
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
  EnterCriticalSection(FLock);
  try
    Write(StdErr, '{"level":"', LEVEL_NAMES[ARecord.Level], '"');
    if ARecord.Message <> '' then
    begin
      Write(StdErr, ',"msg":');
      WriteJsonStr(ARecord.Message);
    end;
    Write(StdErr, ',"ts":', ARecord.TimestampNs);
    LFirst := False;
    for LI := 0 to FPrefixCount - 1 do
      WriteJsonAttr(LFirst, FGroup, FPrefix[LI]);
    for LI := 0 to ARecord.AttrCount - 1 do
      WriteJsonAttr(LFirst, FGroup, ARecord.Attrs[LI]);
    WriteLn(StdErr, '}');
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TJsonLogHandler.Flush;
begin
  System.Flush(StdErr);
end;

function TJsonLogHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TJsonLogHandler;
  LI: Int32;
begin
  LNew := TJsonLogHandler.Create(FMinLevel);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TJsonLogHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TJsonLogHandler;
  LI: Int32;
begin
  LNew := TJsonLogHandler.Create(FMinLevel);
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
  GDefaultInit: Int32 = 0; { 0=not init, 1=init }
  GDefaultLock: TRTLCriticalSection;
  GLogContext: Pointer = nil;

procedure SetLogContext(ACtx: Pointer);
begin
  GLogContext := ACtx;
end;

function GetLogContext: Pointer;
begin
  Result := GLogContext;
end;

procedure SetDefaultLogger(const ALogger: TLogger);
begin
  EnterCriticalSection(GDefaultLock);
  try
    GDefault := ALogger;
    GDefaultInit := 1;
  finally
    LeaveCriticalSection(GDefaultLock);
  end;
end;

function DefaultLogger: TLogger;
begin
  if InterlockedCompareExchange(GDefaultInit, GDefaultInit, 1) <> 1 then
  begin
    EnterCriticalSection(GDefaultLock);
    try
      if GDefaultInit = 0 then
      begin
        GDefault := TLogger.New(NewConsoleHandler(llInfo), llInfo);
        GDefaultInit := 1;
      end;
    finally
      LeaveCriticalSection(GDefaultLock);
    end;
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
    FBroken: Boolean;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    FGroup: string;
    FLock: TRTLCriticalSection;
    procedure EnsureOpen;
    procedure Rotate;
  public
    constructor Create(const APath: string; AMinLevel: TLogLevel;
      AMaxBytes: Int64; AMaxFiles: Int32);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
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
  InitCriticalSection(FLock);
end;

destructor TFileHandler.Destroy;
begin
  if FOpened then
    System.Close(FFile);
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TFileHandler.EnsureOpen;
begin
  if FBroken or FOpened then Exit;
  try
    AssignFile(FFile, FPath);
    if FileExists(FPath) then
      Append(FFile)
    else
      Rewrite(FFile);
    FOpened := True;
  except
    on E: Exception do
    begin
      FBroken := True;
      WriteLn(StdErr, '[LOG] FileHandler broken: ', E.Message);
    end;
  end;
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
  LSize: Int64;
  LKeyPrefix: string;
begin
  if FBroken then Exit;
  EnterCriticalSection(FLock);
  try
    if FBroken then Exit;
    try
      if FCurrentSize >= FMaxBytes then Rotate;
      EnsureOpen;
      if not FOpened then Exit;
      if FGroup <> '' then LKeyPrefix := FGroup + '.' else LKeyPrefix := '';
      LSize := Int64(Length(LEVEL_NAMES[ARecord.Level])) + 1 + Int64(Length(ARecord.Message));
      Write(FFile, LEVEL_NAMES[ARecord.Level], ' ', ARecord.Message);
      for LI := 0 to FPrefixCount - 1 do
      begin
        Write(FFile, ' ', LKeyPrefix, FPrefix[LI].Key, '=');
        LSize += 2 + Int64(Length(LKeyPrefix)) + Int64(Length(FPrefix[LI].Key));
        case FPrefix[LI].Kind of
          akString: begin Write(FFile, FPrefix[LI].SVal); LSize += Int64(Length(FPrefix[LI].SVal)); end;
          akInt: begin Write(FFile, FPrefix[LI].IVal); LSize += 12; end;
          akFloat: begin Write(FFile, FPrefix[LI].FVal:0:2); LSize += 10; end;
          akBool: if FPrefix[LI].BVal then begin Write(FFile, 'true'); LSize += 4; end
                  else begin Write(FFile, 'false'); LSize += 5; end;
        end;
      end;
      for LI := 0 to ARecord.AttrCount - 1 do
      begin
        Write(FFile, ' ', LKeyPrefix, ARecord.Attrs[LI].Key, '=');
        LSize += 2 + Int64(Length(LKeyPrefix)) + Int64(Length(ARecord.Attrs[LI].Key));
        case ARecord.Attrs[LI].Kind of
          akString: begin Write(FFile, ARecord.Attrs[LI].SVal); LSize += Int64(Length(ARecord.Attrs[LI].SVal)); end;
          akInt: begin Write(FFile, ARecord.Attrs[LI].IVal); LSize += 12; end;
          akFloat: begin Write(FFile, ARecord.Attrs[LI].FVal:0:2); LSize += 10; end;
          akBool: if ARecord.Attrs[LI].BVal then begin Write(FFile, 'true'); LSize += 4; end
                  else begin Write(FFile, 'false'); LSize += 5; end;
        end;
      end;
      WriteLn(FFile);
      System.Flush(FFile);
      Inc(FCurrentSize, LSize + 1);
    except
      on E: Exception do
      begin
        FBroken := True;
        if FOpened then begin System.Close(FFile); FOpened := False; end;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFileHandler.Flush;
begin
  if FOpened then System.Flush(FFile);
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
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TFileHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TFileHandler;
  LI: Int32;
begin
  LNew := TFileHandler.Create(FPath, FMinLevel, FMaxBytes, FMaxFiles);
  SetLength(LNew.FPrefix, FPrefixCount);
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  LNew.FPrefixCount := FPrefixCount;
  if FGroup <> '' then
    LNew.FGroup := FGroup + '.' + AName
  else
    LNew.FGroup := AName;
  Result := LNew;
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
    FLock: TRTLCriticalSection;
  public
    constructor Create(const AHandlers: array of ILogHandler);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
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
  InitCriticalSection(FLock);
end;

destructor TMultiHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
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
  EnterCriticalSection(FLock);
  try
    for LI := 0 to FCount - 1 do
      if FHandlers[LI].Enabled(ARecord.Level) then
        FHandlers[LI].Handle(ARecord);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TMultiHandler.Flush;
var LI: Int32;
begin
  for LI := 0 to FCount - 1 do FHandlers[LI].Flush;
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

{ TLoggerAdapter — bridges TLogger to ILogger interface }

type
  TLoggerAdapter = class(TInterfacedObject, ILogger)
  private
    FLogger: TLogger;
  public
    constructor Create(const ALogger: TLogger);
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

constructor TLoggerAdapter.Create(const ALogger: TLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

procedure TLoggerAdapter.Log(const ALevel: TLogLevel; const AMessage: string);
begin
  case ALevel of
    llTrace: FLogger.Trace^.Msg(AMessage);
    llDebug: FLogger.Debug^.Msg(AMessage);
    llInfo: FLogger.Info^.Msg(AMessage);
    llWarn: FLogger.Warn^.Msg(AMessage);
    llError: FLogger.Error^.Msg(AMessage);
    llFatal: FLogger.Fatal^.Msg(AMessage);
  end;
end;

procedure TLoggerAdapter.Trace(const AMessage: string);
begin FLogger.Trace^.Msg(AMessage); end;

procedure TLoggerAdapter.Debug(const AMessage: string);
begin FLogger.Debug^.Msg(AMessage); end;

procedure TLoggerAdapter.Info(const AMessage: string);
begin FLogger.Info^.Msg(AMessage); end;

procedure TLoggerAdapter.Warn(const AMessage: string);
begin FLogger.Warn^.Msg(AMessage); end;

procedure TLoggerAdapter.Error(const AMessage: string);
begin FLogger.Error^.Msg(AMessage); end;

procedure TLoggerAdapter.Fatal(const AMessage: string);
begin FLogger.Fatal^.Msg(AMessage); end;

function TLogger.AsILogger: ILogger;
begin
  Result := TLoggerAdapter.Create(Self);
end;

var
  GFinI: Int32;

initialization
  InitCriticalSection(GDefaultLock);

finalization
  for GFinI := 0 to High(GEventPool) do
    Finalize(GEventPool[GFinI]);
  DoneCriticalSection(GDefaultLock);

end.
