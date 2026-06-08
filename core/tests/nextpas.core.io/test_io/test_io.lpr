program test_io;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer,
  nextpas.core.io.util,
  nextpas.core.io.pipe,
  nextpas.core.io.scanner,
  nextpas.core.io;

var
  T: TTestRunner;

procedure IgnoreReader(const AReader: IReader);
begin
  if AReader = nil then
    Exit;
end;

procedure IgnoreWriter(const AWriter: IWriter);
begin
  if AWriter = nil then
    Exit;
end;

procedure IgnoreReadCloser(const ACloser: IReadCloser);
begin
  if ACloser = nil then
    Exit;
end;

procedure IgnoreScanner(const AScanner: IScanner);
begin
  if AScanner = nil then
    Exit;
end;

type
  TZeroProgressWriter = class(TInterfacedObject, IWriter)
  private
    FCalls: Int32;
    FBytesAcceptedBeforeZero: SizeUInt;
    FZeroOnCall: Int32;
  public
    constructor Create(const AZeroOnCall: Int32);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    property Calls: Int32 read FCalls;
    property BytesAcceptedBeforeZero: SizeUInt read FBytesAcceptedBeforeZero;
  end;

  TPartialForwardingWriter = class(TInterfacedObject, IWriter)
  private
    FInner: IWriter;
    FMaxWrite: SizeUInt;
    FCalls: Int32;
  public
    constructor Create(const AInner: IWriter; const AMaxWrite: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    property Calls: Int32 read FCalls;
  end;

constructor TZeroProgressWriter.Create(const AZeroOnCall: Int32);
begin
  inherited Create;
  FCalls := 0;
  FBytesAcceptedBeforeZero := 0;
  FZeroOnCall := AZeroOnCall;
end;

function TZeroProgressWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Inc(FCalls);
  if FCalls >= FZeroOnCall then
    Exit(0);
  Inc(FBytesAcceptedBeforeZero, ACount);
  Result := ACount;
end;

constructor TPartialForwardingWriter.Create(const AInner: IWriter; const AMaxWrite: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  FMaxWrite := AMaxWrite;
  FCalls := 0;
end;

function TPartialForwardingWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LCount: SizeUInt;
begin
  Inc(FCalls);
  if (ACount = 0) or (FMaxWrite = 0) then
    Exit(0);
  if ACount < FMaxWrite then
    LCount := ACount
  else
    LCount := FMaxWrite;
  Result := FInner.Write(ABuf, LCount);
end;

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

procedure TestBufWriterFlushZeroProgressRaises;
var
  LInnerObj: TZeroProgressWriter;
  LInner: IWriter;
  LW: IWriter;
  LData: array[0..2] of Byte;
  LRaised: Boolean;
begin
  LInnerObj := TZeroProgressWriter.Create(1);
  LInner := LInnerObj;
  LW := BufferedWriter(LInner, 32);
  LData[0] := $AA;
  LData[1] := $BB;
  LData[2] := $CC;
  LW.Write(LData[0], 3);

  LRaised := False;
  try
    (LW as IFlusher).Flush;
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'zero-progress flush raises EIOError');
  CheckEqual(Int64(1), Int64(LInnerObj.Calls), 'flush attempted one inner write');
end;

procedure TestBufWriterDirectWriteZeroProgressRaises;
var
  LInnerObj: TZeroProgressWriter;
  LInner: IWriter;
  LW: IWriter;
  LData: array[0..63] of Byte;
  LI: Integer;
  LRaised: Boolean;
begin
  for LI := 0 to High(LData) do
    LData[LI] := Byte(LI);

  LInnerObj := TZeroProgressWriter.Create(2);
  LInner := LInnerObj;
  LW := BufferedWriter(LInner, 32);

  LRaised := False;
  try
    LW.Write(LData[0], SizeUInt(Length(LData)));
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'zero-progress direct write raises EIOError');
  CheckEqual(Int64(2), Int64(LInnerObj.Calls),
    'write attempted buffered flush and direct write');
  CheckEqual(Int64(32), Int64(LInnerObj.BytesAcceptedBeforeZero),
    'first buffered flush fully reached inner writer before failure');
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

procedure TestLimitReaderNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    IgnoreReader(nextpas.core.io.LimitReader(IReader(nil), 5));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'LimitReader nil inner raises EArgumentError');
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

procedure TestTeeReaderRetriesPartialTapWrite;
var
  LSrc, LTap: IStream;
  LTapObj: TPartialForwardingWriter;
  LTapWriter: IWriter;
  LR: IReader;
  LData: array[0..4] of Byte;
  LBuf: array[0..4] of Byte;
  LTapBuf: array[0..4] of Byte;
  LI: Integer;
  LN: SizeUInt;
begin
  LSrc := BytesStream(16);
  for LI := 0 to 4 do
    LData[LI] := Byte(LI + 20);
  LSrc.Write(LData[0], 5);
  LSrc.Seek(0, soBeginning);
  LTap := BytesStream(16);
  LTapObj := TPartialForwardingWriter.Create(LTap as IWriter, 2);
  LTapWriter := LTapObj;
  LR := nextpas.core.io.TeeReader(LSrc, LTapWriter);

  LN := LR.Read(LBuf[0], 5);

  CheckEqual(SizeUInt(5), LN, 'tee returns full source read count');
  CheckEqual(Int64(3), Int64(LTapObj.Calls), 'tee retries partial tap writes');
  CheckEqual(Int64(5), LTap.Size, 'tee captured full read');
  LTap.Seek(0, soBeginning);
  LTap.Read(LTapBuf[0], 5);
  for LI := 0 to 4 do
    CheckEqual(LData[LI], LTapBuf[LI], 'tap byte');
end;

procedure TestTeeReaderZeroProgressTapRaises;
var
  LSrc: IStream;
  LTapObj: TZeroProgressWriter;
  LTapWriter: IWriter;
  LR: IReader;
  LData: array[0..2] of Byte;
  LBuf: array[0..2] of Byte;
  LRaised: Boolean;
begin
  LSrc := BytesStreamFrom(TBytes.Create($01, $02, $03));
  LTapObj := TZeroProgressWriter.Create(1);
  LTapWriter := LTapObj;
  LR := nextpas.core.io.TeeReader(LSrc, LTapWriter);

  LRaised := False;
  try
    LR.Read(LBuf[0], 3);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'zero-progress tee tap raises EIOError');
  CheckEqual(Int64(1), Int64(LTapObj.Calls), 'tee attempted tap write once');
end;

procedure TestTeeReaderNilInner;
var
  LRaised: Boolean;
  LWriter: IWriter;
begin
  LWriter := nextpas.core.io.Discard;
  LRaised := False;
  try
    IgnoreReader(nextpas.core.io.TeeReader(IReader(nil), LWriter));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'TeeReader nil reader raises EArgumentError');
end;

procedure TestTeeReaderNilWriter;
var
  LRaised: Boolean;
  LSource: IStream;
begin
  LSource := BytesStreamFrom(TBytes.Create($01));
  LRaised := False;
  try
    IgnoreReader(nextpas.core.io.TeeReader(LSource as IReader, IWriter(nil)));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'TeeReader nil writer raises EArgumentError');
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

procedure TestMultiReaderNilInner;
var
  LRaised: Boolean;
  LSource: IStream;
begin
  LSource := BytesStreamFrom(TBytes.Create($01));
  LRaised := False;
  try
    IgnoreReader(nextpas.core.io.MultiReader([LSource as IReader, IReader(nil)]));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'MultiReader nil inner raises EArgumentError');
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

procedure TestMultiWriterRetriesEachWriterToFullPayload;
var
  LS1, LS2: IStream;
  LW1Obj, LW2Obj: TPartialForwardingWriter;
  LW1, LW2, LW: IWriter;
  LData: array[0..4] of Byte;
  LBuf1, LBuf2: array[0..4] of Byte;
  LI: Integer;
  LN: SizeUInt;
begin
  for LI := 0 to 4 do
    LData[LI] := Byte($A0 + LI);
  LS1 := BytesStream(16);
  LS2 := BytesStream(16);
  LW1Obj := TPartialForwardingWriter.Create(LS1 as IWriter, 2);
  LW2Obj := TPartialForwardingWriter.Create(LS2 as IWriter, 3);
  LW1 := LW1Obj;
  LW2 := LW2Obj;
  LW := nextpas.core.io.MultiWriter([LW1, LW2]);

  LN := LW.Write(LData[0], 5);

  CheckEqual(SizeUInt(5), LN, 'multiwriter returns full count');
  CheckEqual(Int64(3), Int64(LW1Obj.Calls), 'writer1 retried to full payload');
  CheckEqual(Int64(2), Int64(LW2Obj.Calls), 'writer2 retried to full payload');
  CheckEqual(Int64(5), LS1.Size, 'writer1 full size');
  CheckEqual(Int64(5), LS2.Size, 'writer2 full size');
  LS1.Seek(0, soBeginning);
  LS2.Seek(0, soBeginning);
  LS1.Read(LBuf1[0], 5);
  LS2.Read(LBuf2[0], 5);
  for LI := 0 to 4 do
  begin
    CheckEqual(LData[LI], LBuf1[LI], 'writer1 byte');
    CheckEqual(LData[LI], LBuf2[LI], 'writer2 byte');
  end;
end;

procedure TestMultiWriterZeroProgressRaises;
var
  LS1: IStream;
  LZeroObj: TZeroProgressWriter;
  LZero: IWriter;
  LW: IWriter;
  LData: array[0..2] of Byte;
  LRaised: Boolean;
begin
  LData[0] := $A1;
  LData[1] := $B2;
  LData[2] := $C3;
  LS1 := BytesStream(16);
  LZeroObj := TZeroProgressWriter.Create(1);
  LZero := LZeroObj;
  LW := nextpas.core.io.MultiWriter([LS1 as IWriter, LZero]);

  LRaised := False;
  try
    LW.Write(LData[0], 3);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'zero-progress multiwriter raises EIOError');
  CheckEqual(Int64(1), Int64(LZeroObj.Calls), 'zero writer attempted once');
end;

procedure TestMultiWriterNilInner;
var
  LDest: IStream;
  LRaised: Boolean;
begin
  LDest := BytesStream(16);
  LRaised := False;
  try
    IgnoreWriter(nextpas.core.io.MultiWriter([LDest as IWriter, IWriter(nil)]));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'MultiWriter nil inner raises EArgumentError');
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

procedure TestNopCloserNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    IgnoreReadCloser(nextpas.core.io.NopCloser(IReader(nil)));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'NopCloser nil inner raises EArgumentError');
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

{ Pipe tests }

procedure TestPipeBasic;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LData: array[0..4] of Byte;
  LBuf: array[0..4] of Byte;
  LI: Integer;
begin
  CreatePipe(LR, LW);
  for LI := 0 to 4 do LData[LI] := Byte(LI + 10);
  CheckEqual(SizeUInt(5), LW.Write(LData[0], 5), 'pipe write');
  CheckEqual(SizeUInt(5), LR.Read(LBuf[0], 5), 'pipe read');
  for LI := 0 to 4 do
    CheckEqual(Byte(LI + 10), LBuf[LI], 'byte');
  LW.Close;
  LR.Close;
end;

procedure TestPipeCloseWriterEOF;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LBuf: Byte;
begin
  CreatePipe(LR, LW);
  LW.Write(LBuf, 1);
  LW.Close;
  LR.Read(LBuf, 1);
  CheckEqual(SizeUInt(0), LR.Read(LBuf, 1), 'EOF after writer close');
  LR.Close;
end;

procedure TestPipeWriteAfterWriterCloseRaises;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LBuf: Byte;
  LRaised: Boolean;
begin
  CreatePipe(LR, LW);
  LBuf := $2A;
  LW.Close;

  LRaised := False;
  try
    LW.Write(LBuf, 1);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'write after writer close raises EIOError');
  CheckEqual(SizeUInt(0), LR.Read(LBuf, 1), 'closed writer did not enqueue data');
  LR.Close;
end;

procedure TestPipeReadAfterReaderCloseRaises;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LBuf: Byte;
  LRaised: Boolean;
begin
  CreatePipe(LR, LW);
  LBuf := $41;
  CheckEqual(SizeUInt(1), LW.Write(LBuf, 1), 'pipe write before reader close');
  LR.Close;

  LRaised := False;
  try
    LR.Read(LBuf, 1);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'read after reader close raises EIOError');
  LW.Close;
end;

procedure TestPipeReaderReleaseClosesEndpoint;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LBuf: Byte;
  LRaised: Boolean;
begin
  CreatePipe(LR, LW);
  LR := nil;
  LBuf := $42;

  LRaised := False;
  try
    LW.Write(LBuf, 1);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'releasing reader closes pipe endpoint');
  LW.Close;
end;

{ New interface tests }

procedure TestReaderAt;
var
  LS: IStream;
  LRA: IReaderAt;
  LBuf: array[0..2] of Byte;
  LData: TBytes;
begin
  LData := TBytes.Create(10, 20, 30, 40, 50);
  LS := BytesStreamFrom(LData);
  LRA := LS as IReaderAt;
  CheckEqual(SizeUInt(3), LRA.ReadAt(LBuf[0], 3, 2), 'read 3 at offset 2');
  CheckEqual(Byte(30), LBuf[0]);
  CheckEqual(Byte(50), LBuf[2]);
  CheckEqual(SizeUInt(0), LRA.ReadAt(LBuf[0], 3, 10), 'past end');
end;

procedure TestWriterAt;
var
  LS: IStream;
  LWA: IWriterAt;
  LBuf: array[0..2] of Byte;
begin
  LS := BytesStream(16);
  LS.Write(LBuf[0], 5);
  LWA := LS as IWriterAt;
  LBuf[0] := $AA; LBuf[1] := $BB;
  LWA.WriteAt(LBuf[0], 2, 1);
  LS.Seek(1, soBeginning);
  LS.Read(LBuf[0], 2);
  CheckEqual(Byte($AA), LBuf[0]);
  CheckEqual(Byte($BB), LBuf[1]);
end;

procedure TestByteReaderStream;
var
  LS: IStream;
  LBR: IByteReader;
begin
  LS := BytesStreamFrom(TBytes.Create($DE, $AD));
  LBR := LS as IByteReader;
  CheckEqual(Byte($DE), LBR.ReadByte, 'first');
  CheckEqual(Byte($AD), LBR.ReadByte, 'second');
end;

procedure TestByteScanner;
var
  LS: IStream;
  LR: IReader;
  LBS: IByteScanner;
  LB: Byte;
begin
  LS := BytesStreamFrom(TBytes.Create(1, 2, 3));
  LR := CreateBufferedReader(LS, 16);
  LBS := LR as IByteScanner;
  LB := LBS.ReadByte;
  CheckEqual(Byte(1), LB, 'read 1');
  LBS.UnreadByte;
  LB := LBS.ReadByte;
  CheckEqual(Byte(1), LB, 'unread then re-read');
  LB := LBS.ReadByte;
  CheckEqual(Byte(2), LB, 'next byte');
end;

procedure TestStringWriter;
var
  LS: IStream;
  LSW: IStringWriter;
  LBuf: array[0..4] of Byte;
begin
  LS := BytesStream(16);
  LSW := LS as IStringWriter;
  CheckEqual(SizeUInt(5), LSW.WriteString('hello'), 'wrote 5');
  LS.Seek(0, soBeginning);
  LS.Read(LBuf[0], 5);
  CheckEqual(Byte(Ord('h')), LBuf[0]);
  CheckEqual(Byte(Ord('o')), LBuf[4]);
end;

procedure TestSectionReader;
var
  LS: IStream;
  LR: IReader;
  LBuf: array[0..9] of Byte;
  LData: TBytes;
begin
  LData := TBytes.Create(0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
  LS := BytesStreamFrom(LData);
  LR := nextpas.core.io.SectionReader(LS as IReaderAt, 3, 4);
  CheckEqual(SizeUInt(4), LR.Read(LBuf[0], 10), 'limited to 4');
  CheckEqual(Byte(3), LBuf[0]);
  CheckEqual(Byte(6), LBuf[3]);
  CheckEqual(SizeUInt(0), LR.Read(LBuf[0], 10), 'EOF');
end;

procedure TestSectionReaderNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    IgnoreReader(nextpas.core.io.SectionReader(IReaderAt(nil), 0, 1));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'SectionReader nil inner raises EArgumentError');
end;

procedure TestUnreadByteThenRead;
var
  LS: IStream;
  LR: IReader;
  LBS: IByteScanner;
  LBuf: array[0..3] of Byte;
  LN: SizeUInt;
begin
  LS := BytesStreamFrom(TBytes.Create(10, 20, 30, 40));
  LR := CreateBufferedReader(LS, 16);
  LBS := LR as IByteScanner;
  LBS.ReadByte;
  LBS.UnreadByte;
  LN := LR.Read(LBuf[0], 4);
  CheckEqual(SizeUInt(4), LN, 'read 4 after unread');
  CheckEqual(Byte(10), LBuf[0], 'unread byte served first');
  CheckEqual(Byte(20), LBuf[1]);
  CheckEqual(Byte(30), LBuf[2]);
  CheckEqual(Byte(40), LBuf[3]);
end;

procedure TestReadZeroAfterUnread;
var
  LS: IStream;
  LR: IReader;
  LBS: IByteScanner;
  LBuf: Byte;
begin
  LS := BytesStreamFrom(TBytes.Create(10, 20));
  LR := CreateBufferedReader(LS, 16);
  LBS := LR as IByteScanner;
  LBS.ReadByte;
  LBS.UnreadByte;
  CheckEqual(SizeUInt(0), LR.Read(LBuf, 0), 'zero read returns 0');
  CheckEqual(Byte(10), LBS.ReadByte, 'unread byte preserved');
end;

procedure TestBufReaderZeroSize;
var
  LS: IStream;
  LGotException: Boolean;
begin
  LS := BytesStream(16);
  LGotException := False;
  try
    CreateBufferedReader(LS as IReader, 0);
  except
    on E: EArgumentError do
      LGotException := True;
  end;
  Check(LGotException, 'zero buf size raises');
end;

procedure TestBufWriterZeroSize;
var
  LS: IStream;
  LGotException: Boolean;
begin
  LS := BytesStream(16);
  LGotException := False;
  try
    CreateBufferedWriter(LS as IWriter, 0);
  except
    on E: EArgumentError do
      LGotException := True;
  end;
  Check(LGotException, 'zero buf size raises');
end;

procedure TestReadAtLeastMinGtCount;
var
  LS: IStream;
  LBuf: array[0..3] of Byte;
  LGotException: Boolean;
begin
  LS := BytesStreamFrom(TBytes.Create(1, 2, 3, 4, 5));
  LGotException := False;
  try
    IoReadAtLeast(LS as IReader, LBuf[0], 4, 10);
  except
    on E: EArgumentError do
      LGotException := True;
  end;
  Check(LGotException, 'AMin > ACount raises');
end;

procedure TestPipeLargeData;
var
  LR: IPipeReader;
  LW: IPipeWriter;
  LData: array[0..3999] of Byte;
  LOut: array[0..3999] of Byte;
  LI: Integer;
  LTotal, LN: SizeUInt;
begin
  CreatePipe(LR, LW);
  for LI := 0 to 3999 do
    LData[LI] := Byte(LI and $FF);
  LW.Write(LData[0], 4000);
  LW.Close;
  LTotal := 0;
  repeat
    LN := LR.Read(LOut[LTotal], 4000 - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  until LTotal >= 4000;
  CheckEqual(SizeUInt(4000), LTotal, 'all data received');
  CheckEqual(Byte(0), LOut[0]);
  CheckEqual(Byte(255), LOut[255]);
  LR.Close;
end;

{ Scanner tests }

procedure TestScannerLines;
var
  LS: IStream;
  LScan: IScanner;
begin
  LS := BytesStreamFrom(TBytes.Create(
    Ord('h'), Ord('i'), 10,
    Ord('b'), Ord('y'), Ord('e'), 10));
  LScan := CreateScanner(LS as IReader, nil);
  Check(LScan.Scan, 'scan line 1');
  CheckEqual('hi', LScan.Text, 'line 1');
  Check(LScan.Scan, 'scan line 2');
  CheckEqual('bye', LScan.Text, 'line 2');
  Check(not LScan.Scan, 'no more');
end;

procedure TestScannerCRLF;
var
  LS: IStream;
  LScan: IScanner;
begin
  LS := BytesStreamFrom(TBytes.Create(
    Ord('a'), 13, 10,
    Ord('b'), 13, 10));
  LScan := CreateScanner(LS as IReader, nil);
  Check(LScan.Scan, 'scan 1');
  CheckEqual('a', LScan.Text, 'strip CR');
  Check(LScan.Scan, 'scan 2');
  CheckEqual('b', LScan.Text, 'strip CR 2');
  Check(not LScan.Scan, 'done');
end;

procedure TestScannerNoTrailingNewline;
var
  LS: IStream;
  LScan: IScanner;
begin
  LS := BytesStreamFrom(TBytes.Create(
    Ord('x'), Ord('y'), Ord('z')));
  LScan := CreateScanner(LS as IReader, nil);
  Check(LScan.Scan, 'scan last line');
  CheckEqual('xyz', LScan.Text, 'no trailing newline');
  Check(not LScan.Scan, 'done');
end;

procedure TestScannerEmpty;
var
  LS: IStream;
  LScan: IScanner;
begin
  LS := BytesStreamFrom(nil);
  LScan := CreateScanner(LS as IReader, nil);
  Check(not LScan.Scan, 'empty input');
end;

procedure TestScannerEmptyLines;
var
  LS: IStream;
  LScan: IScanner;
begin
  LS := BytesStreamFrom(TBytes.Create(10, 10, Ord('x'), 10));
  LScan := CreateScanner(LS as IReader, nil);
  Check(LScan.Scan, 'scan empty line 1');
  CheckEqual('', LScan.Text, 'empty line');
  Check(LScan.Scan, 'scan empty line 2');
  CheckEqual('', LScan.Text, 'empty line 2');
  Check(LScan.Scan, 'scan x');
  CheckEqual('x', LScan.Text, 'x');
  Check(not LScan.Scan, 'done');
end;

procedure TestScannerNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    IgnoreScanner(CreateScanner(IReader(nil), nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Scanner nil inner raises EArgumentError');
end;

procedure TestByteWriterStream;
var
  LS: IStream;
  LBW: IByteWriter;
  LBuf: array[0..1] of Byte;
begin
  LS := BytesStream(16);
  LBW := LS as IByteWriter;
  LBW.WriteByte($CA);
  LBW.WriteByte($FE);
  LS.Seek(0, soBeginning);
  LS.Read(LBuf[0], 2);
  CheckEqual(Byte($CA), LBuf[0]);
  CheckEqual(Byte($FE), LBuf[1]);
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
  T.Run('BufWriter flush zero-progress raises', @TestBufWriterFlushZeroProgressRaises);
  T.Run('BufWriter direct write zero-progress raises', @TestBufWriterDirectWriteZeroProgressRaises);

  T.Run('Copy', @TestCopy);
  T.Run('CopyN', @TestCopyN);
  T.Run('ReadAll', @TestReadAll);
  T.Run('ReadFull', @TestReadFull);
  T.Run('ReadFull short', @TestReadFullShort);
  T.Run('LimitReader', @TestLimitReader);
  T.Run('LimitReader nil inner', @TestLimitReaderNilInner);
  T.Run('TeeReader', @TestTeeReader);
  T.Run('TeeReader retries partial tap write', @TestTeeReaderRetriesPartialTapWrite);
  T.Run('TeeReader zero-progress tap raises', @TestTeeReaderZeroProgressTapRaises);
  T.Run('TeeReader nil inner', @TestTeeReaderNilInner);
  T.Run('TeeReader nil writer', @TestTeeReaderNilWriter);
  T.Run('MultiReader', @TestMultiReader);
  T.Run('MultiReader nil inner', @TestMultiReaderNilInner);
  T.Run('MultiWriter', @TestMultiWriter);
  T.Run('MultiWriter retries each writer to full payload',
    @TestMultiWriterRetriesEachWriterToFullPayload);
  T.Run('MultiWriter zero-progress raises', @TestMultiWriterZeroProgressRaises);
  T.Run('MultiWriter nil inner', @TestMultiWriterNilInner);
  T.Run('Discard', @TestDiscard);
  T.Run('NullReader', @TestNullReader);
  T.Run('NopCloser', @TestNopCloser);
  T.Run('NopCloser nil inner', @TestNopCloserNilInner);
  T.Run('WriteString', @TestWriteString);
  T.Run('ReadAtLeast', @TestReadAtLeast);
  T.Run('CopyBuffer', @TestCopyBuffer);

  T.Run('UnreadByte then Read', @TestUnreadByteThenRead);
  T.Run('Read zero after UnreadByte', @TestReadZeroAfterUnread);
  T.Run('BufReader zero size', @TestBufReaderZeroSize);
  T.Run('BufWriter zero size', @TestBufWriterZeroSize);
  T.Run('ReadAtLeast min>count', @TestReadAtLeastMinGtCount);

  T.Run('Pipe basic', @TestPipeBasic);
  T.Run('Pipe close writer EOF', @TestPipeCloseWriterEOF);
  T.Run('Pipe write after writer close raises',
    @TestPipeWriteAfterWriterCloseRaises);
  T.Run('Pipe read after reader close raises',
    @TestPipeReadAfterReaderCloseRaises);
  T.Run('Pipe reader release closes endpoint',
    @TestPipeReaderReleaseClosesEndpoint);
  T.Run('Pipe large data', @TestPipeLargeData);

  T.Run('ReaderAt', @TestReaderAt);
  T.Run('WriterAt', @TestWriterAt);
  T.Run('ByteReader stream', @TestByteReaderStream);
  T.Run('ByteScanner', @TestByteScanner);
  T.Run('StringWriter', @TestStringWriter);
  T.Run('SectionReader', @TestSectionReader);
  T.Run('SectionReader nil inner', @TestSectionReaderNilInner);

  T.Run('Scanner lines', @TestScannerLines);
  T.Run('Scanner CRLF', @TestScannerCRLF);
  T.Run('Scanner no trailing newline', @TestScannerNoTrailingNewline);
  T.Run('Scanner empty', @TestScannerEmpty);
  T.Run('Scanner empty lines', @TestScannerEmptyLines);
  T.Run('Scanner nil inner', @TestScannerNilInner);
  T.Run('ByteWriter stream', @TestByteWriterStream);

  T.Summary;
end.
