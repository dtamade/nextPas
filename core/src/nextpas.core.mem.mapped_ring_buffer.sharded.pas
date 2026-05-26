unit nextpas.core.mem.mapped_ring_buffer.sharded;

interface
uses
  SysUtils, Classes, SyncObjs, nextpas.core.mem.mapped_ring_buffer;

type
  // 简单分片封装：将并发生产/消费分散到多条底层 ring
  TMappedRingBufferSharded = class
  private
    FShards: array of TMappedRingBuffer;
    FShardCount: Integer;
    FBaseName: string;
    FPushIdx: Integer;
    FPopIdx: Integer;
    FInit: Boolean;
    FCSel: TRTLCriticalSection;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function CreateShared(const BaseName: string; ShardCount: Integer; Capacity: UInt64; ElemSize: UInt32): Boolean;
    function OpenShared(const BaseName: string; ShardCount: Integer): Boolean;
    procedure Close;
    function Push(Data: Pointer): Boolean; overload;   // 轮询选择分片
    function Pop(Data: Pointer): Boolean; overload;
    function TryPush(Data: Pointer; MaxTries: Integer = 0): Boolean;
    function TryPop(Data: Pointer; MaxTries: Integer = 0): Boolean;
    property ShardCount: Integer read FShardCount;
  end;

implementation

constructor TMappedRingBufferSharded.Create;
begin
  inherited Create;
  FShardCount := 0;
  FBaseName := '';
  FPushIdx := 0;
  FPopIdx := 0;
  FInit := False;
  InitCriticalSection(FCSel);
end;

destructor TMappedRingBufferSharded.Destroy;
begin
  Close;
  DoneCriticalSection(FCSel);
  inherited Destroy;
end;

procedure TMappedRingBufferSharded.Close;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FShards) do
  begin
    if FShards[LIndex] <> nil then FShards[LIndex].Free;
    FShards[LIndex] := nil;
  end;
  SetLength(FShards, 0);
  FShardCount := 0;
  FInit := False;
end;

function TMappedRingBufferSharded.CreateShared(const BaseName: string; ShardCount: Integer; Capacity: UInt64; ElemSize: UInt32): Boolean;
var
  LIndex: Integer;
  LName: string;
begin
  Close;
  Result := False;
  if ShardCount <= 0 then Exit;
  FBaseName := BaseName;
  FShardCount := ShardCount;
  SetLength(FShards, ShardCount);
  for LIndex := 0 to ShardCount-1 do
  begin
    FShards[LIndex] := TMappedRingBuffer.Create;
    LName := Format('%s_sh%0.2d', [BaseName, LIndex]);
    if not FShards[LIndex].CreateShared(LName, Capacity, ElemSize) then Exit;
  end;
  FInit := True;
  Result := True;
end;

function TMappedRingBufferSharded.OpenShared(const BaseName: string; ShardCount: Integer): Boolean;
var
  LIndex: Integer;
  LName: string;
begin
  Close;
  Result := False;
  if ShardCount <= 0 then Exit;
  FBaseName := BaseName;
  FShardCount := ShardCount;
  SetLength(FShards, ShardCount);
  for LIndex := 0 to ShardCount-1 do
  begin
    FShards[LIndex] := TMappedRingBuffer.Create;
    LName := Format('%s_sh%0.2d', [BaseName, LIndex]);
    if not FShards[LIndex].OpenShared(LName) then Exit;
  end;
  FInit := True;
  Result := True;
end;

function TMappedRingBufferSharded.Push(Data: Pointer): Boolean;
var
  LIndex, LStart: Integer;
begin
  if not FInit then Exit(False);
  EnterCriticalSection(FCSel);
  try
    LStart := FPushIdx;
    FPushIdx := (FPushIdx + 1) mod FShardCount;
  finally
    LeaveCriticalSection(FCSel);
  end;
  for LIndex := 0 to FShardCount-1 do
  begin
    if FShards[(LStart + LIndex) mod FShardCount].Push(Data) then Exit(True);
  end;
  Result := False;
end;

function TMappedRingBufferSharded.Pop(Data: Pointer): Boolean;
var
  LIndex, LStart: Integer;
begin
  if not FInit then Exit(False);
  EnterCriticalSection(FCSel);
  try
    LStart := FPopIdx;
    FPopIdx := (FPopIdx + 1) mod FShardCount;
  finally
    LeaveCriticalSection(FCSel);
  end;
  for LIndex := 0 to FShardCount-1 do
  begin
    if FShards[(LStart + LIndex) mod FShardCount].Pop(Data) then Exit(True);
  end;
  Result := False;
end;

function TMappedRingBufferSharded.TryPush(Data: Pointer; MaxTries: Integer): Boolean;
var
  LTries: Integer;
begin
  if MaxTries <= 0 then MaxTries := FShardCount;
  for LTries := 1 to MaxTries do
    if Push(Data) then Exit(True);
  Result := False;
end;

function TMappedRingBufferSharded.TryPop(Data: Pointer; MaxTries: Integer): Boolean;
var
  LTries: Integer;
begin
  if MaxTries <= 0 then MaxTries := FShardCount;
  for LTries := 1 to MaxTries do
    if Pop(Data) then Exit(True);
  Result := False;
end;

end.
