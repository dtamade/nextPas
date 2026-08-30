program test_msgpack;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.encoding.msgpack;

var
  T: TTestSuite;

procedure TestFixInt;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.MakeUInt(42);
  B := MsgPackEncodeVal(V);
  CheckEqual(Int64(1), Int64(Length(B)));
  Check(B[0] = 42);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpUInt);
  CheckEqual(QWord(42), D.UIntVal);
  CheckEqual(Int64(1), Int64(LRead));
end;

procedure TestFixStr;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.MakeStr('hello');
  B := MsgPackEncodeVal(V);
  Check(B[0] = ($A0 or 5));
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpStr);
  CheckEqual('hello', D.StrVal);
end;

procedure TestArray;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.MakeArr([
    TMsgPackValue.MakeUInt(1),
    TMsgPackValue.MakeStr('a'),
    TMsgPackValue.MakeBool(True)
  ]);
  B := MsgPackEncodeVal(V);
  Check(B[0] = ($90 or 3));
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpArray);
  CheckEqual(Int64(3), Int64(Length(D.ArrayVals)));
  Check(D.ArrayVals[0].UIntVal = 1);
  CheckEqual('a', D.ArrayVals[1].StrVal);
  Check(D.ArrayVals[2].BoolVal = True);
end;

procedure TestBin;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
  LBin: TBytes;
begin
  SetLength(LBin, 3);
  LBin[0] := 1; LBin[1] := 2; LBin[2] := 3;
  V := TMsgPackValue.MakeBin(LBin);
  B := MsgPackEncodeVal(V);
  Check(B[0] = $C4);
  Check(B[1] = 3);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpBin);
  CheckEqual(Int64(3), Int64(Length(D.BinVal)));
  Check(D.BinVal[0] = 1);
end;

procedure TestNil;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.NilVal;
  B := MsgPackEncodeVal(V);
  Check(B[0] = $C0);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpNil);
end;

procedure TestIntNegative;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.MakeInt(-1);
  B := MsgPackEncodeVal(V);
  Check(B[0] = $FF);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpInt);
  CheckEqual(Int64(-1), D.IntVal);
end;

procedure TestUint16;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
begin
  V := TMsgPackValue.MakeUInt(500);
  B := MsgPackEncodeVal(V);
  Check(B[0] = $CD);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpUInt);
  CheckEqual(QWord(500), D.UIntVal);
end;

procedure TestVarintU32;
var
  B: TBytes;
  V: UInt32;
  LPrefix: Integer;
  LOk: Boolean;
begin
  SetLength(B, 1); B[0] := 42;
  LOk := MsgPackDecodeVarintU32(B, 0, V, LPrefix);
  Check(LOk);
  CheckEqual(QWord(42), QWord(V));
  CheckEqual(Int64(1), Int64(LPrefix));
  SetLength(B, 2); B[0] := $AC; B[1] := $02;
  LOk := MsgPackDecodeVarintU32(B, 0, V, LPrefix);
  Check(LOk);
  CheckEqual(QWord(300), QWord(V));
  CheckEqual(Int64(2), Int64(LPrefix));
end;

procedure TestArrayEncodeArray;
var
  B: TBytes;
  V: TMsgPackValue;
  LRead: Integer;
begin
  B := MsgPackEncodeArray([
    TMsgPackValue.MakeUInt(1),
    TMsgPackValue.MakeUInt(2)
  ]);
  V := MsgPackDecodeAt(B, 0, LRead);
  Check(V.Kind = mpArray);
  CheckEqual(Int64(2), Int64(Length(V.ArrayVals)));
end;

procedure TestLargeStr;
var
  V, D: TMsgPackValue;
  B: TBytes;
  LRead: Integer;
  S: string;
begin
  S := StringOfChar('a', 300);
  V := TMsgPackValue.MakeStr(S);
  B := MsgPackEncodeVal(V);
  Check(B[0] = $DA);
  D := MsgPackDecodeAt(B, 0, LRead);
  Check(D.Kind = mpStr);
  CheckEqual(Int64(300), Int64(Length(D.StrVal)));
end;

begin
  T := TTestSuite.Create('nextpas.core.encoding.msgpack');
  T.Test('fixint', @TestFixInt);
  T.Test('fixstr', @TestFixStr);
  T.Test('array', @TestArray);
  T.Test('bin', @TestBin);
  T.Test('nil', @TestNil);
  T.Test('int_negative', @TestIntNegative);
  T.Test('uint16', @TestUint16);
  T.Test('varint_u32', @TestVarintU32);
  T.Test('array_encode_array', @TestArrayEncodeArray);
  T.Test('large_str', @TestLargeStr);
  if not T.Run then Halt(1);
end.
