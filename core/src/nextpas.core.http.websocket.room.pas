unit nextpas.core.http.websocket.room;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.websocket,
  nextpas.core.sync;

type
  { A named group of WebSocket connections ("room"/"channel") with join,
    leave and broadcast semantics. One connection thread per socket is the
    expected usage: joins/leaves/broadcasts happen from the owning threads of
    the member sockets, all synchronized by an internal per-room lock.

    Membership payload ownership: the room borrows `AData`. The joining
    thread keeps ownership and must release it (typically via `Leave` during
    connection teardown). Broadcast drops dead members without touching their
    payload — the dead connection's own thread still holds the authoritative
    reference and frees it at teardown, so the room never releases a payload
    it does not own. }
  IWebSocketRoom = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-600000000002}']
    function GetChannelId: string;
    function GetCount: Integer;
    { Join the room. Idempotent: re-joining an already-joined socket is a
      no-op and `AData` is ignored (the first payload wins). }
    procedure Join(const AWS: IWebSocket; const AData: TObject);
    { Leave the room and return the payload that was joined with `AWS`
      (nil when `AWS` is not a member). Caller releases the payload. }
    function Leave(const AWS: IWebSocket): TObject;
    { Broadcast `AData` to all members except `AExclude` (nil = no exclude).
      Members are snapshotted under the room lock and written outside it, so
      slow or dead sockets never block joins/leaves or other members. A member
      whose write fails is dropped from the room (see ownership note above). }
    procedure Broadcast(const AData: string; const AExclude: IWebSocket);
    property ChannelId: string read GetChannelId;
    property Count: Integer read GetCount;
  end;

  { Bounded registry of rooms, keyed by channel id. Rooms are reference
    counted: `GetOrCreate`/`Find` hand out `IWebSocketRoom` refs that keep a
    room alive even after the registry evicts it (a held ref never dangles).
    When the registry is at capacity, eviction drops the room with no members
    first, then the smallest one. }
  TWebSocketRoomManager = class
  private
    FLock: INativeMutex;
    FRooms: array of IWebSocketRoom;
    FMaxRooms: Integer;
    function FindIndex(const AId: string): Integer;
    procedure EvictOneRoom;
  public
    constructor Create; overload;
    { AMaxRooms bounds the registry; defaults to 128. Values < 1 clamp to 1. }
    constructor Create(const AMaxRooms: Integer); overload;
    destructor Destroy; override;
    function GetOrCreate(const AId: string): IWebSocketRoom;
    function Find(const AId: string): IWebSocketRoom;
    function Remove(const AId: string): Boolean;
    function RoomCount: Integer;
    property MaxRooms: Integer read FMaxRooms;
  end;

const
  WEBSOCKET_ROOM_DEFAULT_MAX = 128;

implementation

type
  TRoomConn = record
    WS: IWebSocket;
    Data: TObject;
  end;

  TWebSocketRoomImpl = class(TInterfacedObject, IWebSocketRoom)
  private
    FChannelId: string;
    FLock: INativeMutex;
    FConns: array of TRoomConn;
    function FindIndex(const AWS: IWebSocket): Integer;
    function GetChannelId: string;
    function GetCount: Integer;
  public
    constructor Create(const AChannelId: string);
    procedure Join(const AWS: IWebSocket; const AData: TObject);
    function Leave(const AWS: IWebSocket): TObject;
    procedure Broadcast(const AData: string; const AExclude: IWebSocket);
  end;

{ TWebSocketRoomImpl }

constructor TWebSocketRoomImpl.Create(const AChannelId: string);
begin
  inherited Create;
  FChannelId := AChannelId;
  FLock := Mutex;
end;

function TWebSocketRoomImpl.FindIndex(const AWS: IWebSocket): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FConns) do
    if Pointer(FConns[I].WS) = Pointer(AWS) then
      Exit(I);
  Result := -1;
end;

function TWebSocketRoomImpl.GetChannelId: string;
begin
  Result := FChannelId;
end;

function TWebSocketRoomImpl.GetCount: Integer;
begin
  FLock.Acquire;
  try
    Result := Length(FConns);
  finally
    FLock.Release;
  end;
end;

procedure TWebSocketRoomImpl.Join(const AWS: IWebSocket; const AData: TObject);
begin
  FLock.Acquire;
  try
    if FindIndex(AWS) < 0 then
    begin
      SetLength(FConns, Length(FConns) + 1);
      FConns[High(FConns)].WS := AWS;
      FConns[High(FConns)].Data := AData;
    end;
  finally
    FLock.Release;
  end;
end;

function TWebSocketRoomImpl.Leave(const AWS: IWebSocket): TObject;
var
  Idx: Integer;
begin
  Result := nil;
  FLock.Acquire;
  try
    Idx := FindIndex(AWS);
    if Idx < 0 then
      Exit;
    Result := FConns[Idx].Data;
    FConns[Idx] := FConns[High(FConns)];
    SetLength(FConns, Length(FConns) - 1);
  finally
    FLock.Release;
  end;
end;

procedure TWebSocketRoomImpl.Broadcast(const AData: string;
  const AExclude: IWebSocket);
var
  I: Integer;
  LSnapshot: array of TRoomConn;
  LExclude: IWebSocket;
begin
  { Snapshot under the room lock, write outside it: slow or dead members
    never block joins/leaves or other members. }
  FLock.Acquire;
  try
    SetLength(LSnapshot, Length(FConns));
    for I := 0 to High(FConns) do
      LSnapshot[I] := FConns[I];
  finally
    FLock.Release;
  end;

  LExclude := AExclude;
  for I := 0 to High(LSnapshot) do
  begin
    if (LExclude <> nil) and
       (Pointer(LSnapshot[I].WS) = Pointer(LExclude)) then
      Continue;
    try
      LSnapshot[I].WS.WriteText(AData);
    except
      { Drop a member whose socket is closed or otherwise failing so it stops
        consuming broadcast attempts. The payload is not released here: per
        the ownership contract the dead connection's own thread still holds
        the authoritative reference and frees it during teardown. }
      Leave(LSnapshot[I].WS);
    end;
  end;
end;

{ TWebSocketRoomManager }

constructor TWebSocketRoomManager.Create;
begin
  Create(WEBSOCKET_ROOM_DEFAULT_MAX);
end;

constructor TWebSocketRoomManager.Create(const AMaxRooms: Integer);
begin
  inherited Create;
  if AMaxRooms < 1 then
    FMaxRooms := 1
  else
    FMaxRooms := AMaxRooms;
  FLock := Mutex;
end;

destructor TWebSocketRoomManager.Destroy;
begin
  FLock.Acquire;
  try
    SetLength(FRooms, 0);
  finally
    FLock.Release;
  end;
  inherited Destroy;
end;

function TWebSocketRoomManager.FindIndex(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRooms) do
    if FRooms[I].ChannelId = AId then
      Exit(I);
  Result := -1;
end;

procedure TWebSocketRoomManager.EvictOneRoom;
var
  I, LTarget, LSmallest: Integer;
  LEmpty: Integer;
begin
  { Prefer dropping an empty room, else the room with the fewest members.
    Held `IWebSocketRoom` refs keep the evicted room alive, so eviction never
    dangles a reference the caller is using. }
  LEmpty := -1;
  LSmallest := 0;
  for I := 0 to High(FRooms) do
  begin
    if FRooms[I].Count = 0 then
    begin
      LEmpty := I;
      Break;
    end;
    if FRooms[I].Count < FRooms[LSmallest].Count then
      LSmallest := I;
  end;
  if LEmpty >= 0 then
    LTarget := LEmpty
  else
    LTarget := LSmallest;
  FRooms[LTarget] := FRooms[High(FRooms)];
  SetLength(FRooms, Length(FRooms) - 1);
end;

function TWebSocketRoomManager.GetOrCreate(const AId: string): IWebSocketRoom;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    I := FindIndex(AId);
    if I >= 0 then
      Exit(FRooms[I]);
    if Length(FRooms) >= FMaxRooms then
      EvictOneRoom;
    Result := TWebSocketRoomImpl.Create(AId);
    SetLength(FRooms, Length(FRooms) + 1);
    FRooms[High(FRooms)] := Result;
  finally
    FLock.Release;
  end;
end;

function TWebSocketRoomManager.Find(const AId: string): IWebSocketRoom;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    I := FindIndex(AId);
    if I >= 0 then
      Result := FRooms[I]
    else
      Result := nil;
  finally
    FLock.Release;
  end;
end;

function TWebSocketRoomManager.Remove(const AId: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  FLock.Acquire;
  try
    I := FindIndex(AId);
    if I < 0 then
      Exit;
    FRooms[I] := FRooms[High(FRooms)];
    SetLength(FRooms, Length(FRooms) - 1);
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TWebSocketRoomManager.RoomCount: Integer;
begin
  FLock.Acquire;
  try
    Result := Length(FRooms);
  finally
    FLock.Release;
  end;
end;

end.
