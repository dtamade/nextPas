program test_io;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.io,
  nextpas.core.io.base;

var
  T: TTestRunner;

procedure TestBytesStreamWrite;
var
  LS: IStream;
  LData: array[0..3] of Byte;
begin
  LS := BytesStream(64);
  LData[0] := $AA; LData[1] := $BB; LData[2] := $CC; LData[3] := $DD;
  CheckEqual(Int64(4), Int64(LS.Write(LData, 4)), 'write 4 bytes');
  CheckEqual(Int64(4), LS.Size, 'size after write');
  CheckEqual(Int64(4), LS.Position, 'position after write');
end;

procedure TestBytesStreamReadWrite;
var
  LS: IStream;
  LWrite: array[0..2] of Byte;
  LRead: array[0..2] of Byte;
  LN: SizeUInt;
begin
  LS := BytesStream(64);
  LWrite[0] := 10; LWrite[1] := 20; LWrite[2] := 30;
  LS.Write(LWrite, 3);

  LS.Position := 0;
  LN := LS.Read(LRead, 3);
  CheckEqual(Int64(3), Int64(LN), 'read count');
  Check(LRead[0] = 10);
  Check(LRead[1] = 20);
  Check(LRead[2] = 30);
end;

procedure TestBytesStreamEOF;
var
  LS: IStream;
  LBuf: array[0..9] of Byte;
  LN: SizeUInt;
begin
  LS := BytesStreamFrom(nil);
  LN := LS.Read(LBuf, 10);
  CheckEqual(Int64(0), Int64(LN), 'read from empty = 0 (EOF)');
end;

procedure TestBytesStreamSeek;
var
  LS: IStream;
  LData: array[0..4] of Byte;
  LBuf: Byte;
  LPos: Int64;
begin
  LData[0] := 1; LData[1] := 2; LData[2] := 3; LData[3] := 4; LData[4] := 5;
  LS := BytesStream(16);
  LS.Write(LData, 5);

  LPos := LS.Seek(0, soBeginning);
  CheckEqual(Int64(0), LPos, 'seek beginning');

  LPos := LS.Seek(2, soCurrent);
  CheckEqual(Int64(2), LPos, 'seek current +2');

  LS.Read(LBuf, 1);
  Check(LBuf = 3, 'read at pos 2 should be 3');

  LPos := LS.Seek(-1, soEnd);
  CheckEqual(Int64(4), LPos, 'seek end -1');

  LS.Read(LBuf, 1);
  Check(LBuf = 5, 'read at pos 4 should be 5');
end;

procedure TestBytesStreamGrow;
var
  LS: IStream;
  LI: Integer;
  LByte: Byte;
begin
  LS := BytesStream(4);
  for LI := 0 to 99 do
  begin
    LByte := Byte(LI);
    LS.Write(LByte, 1);
  end;
  CheckEqual(Int64(100), LS.Size, 'should grow to 100');
end;

procedure TestBytesStreamFromData;
var
  LData: TBytes;
  LS: IStream;
  LBuf: array[0..2] of Byte;
begin
  SetLength(LData, 3);
  LData[0] := $FF; LData[1] := $FE; LData[2] := $FD;
  LS := BytesStreamFrom(LData);
  CheckEqual(Int64(3), LS.Size);
  CheckEqual(Int64(0), LS.Position);
  LS.Read(LBuf, 3);
  Check(LBuf[0] = $FF);
  Check(LBuf[1] = $FE);
  Check(LBuf[2] = $FD);
end;

procedure TestBufferedReaderSmallReads;
var
  LData: TBytes;
  LInner: IStream;
  LBR: IReader;
  LBuf: Byte;
  LI: Integer;
begin
  SetLength(LData, 100);
  for LI := 0 to 99 do
    LData[LI] := Byte(LI);
  LInner := BytesStreamFrom(LData);
  LBR := BufferedReader(LInner, 16);

  for LI := 0 to 99 do
  begin
    CheckEqual(Int64(1), Int64(LBR.Read(LBuf, 1)), 'read 1 byte');
    Check(LBuf = Byte(LI), 'byte value');
  end;

  CheckEqual(Int64(0), Int64(LBR.Read(LBuf, 1)), 'EOF');
end;

procedure TestBufferedWriterFlush;
var
  LTarget: IStream;
  LBW: IWriter;
  LData: array[0..2] of Byte;
  LTargetAsWriter: IWriter;
begin
  LTarget := BytesStream(64);
  LTargetAsWriter := LTarget as IWriter;
  LBW := BufferedWriter(LTargetAsWriter, 16);
  LData[0] := 1; LData[1] := 2; LData[2] := 3;
  LBW.Write(LData, 3);

  // Force flush by releasing writer
  LBW := nil;

  // After flush, target should have the data
  CheckEqual(Int64(3), LTarget.Size, 'flushed to target');
end;

begin
  T := TTestRunner.Create('nextpas.core.io');
  T.Run('BytesStream write', @TestBytesStreamWrite);
  T.Run('BytesStream read/write', @TestBytesStreamReadWrite);
  T.Run('BytesStream EOF', @TestBytesStreamEOF);
  T.Run('BytesStream seek', @TestBytesStreamSeek);
  T.Run('BytesStream grow', @TestBytesStreamGrow);
  T.Run('BytesStream from data', @TestBytesStreamFromData);
  T.Run('BufferedReader small reads', @TestBufferedReaderSmallReads);
  T.Run('BufferedWriter flush', @TestBufferedWriterFlush);
  T.Summary;
end.
