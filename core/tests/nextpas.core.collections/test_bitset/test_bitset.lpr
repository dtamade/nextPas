program test_bitset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.bitset.intf;

var
  T: TTestRunner;

procedure TestSetAndTest;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(64);
  Check(not LB.Test(0), 'bit 0 initially clear');
  LB.SetBit(0);
  Check(LB.Test(0), 'bit 0 set');
  LB.SetBit(63);
  Check(LB.Test(63), 'bit 63 set');
  Check(not LB.Test(1), 'bit 1 still clear');
end;

procedure TestClearBit;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(64);
  LB.SetBit(10);
  LB.ClearBit(10);
  Check(not LB.Test(10), 'bit cleared');
end;

procedure TestFlip;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(64);
  LB.Flip(5);
  Check(LB.Test(5), 'flip 0->1');
  LB.Flip(5);
  Check(not LB.Test(5), 'flip 1->0');
end;

procedure TestCardinality;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(64);
  CheckEqual(Int64(0), Int64(LB.Cardinality), 'empty cardinality');
  LB.SetBit(0);
  LB.SetBit(10);
  LB.SetBit(63);
  CheckEqual(Int64(3), Int64(LB.Cardinality), 'cardinality 3');
end;

procedure TestSetAllClearAll;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(64);
  LB.SetAll;
  CheckEqual(Int64(64), Int64(LB.Cardinality), 'all set');
  Check(LB.Test(0), 'bit 0');
  Check(LB.Test(63), 'bit 63');
  LB.ClearAll;
  CheckEqual(Int64(0), Int64(LB.Cardinality), 'all cleared');
end;

procedure TestAndWith;
var
  LA, LB, LC: IBitSet;
begin
  LA := MakeBitSet(64);
  LB := MakeBitSet(64);
  LA.SetBit(0); LA.SetBit(1); LA.SetBit(2);
  LB.SetBit(1); LB.SetBit(2); LB.SetBit(3);
  LC := LA.AndWith(LB);
  Check(not LC.Test(0), 'and: 0 not in both');
  Check(LC.Test(1), 'and: 1 in both');
  Check(LC.Test(2), 'and: 2 in both');
  Check(not LC.Test(3), 'and: 3 not in A');
  CheckEqual(Int64(2), Int64(LC.Cardinality), 'and cardinality');
end;

procedure TestOrWith;
var
  LA, LB, LC: IBitSet;
begin
  LA := MakeBitSet(64);
  LB := MakeBitSet(64);
  LA.SetBit(0); LA.SetBit(1);
  LB.SetBit(1); LB.SetBit(2);
  LC := LA.OrWith(LB);
  Check(LC.Test(0), 'or: 0');
  Check(LC.Test(1), 'or: 1');
  Check(LC.Test(2), 'or: 2');
  CheckEqual(Int64(3), Int64(LC.Cardinality), 'or cardinality');
end;

procedure TestXorWith;
var
  LA, LB, LC: IBitSet;
begin
  LA := MakeBitSet(64);
  LB := MakeBitSet(64);
  LA.SetBit(0); LA.SetBit(1);
  LB.SetBit(1); LB.SetBit(2);
  LC := LA.XorWith(LB);
  Check(LC.Test(0), 'xor: 0 only in A');
  Check(not LC.Test(1), 'xor: 1 in both');
  Check(LC.Test(2), 'xor: 2 only in B');
  CheckEqual(Int64(2), Int64(LC.Cardinality), 'xor cardinality');
end;

procedure TestNotBits;
var
  LA, LB: IBitSet;
begin
  LA := MakeBitSet(64);
  LA.SetBit(0);
  LA.SetBit(63);
  LB := LA.NotBits;
  Check(not LB.Test(0), 'not: 0 flipped');
  Check(LB.Test(1), 'not: 1 flipped');
  Check(not LB.Test(63), 'not: 63 flipped');
  CheckEqual(Int64(62), Int64(LB.Cardinality), 'not cardinality');
end;

procedure TestLargeIndex;
var
  LB: IBitSet;
begin
  LB := MakeBitSet(256);
  LB.SetBit(200);
  Check(LB.Test(200), 'large index set');
  Check(not LB.Test(199), 'adjacent clear');
  CheckEqual(Int64(1), Int64(LB.Cardinality), 'cardinality 1');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.bitset');
  T.Run('Set and Test', @TestSetAndTest);
  T.Run('ClearBit', @TestClearBit);
  T.Run('Flip', @TestFlip);
  T.Run('Cardinality', @TestCardinality);
  T.Run('SetAll/ClearAll', @TestSetAllClearAll);
  T.Run('AndWith', @TestAndWith);
  T.Run('OrWith', @TestOrWith);
  T.Run('XorWith', @TestXorWith);
  T.Run('NotBits', @TestNotBits);
  T.Run('Large index', @TestLargeIndex);
  T.Summary;
end.
