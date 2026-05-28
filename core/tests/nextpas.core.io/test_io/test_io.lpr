program test_io;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer,
  nextpas.core.io.util,
  nextpas.core.io;

var
  T: TTestRunner;

{ BytesStream tests }

procedure TestStreamWrite;
var
  LS: IStream;
  LBuf: array[0..2] of Byte;
begin
  LS := BytesStream(16);
  LBuf[0] := 1; LBuf[1] := 2; LBuf[2] := 3;
  CheckEqual(SizeUInt(3), LS.Write(LBuf[0], 3), 'write 3');
  CheckEqual(Int64(3), LS.Size, 'size');
  CheckEqual(Int64(3), LS.Position, 'pos');
end;

procedure TestStreamReadWrite;
var
  LS: IStream;
  LW, LR: array[0..3] of Byte;
  LN: SizeUInt;
begin
  LS := BytesStream(16);
  LW[0] := $AA; LW[1] := $BB; LW[2] := $CC; LW[3] := $DD;
  LS.Write(LW[0], 4);
  LS.Seek(0, soBeginning);
  LN := LS.Read(LR[0], 4);
  CheckEqual(SizeUInt(4), LN, 'read count');
  CheckEqual(Byte($AA), LR[0]);
  CheckEqual(Byte($DD), LR[3]);
end;

procedure TestStreamEOF;
var
  LS: IStream;
  LBuf: Byte;
begin
  LS := BytesStream(16);
  CheckEqual(SizeUInt(0), LS.Read(LBuf, 1), 'EOF returns 0');
end;

procedure TestStreamSeek;
var
  LS: IStream;
  LBuf: array[0..9] of Byte;
  LI: Integer;
begin
  LS := BytesStream(16);
  for LI := 0 to 9 do LBuf[LI] := Byte(LI);
  LS.Write(LBuf[0], 10);
  CheckEqual(Int64(0), LS.Seek(0, soBeginning), 'seek begin');
  CheckEqual(Int64(10), LS.Seek(0, soEnd), 'seek end');
  LS.Seek(5, soBeginning);
  CheckEqual(Int64(7), LS.Seek(2, soCurrent), 'seek current');
end;

procedure TestStreamGrow;
var
  LS: IStream;
  LBuf: array[0..255] of Byte;
  LI: Integer;
begin
  LS := BytesStream(4);
  for LI := 0 to 255 do LBuf[LI] := Byte(LI);
  LS.Write(LBuf[0], 256);
  CheckEqual(Int64(256), LS.Size, 'grew');
end;

procedure TestStreamFromData;
var
  LS: IStream;
  LData: TBytes;
  LBuf: array[0..2] of Byte;
begin
  LData := TBytes.Create(10, 20, 30);
  LS := BytesStreamFrom(LData);
  CheckEqual(Int64(3), LS.Size);
  LS.Read(LBuf[0], 3);
  CheckEqual(Byte(10), LBuf[0]);
  CheckEqual(Byte(30), LBuf[2]);
end;

procedure TestStreamClose;
var
  LS: IStream;
  LBuf: Byte;
begin
  LS := BytesStream(16);
  LS.Write(LBuf, 1);
  LS.Close;
  CheckEqual(Int64(0), LS.Size, 'closed size=0');
end;

{ BufferedReader tests }

procedure TestBufReaderSmall;
var
  LS: IStream;
  LR: IReader;
  LBuf: array[0..0] of Byte;
  LI: Integer;
  LData: array[0..99] of Byte;
begin
  LS := BytesStream(128);
  for LI := 0 to 99 do LData[LI] := Byte(LI);
  LS.Write(LData[0], 100);
  LS.Seek(0, soBeginning);
  LR := BufferedReader(LS, 16);
  for LI := 0 to 99 do
  begin
    CheckEqual(SizeUInt(1), LR.Read(LBuf[0], 1), 'read 1');
    CheckEqual(Byte(LI), LBuf[0], 'byte ' + IntToStr(LI));
  end;
  CheckEqual(SizeUInt(0), LR.Read(LBuf[0], 1), 'EOF');
end;

procedure TestBufReaderLarge;
var
  LS: IStream;
  LR: IReader;
  LData: array[0..1023] of Byte;
  LOut: array[0..1023] of Byte;
  LI: Integer;
begin
  LS := BytesStream(2048);
  for LI := 0 to 1023 do LData[LI] := Byte(LI and $FF);
  LS.Write(LData[0], 1024);
  LS.Seek(0, soBeginning);
  LR := BufferedReader(LS, 64);
  CheckEqual(SizeUInt(1024), LR.Read(LOut[0], 1024), 'large read');
  for LI := 0 to 1023 do
    CheckEqual(LData[LI], LOut[LI], 'byte');
end;

{ BufferedWriter tests }

procedure TestBufWriterFlush;
var
  LS: IStream;
  LW: IWriter;
  LBuf: array[0..2] of Byte;
begin
  LS := BytesStream(64);
  LW := BufferedWriter(LS as IWriter, 32);
  LBuf[0] := $AA; LBuf[1] := $BB; LBuf[2] := $CC;
  LW.Write(LBuf[0], 3);
  (LW as IFlusher).Flush;
  CheckEqual(Int64(3), LS.Size, 'flushed');
end;

procedure TestBufWriterLarge;
var
  LS: IStream;
  LW: IWriter;
  LData: array[0..511] of Byte;
  LI: Integer;
begin
  LS := BytesStream(1024);
  LW := BufferedWriter(LS as IWriter, 32);
  for LI := 0 to 511 do LData[LI] := Byte(LI and $FF);
  CheckEqual(SizeUInt(512), LW.Write(LData[0], 512), 'write 512');
  (LW as IFlusher).Flush;
  CheckEqual(Int64(512), LS.Size, 'all written');
end;

{ Util: Copy }

procedure TestCopy;
var
  LSrc, LDst: IStream;
  LData: array[0..99] of Byte;
  LI: Integer;
  LN: Int64;
  LOut: array[0..99] of Byte;
begin
  LSrc := BytesStream(128);
  for LI := 0 to 99 do LData[LI] := Byte(LI);
  LSrc.Write(LData[0], 100);
  LSrc.Seek(0, soBeginning);
  LDst := BytesStream(128);
  LN := nextpas.core.io.Copy(LDst as IWriter, LSrc);
  CheckEqual(Int64(100), LN, 'copied 100');
  LDst.Seek(0, soBeginning);
  LDst.Read(LOut[0], 100);
  CheckEqual(Byte(0), LOut[0]);
  CheckEqual(Byte(99), LOut[99]);
end;

procedure TestCopyN;
var
  LSrc, LDst: IStream;
  LData: array[0..99] of Byte;
  LI: Integer;
  LN: Int64;
begin
  LSrc := BytesStream(128);
  for LI := 0 to 99 do LData[LI] := Byte(LI);
  LSrc.Write(LData[0], 100);
  LSrc.Seek(0, soBeginning);
  LDst := BytesStream(128);
  LN := nextpas.core.io.CopyN(LDst as IWriter, LSrc, 50);
  CheckEqual(Int64(50), LN, 'copied 50');
  CheckEqual(Int64(50), LDst.Size);
end;

{ Util: ReadAll }

procedure TestReadAll;
var
  LS: IStream;
  LData: array[0..49] of Byte;
  LI: Integer;
  LResult: TBytes;
begin
  LS := BytesStream(64);
  for LI := 0 to 49 do LData[LI] := Byte(LI + 1);
  LS.Write(LData[0], 50);
  LS.Seek(0, soBeginning);
  LResult := nextpas.core.io.ReadAll(LS);
  CheckEqual(50, Length(LResult), 'len');
  CheckEqual(Byte(1), LResult[0]);
  CheckEqual(Byte(50), LResult[49]);
end;

{ Util: ReadFull }

procedure TestReadFull;
var
  LS: IStream;
  LData: array[0..9] of Byte;
  LOut: array[0..9] of Byte;
  LI: Integer;
begin
  LS := BytesStream(16);
  for LI := 0 to 9 do LData[LI] := Byte(LI * 10);
  LS.Write(LData[0], 10);
  LS.Seek(0, soBeginning);
  nextpas.core.io.ReadFull(LS, LOut[0], 10);
  CheckEqual(Byte(0), LOut[0]);
  CheckEqual(Byte(90), LOut[9]);
end;

procedure TestReadFullShort;
var
  LS: IStream;
  LBuf: array[0..9] of Byte;
  LCaught: Boolean;
begin
  LS := BytesStream(4);
  LS.Write(LBuf[0], 3);
  LS.Seek(0, soBeginning);
  LCaught := False;
  try
    nextpas.core.io.ReadFull(LS, LBuf[0], 10);
  except
    LCaught := True;
  end;
  Check(LCaught, 'should raise on short read');
end;

{ Util: LimitReader }

procedure TestLimitReader;
var
  LS: IStream;
  LR: IReader;
  LBuf: array[0..9] of Byte;
  LData: array[0..99] of Byte;
  LI: Integer;
begin
  LS := BytesStream(128);
  for LI := 0 to 99 do LData[LI] := Byte(LI);
  LS.Write(LData[0], 100);
  LS.Seek(0, soBeginning);
  LR := nextpas.core.io.LimitReader(LS, 5);
  CheckEqual(SizeUInt(5), LR.Read(LBuf[0], 10), 'limited to 5');
  CheckEqual(SizeUInt(0), LR.Read(LBuf[0], 10), 'EOF after limit');
  CheckEqual(Byte(0), LBuf[0]);
  CheckEqual(Byte(4), LBuf[4]);
end;

{ Util: TeeReader }

procedure TestTeeReader;
var
  LSrc, LTap: IStream;
  LR: IReader;
  LData: array[0..4] of Byte;
  LBuf: array[0..4] of Byte;
  LI: Integer;
begin
  LSrc := BytesStream(16);
  for LI := 0 to 4 do LData[LI] := Byte(LI + 10);
  LSrc.Write(LData[0], 5);
  LSrc.Seek(0, soBeginning);
  LTap := BytesStream(16);
  LR := nextpas.core.io.TeeReader(LSrc, LTap as IWriter);
  LR.Read(LBuf[0], 5);
  CheckEqual(Int64(5), LTap.Size, 'tee captured');
end;

{ Util: MultiReader }

procedure TestMultiReader;
var
  LS1, LS2: IStream;
  LR: IReader;
  LBuf: array[0..5] of Byte;
  LN: SizeUInt;
begin
  LS1 := BytesStreamFrom(TBytes.Create(1, 2, 3));
  LS2 := BytesStreamFrom(TBytes.Create(4, 5, 6));
  LR := nextpas.core.io.MultiReader([LS1, LS2]);
  LN := LR.Read(LBuf[0], 6);
  CheckEqual(SizeUInt(3), LN, 'first reader');
  CheckEqual(Byte(1), LBuf[0]);
  LN := LR.Read(LBuf[0], 6);
  CheckEqual(SizeUInt(3), LN, 'second reader');
  CheckEqual(Byte(4), LBuf[0]);
  LN := LR.Read(LBuf[0], 6);
  CheckEqual(SizeUInt(0), LN, 'EOF');
end;

{ Util: MultiWriter }

procedure TestMultiWriter;
var
  LS1, LS2: IStream;
  LW: IWriter;
  LData: array[0..2] of Byte;
begin
  LS1 := BytesStream(16);
  LS2 := BytesStream(16);
  LW := nextpas.core.io.MultiWriter([LS1 as IWriter, LS2 as IWriter]);
  LData[0] := $AA; LData[1] := $BB; LData[2] := $CC;
  LW.Write(LData[0], 3);
  CheckEqual(Int64(3), LS1.Size, 'writer1');
  CheckEqual(Int64(3), LS2.Size, 'writer2');
end;

{ Util: Discard + NullReader }

procedure TestDiscard;
var
  LW: IWriter;
  LBuf: array[0..99] of Byte;
begin
  LW := nextpas.core.io.Discard;
  CheckEqual(SizeUInt(100), LW.Write(LBuf[0], 100), 'discard accepts all');
end;

procedure TestNullReader;
var
  LR: IReader;
  LBuf: Byte;
begin
  LR := nextpas.core.io.NullReader;
  CheckEqual(SizeUInt(0), LR.Read(LBuf, 1), 'null returns 0');
end;

{ Util: NopCloser }

procedure TestNopCloser;
var
  LS: IStream;
  LRC: IReadCloser;
  LBuf: array[0..2] of Byte;
begin
  LS := BytesStreamFrom(TBytes.Create(7, 8, 9));
  LRC := nextpas.core.io.NopCloser(LS);
  CheckEqual(SizeUInt(3), LRC.Read(LBuf[0], 3), 'read through');
  LRC.Close;
  CheckEqual(Byte(7), LBuf[0]);
end;

{ Util: WriteString }

procedure TestWriteString;
var
  LS: IStream;
  LN: SizeUInt;
  LBuf: array[0..4] of Byte;
begin
  LS := BytesStream(16);
  LN := nextpas.core.io.WriteString(LS as IWriter, 'hello');
  CheckEqual(SizeUInt(5), LN, 'wrote 5');
  LS.Seek(0, soBeginning);
  LS.Read(LBuf[0], 5);
  CheckEqual(Byte(Ord('h')), LBuf[0]);
  CheckEqual(Byte(Ord('o')), LBuf[4]);
end;

{ Util: ReadAtLeast }

procedure TestReadAtLeast;
var
  LS: IStream;
  LBuf: array[0..9] of Byte;
begin
  LS := BytesStreamFrom(TBytes.Create(1, 2, 3, 4, 5));
  nextpas.core.io.ReadAtLeast(LS, LBuf[0], 10, 3);
  CheckEqual(Byte(1), LBuf[0]);
  CheckEqual(Byte(3), LBuf[2]);
end;

{ Util: CopyBuffer }

procedure TestCopyBuffer;
var
  LSrc, LDst: IStream;
  LBuf: array[0..7] of Byte;
  LData: array[0..19] of Byte;
  LI: Integer;
  LN: Int64;
begin
  LSrc := BytesStream(32);
  for LI := 0 to 19 do LData[LI] := Byte(LI);
  LSrc.Write(LData[0], 20);
  LSrc.Seek(0, soBeginning);
  LDst := BytesStream(32);
  LN := nextpas.core.io.CopyBuffer(LDst as IWriter, LSrc, LBuf[0], 8);
  CheckEqual(Int64(20), LN, 'copied with custom buf');
end;

begin
  T := TTestRunner.Create('nextpas.core.io');

  T.Run('Stream write', @TestStreamWrite);
  T.Run('Stream read/write', @TestStreamReadWrite);
  T.Run('Stream EOF', @TestStreamEOF);
  T.Run('Stream seek', @TestStreamSeek);
  T.Run('Stream grow', @TestStreamGrow);
  T.Run('Stream from data', @TestStreamFromData);
  T.Run('Stream close', @TestStreamClose);

  T.Run('BufReader small', @TestBufReaderSmall);
  T.Run('BufReader large', @TestBufReaderLarge);
  T.Run('BufWriter flush', @TestBufWriterFlush);
  T.Run('BufWriter large', @TestBufWriterLarge);

  T.Run('Copy', @TestCopy);
  T.Run('CopyN', @TestCopyN);
  T.Run('ReadAll', @TestReadAll);
  T.Run('ReadFull', @TestReadFull);
  T.Run('ReadFull short', @TestReadFullShort);
  T.Run('LimitReader', @TestLimitReader);
  T.Run('TeeReader', @TestTeeReader);
  T.Run('MultiReader', @TestMultiReader);
  T.Run('MultiWriter', @TestMultiWriter);
  T.Run('Discard', @TestDiscard);
  T.Run('NullReader', @TestNullReader);
  T.Run('NopCloser', @TestNopCloser);
  T.Run('WriteString', @TestWriteString);
  T.Run('ReadAtLeast', @TestReadAtLeast);
  T.Run('CopyBuffer', @TestCopyBuffer);

  T.Summary;
end.