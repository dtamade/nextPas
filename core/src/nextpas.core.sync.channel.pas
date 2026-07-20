unit nextpas.core.sync.channel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf,
  nextpas.core.time.base;

function CreateChannel(const ACapacity: SizeInt): IChannel;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.sync.mutex,
  nextpas.core.sync.condvar;

type
  TChannel = class(TInterfacedObject, IChannel)
  private
    FMutex: INativeMutex;
    FNotEmpty: ICondVar;
    FNotFull: ICondVar;
    FBuf: array of Pointer;
    FCap: SizeInt;
    FLen: SizeInt;
    FHead: SizeInt;
    FTail: SizeInt;
    FClosed: Boolean;
    procedure PushUnlocked(AItem: Pointer);
    function PopUnlocked(out AItem: Pointer): Boolean;
  public
    constructor Create(const ACapacity: SizeInt);
    function TrySend(AItem: Pointer): TChannelSendResult;
    function Send(AItem: Pointer): Boolean;
    function TryRecv(out AItem: Pointer): TChannelRecvResult;
    function Recv(out AItem: Pointer): Boolean;
    function SendTimeout(AItem: Pointer; const ATimeoutNs: Int64): TChannelSendResult;
    function SendTimeout(AItem: Pointer; const ATimeout: TDuration): TChannelSendResult;
    function RecvTimeout(out AItem: Pointer; const ATimeoutNs: Int64): TChannelRecvResult;
    function RecvTimeout(out AItem: Pointer; const ATimeout: TDuration): TChannelRecvResult;
    procedure Close;
    function IsClosed: Boolean;
    function Len: SizeInt;
    function Cap: SizeInt;
  end;

constructor TChannel.Create(const ACapacity: SizeInt);
begin
  inherited Create;
  if ACapacity < 1 then
    SyncRaiseArg('TChannel: capacity must be >= 1');
  FCap := ACapacity;
  SetLength(FBuf, ACapacity);
  FLen := 0;
  FHead := 0;
  FTail := 0;
  FClosed := False;
  FMutex := TMutex.Create;
  FNotEmpty := TCondVar.Create;
  FNotFull := TCondVar.Create;
end;

procedure TChannel.PushUnlocked(AItem: Pointer);
begin
  FBuf[FTail] := AItem;
  FTail := (FTail + 1) mod FCap;
  Inc(FLen);
end;

function TChannel.PopUnlocked(out AItem: Pointer): Boolean;
begin
  if FLen = 0 then
  begin
    AItem := nil;
    Exit(False);
  end;
  AItem := FBuf[FHead];
  FBuf[FHead] := nil;
  FHead := (FHead + 1) mod FCap;
  Dec(FLen);
  Result := True;
end;

function TChannel.TrySend(AItem: Pointer): TChannelSendResult;
begin
  FMutex.Acquire;
  try
    if FClosed then
      Exit(csrClosed);
    if FLen >= FCap then
      Exit(csrFull);
    PushUnlocked(AItem);
    FNotEmpty.Signal;
    Result := csrOk;
  finally
    FMutex.Release;
  end;
end;

function TChannel.Send(AItem: Pointer): Boolean;
begin
  FMutex.Acquire;
  try
    while True do
    begin
      if FClosed then
        Exit(False);
      if FLen < FCap then
      begin
        PushUnlocked(AItem);
        FNotEmpty.Signal;
        Exit(True);
      end;
      FNotFull.Wait(FMutex);
    end;
  finally
    FMutex.Release;
  end;
end;

function TChannel.TryRecv(out AItem: Pointer): TChannelRecvResult;
begin
  FMutex.Acquire;
  try
    if PopUnlocked(AItem) then
    begin
      FNotFull.Signal;
      Exit(crrOk);
    end;
    if FClosed then
      Exit(crrClosed);
    Result := crrEmpty;
  finally
    FMutex.Release;
  end;
end;

function TChannel.Recv(out AItem: Pointer): Boolean;
begin
  FMutex.Acquire;
  try
    while True do
    begin
      if PopUnlocked(AItem) then
      begin
        FNotFull.Signal;
        Exit(True);
      end;
      if FClosed then
      begin
        AItem := nil;
        Exit(False);
      end;
      FNotEmpty.Wait(FMutex);
    end;
  finally
    FMutex.Release;
  end;
end;

function TChannel.SendTimeout(AItem: Pointer; const ATimeoutNs: Int64): TChannelSendResult;
var
  LDeadline: TInstant;
  LRemaining: Int64;
begin
  LDeadline := TInstant.Now;
  FMutex.Acquire;
  try
    while True do
    begin
      if FClosed then
        Exit(csrClosed);
      if FLen < FCap then
      begin
        PushUnlocked(AItem);
        FNotEmpty.Signal;
        Exit(csrOk);
      end;
      LRemaining := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
      if LRemaining <= 0 then
        Exit(csrFull);
      if not FNotFull.WaitTimeout(FMutex, LRemaining) then
        Exit(csrFull);
    end;
  finally
    FMutex.Release;
  end;
end;

function TChannel.SendTimeout(AItem: Pointer; const ATimeout: TDuration): TChannelSendResult;
begin
  Result := SendTimeout(AItem, ATimeout.AsNanoseconds);
end;

function TChannel.RecvTimeout(out AItem: Pointer; const ATimeoutNs: Int64): TChannelRecvResult;
var
  LDeadline: TInstant;
  LRemaining: Int64;
begin
  LDeadline := TInstant.Now;
  FMutex.Acquire;
  try
    while True do
    begin
      if PopUnlocked(AItem) then
      begin
        FNotFull.Signal;
        Exit(crrOk);
      end;
      if FClosed then
      begin
        AItem := nil;
        Exit(crrClosed);
      end;
      LRemaining := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
      if LRemaining <= 0 then
        Exit(crrEmpty);
      if not FNotEmpty.WaitTimeout(FMutex, LRemaining) then
        Exit(crrEmpty);
    end;
  finally
    FMutex.Release;
  end;
end;

function TChannel.RecvTimeout(out AItem: Pointer; const ATimeout: TDuration): TChannelRecvResult;
begin
  Result := RecvTimeout(AItem, ATimeout.AsNanoseconds);
end;

procedure TChannel.Close;
begin
  FMutex.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    FNotEmpty.Broadcast;
    FNotFull.Broadcast;
  finally
    FMutex.Release;
  end;
end;

function TChannel.IsClosed: Boolean;
begin
  FMutex.Acquire;
  try
    Result := FClosed;
  finally
    FMutex.Release;
  end;
end;

function TChannel.Len: SizeInt;
begin
  FMutex.Acquire;
  try
    Result := FLen;
  finally
    FMutex.Release;
  end;
end;

function TChannel.Cap: SizeInt;
begin
  Result := FCap;
end;

function CreateChannel(const ACapacity: SizeInt): IChannel;
begin
  Result := TChannel.Create(ACapacity);
end;

end.
