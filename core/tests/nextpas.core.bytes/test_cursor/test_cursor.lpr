program test_cursor;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes;

var
  T: TTestSuite;

function MakeData(ASize: Integer): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, ASize);
  for LI := 0 to ASize - 1 do
    Result[LI] := Byte(LI);
end;

procedure TestSequentialLE;
var
  LC: IByteCursor;
begin
  { 数据为 [0,1,2,...]，故 u16@0 的 LE 值是 $0100 }
  LC := NewByteCursor(MakeData(16));
  CheckEqual(Int64(16), Int64(LC.Length), 'length');
  CheckEqual(Int64($0100), Int64(LC.ReadU16LE), 'u16 LE at 0');
  CheckEqual(Int64(2), Int64(LC.Position), 'position advanced');
  CheckEqual(Int64($0302), Int64(LC.ReadU16LE), 'u16 LE at 2');
  CheckEqual(Int64($07060504), Int64(LC.ReadU32LE), 'u32 LE at 4');
  CheckEqual(Int64($0F0E0D0C0B0A0908), Int64(LC.ReadU64LE), 'u64 LE at 8');
  CheckEqual(Int64(0), Int64(LC.Remaining), 'remaining after full read');
end;

procedure TestBEAndPeek;
var
  LC: IByteCursor;
begin
  LC := NewByteCursor(MakeData(16));
  CheckEqual(Int64($0001), Int64(LC.ReadU16BE), 'u16 BE');
  CheckEqual(Int64($05040302), Int64(LC.PeekU32LE(2)), 'peek does not advance');
  CheckEqual(Int64(2), Int64(LC.Position), 'position unchanged by peek');
  LC.Seek(8);
  CheckEqual(Int64($0B0A), Int64(LC.PeekU16LE(10)), 'peek at offset 10');
  LC.Seek(0);
  CheckEqual(Int64($00010203), Int64(LC.ReadU32BE), 'u32 BE');
  LC.Seek(8);
  CheckEqual(Int64($08090A0B0C0D0E0F), Int64(LC.ReadU64BE), 'u64 BE');
end;

procedure TestReadBytesAndTryVariants;
var
  LC: IByteCursor;
  LOut: TBytes;
  LOk: Boolean;
begin
  LC := NewByteCursor(MakeData(8));
  LOut := LC.ReadBytes(4);
  Check((Length(LOut) = 4) and (LOut[0] = 0) and (LOut[3] = 3), 'read bytes head');
  LOk := LC.TryReadBytes(5, LOut);
  Check(not LOk, 'try read beyond remaining fails');
  LOk := LC.TryReadBytes(4, LOut);
  Check(LOk and (Length(LOut) = 4) and (LOut[0] = 4), 'try read tail succeeds');
  CheckEqual(Int64(8), Int64(LC.Position), 'fully consumed');
end;

procedure TestBoundsGuards;
var
  LC: IByteCursor;
  LGot: Boolean;
begin
  LC := NewByteCursor(MakeData(4));

  LGot := False;
  try
    LC.Seek(5);
  except
    on E: EIndexOutOfRangeError do LGot := True;
  end;
  Check(LGot, 'seek past end raises');

  { 定位到末尾后任何读取都越界 }
  LC.Seek(4);
  LGot := False;
  try
    LC.ReadU16LE;
  except
    on E: EIndexOutOfRangeError do LGot := True;
  end;
  Check(LGot, 'read at end-of-buffer raises');

  LGot := False;
  try
    LC.PeekU64LE(0);
  except
    on E: EIndexOutOfRangeError do LGot := True;
  end;
  Check(LGot, 'peek u64 overruns raise');

  Check(not LC.TrySeek(99), 'try seek past end is False');
  LC.TrySeek(2);
  CheckEqual(Int64(2), Int64(LC.Position), 'try seek ok position');

  { 空缓冲区 }
  LC := NewByteCursor(nil);
  CheckEqual(Int64(0), Int64(LC.Length), 'empty buffer length');
  LGot := False;
  try
    LC.ReadU16LE;
  except
    on E: EIndexOutOfRangeError do LGot := True;
  end;
  Check(LGot, 'empty buffer read raises');
end;

procedure TestRawPointerConstruction;
var
  LData: TBytes;
  LC: IByteCursor;
begin
  LData := MakeData(12);
  LC := NewByteCursorAt(@LData[0], 12);
  CheckEqual(Int64($07060504), Int64(LC.PeekU32LE(4)), 'raw cursor reads');
  CheckEqual(Int64(12), Int64(LC.Length), 'raw cursor length');
end;

begin
  T := TTestSuite.Create('nextpas.core.bytes.cursor');
  T.Test('Sequential LE reads', @TestSequentialLE);
  T.Test('BE reads and peek', @TestBEAndPeek);
  T.Test('ReadBytes and Try variants', @TestReadBytesAndTryVariants);
  T.Test('Bounds guards', @TestBoundsGuards);
  T.Test('Raw pointer construction', @TestRawPointerConstruction);
  if not T.Run then Halt(1);
end.
