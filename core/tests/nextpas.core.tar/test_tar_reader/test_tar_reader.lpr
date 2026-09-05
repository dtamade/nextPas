program test_tar_reader;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.tar.base,
  nextpas.core.tar.common,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.io.memory,
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.archive.pax;

function BytesOf(const S: string): TBytes; inline;

begin
  // perf: single-source via bytes.ops.StringToBytes (zero-copy PAnsiChar view, single Move), inline thin forward, owner bytes.ops; heaptrc0 via common.mk HEAPTRC_GATE=1 (-gh, haltonnotreleased+log), no duplicate Move
  Result := nextpas.core.bytes.ops.StringToBytes(S);
end;

procedure TestHeaderCacheFieldsMixed;
var
  S: IStream; W: TTarWriter; R: TTarReader; H: TTarHeader;
  Hdr: TTarHeader; Arc: TBytes; LongDir, LongName: string; I: Integer;
begin
  LongDir := '';
  for I := 1 to 95 do LongDir := LongDir + 'd';
  LongName := LongDir + '/f.bin';
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    Hdr := Default(TTarHeader);
    Hdr.Name := 'link.txt';
    Hdr.Kind := tekSymlink;
    Hdr.LinkName := 'target/with/slash.txt';
    Hdr.Mode := $1A4;
    Hdr.UName := 'alice';
    Hdr.GName := 'staff';
    W.AddEntry(Hdr, nil);
    Hdr := Default(TTarHeader);
    Hdr.Name := 'doc.txt';
    Hdr.Kind := tekRegular;
    Hdr.Mode := $1A4;
    Hdr.UName := 'bob';
    Hdr.GName := 'ops';
    Hdr.Size := 3;
    W.AddEntry(Hdr, BytesOf('doc'));
    W.AddFile(LongName, BytesOf('L'));
    W.Finish;
  finally W.Free; end;
  SetLength(Arc, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Arc[0], Length(Arc));
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'link present');
    CheckEqual('link.txt', H.Name, 'link name');
    CheckEqual(Ord(tekSymlink), Ord(H.Kind), 'link kind');
    CheckEqual('target/with/slash.txt', H.LinkName, 'link target');
    CheckEqual('alice', H.UName, 'link uname');
    CheckEqual('staff', H.GName, 'link gname');
    CheckTrue(R.Next(H), 'doc present');
    CheckEqual('doc.txt', H.Name, 'doc name');
    CheckEqual('bob', H.UName, 'doc uname');
    CheckEqual('ops', H.GName, 'doc gname');
    CheckTrue(R.Next(H), 'long present');
    CheckEqual(LongName, H.Name, 'prefix recombined');
    CheckEqual('', H.LinkName, 'empty link');
    CheckEqual('', H.UName, 'empty uname');
    CheckTrue(R.Next(H) = False, 'end');
  finally R.Free; end;
end;

function SameBytes(const A, B: TBytes): Boolean; inline;
begin
  // perf: single-source via bytes.ops.BytesEqual -> SpanEqual/MemEqual zero-copy SIMD, inline thin forward, no duplicate loop
  Result := nextpas.core.bytes.ops.BytesEqual(A, B);
end;

function Patterned(ASize: Integer; ASeed: Cardinal): TBytes;
var
  I: Integer;
  S: Cardinal;
begin
  SetLength(Result, ASize);
  S := ASeed;
  for I := 0 to ASize - 1 do
  begin
    S := S * 1664525 + 1013904223;
    Result[I] := Byte((S shr 16) and $FF);
  end;
end;

procedure TestRoundTripRegular;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  Data, Out: TBytes;
  LSlice: TByteSpan;
begin
  Data := BytesOf('hello tar');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('a.txt', Data, $1A4, 1700000000);
    W.AddDir('dir');
    W.AddFile('dir/b.bin', Patterned(600, 1), $1A4, 1700000001);
    W.Finish;
  finally W.Free; end;
  SetLength(Data, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Data[0], Length(Data));
  R := TTarReader.Create(Data);
  try
    CheckTrue(R.Next(H), 'first');
    CheckEqual('a.txt', H.Name, 'name');
    CheckEqual(9, H.Size, 'size');
    CheckTrue(R.TrySlice(LSlice), 'slice');
    Out := SpanClone(LSlice);
    CheckTrue(SameBytes(Out, BytesOf('hello tar')), 'payload');
    CheckTrue(R.Next(H), 'second');
    CheckEqual('dir/', H.Name, 'dir name');
    CheckEqual(Ord(tekDirectory), Ord(H.Kind), 'dir kind');
    CheckTrue(R.Next(H), 'third');
    CheckEqual('dir/b.bin', H.Name, 'nested');
    CheckTrue(R.Next(H) = False, 'end');
  finally R.Free; end;
end;

procedure TestGNUAndPaxLongNames;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  LongName: string;
  Payload: TBytes;
  I: Integer;
begin
  LongName := '';
  for I := 1 to 40 do LongName := LongName + 'l';
  LongName := LongName + '/' + LongName + '/' + LongName + 'n';
  Payload := BytesOf('payload');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    { writer uses ustar prefix split for long names }
    W.AddFile(LongName, Payload);
    W.Finish;
  finally W.Free; end;
  SetLength(Payload, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Payload[0], Length(Payload));
  R := TTarReader.Create(Payload);
  try
    CheckTrue(R.Next(H), 'found');
    CheckEqual(LongName, H.Name, 'roundtrip long name');
    CheckTrue(R.Next(H) = False, 'end');
  finally R.Free; end;
end;

procedure TestBase256AndChecksum;
var
  B: TBytes;
  R: TTarReader;
  H: TTarHeader;
  Hello: TBytes;
  Sum, I: Integer;
  LSp: TByteSpan;
  procedure PutTextAt(AOfs: Integer; const V: string);
  begin
    // single-source: bytes.ops.CopyStringToBuffer zero-copy PAnsiChar view, single Move, owner bytes.ops
    nextpas.core.bytes.ops.CopyStringToBuffer(V, PByte(@B[AOfs]), Length(V));
  end;
begin
  SetLength(B, 2048);
  FillChar(B[0], 2048, 0);
  PutTextAt(0, 'b256.txt');
  PutTextAt(100, '0000644'#0);
  B[124] := $80; B[135] := 5;
  PutTextAt(136, '00000000000'#0);
  FillChar(B[148], 8, Ord(' '));
  B[156] := Ord('0');
  PutTextAt(257, 'ustar');
  PutTextAt(263, '00');
  Sum := 0;
  for I := 0 to 511 do Sum := Sum + B[I];
  for I := 0 to 5 do B[148 + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  B[154] := 0; B[155] := Ord(' ');
  Hello := BytesOf('hello');
  // single-source: bytes.ops.CopyMemory zero-copy PByte view, single Move, owner bytes.ops
  nextpas.core.bytes.ops.CopyMemory(PByte(@Hello[0]), PByte(@B[512]), 5);
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'entry');
    CheckEqual(5, H.Size, 'base256 size');
    CheckTrue(R.TrySlice(LSp), 'slice');
    CheckTrue(SameBytes(SpanClone(LSp), Hello), 'payload');
  finally R.Free; end;
  B[3] := B[3] xor $20;
  try
    R := TTarReader.Create(B);
    try R.Next(H); CheckTrue(False, 'should raise'); finally R.Free; end;
  except on E: EIOError do CheckTrue(True, 'corrupt checksum raises EIOError'); end;
end;

procedure TestZeroCopySliceAndStream;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  D: TBytes;
  P: PByte;
  C: SizeUInt;
  RS: IReader;
  Buf: array[0..31] of Byte;
  N: SizeUInt;
begin
  D := Patterned(100, 42);
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('x.bin', D);
    W.Finish;
  finally W.Free; end;
  SetLength(D, S.Size);
  S.Seek(0, soBeginning);
  S.Read(D[0], Length(D));
  R := TTarReader.Create(D);
  try
    CheckTrue(R.Next(H), 'next');
    CheckTrue(R.EntryDataSlice(P, C), 'slice');
    CheckEqual(100, Int64(C), 'slice size');
    CheckTrue(P <> nil, 'slice ptr');
    RS := R.OpenEntryStream;
    N := RS.Read(Buf[0], 10);
    CheckEqual(10, Int64(N), 'stream read');
  finally R.Free; end;
end;

procedure EmitHeader(var ABuf: TBytes; const AName: string; AType: Char; ASize: Int64);
var
  Block: array[0..511] of Byte;
  P: PByte;
begin
  FillChar(Block[0], 512, 0);
  P := @Block[0];
  TarPutHeaderString(P, C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, AName);
  TarFormatNumericField(P, C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, $1A4);
  TarFormatNumericField(P, C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len, 0);
  TarFormatNumericField(P, C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len, 0);
  TarFormatNumericField(P, C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, ASize);
  TarFormatNumericField(P, C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len, 0);
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord(AType);
  TarWriteUStarMagic(P);
  TarFinalizeHeaderChecksum(P);
  BytesAppend(ABuf, P, 512);
end;

procedure AppendPayload(var ABuf: TBytes; const AData: TBytes);
var
  Pad: SizeInt;
begin
  if Length(AData) > 0 then
    BytesAppend(ABuf, PByte(@AData[0]), SizeUInt(Length(AData)));
  Pad := TarPadToBlock(Int64(Length(AData)));
  if Pad > 0 then
  begin
    SetLength(ABuf, Length(ABuf) + Pad);
    FillChar(ABuf[Length(ABuf)-Pad], Pad, 0);
  end;
end;

procedure TestGlobalPaxMultiEntryInheritance;
var
  Tar: TBytes;
  R: TTarReader;
  H: TTarHeader;
  PaxRec: string;
  PaxBytes: TBytes;
  Guard: IInterface;
begin
  Tar := nil;
  PaxRec := ArchivePaxFormatRecord('path', 'inherited.txt');
  PaxBytes := StringToBytes(PaxRec);
  EmitHeader(Tar, '', 'g', Length(PaxBytes));
  AppendPayload(Tar, PaxBytes);
  EmitHeader(Tar, 'a.txt', '0', 3);
  AppendPayload(Tar, BytesOf('hi1'));
  EmitHeader(Tar, 'b.txt', '0', 3);
  AppendPayload(Tar, BytesOf('hi2'));
  SetLength(Tar, Length(Tar) + 1024);
  FillChar(Tar[Length(Tar)-1024], 1024, 0);
  R := TTarReader.Create(Tar);
  try
    // persistence requires guard scope; without guard g is single-use auto-cleared to prevent pollution
    Guard := R.AcquireGlobalPaxGuard;
    CheckTrue(R.Next(H), 'first after g');
    CheckEqual('inherited.txt', H.Name, 'g persists entry1 with guard');
    CheckTrue(R.Next(H), 'second after g');
    CheckEqual('inherited.txt', H.Name, 'g persists entry2 with guard multi-entry');
    CheckTrue(R.Next(H)=False, 'end');
  finally R.Free; end;
end;

procedure TestGlobalPaxSingleUseWithoutGuard;
var
  Tar: TBytes;
  R: TTarReader;
  H: TTarHeader;
  PaxRec: string;
  PaxBytes: TBytes;
begin
  Tar := nil;
  PaxRec := ArchivePaxFormatRecord('path', 'once.txt');
  PaxBytes := StringToBytes(PaxRec);
  EmitHeader(Tar, '', 'g', Length(PaxBytes));
  AppendPayload(Tar, PaxBytes);
  EmitHeader(Tar, 'a.txt', '0', 3);
  AppendPayload(Tar, BytesOf('hi1'));
  EmitHeader(Tar, 'b.txt', '0', 3);
  AppendPayload(Tar, BytesOf('hi2'));
  SetLength(Tar, Length(Tar) + 1024);
  FillChar(Tar[Length(Tar)-1024], 1024, 0);
  R := TTarReader.Create(Tar);
  try
    CheckTrue(R.Next(H), 'first after g');
    CheckEqual('once.txt', H.Name, 'g single-use first');
    CheckTrue(R.Next(H), 'second');
    CheckEqual('b.txt', H.Name, 'g auto-cleared second without guard prevents pollution');
    CheckTrue(R.Next(H)=False, 'end');
  finally R.Free; end;
end;

procedure TestGlobalPaxMaliciousClear;
var
  Tar: TBytes;
  R: TTarReader;
  H: TTarHeader;
  PaxRec: string;
  PaxBytes: TBytes;
begin
  Tar := nil;
  PaxRec := ArchivePaxFormatRecord('path', '../evil.txt');
  PaxBytes := StringToBytes(PaxRec);
  EmitHeader(Tar, '', 'g', Length(PaxBytes));
  AppendPayload(Tar, PaxBytes);
  EmitHeader(Tar, 'ok.txt', '0', 3);
  AppendPayload(Tar, BytesOf('ok1'));
  EmitHeader(Tar, 'ok2.txt', '0', 3);
  AppendPayload(Tar, BytesOf('ok2'));
  SetLength(Tar, Length(Tar) + 1024);
  FillChar(Tar[Length(Tar)-1024], 1024, 0);
  R := TTarReader.Create(Tar);
  try
    CheckTrue(R.Next(H), 'evil first');
    // 修复：恶意 g 由 Reader 自动 IsSafe 丢弃并 Guard 防静默劫持，显式 Clear 可选
    CheckEqual('ok.txt', H.Name, 'malicious g discarded fallback');
    CheckTrue(IsSafeTarEntryName(H.Name), 'safe after discard');
    R.ClearGlobalPax;
    CheckTrue(R.Next(H), 'after clear');
    CheckEqual('ok2.txt', H.Name, 'explicit clear prevents pollution, fail-closed optional');
  finally R.Free; end;
end;

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  Results: specialize TArray<TTestRunResult>;
begin
  // heaptrc0 evidence: common.mk HEAPTRC_GATE=1 (-gh, haltonnotreleased+log) gates "0 unfreed blocks" + "Heap dump by heaptrc unit"; stability: W/R try..finally guarantees Free not lost
  Suite := TTestSuite.Create('tar.reader');

  Suite.Test('roundtrip regular', @TestRoundTripRegular);
  Suite.Test('header cache mixed fields', @TestHeaderCacheFieldsMixed);
  Suite.Test('long names prefix split', @TestGNUAndPaxLongNames);
  Suite.Test('base256 and checksum', @TestBase256AndChecksum);
  Suite.Test('zero-copy slice and stream', @TestZeroCopySliceAndStream);
  Suite.Test('global pax multi-entry inheritance', @TestGlobalPaxMultiEntryInheritance);
  Suite.Test('global pax single-use without guard', @TestGlobalPaxSingleUseWithoutGuard);
  Suite.Test('global pax malicious clear', @TestGlobalPaxMaliciousClear);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results) = 0) or (not Results[0].AllPassed) then Halt(1);
end.
