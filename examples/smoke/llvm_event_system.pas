program llvm_event_system;
type
  THandler = class
    FId: Integer;
    FNext: THandler;
    constructor Create(Id: Integer);
    function Handle(Data: Integer): Integer; virtual;
  end;

  TEventBus = class
    FHead: THandler;
    FCount: Integer;
    constructor Create;
    procedure Subscribe(H: THandler); virtual;
    function Dispatch(Data: Integer): Integer; virtual;
  end;

constructor THandler.Create(Id: Integer);
begin
  FId := Id;
end;

function THandler.Handle(Data: Integer): Integer;
begin
  Result := Data + FId;
end;

constructor TEventBus.Create;
begin
  FCount := 0;
end;

procedure TEventBus.Subscribe(H: THandler);
begin
  H.FNext := FHead;
  FHead := H;
  FCount := FCount + 1;
end;

function TEventBus.Dispatch(Data: Integer): Integer;
var
  Cur: THandler;
  Total: Integer;
begin
  Total := 0;
  Cur := FHead;
  while Cur <> nil do
  begin
    Total := Total + Cur.Handle(Data);
    Cur := Cur.FNext;
  end;
  Result := Total;
end;

var
  Bus: TEventBus;
begin
  Bus := TEventBus.Create;
  Bus.Subscribe(THandler.Create(1));
  Bus.Subscribe(THandler.Create(2));
  Bus.Subscribe(THandler.Create(3));
  Halt(Bus.Dispatch(10));
end.
