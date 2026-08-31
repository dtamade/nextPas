program test_slotregistry;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.time,
  nextpas.core.collections.slotregistry;

type
  IItem = interface(ISlotRegistryItem)
    ['{A1B2C3D4-E5F6-7890-ABCD-00000000B001}']
    function GetTag: Integer;
  end;

  { 并列祖先接口：FPC QueryInterface 否则不识别 ISlotRegistryItem。 }
  TItem = class(TInterfacedObject, IItem, ISlotRegistryItem)
  private
    FSlot: Integer;
    FTag: Integer;
  public
    constructor Create(ATag: Integer);
    function GetSlotIndex: Integer;
    procedure SetSlotIndex(const AIndex: Integer);
    function GetTag: Integer;
  end;

  TReg = specialize TSlotRegistry<IItem>;

constructor TItem.Create(ATag: Integer);
begin
  inherited Create;
  FSlot := -1;
  FTag := ATag;
end;

function TItem.GetSlotIndex: Integer;
begin
  Result := FSlot;
end;

procedure TItem.SetSlotIndex(const AIndex: Integer);
begin
  FSlot := AIndex;
end;

function TItem.GetTag: Integer;
begin
  Result := FTag;
end;

procedure TestGrowReuseTailSwap;
var
  R: TReg;
  A, B, C, D, E, LNew: IItem;
begin
  R := TReg.Create(4);
  A := TItem.Create(1) as IItem;
  B := TItem.Create(2) as IItem;
  C := TItem.Create(3) as IItem;
  D := TItem.Create(4) as IItem;
  E := TItem.Create(5) as IItem;
  LNew := TItem.Create(6) as IItem;
  CheckEqual(Int64(0), Int64(R.Capacity), 'lazy cap 0');
  R.Add(A); R.Add(B); R.Add(C);
  CheckEqual(Int64(4), Int64(R.Capacity), 'first wave allocates init cap');
  CheckEqual(Int64(0), Int64(A.GetSlotIndex), 'slot 0');
  CheckEqual(Int64(1), Int64(B.GetSlotIndex), 'slot 1');
  CheckEqual(Int64(2), Int64(C.GetSlotIndex), 'slot 2');
  R.Add(D);
  CheckEqual(Int64(4), Int64(R.Capacity), 'not full no grow');
  R.Add(E);
  CheckEqual(Int64(8), Int64(R.Capacity), 'full doubles');
  CheckEqual(Int64(5), Int64(R.Count), '5 live');
  R.Remove(B);
  CheckEqual(Int64(4), Int64(R.Count), 'after remove');
  CheckEqual(Int64(1), Int64(E.GetSlotIndex), 'tail-swap into hole');
  CheckEqual(Int64(-1), Int64(B.GetSlotIndex), 'removed is -1');
  Check(R.Items[1] = E, 'hole holds tail');
  R.Remove(B);
  CheckEqual(Int64(4), Int64(R.Count), 'idempotent remove');
  R.Add(LNew);
  CheckEqual(Int64(5), Int64(R.Count), 'reuse live');
  CheckEqual(Int64(4), Int64(LNew.GetSlotIndex), 'LIFO reuse last hole');
  CheckEqual(Int64(8), Int64(R.Capacity), 'reuse does not grow');
  R.Free;
end;

procedure TestNilAndUnregistered;
var
  R: TReg;
  A: IItem;
begin
  R := TReg.Create(4);
  R.Add(nil);
  CheckEqual(Int64(0), Int64(R.Count), 'nil add is no-op');
  A := TItem.Create(1) as IItem;
  R.Remove(A);
  CheckEqual(Int64(0), Int64(R.Count), 'unregistered remove is no-op');
  CheckEqual(Int64(-1), Int64(A.GetSlotIndex), 'still -1');
  Check(R.Items[-1] = nil, 'oob negative is nil');
  Check(R.Items[0] = nil, 'oob empty is nil');
  R.Free;
end;

procedure TestIdempotentAddAndDestroy;
var
  R: TReg;
  A, B: IItem;
begin
  R := TReg.Create(4);
  A := TItem.Create(1) as IItem;
  B := TItem.Create(2) as IItem;
  R.Add(A);
  R.Add(A);
  CheckEqual(Int64(1), Int64(R.Count), 'double add is no-op');
  CheckEqual(Int64(0), Int64(A.GetSlotIndex), 'slot stays 0');
  R.Add(B);
  CheckEqual(Int64(2), Int64(R.Count), 'second item');
  Check(R.Items[0] = A, 'items 0');
  Check(R.Items[1] = B, 'items 1');
  Check(R.Items[99] = nil, 'oob high is nil');
  R.Free;
  CheckEqual(Int64(0), Int64(A.GetSlotIndex), 'destroy does not rewrite slots');
end;

procedure TestScale;
const
  N = 100000;
var
  R: TReg;
  Items: array of IItem;
  I: Integer;
  T0, Elapsed: UInt64;
begin
  R := TReg.Create(64);
  SetLength(Items, N);
  for I := 0 to N - 1 do
    Items[I] := TItem.Create(I) as IItem;
  T0 := GetTickCount64;
  for I := 0 to N - 1 do
    R.Add(Items[I]);
  CheckEqual(Int64(N), Int64(R.Count), 'scale add');
  for I := N - 1 downto 0 do
    R.Remove(Items[I]);
  CheckEqual(Int64(0), Int64(R.Count), 'scale remove');
  Elapsed := GetTickCount64 - T0;
  Check(Elapsed <= 2400, '100k add/remove not quadratic');
  SetLength(Items, 0);
  R.Free;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.collections.slotregistry');
  T.Test('grow reuse tail-swap idempotent', @TestGrowReuseTailSwap);
  T.Test('nil and unregistered', @TestNilAndUnregistered);
  T.Test('idempotent add and destroy', @TestIdempotentAddAndDestroy);
  T.Test('100k scale', @TestScale);
  if not T.Run then Halt(1);
end.
