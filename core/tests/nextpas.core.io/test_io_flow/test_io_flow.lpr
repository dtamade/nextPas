program test_io_flow;

{$I nextpas.core.settings.inc}

uses
  SysUtils, nextpas.core.fs,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.text.view,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.buffer,
  nextpas.core.io.scanner,
  nextpas.core.io.linewriter,
  nextpas.core.io.collect,
  nextpas.core.io.mapped,
  nextpas.core.io.base;

var
  T: TTestRunner;

type
  TZeroProgressWriter = class(TInterfacedObject, IWriter)
  private
    FCalls: Int32;
    FZeroOnCall: Int32;
  public
    constructor Create(const AZeroOnCall: Int32);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    property Calls: Int32 read FCalls;
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
  FZeroOnCall := AZeroOnCall;
end;

function TZeroProgressWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Inc(FCalls);
  if FCalls >= FZeroOnCall then
    Exit(0);
  Result := ACount;
end;

constructor TPartialForwardingWriter.Create(const AInner: IWriter;
  const AMaxWrite: SizeUInt);
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

{ === LineWriter Tests === }

procedure TestLineWriterBasic;
var
  LBuf: IStream;
  LW: ILineWriter;
  LData: TBytes;
begin
  LBuf := CreateBytesStream;
  LW := CreateLineWriter(LBuf as IWriter);
  LW.WriteLine('hello');
  LW.WriteLine('world');
  LBuf.Seek(0, soBeginning);
  SetLength(LData, LBuf.Size);
  (LBuf as IReader).Read(LData[0], Length(LData));
  Check(Length(LData) = 12, 'linewriter 2 lines = 12 bytes');
  Check((LData[0] = Ord('h')) and (LData[5] = 10), 'content correct');
end;

procedure TestLineWriterEmpty;
var
  LBuf: IStream;
  LW: ILineWriter;
begin
  LBuf := CreateBytesStream;
  LW := CreateLineWriter(LBuf as IWriter);
  LW.WriteLine('');
  Check(LBuf.Size = 1, 'empty line = just newline');
end;

procedure TestLineWriterRetriesPartialWriter;
var
  LBuf: IStream;
  LPartialObj: TPartialForwardingWriter;
  LPartial: IWriter;
  LW: ILineWriter;
  LData: TBytes;
begin
  LBuf := CreateBytesStream;
  LPartialObj := TPartialForwardingWriter.Create(LBuf as IWriter, 2);
  LPartial := LPartialObj;
  LW := CreateLineWriter(LPartial);

  LW.WriteLine('hello');

  CheckEqual(Int64(4), Int64(LPartialObj.Calls),
    'LineWriter retries body writes and writes newline');
  CheckEqual(Int64(6), LBuf.Size, 'LineWriter wrote full line');
  LBuf.Seek(0, soBeginning);
  SetLength(LData, LBuf.Size);
  (LBuf as IReader).Read(LData[0], Length(LData));
  Check((LData[0] = Ord('h')) and (LData[4] = Ord('o')) and
    (LData[5] = 10), 'LineWriter content correct');
end;

procedure TestLineWriterZeroProgressRaises;
var
  LZeroObj: TZeroProgressWriter;
  LZero: IWriter;
  LW: ILineWriter;
  LRaised: Boolean;
begin
  LZeroObj := TZeroProgressWriter.Create(1);
  LZero := LZeroObj;
  LW := CreateLineWriter(LZero);

  LRaised := False;
  try
    LW.WriteLine('abc');
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'LineWriter zero-progress write raises EIOError');
  CheckEqual(Int64(1), Int64(LZeroObj.Calls), 'LineWriter attempted one write');
end;

procedure TestLineWriterFlushForwardsInnerFlusher;
var
  LBuf: IStream;
  LBuffered: IWriter;
  LW: ILineWriter;
begin
  LBuf := CreateBytesStream;
  LBuffered := CreateBufferedWriter(LBuf as IWriter, 32);
  LW := CreateLineWriter(LBuffered);

  LW.WriteLine('hello');
  CheckEqual(Int64(0), LBuf.Size, 'buffered inner writer holds data before flush');

  LW.Flush;

  CheckEqual(Int64(6), LBuf.Size, 'LineWriter.Flush forwards to inner flusher');
end;

procedure TestIoWriteLines;
var
  LBuf: IStream;
begin
  LBuf := CreateBytesStream;
  IoWriteLines(LBuf as IWriter, TStringArray.Create('a', 'b', 'c'));
  Check(LBuf.Size = 6, '3 lines a\nb\nc\n = 6 bytes');
end;

procedure TestIoWriteLineRetriesPartialWriter;
var
  LBuf: IStream;
  LPartialObj: TPartialForwardingWriter;
  LPartial: IWriter;
begin
  LBuf := CreateBytesStream;
  LPartialObj := TPartialForwardingWriter.Create(LBuf as IWriter, 2);
  LPartial := LPartialObj;

  IoWriteLine(LPartial, 'hello');

  CheckEqual(Int64(4), Int64(LPartialObj.Calls),
    'IoWriteLine retries body writes and writes newline');
  CheckEqual(Int64(6), LBuf.Size, 'IoWriteLine wrote full line');
end;

procedure TestIoWriteLineZeroProgressRaises;
var
  LZeroObj: TZeroProgressWriter;
  LZero: IWriter;
  LRaised: Boolean;
begin
  LZeroObj := TZeroProgressWriter.Create(1);
  LZero := LZeroObj;

  LRaised := False;
  try
    IoWriteLine(LZero, 'abc');
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'IoWriteLine zero-progress write raises EIOError');
  CheckEqual(Int64(1), Int64(LZeroObj.Calls), 'IoWriteLine attempted one write');
end;

{ === Collect Tests === }

procedure TestCollectLinesBasic;
var
  LBuf: IStream;
  LScanner: IScanner;
  LLines: TStringArray;
begin
  LBuf := CreateBytesStreamFrom(TBytes.Create(
    Ord('l'), Ord('i'), Ord('n'), Ord('e'), Ord('1'), 10,
    Ord('l'), Ord('i'), Ord('n'), Ord('e'), Ord('2'), 10,
    Ord('l'), Ord('i'), Ord('n'), Ord('e'), Ord('3')));
  LScanner := CreateScanner(LBuf as IReader);
  LLines := CollectLines(LScanner);
  CheckEqual(Int64(3), Int64(Length(LLines)), 'collect 3 lines');
  Check(LLines[0] = 'line1', 'line 0');
  Check(LLines[1] = 'line2', 'line 1');
  Check(LLines[2] = 'line3', 'line 2');
end;

procedure TestCollectLinesEmpty;
var
  LBuf: IStream;
  LScanner: IScanner;
  LLines: TStringArray;
begin
  LBuf := CreateBytesStreamFrom(nil);
  LScanner := CreateScanner(LBuf as IReader);
  LLines := CollectLines(LScanner);
  CheckEqual(Int64(0), Int64(Length(LLines)), 'collect empty');
end;

procedure TestCollectLinesFrom;
var
  LBuf: IStream;
  LLines: TStringArray;
begin
  LBuf := CreateBytesStreamFrom(TBytes.Create(
    Ord('a'), 10, Ord('b'), 10));
  LLines := CollectLinesFrom(LBuf as IReader);
  CheckEqual(Int64(2), Int64(Length(LLines)), 'collectfrom 2 lines');
  Check(LLines[0] = 'a', 'a');
  Check(LLines[1] = 'b', 'b');
end;

procedure TestCollectLinesLarge;
var
  LData: TBytes;
  LBuf: IStream;
  LLines: TStringArray;
  LI: Int32;
begin
  // 1000 lines
  SetLength(LData, 6000);
  for LI := 0 to 999 do
  begin
    LData[LI * 6 + 0] := Ord('L');
    LData[LI * 6 + 1] := Ord('0') + ((LI div 100) mod 10);
    LData[LI * 6 + 2] := Ord('0') + ((LI div 10) mod 10);
    LData[LI * 6 + 3] := Ord('0') + (LI mod 10);
    LData[LI * 6 + 4] := Ord('!');
    LData[LI * 6 + 5] := 10;
  end;
  LBuf := CreateBytesStreamFrom(LData);
  LLines := CollectLinesFrom(LBuf as IReader);
  CheckEqual(Int64(1000), Int64(Length(LLines)), '1000 lines');
  Check(LLines[0] = 'L000!', 'first');
  Check(LLines[999] = 'L999!', 'last');
end;

{ === Mapped Tests === }

procedure TestMmapOpen;
var
  LPath: string;
  LF: IMappedFile;
begin
  LPath := '/tmp/test_mmap_' + IntToStr(Random(99999)) + '.txt';
  WriteFileText(LPath, 'hello mmap');
  LF := MmapOpen(LPath);
  CheckEqual(Int64(10), LF.Size, 'mmap size');
  Check(LF.Data <> nil, 'mmap data not nil');
  Check(LF.AsView.ToString = 'hello mmap', 'mmap content');
  LF := nil;
  DeleteFile(LPath);
end;

procedure TestMmapLines;
var
  LPath: string;
  LM: IMappedLines;
begin
  LPath := '/tmp/test_mmap_lines_' + IntToStr(Random(99999)) + '.txt';
  WriteFileText(LPath, 'line1' + #10 + 'line2' + #10 + 'line3');
  LM := MmapLines(LPath);
  CheckEqual(Int64(3), Int64(LM.Count), 'mmap 3 lines');
  Check(LM.Line(0).ToString = 'line1', 'mmap line 0');
  Check(LM.Line(1).ToString = 'line2', 'mmap line 1');
  Check(LM.Line(2).ToString = 'line3', 'mmap line 2');
  LM := nil;
  DeleteFile(LPath);
end;

procedure TestMmapLinesSearch;
var
  LPath: string;
  LM: IMappedLines;
begin
  LPath := '/tmp/test_mmap_search_' + IntToStr(Random(99999)) + '.txt';
  WriteFileText(LPath, 'info: ok' + #10 + 'error: fail' + #10 + 'info: done');
  LM := MmapLines(LPath);
  Check(LM.Contains('error'), 'contains error');
  Check(not LM.Contains('warning'), 'not contains warning');
  CheckEqual(Int64(1), Int64(LM.IndexOf('error')), 'indexOf error = 1');
  CheckEqual(Int64(-1), Int64(LM.IndexOf('missing')), 'indexOf missing = -1');
  LM := nil;
  DeleteFile(LPath);
end;

procedure TestMmapEmpty;
var
  LPath: string;
  LM: IMappedLines;
begin
  LPath := '/tmp/test_mmap_empty_' + IntToStr(Random(99999)) + '.txt';
  WriteFileText(LPath, '');
  LM := MmapLines(LPath);
  CheckEqual(Int64(0), Int64(LM.Count), 'mmap empty = 0 lines');
  LM := nil;
  DeleteFile(LPath);
end;

procedure TestMmapCRLF;
var
  LPath: string;
  LM: IMappedLines;
begin
  LPath := '/tmp/test_mmap_crlf_' + IntToStr(Random(99999)) + '.txt';
  WriteFileText(LPath, 'win' + #13#10 + 'line');
  LM := MmapLines(LPath);
  CheckEqual(Int64(2), Int64(LM.Count), 'crlf 2 lines');
  Check(LM.Line(0).ToString = 'win', 'crlf strips CR');
  Check(LM.Line(1).ToString = 'line', 'crlf line 2');
  LM := nil;
  DeleteFile(LPath);
end;

{ === Integration: Write then Read === }

procedure TestWriteThenCollect;
var
  LBuf: IStream;
  LW: ILineWriter;
  LLines: TStringArray;
begin
  LBuf := CreateBytesStream;
  LW := CreateLineWriter(LBuf as IWriter);
  LW.WriteLine('alpha');
  LW.WriteLine('beta');
  LW.WriteLine('gamma');
  LBuf.Seek(0, soBeginning);
  LLines := CollectLinesFrom(LBuf as IReader);
  CheckEqual(Int64(3), Int64(Length(LLines)), 'write-then-collect 3');
  Check(LLines[0] = 'alpha', 'alpha');
  Check(LLines[2] = 'gamma', 'gamma');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.flow');
  T.Run('LineWriter basic', @TestLineWriterBasic);
  T.Run('LineWriter empty', @TestLineWriterEmpty);
  T.Run('LineWriter retries partial writer',
    @TestLineWriterRetriesPartialWriter);
  T.Run('LineWriter zero-progress raises',
    @TestLineWriterZeroProgressRaises);
  T.Run('LineWriter flush forwards inner flusher',
    @TestLineWriterFlushForwardsInnerFlusher);
  T.Run('IoWriteLines', @TestIoWriteLines);
  T.Run('IoWriteLine retries partial writer',
    @TestIoWriteLineRetriesPartialWriter);
  T.Run('IoWriteLine zero-progress raises',
    @TestIoWriteLineZeroProgressRaises);
  T.Run('CollectLines basic', @TestCollectLinesBasic);
  T.Run('CollectLines empty', @TestCollectLinesEmpty);
  T.Run('CollectLinesFrom', @TestCollectLinesFrom);
  T.Run('CollectLines 1000', @TestCollectLinesLarge);
  T.Run('Mmap open', @TestMmapOpen);
  T.Run('Mmap lines', @TestMmapLines);
  T.Run('Mmap search', @TestMmapLinesSearch);
  T.Run('Mmap empty', @TestMmapEmpty);
  T.Run('Mmap CRLF', @TestMmapCRLF);
  T.Run('Write then collect', @TestWriteThenCollect);
  T.Summary;
end.
