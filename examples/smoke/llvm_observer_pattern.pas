program llvm_observer_pattern;
type
  TObserver = class
    FId: Integer;
    constructor Create(Id: Integer);
    function OnEvent(Data: Integer): Integer; virtual;
  end;
  TLogger = class(TObserver)
    constructor Create(Id: Integer);
    function OnEvent(Data: Integer): Integer; override;
  end;
  TCounter = class(TObserver)
    FCount: Integer;
    constructor Create(Id: Integer);
    function OnEvent(Data: Integer): Integer; override;
  end;

constructor TObserver.Create(Id: Integer);
begin
  FId := Id;
end;
function TObserver.OnEvent(Data: Integer): Integer;
begin
  Result := 0;
end;

constructor TLogger.Create(Id: Integer);
begin
  FId := Id;
end;
function TLogger.OnEvent(Data: Integer): Integer;
begin
  Result := Data;
end;

constructor TCounter.Create(Id: Integer);
begin
  FId := Id;
  FCount := 0;
end;
function TCounter.OnEvent(Data: Integer): Integer;
begin
  FCount := FCount + 1;
  Result := FCount;
end;

function Notify(O: TObserver; Data: Integer): Integer;
begin
  Result := O.OnEvent(Data);
end;

var
  L: TLogger;
  C: TCounter;
  R: Integer;
begin
  L := TLogger.Create(1);
  C := TCounter.Create(2);
  R := Notify(L, 36);
  R := R + Notify(C, 0);
  R := R + Notify(C, 0);
  R := R + Notify(C, 0);
  Halt(R);
end.
