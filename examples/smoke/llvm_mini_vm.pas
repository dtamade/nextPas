program llvm_mini_vm;
type
  TVM = class
    FStack: array of Integer;
    FSP: Integer;
    FAcc: Integer;
    constructor Create;
    procedure Push(V: Integer); virtual;
    function Pop: Integer; virtual;
    procedure Add; virtual;
    procedure Mul; virtual;
    function GetAcc: Integer; virtual;
  end;

constructor TVM.Create;
begin
  FSP := 0;
  FAcc := 0;
  SetLength(FStack, 16);
end;

procedure TVM.Push(V: Integer);
begin
  FStack[FSP] := V;
  FSP := FSP + 1;
end;

function TVM.Pop: Integer;
begin
  FSP := FSP - 1;
  Result := FStack[FSP];
end;

procedure TVM.Add;
var A, B: Integer;
begin
  A := Pop;
  B := Pop;
  FAcc := A + B;
  Push(FAcc);
end;

procedure TVM.Mul;
var A, B: Integer;
begin
  A := Pop;
  B := Pop;
  FAcc := A * B;
  Push(FAcc);
end;

function TVM.GetAcc: Integer;
begin
  Result := FAcc;
end;

var VM: TVM;
begin
  VM := TVM.Create;
  VM.Push(3);
  VM.Push(4);
  VM.Add;
  VM.Push(6);
  VM.Mul;
  Halt(VM.GetAcc);
end.
