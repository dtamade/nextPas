program llvm_mini_rtl;
type
  TStringBuilder = class
    FBuf: array of Integer;
    FLen: Integer;
    constructor Create;
    procedure Append(Ch: Integer); virtual;
    function Length: Integer; virtual;
    function CharAt(Idx: Integer): Integer; virtual;
  end;

constructor TStringBuilder.Create;
begin
  FLen := 0;
  SetLength(FBuf, 64);
end;

procedure TStringBuilder.Append(Ch: Integer);
begin
  FBuf[FLen] := Ch;
  FLen := FLen + 1;
end;

function TStringBuilder.Length: Integer;
begin
  Result := FLen;
end;

function TStringBuilder.CharAt(Idx: Integer): Integer;
begin
  Result := FBuf[Idx];
end;

generic function Reduce<T>(Arr: array of T; Count: Integer; Init: T): T;
var I: Integer;
    Acc: T;
begin
  Acc := Init;
  for I := 0 to Count - 1 do
    Acc := Acc + Arr[I];
  Result := Acc;
end;

var
  SB: TStringBuilder;
  Nums: array of Integer;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  SB.Append(29);
  SB.Append(101);
  SB.Append(108);

  SetLength(Nums, 4);
  Nums[0] := 1;
  Nums[1] := 2;
  Nums[2] := 3;
  Nums[3] := 4;

  I := specialize Reduce<Integer>(Nums, 4, 0);
  Halt(SB.Length + SB.CharAt(0) + I);
end.
