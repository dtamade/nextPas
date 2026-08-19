program test_http_websocket_room;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.websocket,
  nextpas.core.http.websocket.room,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

type
  { Deterministic IWebSocket double: records WriteText calls, fails writes on
    demand (closed/failing socket), never reads. Tests hold both the object
    reference (for inspection) and a strong interface reference (as a
    connection thread would hold), so a mock stays valid even after the room
    drops its own reference during eviction. }
  TMockWs = class(TInterfacedObject, IWebSocket)
  private
    FId: Integer;
    FClosed: Boolean;
    FFailWrites: Boolean;
    FWritten: array of string;
  public
    constructor Create(const AId: Integer);
    { Simulate a closed connection: subsequent writes raise. }
    procedure CloseConn;
    { Simulate a write failure without closing: subsequent writes raise. }
    procedure FailWrites;
    function ReadFrame: TWebSocketFrame;
    function ReadMessage: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: TBytes);
    procedure Ping(const AData: TBytes);
    procedure Pong(const AData: TBytes);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
    function WrittenCount: Integer;
    function WrittenAt(const AIndex: Integer): string;
  end;

  { Borrowed membership payload; plain TObject, freed by the test (caller). }
  TPayload = class
  private
    FId: Integer;
  public
    constructor Create(const AId: Integer);
    property Id: Integer read FId;
  end;

constructor TMockWs.Create(const AId: Integer);
begin
  inherited Create;
  FId := AId;
end;

function TMockWs.ReadFrame: TWebSocketFrame;
begin
  raise EHttpError.Create(hekProtocol, 'mock read not expected in room tests');
end;

function TMockWs.ReadMessage: TWebSocketFrame;
begin
  raise EHttpError.Create(hekProtocol, 'mock read not expected in room tests');
end;

procedure TMockWs.WriteText(const AData: string);
begin
  if FClosed or FFailWrites then
    raise EHttpError.Create(hekConnect, 'mock write failed');
  SetLength(FWritten, Length(FWritten) + 1);
  FWritten[High(FWritten)] := AData;
end;

procedure TMockWs.WriteBinary(const AData: TBytes);
begin
  raise EHttpError.Create(hekProtocol, 'mock binary write not expected');
end;

procedure TMockWs.Ping(const AData: TBytes);
begin
end;

procedure TMockWs.Pong(const AData: TBytes);
begin
end;

procedure TMockWs.Close(const ACode: UInt16; const AReason: string);
begin
  FClosed := True;
end;

procedure TMockWs.CloseConn;
begin
  FClosed := True;
end;

procedure TMockWs.FailWrites;
begin
  FFailWrites := True;
end;

function TMockWs.IsOpen: Boolean;
begin
  Result := not FClosed;
end;

function TMockWs.WrittenCount: Integer;
begin
  Result := Length(FWritten);
end;

function TMockWs.WrittenAt(const AIndex: Integer): string;
begin
  Result := FWritten[AIndex];
end;

constructor TPayload.Create(const AId: Integer);
begin
  inherited Create;
  FId := AId;
end;

{ Verify every WriteText in AExpected arrived at AWs, in order, and nothing else. }
procedure CheckExactWrites(AWs: TMockWs; const AExpected: array of string);
var
  I: Integer;
begin
  CheckEqual(Length(AExpected), AWs.WrittenCount, 'written count');
  for I := 0 to High(AExpected) do
    CheckEqual(AExpected[I], AWs.WrittenAt(I), 'written item ' + IntToStr(I));
end;

procedure TestJoinLeaveCount;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2: TMockWs;
  IW1, IW2: IWebSocket;
  P1, P2: TPayload;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    P1 := TPayload.Create(10);
    P2 := TPayload.Create(20);
    CheckEqual(0, Room.Count, 'empty room count');
    Room.Join(IW1, P1);
    CheckEqual(1, Room.Count, 'after first join');
    Room.Join(IW2, P2);
    CheckEqual(2, Room.Count, 'after second join');
    CheckEqual(10, TPayload(Room.Leave(IW1)).Id, 'leave returns payload');
    CheckEqual(1, Room.Count, 'after leave w1');
    CheckEqual(20, TPayload(Room.Leave(IW2)).Id, 'leave returns payload 2');
    CheckEqual(0, Room.Count, 'after leave w2');
    P1.Free;
    P2.Free;
  finally
    Mgr.Free;
  end;
end;

procedure TestJoinIdempotent;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W: TMockWs;
  IW: IWebSocket;
  P1, P2: TPayload;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W := TMockWs.Create(1);
    IW := W;
    P1 := TPayload.Create(1);
    P2 := TPayload.Create(2);
    Room.Join(IW, P1);
    { re-join is a no-op: first payload wins, count unchanged }
    Room.Join(IW, P2);
    CheckEqual(1, Room.Count, 'idempotent join count');
    Check(Pointer(Room.Leave(IW)) = Pointer(P1), 'first payload kept on re-join');
    P1.Free;
    P2.Free;
  finally
    Mgr.Free;
  end;
end;

procedure TestLeaveUnknownReturnsNil;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  IW: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    IW := TMockWs.Create(1);
    Check(Room.Leave(IW) = nil, 'leave non-member returns nil');
    CheckEqual(0, Room.Count, 'count unchanged');
  finally
    Mgr.Free;
  end;
end;

procedure TestBroadcastAllMembers;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2, W3: TMockWs;
  IW1, IW2, IW3: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    W3 := TMockWs.Create(3);
    IW3 := W3;
    Room.Join(IW1, nil);
    Room.Join(IW2, nil);
    Room.Join(IW3, nil);
    Room.Broadcast('m1', nil);
    Room.Broadcast('m2', nil);
    CheckExactWrites(W1, ['m1', 'm2']);
    CheckExactWrites(W2, ['m1', 'm2']);
    CheckExactWrites(W3, ['m1', 'm2']);
    CheckEqual(3, Room.Count, 'members intact after broadcast');
  finally
    Mgr.Free;
  end;
end;

procedure TestBroadcastExclude;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2, W3: TMockWs;
  IW1, IW2, IW3: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    W3 := TMockWs.Create(3);
    IW3 := W3;
    Room.Join(IW1, nil);
    Room.Join(IW2, nil);
    Room.Join(IW3, nil);
    Room.Broadcast('m1', IW2);
    CheckExactWrites(W1, ['m1']);
    CheckExactWrites(W2, []);
    CheckExactWrites(W3, ['m1']);
    CheckEqual(3, Room.Count, 'excluded member stays in room');
  finally
    Mgr.Free;
  end;
end;

procedure TestBroadcastDropsDeadMember;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2, W3: TMockWs;
  IW1, IW2, IW3: IWebSocket;
  P: TPayload;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    W3 := TMockWs.Create(3);
    IW3 := W3;
    P := TPayload.Create(22);
    Room.Join(IW1, nil);
    Room.Join(IW2, P);
    Room.Join(IW3, nil);
    { IW2's socket dies: its write raises mid-broadcast }
    W2.CloseConn;
    Room.Broadcast('m1', nil);
    CheckExactWrites(W1, ['m1']);
    CheckExactWrites(W2, []);
    CheckExactWrites(W3, ['m1']);
    CheckEqual(2, Room.Count, 'dead member dropped');
    { IW2 is not a member anymore: leave returns nil now }
    Check(Room.Leave(IW2) = nil, 'dead member already removed');
    { Subsequent broadcasts reach only the surviving members }
    Room.Broadcast('m2', nil);
    CheckExactWrites(W1, ['m1', 'm2']);
    CheckExactWrites(W3, ['m1', 'm2']);
    { Broadcast dropped the borrowed payload ref; the owning thread (the test,
      standing in for the dead connection) still holds it and frees it once. }
    CheckEqual(22, P.Id, 'payload untouched by eviction');
    P.Free;
  finally
    Mgr.Free;
  end;
end;

procedure TestBroadcastDropsWriteFailingMember;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2, W3: TMockWs;
  IW1, IW2, IW3: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    W3 := TMockWs.Create(3);
    IW3 := W3;
    Room.Join(IW1, nil);
    Room.Join(IW2, nil);
    Room.Join(IW3, nil);
    { transient write failure (socket still open) drops the member too }
    W2.FailWrites;
    Room.Broadcast('m1', nil);
    CheckExactWrites(W1, ['m1']);
    CheckExactWrites(W2, []);
    CheckExactWrites(W3, ['m1']);
    CheckEqual(2, Room.Count, 'failing member dropped');
  finally
    Mgr.Free;
  end;
end;

procedure TestBroadcastFailureDoesNotFreePayload;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  W1, W2: TMockWs;
  IW1, IW2: IWebSocket;
  P: TPayload;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    W1 := TMockWs.Create(1);
    IW1 := W1;
    W2 := TMockWs.Create(2);
    IW2 := W2;
    P := TPayload.Create(99);
    Room.Join(IW1, nil);
    Room.Join(IW2, P);
    W2.CloseConn;
    Room.Broadcast('m1', nil);
    { Payload is borrowed, not owned: broadcast must not free it. We still
      hold it and can release it exactly once. }
    CheckEqual(99, P.Id, 'payload untouched by broadcast');
    P.Free;
  finally
    Mgr.Free;
  end;
end;

procedure TestManagerGetOrCreateReuse;
var
  Mgr: TWebSocketRoomManager;
  R1, R2, R3: IWebSocketRoom;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    R1 := Mgr.GetOrCreate('ch1');
    R2 := Mgr.GetOrCreate('ch1');
    Check(Pointer(R1) = Pointer(R2), 'same channel yields same room');
    CheckEqual('ch1', R1.ChannelId, 'channel id');
    R3 := Mgr.GetOrCreate('ch2');
    Check(Pointer(R1) <> Pointer(R3), 'different channel yields different room');
    CheckEqual(2, Mgr.RoomCount, 'registry count');
  finally
    Mgr.Free;
  end;
end;

procedure TestManagerFindRemove;
var
  Mgr: TWebSocketRoomManager;
  R: IWebSocketRoom;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Check(Mgr.Find('missing') = nil, 'find missing returns nil');
    R := Mgr.GetOrCreate('ch1');
    Check(Pointer(Mgr.Find('ch1')) = Pointer(R), 'find existing room');
    Check(Mgr.Remove('ch1'), 'remove existing room');
    Check(Mgr.Find('ch1') = nil, 'find after remove');
    Check(not Mgr.Remove('ch1'), 'remove again false');
    CheckEqual(0, Mgr.RoomCount, 'registry empty');
    { removed room interface still usable (caller-held ref) }
    CheckEqual(0, R.Count, 'held ref works after removal');
  finally
    Mgr.Free;
  end;
end;

procedure TestManagerMaxRoomsEvictsEmptyFirst;
var
  Mgr: TWebSocketRoomManager;
  R1, R2, R3: IWebSocketRoom;
  W: TMockWs;
  IW: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create(2);
  try
    R1 := Mgr.GetOrCreate('a');
    W := TMockWs.Create(1);
    IW := W;
    R1.Join(IW, nil);
    R2 := Mgr.GetOrCreate('b');
    { registry full (a, b); creating 'c' evicts the empty room 'b' first }
    R3 := Mgr.GetOrCreate('c');
    Check(Mgr.Find('b') = nil, 'empty room evicted first');
    Check(Pointer(Mgr.Find('a')) = Pointer(R1), 'non-empty room kept');
    Check(Pointer(Mgr.Find('c')) = Pointer(R3), 'new room present');
    CheckEqual(2, Mgr.RoomCount, 'registry capped');
    CheckEqual(1, R1.Count, 'kept room membership intact');
  finally
    Mgr.Free;
  end;
end;

procedure TestManagerMaxRoomsEvictsSmallestAndHeldRefStaysValid;
var
  Mgr: TWebSocketRoomManager;
  RA, RB, RC: IWebSocketRoom;
  W1: TMockWs;
  IW1: IWebSocket;
begin
  Mgr := TWebSocketRoomManager.Create(2);
  try
    RA := Mgr.GetOrCreate('a');
    RA.Join(TMockWs.Create(1), nil);
    RA.Join(TMockWs.Create(2), nil);
    RB := Mgr.GetOrCreate('b');
    W1 := TMockWs.Create(3);
    IW1 := W1;
    RB.Join(IW1, nil);
    { registry full; no empty room: 'b' (1 member) evicted over 'a' (2) }
    RC := Mgr.GetOrCreate('c');
    Check(Mgr.Find('b') = nil, 'smallest room evicted');
    Check(Pointer(Mgr.Find('a')) = Pointer(RA), 'largest room kept');
    CheckEqual(1, RB.Count, 'evicted room alive through held ref');
    RB.Join(TMockWs.Create(4), nil);
    CheckEqual(2, RB.Count, 'evicted room still joins');
    RB.Broadcast('m', nil);
    CheckEqual(1, W1.WrittenCount, 'evicted room still broadcasts');
  finally
    Mgr.Free;
  end;
end;

procedure TestManagerClampsMaxRooms;
var
  Mgr: TWebSocketRoomManager;
begin
  Mgr := TWebSocketRoomManager.Create(0);
  try
    CheckEqual(1, Mgr.MaxRooms, 'max rooms clamped to 1');
  finally
    Mgr.Free;
  end;
end;

type
  PThreadCtx = ^TThreadCtx;
  TThreadCtx = record
    Room: IWebSocketRoom;
    WS: IWebSocket;
  end;

function JoinLeaveThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  Ctx: PThreadCtx;
  I: Integer;
begin
  Ctx := PThreadCtx(AArg);
  for I := 0 to 249 do
  begin
    Ctx^.Room.Join(Ctx^.WS, nil);
    Ctx^.Room.Leave(Ctx^.WS);
  end;
  Result := nil;
end;

procedure TestThreadedJoinLeave;
const
  ThreadCount = 4;
var
  Mgr: TWebSocketRoomManager;
  Room: IWebSocketRoom;
  Handles: array[0..ThreadCount - 1] of TPlatformThreadHandle;
  Contexts: array[0..ThreadCount - 1] of TThreadCtx;
  Sockets: array[0..ThreadCount - 1] of TMockWs;
  I: Integer;
  LRet: Pointer;
  LAllJoined: Boolean;
begin
  Mgr := TWebSocketRoomManager.Create;
  try
    Room := Mgr.GetOrCreate('ch1');
    for I := 0 to ThreadCount - 1 do
    begin
      Sockets[I] := TMockWs.Create(I);
      Contexts[I].Room := Room;
      Contexts[I].WS := Sockets[I];
      if platform_thread_create(Handles[I], @JoinLeaveThreadFunc,
        @Contexts[I]) <> 0 then
        Check(False, 'thread create failed ' + IntToStr(I));
    end;
    for I := 0 to ThreadCount - 1 do
      platform_thread_join(Handles[I], LRet);
    CheckEqual(0, Room.Count, 'concurrent join/leave leaves room empty');
    { Re-join all sockets, then a broadcast must reach every one exactly once }
    for I := 0 to ThreadCount - 1 do
      Room.Join(Sockets[I], nil);
    Room.Broadcast('final', nil);
    LAllJoined := True;
    for I := 0 to ThreadCount - 1 do
      if Sockets[I].WrittenCount <> 1 then
        LAllJoined := False;
    Check(LAllJoined, 'all sockets joined and received broadcast');
  finally
    Mgr.Free;
  end;
end;

begin
  T := TTestSuite.Create('http.websocket.room');
  T.Test('JoinLeaveCount', @TestJoinLeaveCount);
  T.Test('JoinIdempotent', @TestJoinIdempotent);
  T.Test('LeaveUnknownReturnsNil', @TestLeaveUnknownReturnsNil);
  T.Test('BroadcastAllMembers', @TestBroadcastAllMembers);
  T.Test('BroadcastExclude', @TestBroadcastExclude);
  T.Test('BroadcastDropsDeadMember', @TestBroadcastDropsDeadMember);
  T.Test('BroadcastDropsWriteFailingMember', @TestBroadcastDropsWriteFailingMember);
  T.Test('BroadcastFailureDoesNotFreePayload', @TestBroadcastFailureDoesNotFreePayload);
  T.Test('ManagerGetOrCreateReuse', @TestManagerGetOrCreateReuse);
  T.Test('ManagerFindRemove', @TestManagerFindRemove);
  T.Test('ManagerMaxRoomsEvictsEmptyFirst', @TestManagerMaxRoomsEvictsEmptyFirst);
  T.Test('ManagerMaxRoomsEvictsSmallestAndHeldRefStaysValid',
    @TestManagerMaxRoomsEvictsSmallestAndHeldRefStaysValid);
  T.Test('ManagerClampsMaxRooms', @TestManagerClampsMaxRooms);
  T.Test('ThreadedJoinLeave', @TestThreadedJoinLeave);
  if not T.Run then Halt(1);
end.