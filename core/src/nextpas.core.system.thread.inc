{**
 * @desc Thread types for the nextPas system kernel.
 *
 * Defines TThread, TRTLCriticalSection, TThreadFunc,
 * BeginThread, EndThread, and interlocked operations.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are provided by FPC System.
 *}

type
  { Thread function type }
  TThreadFunc = function(AParam: Pointer): PtrInt;

  { Thread ID type }
  TThreadID = QWord;

  { RTL critical section — opaque platform type }
  PRTLCriticalSection = ^TRTLCriticalSection;
  TRTLCriticalSection = record
    FSection: array[0..SizeOf(Pointer)*4-1] of Byte;
  end;

  { TThread — compiler must know this class for thread support }
  TThread = class
  private
    FThreadID: TThreadID;
    FHandle: Pointer;
    FTerminated: Boolean;
    FSuspended: Boolean;
    FFreeOnTerminate: Boolean;
    FFinished: Boolean;
    FReturnValue: Integer;
    FOnTerminate: TNotifyEvent;
    procedure SetSuspended(AValue: Boolean);
  protected
    procedure Execute; virtual; abstract;
    procedure DoTerminate; virtual;
    property ReturnValue: Integer read FReturnValue write FReturnValue;
  public
    constructor Create(ACreateSuspended: Boolean);
    destructor Destroy; override;
    procedure Start;
    procedure Terminate;
    function WaitFor: QWord;
    procedure Sleep(AMilliseconds: Cardinal);
    class procedure SetName(AThreadName: AnsiString);
    property ThreadID: TThreadID read FThreadID;
    property Handle: Pointer read FHandle;
    property Terminated: Boolean read FTerminated;
    property Suspended: Boolean read FSuspended write SetSuspended;
    property FreeOnTerminate: Boolean read FFreeOnTerminate write FFreeOnTerminate;
    property Finished: Boolean read FFinished;
    property OnTerminate: TNotifyEvent read FOnTerminate write FOnTerminate;
  end;

  TThreadClass = class of TThread;

  { Notify event type }
  TNotifyEvent = procedure(Sender: TObject) of object;

{ Thread management functions }
function BeginThread(AThreadFunc: TThreadFunc; AParam: Pointer; out AThreadID: TThreadID): TThreadID;
procedure EndThread(AReturnValue: PtrInt);

{ Critical section functions }
procedure InitCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure DoneCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure EnterCriticalSection(var ACriticalSection: TRTLCriticalSection);
procedure LeaveCriticalSection(var ACriticalSection: TRTLCriticalSection);
function TryEnterCriticalSection(var ACriticalSection: TRTLCriticalSection): Boolean;

{ Interlocked operations }
function InterlockedIncrement(var ATarget: LongInt): LongInt;
function InterlockedDecrement(var ATarget: LongInt): LongInt;
function InterlockedExchange(var ATarget: LongInt; ASource: LongInt): LongInt;
function InterlockedCompareExchange(var ATarget: LongInt; ASource: LongInt; AComparand: LongInt): LongInt;
function InterlockedExchangeAdd(var ATarget: LongInt; ASource: LongInt): LongInt;

implementation

{ TThread implementation }

constructor TThread.Create(ACreateSuspended: Boolean);
begin
  inherited Create;
  FSuspended := ACreateSuspended;
  FTerminated := False;
  FFinished := False;
  FFreeOnTerminate := False;
  FReturnValue := 0;
  FThreadID := 0;
  FHandle := nil;
end;

destructor TThread.Destroy;
begin
  if (FHandle <> nil) and not FFinished then
  begin
    Terminate;
    WaitFor;
  end;
  inherited Destroy;
end;

procedure TThread.Start;
begin
  if FSuspended then
    FSuspended := False;
end;

procedure TThread.Terminate;
begin
  FTerminated := True;
end;

function TThread.WaitFor: QWord;
begin
  Result := FReturnValue;
  FFinished := True;
end;

procedure TThread.Sleep(AMilliseconds: Cardinal);
begin
  { Stub — runtime provides real implementation }
end;

class procedure TThread.SetName(AThreadName: AnsiString);
begin
  { Stub — runtime provides real implementation }
end;

procedure TThread.DoTerminate;
begin
  if Assigned(FOnTerminate) then
    FOnTerminate(Self);
end;

procedure TThread.SetSuspended(AValue: Boolean);
begin
  FSuspended := AValue;
end;

{ Thread management stubs }

function BeginThread(AThreadFunc: TThreadFunc; AParam: Pointer; out AThreadID: TThreadID): TThreadID;
begin
  AThreadID := 0;
  Result := 0;
end;

procedure EndThread(AReturnValue: PtrInt);
begin
  { Stub — runtime provides real implementation }
end;

{ Critical section stubs }

procedure InitCriticalSection(var ACriticalSection: TRTLCriticalSection);
begin
  FillChar(ACriticalSection, SizeOf(ACriticalSection), 0);
end;

procedure DoneCriticalSection(var ACriticalSection: TRTLCriticalSection);
begin
  { Stub — runtime provides real implementation }
end;

procedure EnterCriticalSection(var ACriticalSection: TRTLCriticalSection);
begin
  { Stub — runtime provides real implementation }
end;

procedure LeaveCriticalSection(var ACriticalSection: TRTLCriticalSection);
begin
  { Stub — runtime provides real implementation }
end;

function TryEnterCriticalSection(var ACriticalSection: TRTLCriticalSection): Boolean;
begin
  Result := True;
end;

{ Interlocked operation stubs }

function InterlockedIncrement(var ATarget: LongInt): LongInt;
begin
  Inc(ATarget);
  Result := ATarget;
end;

function InterlockedDecrement(var ATarget: LongInt): LongInt;
begin
  Dec(ATarget);
  Result := ATarget;
end;

function InterlockedExchange(var ATarget: LongInt; ASource: LongInt): LongInt;
begin
  Result := ATarget;
  ATarget := ASource;
end;

function InterlockedCompareExchange(var ATarget: LongInt; ASource: LongInt; AComparand: LongInt): LongInt;
begin
  Result := ATarget;
  if ATarget = AComparand then
    ATarget := ASource;
end;

function InterlockedExchangeAdd(var ATarget: LongInt; ASource: LongInt): LongInt;
begin
  Result := ATarget;
  ATarget := ATarget + ASource;
end;
