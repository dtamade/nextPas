program llvm_bitset;
type
  TBitSet = class
    FBits: Integer;
    constructor Create;
    procedure Include(Bit: Integer); virtual;
    procedure Exclude(Bit: Integer); virtual;
    function Contains(Bit: Integer): Integer; virtual;
    function Count: Integer; virtual;
  end;

constructor TBitSet.Create;
begin
  FBits := 0;
end;

procedure TBitSet.Include(Bit: Integer);
var Mask: Integer;
begin
  Mask := 1;
  while Bit > 0 do
  begin
    Mask := Mask * 2;
    Bit := Bit - 1;
  end;
  FBits := FBits + Mask;
end;

procedure TBitSet.Exclude(Bit: Integer);
var Mask: Integer;
begin
  Mask := 1;
  while Bit > 0 do
  begin
    Mask := Mask * 2;
    Bit := Bit - 1;
  end;
  FBits := FBits - Mask;
end;

function TBitSet.Contains(Bit: Integer): Integer;
var Mask, Val: Integer;
begin
  Mask := 1;
  while Bit > 0 do
  begin
    Mask := Mask * 2;
    Bit := Bit - 1;
  end;
  Val := FBits div Mask;
  Result := Val mod 2;
end;

function TBitSet.Count: Integer;
var I, C: Integer;
begin
  C := 0;
  for I := 0 to 7 do
    C := C + Contains(I);
  Result := C;
end;

var S: TBitSet;
begin
  S := TBitSet.Create;
  S.Include(0);
  S.Include(2);
  S.Include(5);
  S.Include(7);
  S.Exclude(2);
  Halt(S.Count * 10 + S.Contains(5));
end.
