program test_bytes;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.bytes,
  nextpas.core.bytes.base;

var
  T: TTestRunner;

procedure TestBufferCreate;
var
  LBuf: IByteBuffer;
begin
  LBuf := ByteBuffer(64);
  CheckEqual(Int64(0), Int64(LBuf.Size), 'initial size');
  Check(LBuf.Capacity >= 64, 'capacity');
end;

procedure TestBufferFromBytes;
var
  LData: TBytes;
  LBuf: IByteBuffer;
begin
  SetLength(LData, 3);
  LData[0] := $AA;
  LData[1] := $BB;
  LData[2] := $CC;
  LBuf := ByteBufferFrom(LData);
  CheckEqual(Int64(3), Int64(LBuf.Size));
  Check(LBuf.Data[0] = $AA);
  Check(LBuf.Data[1] = $BB);
  Check(LBuf.Data[2] = $CC);
end;

procedure TestBufferSlice;
var
  LData: TBytes;
  LBuf, LSlice: IByteBuffer;
begin
  SetLength(LData, 5);
  LData[0] := 10; LData[1] := 20; LData[2] := 30;
  LData[3] := 40; LData[4] := 50;
  LBuf := ByteBufferFrom(LData);
  LSlice := LBuf.Slice(1, 3);
  CheckEqual(Int64(3), Int64(LSlice.Size));
  Check(LSlice.Data[0] = 20);
  Check(LSlice.Data[1] = 30);
  Check(LSlice.Data[2] = 40);
end;

procedure TestBuilderAppend;
var
  LB: IByteBuilder;
  LResult: TBytes;
begin
  LB := ByteBuilder(16);
  LB.AppendByte($01);
  LB.AppendByte($02);
  LB.AppendByte($03);
  CheckEqual(Int64(3), Int64(LB.Size));
  LResult := LB.ToBytes;
  Check(Length(LResult) = 3);
  Check(LResult[0] = $01);
  Check(LResult[1] = $02);
  Check(LResult[2] = $03);
end;

procedure TestBuilderEndian;
var
  LB: IByteBuilder;
  LResult: TBytes;
begin
  LB := ByteBuilder(16);
  LB.AppendUInt16($1234, enBig);
  LB.AppendUInt32($DEADBEEF, enLittle);
  LResult := LB.ToBytes;
  CheckEqual(Int64(6), Int64(Length(LResult)));
  Check(LResult[0] = $12);
  Check(LResult[1] = $34);
  Check(LResult[2] = $EF);
  Check(LResult[3] = $BE);
  Check(LResult[4] = $AD);
  Check(LResult[5] = $DE);
end;

procedure TestBuilderGrow;
var
  LB: IByteBuilder;
  LI: Integer;
begin
  LB := ByteBuilder(4);
  for LI := 0 to 999 do
    LB.AppendByte(Byte(LI and $FF));
  CheckEqual(Int64(1000), Int64(LB.Size));
end;

procedure TestBuilderClear;
var
  LB: IByteBuilder;
begin
  LB := ByteBuilder(16);
  LB.AppendByte(1);
  LB.AppendByte(2);
  LB.Clear;
  CheckEqual(Int64(0), Int64(LB.Size));
end;

begin
  T := TTestRunner.Create('nextpas.core.bytes');
  T.Run('Buffer create', @TestBufferCreate);
  T.Run('Buffer from bytes', @TestBufferFromBytes);
  T.Run('Buffer slice', @TestBufferSlice);
  T.Run('Builder append', @TestBuilderAppend);
  T.Run('Builder endian', @TestBuilderEndian);
  T.Run('Builder grow', @TestBuilderGrow);
  T.Run('Builder clear', @TestBuilderClear);
  T.Summary;
end.
