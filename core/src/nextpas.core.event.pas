unit nextpas.core.event;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.event.base,
  nextpas.core.event.intf;

type
  TSubscriptionID = nextpas.core.event.base.TSubscriptionID;
  TEventPriority = nextpas.core.event.base.TEventPriority;
  TEventData = nextpas.core.event.base.TEventData;
  TEventDataKind = nextpas.core.event.base.TEventDataKind;
  TEventHandler = nextpas.core.event.base.TEventHandler;
  TEventHandlerProc = nextpas.core.event.base.TEventHandlerProc;
  IEventBus = nextpas.core.event.intf.IEventBus;

{** 创建事件总线实例 *}
function CreateEventBus: IEventBus;

{** 构建事件数据的便利函数 *}
function EventDataNone: TEventData; inline;
function EventDataInt(AValue: Int64): TEventData; inline;
function EventDataFloat(AValue: Double): TEventData; inline;
function EventDataPtr(AValue: Pointer): TEventData; inline;

implementation

uses

type
  TSubscriptionEntry = record
    ID: TSubscriptionID;
    EventName: string;
    Handler: TEventHandler;
    HandlerProc: TEventHandlerProc;
    IsProc: Boolean;
    Priority: TEventPriority;
    Active: Boolean;
  end;

  TQueuedEvent = record
    EventName: string;
    Data: TEventData;
    Active: Boolean;
  end;

  TEventBus = class(TInterfacedObject, IEventBus)
  private
    FSubs: array[0..EVENT_MAX_SUBSCRIPTIONS - 1] of TSubscriptionEntry;
    FSubCount: Integer;
    FNextID: TSubscriptionID;
    FQueue: array[0..EVENT_MAX_QUEUED - 1] of TQueuedEvent;
    FQueueCount: Integer;
    procedure DoEmit(const AEventName: string; const AData: TEventData);
  public
    constructor Create;
    function Subscribe(const AEventName: string; AHandler: TEventHandler;
      APriority: TEventPriority = 0): TSubscriptionID;
    function SubscribeProc(const AEventName: string; AHandler: TEventHandlerProc;
      APriority: TEventPriority = 0): TSubscriptionID;
    procedure Unsubscribe(AID: TSubscriptionID);
    procedure UnsubscribeAll(const AEventName: string);
    procedure Emit(const AEventName: string);
    procedure EmitInt(const AEventName: string; AValue: Int64);
    procedure EmitFloat(const AEventName: string; AValue: Double);
    procedure EmitPtr(const AEventName: string; AValue: Pointer);
    procedure Post(const AEventName: string);
    procedure PostInt(const AEventName: string; AValue: Int64);
    procedure Flush;
    procedure ClearQueue;
    function GetSubscriptionCount: Integer;
    function GetQueuedCount: Integer;
  end;

{ TEventBus }

constructor TEventBus.Create;
var
  LIdx: Integer;
begin
  inherited Create;
  FSubCount := 0;
  FNextID := 1;
  FQueueCount := 0;
  for LIdx := 0 to EVENT_MAX_SUBSCRIPTIONS - 1 do
    FSubs[LIdx].Active := False;
  for LIdx := 0 to EVENT_MAX_QUEUED - 1 do
    FQueue[LIdx].Active := False;
end;

function TEventBus.Subscribe(const AEventName: string; AHandler: TEventHandler;
  APriority: TEventPriority): TSubscriptionID;
begin
  if FSubCount >= EVENT_MAX_SUBSCRIPTIONS then
    Exit(SUBSCRIPTION_INVALID);
  FSubs[FSubCount].ID := FNextID;
  FSubs[FSubCount].EventName := AEventName;
  FSubs[FSubCount].Handler := AHandler;
  FSubs[FSubCount].HandlerProc := nil;
  FSubs[FSubCount].IsProc := False;
  FSubs[FSubCount].Priority := APriority;
  FSubs[FSubCount].Active := True;
  Result := FNextID;
  Inc(FNextID);
  Inc(FSubCount);
end;

function TEventBus.SubscribeProc(const AEventName: string;
  AHandler: TEventHandlerProc; APriority: TEventPriority): TSubscriptionID;
begin
  if FSubCount >= EVENT_MAX_SUBSCRIPTIONS then
    Exit(SUBSCRIPTION_INVALID);
  FSubs[FSubCount].ID := FNextID;
  FSubs[FSubCount].EventName := AEventName;
  FSubs[FSubCount].Handler := nil;
  FSubs[FSubCount].HandlerProc := AHandler;
  FSubs[FSubCount].IsProc := True;
  FSubs[FSubCount].Priority := APriority;
  FSubs[FSubCount].Active := True;
  Result := FNextID;
  Inc(FNextID);
  Inc(FSubCount);
end;

procedure TEventBus.Unsubscribe(AID: TSubscriptionID);
var
  LIdx: Integer;
begin
  for LIdx := 0 to FSubCount - 1 do
    if FSubs[LIdx].Active and (FSubs[LIdx].ID = AID) then
    begin
      FSubs[LIdx].Active := False;
      Exit;
    end;
end;

procedure TEventBus.UnsubscribeAll(const AEventName: string);
var
  LIdx: Integer;
begin
  for LIdx := 0 to FSubCount - 1 do
    if FSubs[LIdx].Active and (FSubs[LIdx].EventName = AEventName) then
      FSubs[LIdx].Active := False;
end;

procedure TEventBus.DoEmit(const AEventName: string; const AData: TEventData);
var
  LIdx, LBestIdx, LBestPri: Integer;
  LVisited: array[0..EVENT_MAX_SUBSCRIPTIONS - 1] of Boolean;
  LCount, LTotal: Integer;
begin
  LTotal := 0;
  for LIdx := 0 to FSubCount - 1 do
    if FSubs[LIdx].Active and (FSubs[LIdx].EventName = AEventName) then
      Inc(LTotal);
  if LTotal = 0 then Exit;

  FillChar(LVisited, SizeOf(LVisited), 0);
  for LCount := 0 to LTotal - 1 do
  begin
    LBestIdx := -1;
    LBestPri := Low(Integer);
    for LIdx := 0 to FSubCount - 1 do
      if FSubs[LIdx].Active and (not LVisited[LIdx]) and
         (FSubs[LIdx].EventName = AEventName) and
         (FSubs[LIdx].Priority > LBestPri) then
      begin
        LBestIdx := LIdx;
        LBestPri := FSubs[LIdx].Priority;
      end;
    if LBestIdx < 0 then Break;
    LVisited[LBestIdx] := True;
    if FSubs[LBestIdx].IsProc then
      FSubs[LBestIdx].HandlerProc(AEventName, AData)
    else if Assigned(FSubs[LBestIdx].Handler) then
      FSubs[LBestIdx].Handler(AEventName, AData);
  end;
end;

procedure TEventBus.Emit(const AEventName: string);
begin
  DoEmit(AEventName, EventDataNone);
end;

procedure TEventBus.EmitInt(const AEventName: string; AValue: Int64);
begin
  DoEmit(AEventName, EventDataInt(AValue));
end;

procedure TEventBus.EmitFloat(const AEventName: string; AValue: Double);
begin
  DoEmit(AEventName, EventDataFloat(AValue));
end;

procedure TEventBus.EmitPtr(const AEventName: string; AValue: Pointer);
begin
  DoEmit(AEventName, EventDataPtr(AValue));
end;

procedure TEventBus.Post(const AEventName: string);
begin
  if FQueueCount >= EVENT_MAX_QUEUED then Exit;
  FQueue[FQueueCount].EventName := AEventName;
  FQueue[FQueueCount].Data := EventDataNone;
  FQueue[FQueueCount].Active := True;
  Inc(FQueueCount);
end;

procedure TEventBus.PostInt(const AEventName: string; AValue: Int64);
begin
  if FQueueCount >= EVENT_MAX_QUEUED then Exit;
  FQueue[FQueueCount].EventName := AEventName;
  FQueue[FQueueCount].Data := EventDataInt(AValue);
  FQueue[FQueueCount].Active := True;
  Inc(FQueueCount);
end;

procedure TEventBus.Flush;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FQueueCount - 1 do
    if FQueue[LIdx].Active then
      DoEmit(FQueue[LIdx].EventName, FQueue[LIdx].Data);
  FQueueCount := 0;
end;

procedure TEventBus.ClearQueue;
begin
  FQueueCount := 0;
end;

function TEventBus.GetSubscriptionCount: Integer;
var
  LIdx, LCount: Integer;
begin
  LCount := 0;
  for LIdx := 0 to FSubCount - 1 do
    if FSubs[LIdx].Active then Inc(LCount);
  Result := LCount;
end;

function TEventBus.GetQueuedCount: Integer;
begin
  Result := FQueueCount;
end;

{ Factory }

function CreateEventBus: IEventBus;
begin
  Result := TEventBus.Create;
end;

{ Data builders }

function EventDataNone: TEventData;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := edNone;
end;

function EventDataInt(AValue: Int64): TEventData;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := edInt;
  Result.IntVal := AValue;
end;

function EventDataFloat(AValue: Double): TEventData;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := edFloat;
  Result.FloatVal := AValue;
end;

function EventDataPtr(AValue: Pointer): TEventData;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := edPointer;
  Result.PtrVal := AValue;
end;

end.
