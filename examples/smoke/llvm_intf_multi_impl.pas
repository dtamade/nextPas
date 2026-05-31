program test_intf_multi2;
type
  IReader = interface
    function Read: Integer;
  end;
  IWriter = interface
    procedure Store(V: Integer);
  end;
  TBuffer = class(TInterfacedObject, IReader, IWriter)
    FVal: Integer;
    constructor Create;
    function Read: Integer;
    procedure Store(V: Integer);
  end;

constructor TBuffer.Create; begin FVal := 0; end;
function TBuffer.Read: Integer; begin Result := FVal; end;
procedure TBuffer.Store(V: Integer); begin FVal := V; end;

var
  B: TBuffer;
  W: IWriter;
  R: IReader;
begin
  B := TBuffer.Create;
  W := B;
  W.Store(77);
  R := B;
  Halt(R.Read);
end.
