program Llvm_self_call;
type
  TAccum = class
  private
    FVal: Integer;
  public
    constructor Create(V: Integer);
    procedure Add(X: Integer);
    procedure AddTwice(X: Integer);
    function GetVal: Integer;
  end;

constructor TAccum.Create(V: Integer);
begin
  FVal := V;
end;

procedure TAccum.Add(X: Integer);
begin
  FVal := FVal + X;
end;

procedure TAccum.AddTwice(X: Integer);
begin
  Add(X);
  Add(X);
end;

function TAccum.GetVal: Integer;
begin
  Result := FVal;
end;

var
  A: TAccum;
begin
  A := TAccum.Create(1);
  A.AddTwice(3);
  A.Add(2);
  Halt(A.GetVal);
end.
