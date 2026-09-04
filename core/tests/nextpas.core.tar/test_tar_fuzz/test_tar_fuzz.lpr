program test_tar_fuzz;

{**
 * @desc tar 随机/边界 fuzz 门禁：随机载荷与随机名往返、边界尺寸、
 *   损坏输入不崩溃、bomb 上限、writer 资源语义、builder 等价、fs 确定性与落盘安全。
 *   全固定种子 LCG，可复现；驱动真实公共入口并断言真实行为。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.bytes.ops,
  nextpas.core.tar.base,
  nextpas.core.tar.common,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.tar.builder,
  nextpas.core.tar.fs,
  nextpas.core.archive.pax,
  nextpas.core.archive.fs,
  nextpas.core.fs,
  nextpas.core.fs.base;

var
  GSeed: Cardinal;

procedure RandInit(ASeed: Cardinal); inline;
begin
  GSeed := ASeed;
end;

function RandNext: Cardinal; inline;
begin
  GSeed := GSeed * 1664525 + 1013904223;
  Result := GSeed;
end;

function RandRange(AN: Cardinal): Cardinal; inline;
begin
  Result := RandNext mod AN;
end;

function RandomBytes(ALen: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := Byte((RandNext shr 16) and $FF);
end;

function RandomSeg(AMin, AMax: Integer): string;
const
  C_ALPH = 'abcdefghijklmnopqrstuvwxyz0123456789_-';
var
  L, I: Integer;
begin
  L := AMin + Integer(RandRange(Cardinal(AMax - AMin + 1)));
  SetLength(Result, L);
  for I := 1 to L do
    Result[I] := C_ALPH[1 + Integer(RandRange(38))];
end;

function RandomName: string;
var
  R: Cardinal;
begin
  { 70% 普通短路径，15% 无斜杠超长（pax x 回退），15% 深路径（prefix 分割） }
  R := RandRange(100);
  if R < 70 then
  begin
    Result := RandomSeg(1, 12);
    if RandRange(3) = 0 then
      Result := Result + '/' + RandomSeg(1, 12);
    if RandRange(4) = 0 then
      Result := Result + '/' + RandomSeg(1, 12);
  end
  else if R < 85 then
    Result := RandomSeg(101, 160)
  else
    Result := RandomSeg(40, 69) + '/' + RandomSeg(60, 99);
end;

function RandomSize: Integer;
const
  C_EDGE: array[0..10] of Integer = (0, 1, 2, 511, 512, 513, 1023, 1024, 4095, 4096, 4097);
begin
  if RandRange(2) = 0 then
    Result := C_EDGE[RandRange(11)]
  else
    Result := Integer(RandRange(3000));
end;

function Snapshot(S: IStream): TBytes;
begin
  SetLength(Result, S.Size);
  if Length(Result) > 0 then
  begin
    S.Seek(0, soBeginning);
    S.Read(Result[0], Length(Result));
  end;
end;

function ReadAll(const RS: IReader; ASize: Integer): TBytes;
var
  Got, N: Integer;
begin
  SetLength(Result, ASize);
  Got := 0;
  while Got < ASize do
  begin
    N := Integer(RS.Read(Result[Got], SizeUInt(ASize - Got)));
    if N = 0 then
      Break;
    Inc(Got, N);
  end;
  SetLength(Result, Got);
end;

procedure EmitRawHeader(var ABuf: TBytes; const AName: string; AType: Char; ASize: Int64);
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
    FillChar(ABuf[Length(ABuf) - Pad], Pad, 0);
  end;
end;

procedure AppendZeros(var ABuf: TBytes; ACount: Integer);
var
  Old: Integer;
begin
  Old := Length(ABuf);
  SetLength(ABuf, Old + ACount);
  FillChar(ABuf[Old], ACount, 0);
end;

type
  TExpEntry = record
    Hdr: TTarHeader;
    Data: TBytes;
  end;
  TExpArray = array of TExpEntry;
  TSparseTestSeg = record Off, Len: Int64; end;

procedure BuildRandomArchive(out AArc: TBytes; out AExp: TExpArray; ACount: Integer);
var
  S: IStream;
  W: TTarWriter;
  I, R: Integer;
  E: TExpEntry;
begin
  SetLength(AExp, ACount);
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    for I := 0 to ACount - 1 do
    begin
      E.Hdr := Default(TTarHeader);
      E.Hdr.Name := RandomName;
      R := Integer(RandRange(100));
      if R < 60 then
        E.Hdr.Kind := tekRegular
      else if R < 70 then
        E.Hdr.Kind := tekDirectory
      else if R < 76 then
        E.Hdr.Kind := tekSymlink
      else if R < 80 then
        E.Hdr.Kind := tekHardLink
      else if R < 84 then
        E.Hdr.Kind := tekFifo
      else if R < 88 then
        E.Hdr.Kind := tekCharDevice
      else if R < 92 then
        E.Hdr.Kind := tekBlockDevice
      else
        E.Hdr.Kind := tekRegular;
      E.Hdr.Mode := RandRange(4096);
      if RandRange(4) = 0 then
        E.Hdr.UID := Int64($1FFFFFFFFF) - RandRange(1000)
      else
        E.Hdr.UID := RandRange(2000);
      if RandRange(4) = 0 then
        E.Hdr.GID := Int64($123456789) + RandRange(1000)
      else
        E.Hdr.GID := RandRange(2000);
      if RandRange(4) = 0 then
        E.Hdr.MTimeUnix := Int64($123456789AB) + RandRange(1000)
      else
        E.Hdr.MTimeUnix := Int64(1700000000) + RandRange(100000);
      if RandRange(2) = 0 then
        E.Hdr.UName := 'u' + RandomSeg(1, 8)
      else
        E.Hdr.UName := '';
      if RandRange(2) = 0 then
        E.Hdr.GName := 'g' + RandomSeg(1, 8)
      else
        E.Hdr.GName := '';
      E.Hdr.DevMajor := RandRange(4);
      E.Hdr.DevMinor := RandRange(8);
      if E.Hdr.Kind = tekRegular then
      begin
        E.Hdr.Size := RandomSize;
        E.Data := RandomBytes(Integer(E.Hdr.Size));
      end
      else
      begin
        E.Hdr.Size := 0;
        E.Data := nil;
        if (E.Hdr.Kind = tekSymlink) or (E.Hdr.Kind = tekHardLink) then
          E.Hdr.LinkName := 'target-' + RandomSeg(1, 8) + '.txt';
      end;
      if E.Hdr.Kind = tekDirectory then
        E.Hdr.Name := E.Hdr.Name + '/';
      W.AddEntry(E.Hdr, E.Data);
      AExp[I] := E;
    end;
    W.Finish;
  finally
    W.Free;
  end;
  AArc := Snapshot(S);
end;

procedure TestFuzzRoundTrip;
var
  Arc: TBytes;
  Exp: TExpArray;
  R: TTarReader;
  H: TTarHeader;
  I: Integer;
  LSlice: TByteSpan;
  P: PByte;
  C: SizeUInt;
  RS: IReader;
begin
  RandInit(20260905);
  BuildRandomArchive(Arc, Exp, 80);
  CheckTrue(Length(Arc) mod 512 = 0, 'archive block aligned');
  R := TTarReader.Create(Arc);
  try
    for I := 0 to High(Exp) do
    begin
      CheckTrue(R.Next(H), 'entry present');
      CheckEqual(Exp[I].Hdr.Name, H.Name, 'name');
      CheckEqual(Int64(Ord(Exp[I].Hdr.Kind)), Int64(Ord(H.Kind)), 'kind');
      CheckEqual(Int64(Exp[I].Hdr.Mode), Int64(H.Mode), 'mode');
      CheckEqual(Int64(Exp[I].Hdr.UID), Int64(H.UID), 'uid');
      CheckEqual(Int64(Exp[I].Hdr.GID), Int64(H.GID), 'gid');
      CheckEqual(Exp[I].Hdr.Size, H.Size, 'size');
      CheckEqual(Exp[I].Hdr.MTimeUnix, H.MTimeUnix, 'mtime');
      CheckEqual(Exp[I].Hdr.UName, H.UName, 'uname');
      CheckEqual(Exp[I].Hdr.GName, H.GName, 'gname');
      CheckEqual(Exp[I].Hdr.DevMajor, H.DevMajor, 'devmajor');
      CheckEqual(Exp[I].Hdr.DevMinor, H.DevMinor, 'devminor');
      if Exp[I].Hdr.Kind = tekRegular then
        CheckEqual(Exp[I].Hdr.LinkName, H.LinkName, 'linkname')
      else if (Exp[I].Hdr.Kind = tekSymlink) or (Exp[I].Hdr.Kind = tekHardLink) then
        CheckEqual(Exp[I].Hdr.LinkName, H.LinkName, 'link target');
      if Length(Exp[I].Data) > 0 then
      begin
        CheckTrue(R.TrySlice(LSlice), 'slice');
        CheckTrue(BytesEqual(Exp[I].Data, SpanClone(LSlice)), 'payload');
        CheckTrue(R.EntryDataSlice(P, C), 'slice ptr');
        CheckTrue((C = LSlice.Len) and (P = LSlice.Data), 'slice consistent');
        if I mod 8 = 0 then
        begin
          RS := R.OpenEntryStream;
          CheckTrue(BytesEqual(Exp[I].Data, ReadAll(RS, Length(Exp[I].Data))), 'stream');
        end;
      end
      else
        CheckTrue(R.TrySlice(LSlice) = False, 'empty no slice');
    end;
    CheckTrue(R.Next(H) = False, 'end of archive');
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
  SetLength(Exp, 0);
end;

procedure TestFuzzBoundarySizes;
const
  C_SIZES: array[0..11] of Integer = (0, 1, 511, 512, 513, 1023, 1024, 4095, 4096, 4097, 65535, 65536);
var
  I: Integer;
  Data, Arc: TBytes;
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  LSlice: TByteSpan;
begin
  for I := 0 to High(C_SIZES) do
  begin
    Data := RandomBytes(C_SIZES[I]);
    S := CreateBytesStream;
    W := TTarWriter.Create(S as IWriter);
    try
      W.AddFile('edge.bin', Data);
      W.Finish;
    finally
      W.Free;
    end;
    Arc := Snapshot(S);
    R := TTarReader.Create(Arc);
    try
      CheckTrue(R.Next(H), 'edge present');
      CheckEqual(Int64(C_SIZES[I]), H.Size, 'edge size');
      if C_SIZES[I] > 0 then
      begin
        CheckTrue(R.TrySlice(LSlice), 'edge slice');
        CheckTrue(BytesEqual(Data, SpanClone(LSlice)), 'edge payload');
      end;
      CheckTrue(R.Next(H) = False, 'edge end');
    finally
      R.Free;
    end;
    SetLength(Data, 0);
    SetLength(Arc, 0);
  end;
end;

procedure TestFuzzCorruptNoCrash;
var
  Base, Mut: TBytes;
  Exp: TExpArray;
  I, J, Clean, Raised: Integer;
  R: TTarReader;
  H: TTarHeader;
  LSlice: TByteSpan;
  Op: Cardinal;
  Cut: Integer;
begin
  RandInit(77);
  BuildRandomArchive(Base, Exp, 10);
  SetLength(Exp, 0);
  Clean := 0;
  Raised := 0;
  for I := 1 to 200 do
  begin
    Mut := nil;
    SetLength(Mut, Length(Base));
    if Length(Base) > 0 then
      for J := 0 to High(Base) do
        Mut[J] := Base[J];
    Op := RandRange(3);
    if Op = 0 then
      Mut[Integer(RandRange(Cardinal(Length(Mut))))] :=
        Byte(Mut[Integer(RandRange(Cardinal(Length(Mut))))] xor (1 shl Integer(RandRange(8))))
    else if Op = 1 then
    begin
      Cut := Length(Mut) - Integer(RandRange(Cardinal(Length(Mut) div 2) + 1)) - 1;
      if Cut < 1 then
        Cut := 1;
      SetLength(Mut, Cut);
    end
    else
      AppendPayload(Mut, RandomBytes(Integer(RandRange(600))));
    R := TTarReader.Create(Mut);
    try
      try
        while R.Next(H) do
          if R.TrySlice(LSlice) then
            CheckTrue((LSlice.Len = 0) or (LSlice.Data <> nil), 'touch slice');
        Inc(Clean);
      except
        on E: EIOError do
          Inc(Raised);
        on E: EParseError do
          Inc(Raised);
        on E: Exception do
          CheckTrue(False, 'unexpected exception: ' + E.ClassName);
      end;
    finally
      R.Free;
    end;
    SetLength(Mut, 0);
  end;
  CheckTrue(Raised > 0, 'corruption detected sometimes');
  CheckTrue(Clean > 0, 'benign mutations still parse');
  SetLength(Base, 0);
end;

procedure TestGnuLongNameLink;
var
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  LongName, LongLink: string;
  LSlice: TByteSpan;
begin
  LongName := 'L0123456789';
  while Length(LongName) < 300 do
    LongName := LongName + 'n';
  Arc := nil;
  EmitRawHeader(Arc, './@LongLink', 'L', Length(LongName));
  AppendPayload(Arc, StringToBytes(LongName));
  EmitRawHeader(Arc, 'short.txt', '0', 4);
  AppendPayload(Arc, StringToBytes('data'));
  LongLink := 'K0123456789';
  while Length(LongLink) < 200 do
    LongLink := LongLink + 'k';
  EmitRawHeader(Arc, 'alias.txt', 'K', Length(LongLink));
  AppendPayload(Arc, StringToBytes(LongLink));
  EmitRawHeader(Arc, 'dummy', '2', 0);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'longname entry');
    CheckEqual(LongName, H.Name, 'gnu L overrides name');
    CheckTrue(R.TrySlice(LSlice), 'longname payload');
    CheckTrue(BytesEqual(StringToBytes('data'), SpanClone(LSlice)), 'longname data');
    CheckTrue(R.Next(H), 'longlink entry');
    CheckEqual(LongLink, H.LinkName, 'gnu K overrides linkname');
    CheckEqual(Ord(tekSymlink), Ord(H.Kind), 'symlink kind kept');
    CheckTrue(R.Next(H) = False, 'gnu end');
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
end;

procedure TestPaxFullKeywords;
var
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  Pax: string;
  I: Integer;
  FoundComment, FoundAtime, FoundMTime, FoundEmptyUName: Boolean;
  Guard: IInterface;

  procedure ExpectPaxRaise(const ABad: string);
  var
    B: TBytes;
    RR: TTarReader;
    HH: TTarHeader;
    P: string;
  begin
    B := nil;
    P := ArchivePaxFormatRecord('path', 'v.txt') + ArchivePaxFormatRecord('size', '1') + ABad;
    EmitRawHeader(B, '', 'x', Length(StringToBytes(P)));
    AppendPayload(B, StringToBytes(P));
    EmitRawHeader(B, 'v.txt', '0', 1);
    AppendPayload(B, StringToBytes('q'));
    AppendZeros(B, 1024);
    RR := TTarReader.Create(B);
    try
      try
        while RR.Next(HH) do
        begin
        end;
        CheckTrue(False, 'bad pax value must raise: ' + ABad);
      except
        on E: EIOError do
          CheckTrue(True, 'bad pax rejected');
      end;
    finally
      RR.Free;
    end;
    SetLength(B, 0);
  end;

begin
  Arc := nil;
  Pax := ArchivePaxFormatRecord('path', 'real.txt')
    + ArchivePaxFormatRecord('size', '4')
    + ArchivePaxFormatRecord('mtime', '1700000000.999')
    + ArchivePaxFormatRecord('uid', '1001')
    + ArchivePaxFormatRecord('gid', '1002')
    + ArchivePaxFormatRecord('uname', 'pu')
    + ArchivePaxFormatRecord('gname', 'pg')
    + ArchivePaxFormatRecord('comment', 'hi')
    + ArchivePaxFormatRecord('atime', '123');
  EmitRawHeader(Arc, '', 'x', Length(StringToBytes(Pax)));
  AppendPayload(Arc, StringToBytes(Pax));
  EmitRawHeader(Arc, 'short.txt', '0', 0);
  AppendPayload(Arc, StringToBytes('abcd'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'pax entry');
    CheckEqual('real.txt', H.Name, 'pax path');
    CheckEqual(Int64(4), H.Size, 'pax size overrides ustar 0');
    CheckEqual(Int64(1700000000), H.MTimeUnix, 'pax mtime truncates fraction');
    CheckEqual(Int64(1001), Int64(H.UID), 'pax uid');
    CheckEqual(Int64(1002), Int64(H.GID), 'pax gid');
    CheckEqual('pu', H.UName, 'pax uname');
    CheckEqual('pg', H.GName, 'pax gname');
    CheckEqual(Int64(9), Int64(Length(H.PaxRecords)), 'passthrough count');
    FoundComment := False;
    FoundAtime := False;
    FoundMTime := False;
    for I := 0 to High(H.PaxRecords) do
    begin
      if (H.PaxRecords[I].Key = 'comment') and (H.PaxRecords[I].Value = 'hi') then
        FoundComment := True;
      if (H.PaxRecords[I].Key = 'atime') and (H.PaxRecords[I].Value = '123') then
        FoundAtime := True;
      if (H.PaxRecords[I].Key = 'mtime') and (H.PaxRecords[I].Value = '1700000000.999') then
        FoundMTime := True;
    end;
    CheckTrue(FoundComment and FoundAtime and FoundMTime, 'unknown keys pass through');
    CheckTrue(R.Next(H) = False, 'pax end');
  finally
    R.Free;
  end;
  ExpectPaxRaise(ArchivePaxFormatRecord('size', 'abc'));
  ExpectPaxRaise(ArchivePaxFormatRecord('size', '-5'));
  ExpectPaxRaise(ArchivePaxFormatRecord('size', '9223372036854775808'));
  ExpectPaxRaise(ArchivePaxFormatRecord('uid', '4294967296'));
  ExpectPaxRaise(ArchivePaxFormatRecord('gid', '-1'));
  ExpectPaxRaise(ArchivePaxFormatRecord('mtime', 'abc'));
  ExpectPaxRaise(ArchivePaxFormatRecord('mtime', ''));
  Arc := nil;
  Pax := ArchivePaxFormatRecord('mtime', '111') + ArchivePaxFormatRecord('uname', 'gu');
  EmitRawHeader(Arc, '', 'g', Length(StringToBytes(Pax)));
  AppendPayload(Arc, StringToBytes(Pax));
  EmitRawHeader(Arc, 'ga.txt', '0', 1);
  AppendPayload(Arc, StringToBytes('a'));
  EmitRawHeader(Arc, 'gb.txt', '0', 1);
  AppendPayload(Arc, StringToBytes('b'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    Guard := R.AcquireGlobalPaxGuard;
    CheckTrue(R.Next(H), 'g first');
    CheckEqual(Int64(111), H.MTimeUnix, 'g mtime persists with guard');
    CheckEqual('gu', H.UName, 'g uname persists with guard');
    CheckTrue(R.Next(H), 'g second');
    CheckEqual(Int64(111), H.MTimeUnix, 'g mtime second with guard');
    Guard := nil;
  finally
    R.Free;
  end;
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'g single first');
    CheckEqual(Int64(111), H.MTimeUnix, 'g single-use first');
    CheckTrue(R.Next(H), 'g single second');
    CheckEqual(Int64(0), H.MTimeUnix, 'g auto-cleared second');
    CheckTrue(R.Next(H) = False, 'g end');
  finally
    R.Free;
  end;
  Arc := nil;
  Pax := ArchivePaxFormatRecord('uname', 'gu');
  EmitRawHeader(Arc, '', 'g', Length(StringToBytes(Pax)));
  AppendPayload(Arc, StringToBytes(Pax));
  Pax := ArchivePaxFormatRecord('path', 'e.txt') + ArchivePaxFormatRecord('uname', '');
  EmitRawHeader(Arc, '', 'x', Length(StringToBytes(Pax)));
  AppendPayload(Arc, StringToBytes(Pax));
  EmitRawHeader(Arc, 'e.txt', '0', 1);
  AppendPayload(Arc, StringToBytes('e'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    Guard := R.AcquireGlobalPaxGuard;
    CheckTrue(R.Next(H), 'empty uname entry');
    CheckEqual('', H.UName, 'empty per-entry uname beats global');
    FoundEmptyUName := False;
    for I := 0 to High(H.PaxRecords) do
      if (H.PaxRecords[I].Key = 'uname') and (H.PaxRecords[I].Value = '') then
        FoundEmptyUName := True;
    CheckTrue(FoundEmptyUName, 'empty uname in passthrough');
    Guard := nil;
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
end;

procedure TestNumericFullRange;
var
  Block: array[0..511] of Byte;
  VI: Integer;
  Vals8: array[0..6] of Int64;
  Vals12: array[0..6] of Int64;
  Back: Int64;

  procedure ExpectFormatRaise(ALen: SizeUInt; AValue: Int64; const AMsg: string);
  begin
    FillChar(Block[0], 512, 0);
    try
      TarFormatNumericField(@Block[0], 0, ALen, AValue);
      CheckTrue(False, AMsg);
    except
      on E: EIOError do
        CheckTrue(True, AMsg);
    end;
  end;

  procedure ExpectRoundTrip(ALen: SizeUInt; AValue: Int64);
  begin
    FillChar(Block[0], 512, 0);
    TarFormatNumericField(@Block[0], 0, ALen, AValue);
    if AValue >= (Int64(1) shl ((ALen - 1) * 3)) then
      CheckTrue((Block[0] and $80) <> 0, 'base-256 marker');
    Back := TarParseNumericField(@Block[0], ALen, 0);
    CheckEqual(AValue, Back, 'numeric roundtrip');
  end;

begin
  Vals8[0] := 0;
  Vals8[1] := 1;
  Vals8[2] := (Int64(1) shl 21) - 1;
  Vals8[3] := Int64(1) shl 21;
  Vals8[4] := (Int64(1) shl 21) + 1;
  Vals8[5] := Int64($123456789);
  Vals8[6] := (Int64(1) shl 62) - 1;
  for VI := 0 to High(Vals8) do
    ExpectRoundTrip(8, Vals8[VI]);
  FillChar(Block[0], 512, 0);
  TarFormatNumericField(@Block[0], 0, 8, (Int64(1) shl 62) - 1);
  CheckEqual(Int64($BF), Int64(Block[0]), 'top data bits ride first byte');
  Vals12[0] := 0;
  Vals12[1] := 1;
  Vals12[2] := (Int64(1) shl 33) - 1;
  Vals12[3] := Int64(1) shl 33;
  Vals12[4] := (Int64(1) shl 33) + 1;
  Vals12[5] := Int64($123456789AB);
  Vals12[6] := High(Int64);
  for VI := 0 to High(Vals12) do
    ExpectRoundTrip(12, Vals12[VI]);
  FillChar(Block[0], 512, 0);
  TarFormatNumericField(@Block[0], 0, 12, High(Int64));
  CheckEqual(Int64($80), Int64(Block[0]), 'wide field sentinel only');
  ExpectFormatRaise(8, -1, 'negative refused');
  ExpectFormatRaise(8, Int64(1) shl 62, 'beyond roundtrip capacity refused');
  ExpectFormatRaise(8, High(Int64), 'int64 max not representable in 8 bytes');
  ExpectFormatRaise(1, 5, 'tiny field refused');
  FillChar(Block[0], 512, 0);
  Block[0] := Ord('1');
  Block[1] := Ord('8');
  try
    TarParseNumericField(@Block[0], 8, 0);
    CheckTrue(False, 'bad octal digit must raise');
  except
    on E: EIOError do
      CheckTrue(True, 'bad octal digit');
  end;
  FillChar(Block[0], 512, 0);
  Block[0] := $80;
  for VI := 1 to 11 do
    Block[VI] := $FF;
  try
    TarParseNumericField(@Block[0], 12, 0);
    CheckTrue(False, 'base-256 overflow must raise');
  except
    on E: EIOError do
      CheckTrue(True, 'base-256 overflow');
  end;
end;

function DecStr(AValue: Int64): string;
var
  Neg: Boolean;
  U: UInt64;
  Buf: array[0..19] of Char;
  N, I: Integer;
begin
  if AValue < 0 then
  begin
    Neg := True;
    U := UInt64(-(AValue + 1)) + 1;
  end
  else
  begin
    Neg := False;
    U := UInt64(AValue);
  end;
  N := 0;
  repeat
    Buf[N] := Chr(Ord('0') + U mod 10);
    U := U div 10;
    Inc(N);
  until U = 0;
  if Neg then
  begin
    Buf[N] := '-';
    Inc(N);
  end;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[1 + I] := Buf[N - 1 - I];
end;

function SparseMapBytes(const ASegs: array of TSparseTestSeg; AReal: Int64): TBytes;
var
  S: string;
  I: Integer;
begin
  S := DecStr(Length(ASegs) + 1) + #10;
  for I := 0 to High(ASegs) do
    S := S + DecStr(ASegs[I].Off) + #10 + DecStr(ASegs[I].Len) + #10;
  S := S + DecStr(AReal) + #10 + '0' + #10;
  Result := StringToBytes(S);
end;

function RepByte(ACh: Char; AN: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, AN);
  for I := 0 to AN - 1 do
    Result[I] := Byte(Ord(ACh));
end;

procedure AppendRep(var AData: TBytes; ACh: Char; AN: Integer);
var
  Tmp: TBytes;
begin
  if AN <= 0 then
    Exit;
  Tmp := RepByte(ACh, AN);
  BytesAppend(AData, @Tmp[0], SizeUInt(AN));
  SetLength(Tmp, 0);
end;

procedure EmitSparseOld(var AArc: TBytes; const AName: string; const ASegs: array of TSparseTestSeg; AReal: Int64; AUseRealSize: Boolean; const AData: TBytes);
var
  Block: array[0..511] of Byte;
  Idx, M, I: Integer;

  procedure PutSeg(ABase: PByte; ASlot: Integer; AOff, ALen: Int64);
  begin
    TarFormatNumericField(ABase, SizeUInt(ASlot) * 24, 12, AOff);
    TarFormatNumericField(ABase, SizeUInt(ASlot) * 24 + 12, 12, ALen);
  end;

begin
  Idx := 0;
  FillChar(Block[0], 512, 0);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, AName);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, $1A4);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, Length(AData));
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord('S');
  TarWriteUStarMagic(@Block[0]);
  M := Length(ASegs);
  if M > 4 then
    M := 4;
  for I := 0 to M - 1 do
  begin
    PutSeg(@Block[386], I, ASegs[Idx].Off, ASegs[Idx].Len);
    Inc(Idx);
  end;
  if Idx < Length(ASegs) then
    Block[482] := 1
  else
  begin
    PutSeg(@Block[386], Idx, AReal, 0);
    Block[482] := 0;
  end;
  if AUseRealSize then
    TarFormatNumericField(@Block[0], 483, 12, AReal);
  TarFinalizeHeaderChecksum(@Block[0]);
  BytesAppend(AArc, @Block[0], 512);
  while Idx < Length(ASegs) do
  begin
    FillChar(Block[0], 512, 0);
    M := Length(ASegs) - Idx;
    if M > 21 then
      M := 21;
    for I := 0 to M - 1 do
    begin
      PutSeg(@Block[0], I, ASegs[Idx].Off, ASegs[Idx].Len);
      Inc(Idx);
    end;
    if Idx < Length(ASegs) then
      Block[504] := 1
    else
    begin
      PutSeg(@Block[0], M, AReal, 0);
      Block[504] := 0;
    end;
    BytesAppend(AArc, @Block[0], 512);
  end;
  AppendPayload(AArc, AData);
end;

procedure EmitSparse10(var AArc: TBytes; const ARealName: string; AReal: Int64; const ASegs: array of TSparseTestSeg; const AData: TBytes; const AExtra: string);
var
  Pax: string;
  MapB, Stored: TBytes;
  Pad: SizeInt;
begin
  Pax := ArchivePaxFormatRecord('GNU.sparse.major', '1')
    + ArchivePaxFormatRecord('GNU.sparse.minor', '0')
    + ArchivePaxFormatRecord('GNU.sparse.name', ARealName)
    + ArchivePaxFormatRecord('GNU.sparse.realsize', DecStr(AReal))
    + AExtra;
  EmitRawHeader(AArc, 'paxh', 'x', Length(StringToBytes(Pax)));
  AppendPayload(AArc, StringToBytes(Pax));
  MapB := SparseMapBytes(ASegs, AReal);
  Stored := nil;
  BytesAppend(Stored, PByte(@MapB[0]), SizeUInt(Length(MapB)));
  Pad := TarPadToBlock(Int64(Length(MapB)));
  if Pad > 0 then
  begin
    SetLength(Stored, Length(Stored) + Pad);
    FillChar(Stored[Length(Stored) - Pad], Pad, 0);
  end;
  if Length(AData) > 0 then
    BytesAppend(Stored, PByte(@AData[0]), SizeUInt(Length(AData)));
  EmitRawHeader(AArc, './GNUSparseFile.12345/' + ARealName, '0', Length(Stored));
  AppendPayload(AArc, Stored);
  SetLength(MapB, 0);
  SetLength(Stored, 0);
end;

procedure TestFuzzCorruptSparseNoCrash;
var
  Base, Mut, Holey, Data: TBytes;
  Segs: array[0..1] of TSparseTestSeg;
  S: IStream; W: TTarWriter;
  I, J, Clean, Raised: Integer;
  R: TTarReader;
  H: TTarHeader;
  LSlice: TByteSpan;
  Op: Cardinal;
  Cut: Integer;
begin
  SetLength(Holey, 9000);
  FillChar(Holey[0], 9000, 0);
  for I := 0 to 99 do Holey[I] := Ord('A');
  for I := 0 to 199 do Holey[5000 + I] := Ord('B');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddSparseFile('corrupt-me.bin', Holey);
    W.AddFile('plain.txt', StringToBytes('plain'));
    W.Finish;
    SetLength(Base, S.Size);
    if Length(Base) > 0 then
    begin S.Seek(0, soBeginning); S.Read(Base[0], Length(Base)); end;
  finally W.Free; end;
  Segs[0].Off := 0; Segs[0].Len := 50;
  Segs[1].Off := 1000; Segs[1].Len := 50;
  Data := nil;
  AppendRep(Data, 'm', 50);
  AppendRep(Data, 'n', 50);
  EmitSparseOld(Base, 'oldstyle.bin', [Segs[0], Segs[1]], 1200, True, Data);
  AppendZeros(Base, 1024);
  SetLength(Data, 0);
  SetLength(Holey, 0);
  RandInit(31337);
  Clean := 0;
  Raised := 0;
  for I := 1 to 200 do
  begin
    Mut := nil;
    SetLength(Mut, Length(Base));
    if Length(Base) > 0 then
      for J := 0 to High(Base) do
        Mut[J] := Base[J];
    Op := RandRange(3);
    if Op = 0 then
      Mut[Integer(RandRange(Cardinal(Length(Mut))))] :=
        Byte(Mut[Integer(RandRange(Cardinal(Length(Mut))))] xor (1 shl Integer(RandRange(8))))
    else if Op = 1 then
    begin
      Cut := Length(Mut) - Integer(RandRange(Cardinal(Length(Mut) div 2) + 1)) - 1;
      if Cut < 1 then
        Cut := 1;
      SetLength(Mut, Cut);
    end
    else
      AppendPayload(Mut, RandomBytes(Integer(RandRange(600))));
    R := TTarReader.Create(Mut);
    try
      try
        while R.Next(H) do
          if R.TrySlice(LSlice) then
            CheckTrue((LSlice.Len = 0) or (LSlice.Data <> nil), 'touch sparse slice');
        Inc(Clean);
      except
        on E: EIOError do
          Inc(Raised);
        on E: EParseError do
          Inc(Raised);
        on E: Exception do
          CheckTrue(False, 'unexpected exception: ' + E.ClassName);
      end;
    finally
      R.Free;
    end;
    SetLength(Mut, 0);
  end;
  CheckTrue(Raised > 0, 'sparse corruption detected sometimes');
  CheckTrue(Clean > 0, 'sparse benign mutations still parse');
  SetLength(Base, 0);
end;

procedure TestSparseRead;
var
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  LSlice: TByteSpan;
  Segs: array[0..4] of TSparseTestSeg;
  Segs2: array[0..1] of TSparseTestSeg;
  NoSegs: array of TSparseTestSeg;
  Data, Expect: TBytes;
  I: Integer;
begin
  Arc := nil;
  Segs[0].Off := 0; Segs[0].Len := 100;
  Segs[1].Off := 5000; Segs[1].Len := 200;
  Segs[2].Off := 8000; Segs[2].Len := 50;
  Data := nil;
  AppendRep(Data, 'A', 100);
  AppendRep(Data, 'B', 200);
  AppendRep(Data, 'C', 50);
  SetLength(Expect, 9000);
  FillChar(Expect[0], 9000, 0);
  for I := 0 to 99 do Expect[I] := Ord('A');
  for I := 0 to 199 do Expect[5000 + I] := Ord('B');
  for I := 0 to 49 do Expect[8000 + I] := Ord('C');
  EmitSparse10(Arc, 'sparse10.bin', 9000, [Segs[0], Segs[1], Segs[2]], Data, ArchivePaxFormatRecord('mtime', '1700000001'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'sparse10 present');
    CheckEqual('sparse10.bin', H.Name, 'sparse real name');
    CheckEqual(Int64(9000), H.Size, 'sparse real size');
    CheckEqual(Int64(1700000001), H.MTimeUnix, 'sparse x mtime still applies');
    CheckTrue(R.TrySlice(LSlice), 'sparse slice');
    CheckTrue(BytesEqual(Expect, SpanClone(LSlice)), 'sparse reconstructed');
    CheckTrue(R.Next(H) = False, 'sparse10 end');
  finally
    R.Free;
  end;
  Arc := nil;
  Segs[0].Off := 0; Segs[0].Len := 100;
  Segs[1].Off := 1000; Segs[1].Len := 100;
  Segs[2].Off := 2000; Segs[2].Len := 100;
  Segs[3].Off := 3000; Segs[3].Len := 100;
  Segs[4].Off := 4000; Segs[4].Len := 100;
  Data := nil;
  for I := 0 to 4 do
    AppendRep(Data, Chr(Ord('a') + I), 100);
  SetLength(Expect, 5000);
  FillChar(Expect[0], 5000, 0);
  for I := 0 to 4 do
    Move(Data[I * 100], Expect[I * 1000], 100);
  EmitSparseOld(Arc, 'sparseold.bin', [Segs[0], Segs[1], Segs[2], Segs[3], Segs[4]], 5000, True, Data);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'sparseold present');
    CheckEqual('sparseold.bin', H.Name, 'old name');
    CheckEqual(Int64(5000), H.Size, 'old real size');
    CheckEqual(Int64(Ord(tekRegular)), Int64(Ord(H.Kind)), 'old kind regular');
    CheckTrue(R.TrySlice(LSlice), 'old slice');
    CheckTrue(BytesEqual(Expect, SpanClone(LSlice)), 'old extended reconstruction');
    CheckTrue(R.Next(H) = False, 'old end');
  finally
    R.Free;
  end;
  Arc := nil;
  Segs2[0].Off := 0; Segs2[0].Len := 100;
  Segs2[1].Off := 1000; Segs2[1].Len := 100;
  Data := nil;
  AppendRep(Data, 'x', 100);
  AppendRep(Data, 'y', 100);
  SetLength(Expect, 1100);
  FillChar(Expect[0], 1100, 0);
  for I := 0 to 99 do Expect[I] := Ord('x');
  for I := 0 to 99 do Expect[1000 + I] := Ord('y');
  EmitSparseOld(Arc, 'sparse00.bin', [Segs2[0], Segs2[1]], 0, False, Data);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'sparse00 present');
    CheckEqual(Int64(1100), H.Size, '0.0 derived size');
    CheckTrue(R.TrySlice(LSlice), '00 slice');
    CheckTrue(BytesEqual(Expect, SpanClone(LSlice)), '0.0 reconstruction');
  finally
    R.Free;
  end;
  Arc := nil;
  NoSegs := nil;
  EmitSparse10(Arc, 'allholes.bin', 4096, NoSegs, nil, '');
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'allholes present');
    CheckEqual(Int64(4096), H.Size, 'allholes size');
    SetLength(Expect, 4096);
    FillChar(Expect[0], 4096, 0);
    CheckTrue(R.TrySlice(LSlice), 'allholes zero view');
    CheckTrue(BytesEqual(Expect, SpanClone(LSlice)), 'allholes zeros');
    CheckTrue(R.Next(H) = False, 'allholes end');
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
  SetLength(Data, 0);
  SetLength(Expect, 0);
end;

procedure TestSparseReject;
var
  Segs: array[0..0] of TSparseTestSeg;
  NoSegs: array of TSparseTestSeg;
  Data: TBytes;

  procedure ExpectSparseRaise(const AMsg: string; ABuild: Integer);
  var
    B: TBytes;
    RR: TTarReader;
    HH: TTarHeader;
    P: string;
    RO: TTarReadOptions;
  begin
    B := nil;
    case ABuild of
      1:
        begin
          P := ArchivePaxFormatRecord('GNU.sparse.major', '2')
            + ArchivePaxFormatRecord('GNU.sparse.minor', '0')
            + ArchivePaxFormatRecord('GNU.sparse.name', 's.bin')
            + ArchivePaxFormatRecord('GNU.sparse.realsize', '100');
          EmitRawHeader(B, 'paxh', 'x', Length(StringToBytes(P)));
          AppendPayload(B, StringToBytes(P));
          EmitRawHeader(B, './GNUSparseFile.1/s.bin', '0', 0);
          AppendZeros(B, 1024);
        end;
      2:
        begin
          P := ArchivePaxFormatRecord('GNU.sparse.major', '1')
            + ArchivePaxFormatRecord('GNU.sparse.minor', '0')
            + ArchivePaxFormatRecord('GNU.sparse.name', 's.bin')
            + ArchivePaxFormatRecord('GNU.sparse.realsize', '100');
          EmitRawHeader(B, 'paxh', 'x', Length(StringToBytes(P)));
          AppendPayload(B, StringToBytes(P));
          EmitRawHeader(B, 'plain.txt', '0', 1);
          AppendPayload(B, StringToBytes('q'));
          AppendZeros(B, 1024);
        end;
      3:
        begin
          EmitRawHeader(B, './GNUSparseFile.1/lone.bin', '0', 0);
          AppendZeros(B, 1024);
        end;
      4:
        begin
          P := ArchivePaxFormatRecord('GNU.sparse.major', '1')
            + ArchivePaxFormatRecord('GNU.sparse.minor', '0')
            + ArchivePaxFormatRecord('GNU.sparse.name', 's.bin')
            + ArchivePaxFormatRecord('GNU.sparse.realsize', '100');
          EmitRawHeader(B, 'paxh', 'x', Length(StringToBytes(P)));
          AppendPayload(B, StringToBytes(P));
          P := '2' + #10 + '0' + #10 + '10' + #10 + '0' + #10 + '100' + #10;
          EmitRawHeader(B, './GNUSparseFile.1/s.bin', '0', Length(StringToBytes(P)));
          AppendPayload(B, StringToBytes(P));
          AppendZeros(B, 1024);
        end;
      5:
        begin
          Segs[0].Off := 0; Segs[0].Len := 100;
          Data := nil;
          AppendRep(Data, 'Z', 100);
          EmitSparseOld(B, 'over.bin', [Segs[0]], 50, True, Data);
          AppendZeros(B, 1024);
          SetLength(Data, 0);
        end;
      6:
        begin
          P := ArchivePaxFormatRecord('GNU.sparse.major', '1')
            + ArchivePaxFormatRecord('GNU.sparse.minor', '0')
            + ArchivePaxFormatRecord('GNU.sparse.name', 'big.bin')
            + ArchivePaxFormatRecord('GNU.sparse.realsize', '100000');
          EmitRawHeader(B, 'paxh', 'x', Length(StringToBytes(P)));
          AppendPayload(B, StringToBytes(P));
          NoSegs := nil;
          EmitSparse10(B, 'big.bin', 100000, NoSegs, nil, '');
          AppendZeros(B, 1024);
        end;
    end;
    if ABuild = 6 then
    begin
      RO := DefaultTarReadOptions;
      RO.MaxEntrySize := 100;
      RR := TTarReader.CreateWithOptions(B, RO);
    end
    else
      RR := TTarReader.Create(B);
    try
      try
        while RR.Next(HH) do
        begin
        end;
        CheckTrue(False, AMsg);
      except
        on E: EIOError do
          CheckTrue(True, AMsg);
        on E: EParseError do
          CheckTrue(ABuild = 3, AMsg);
      end;
    finally
      RR.Free;
    end;
    SetLength(B, 0);
  end;

begin
  ExpectSparseRaise('bad major refused', 1);
  ExpectSparseRaise('map without data refused', 2);
  ExpectSparseRaise('lone placeholder rejected', 3);
  ExpectSparseRaise('missing terminator refused', 4);
  ExpectSparseRaise('segment overflow refused', 5);
  ExpectSparseRaise('realsize bomb refused before alloc', 6);
end;

procedure TestBombLimits;
var
  S: IStream;
  W: TTarWriter;
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  ROpts: TTarReadOptions;
  LongPayload: TBytes;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('big.bin', RandomBytes(200));
    W.Finish;
  finally
    W.Free;
  end;
  Arc := Snapshot(S);
  ROpts := DefaultTarReadOptions;
  ROpts.MaxEntrySize := 16;
  R := TTarReader.CreateWithOptions(Arc, ROpts);
  try
    try
      R.Next(H);
      CheckTrue(False, 'single entry limit must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'single entry limit');
    end;
  finally
    R.Free;
  end;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('a.bin', RandomBytes(100));
    W.AddFile('b.bin', RandomBytes(100));
    W.Finish;
  finally
    W.Free;
  end;
  Arc := Snapshot(S);
  ROpts := DefaultTarReadOptions;
  ROpts.MaxTotalSize := 150;
  R := TTarReader.CreateWithOptions(Arc, ROpts);
  try
    CheckTrue(R.Next(H), 'first within total');
    try
      R.Next(H);
      CheckTrue(False, 'total limit must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'total limit');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  LongPayload := RandomBytes(300);
  EmitRawHeader(Arc, '', 'L', 300);
  AppendPayload(Arc, LongPayload);
  EmitRawHeader(Arc, 'short.txt', '0', 3);
  AppendPayload(Arc, StringToBytes('abc'));
  AppendZeros(Arc, 1024);
  ROpts := DefaultTarReadOptions;
  ROpts.MaxTotalSize := 100;
  R := TTarReader.CreateWithOptions(Arc, ROpts);
  try
    try
      R.Next(H);
      CheckTrue(False, 'extended payload must count toward total');
    except
      on E: EIOError do
        CheckTrue(True, 'extended counted');
    end;
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
  SetLength(LongPayload, 0);
end;

procedure TestMalformedHeaders;
var
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  Block: array[0..511] of Byte;
  I: Integer;
  U, Sv: Int64;
begin
  Arc := nil;
  EmitRawHeader(Arc, 'ok.txt', '0', 3);
  AppendPayload(Arc, StringToBytes('ok!'));
  AppendZeros(Arc, 1024);
  Arc[10] := Arc[10] xor $FF;
  R := TTarReader.Create(Arc);
  try
    try
      R.Next(H);
      CheckTrue(False, 'bad checksum must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'bad checksum');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, 'weird.txt', '9', 0);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    try
      R.Next(H);
      CheckTrue(False, 'unsupported typeflag must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'bad typeflag');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  FillChar(Block[0], 512, 0);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len, 'neg.txt');
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, $1A4);
  Block[C_TAR_LAYOUT.Size.Off] := $FF;
  for I := 1 to 11 do
    Block[C_TAR_LAYOUT.Size.Off + I] := $FF;
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord('0');
  TarWriteUStarMagic(@Block[0]);
  TarFinalizeHeaderChecksum(@Block[0]);
  BytesAppend(Arc, @Block[0], 512);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    try
      R.Next(H);
      CheckTrue(False, 'negative size must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'negative size');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, '', '0', 0);
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    try
      R.Next(H);
      CheckTrue(False, 'empty name must raise');
    except
      on E: EParseError do
        CheckTrue(True, 'empty name');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, 'cut.bin', '0', 100);
  AppendPayload(Arc, StringToBytes('0123456789'));
  SetLength(Arc, 512 + 10);
  R := TTarReader.Create(Arc);
  try
    try
      R.Next(H);
      CheckTrue(False, 'truncated payload must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'truncated payload');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, 'a.txt', '0', 2);
  AppendPayload(Arc, StringToBytes('hi'));
  AppendZeros(Arc, 1024);
  AppendPayload(Arc, RandomBytes(100));
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'entry before trailing garbage');
    CheckTrue(R.Next(H) = False, 'garbage after two zero blocks ignored');
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, 'a.txt', '0', 2);
  AppendPayload(Arc, StringToBytes('hi'));
  AppendZeros(Arc, 1024);
  Arc[Length(Arc) - 512] := Ord('X');
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'entry before lone zero');
    try
      R.Next(H);
      CheckTrue(False, 'lone zero plus data must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'lone zero');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  EmitRawHeader(Arc, '', 'x', 7);
  AppendPayload(Arc, StringToBytes('garbage'));
  EmitRawHeader(Arc, 'after.txt', '0', 1);
  AppendPayload(Arc, StringToBytes('q'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    try
      while R.Next(H) do
      begin
      end;
      CheckTrue(False, 'bad pax must raise');
    except
      on E: EIOError do
        CheckTrue(True, 'bad pax');
    end;
  finally
    R.Free;
  end;
  Arc := nil;
  FillChar(Block[0], 512, 0);
  TarPutHeaderString(@Block[0], C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len,
    'hq' + Chr($C3) + Chr($A9) + '.txt');
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len, $1A4);
  TarFormatNumericField(@Block[0], C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len, 3);
  Block[C_TAR_LAYOUT.TypeFlag.Off] := Ord('0');
  TarWriteUStarMagic(@Block[0]);
  FillChar(Block[C_TAR_LAYOUT.Chksum.Off], 8, Ord(' '));
  TarComputeChecksumsDual(@Block[0], U, Sv);
  CheckTrue(U <> Sv, 'signed differs with high-bit name');
  for I := 0 to 5 do
    Block[C_TAR_LAYOUT.Chksum.Off + I] := Byte(Ord('0') + ((Sv shr ((5 - I) * 3)) and 7));
  Block[C_TAR_LAYOUT.Chksum.Off + 6] := 0;
  Block[C_TAR_LAYOUT.Chksum.Off + 7] := Ord(' ');
  BytesAppend(Arc, @Block[0], 512);
  AppendPayload(Arc, StringToBytes('ok!'));
  AppendZeros(Arc, 1024);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'signed checksum accepted');
    CheckEqual('hq' + Chr($C3) + Chr($A9) + '.txt', H.Name, 'high-bit name');
  finally
    R.Free;
  end;
  SetLength(Arc, 0);
end;

procedure TestWriterSemantics;
var
  S: IStream;
  W: TTarWriter;
  Hdr: TTarHeader;
  Data, Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  RS: IReader;
  Src: IStream;
begin
  try
    W := TTarWriter.Create(nil);
    W.Free;
    CheckTrue(False, 'nil destination must raise');
  except
    on E: EArgumentError do
      CheckTrue(True, 'nil destination');
  end;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('a.txt', StringToBytes('hi'));
    W.Finish;
    W.Finish;
    CheckTrue(True, 'double finish idempotent');
    try
      W.AddFile('b.txt', StringToBytes('x'));
      CheckTrue(False, 'write after finish must raise');
    except
      on E: EInvalidOperationError do
        CheckTrue(True, 'write after finish');
    end;
  finally
    W.Free;
  end;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  W.AddFile('a.txt', StringToBytes('hi'));
  W.Free;
  CheckTrue(S.Size = 1024, 'destructor without finish appends nothing');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    try
      W.AddFile('../evil.txt', StringToBytes('x'));
      CheckTrue(False, 'unsafe name must raise');
    except
      on E: EArgumentError do
        CheckTrue(True, 'unsafe name');
    end;
    try
      W.AddFile('', StringToBytes('x'));
      CheckTrue(False, 'empty name must raise');
    except
      on E: EArgumentError do
        CheckTrue(True, 'empty name rejected');
    end;
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Name := 'neg.bin';
    Hdr.Kind := tekRegular;
    Hdr.Size := -5;
    try
      W.AddEntryFromReader(Hdr, nil);
      CheckTrue(False, 'negative stream size must raise');
    except
      on E: EArgumentError do
        CheckTrue(True, 'negative stream size');
    end;
    Hdr.Size := 10;
    try
      W.AddEntryFromReader(Hdr, nil);
      CheckTrue(False, 'nil reader must raise');
    except
      on E: EArgumentError do
        CheckTrue(True, 'nil reader');
    end;
    W.Finish;
  finally
    W.Free;
  end;
  Data := RandomBytes(1500);
  Src := CreateBytesStream;
  Src.Write(Data[0], Length(Data));
  Src.Seek(0, soBeginning);
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Name := 'streamed.bin';
    Hdr.Kind := tekRegular;
    Hdr.Mode := $1A4;
    Hdr.Size := Length(Data);
    W.AddEntryFromReader(Hdr, Src as IReader);
    W.Finish;
  finally
    W.Free;
  end;
  Arc := Snapshot(S);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'streamed present');
    CheckEqual(Int64(Length(Data)), H.Size, 'streamed size');
    RS := R.OpenEntryStream;
    CheckTrue(BytesEqual(Data, ReadAll(RS, Length(Data))), 'streamed payload');
    CheckTrue(R.Next(H) = False, 'streamed end');
  finally
    R.Free;
  end;
  SetLength(Data, 0);
  SetLength(Arc, 0);
end;

procedure TestBuilderEquivalence;
var
  B1, B2: TBytes;
  Hdr: TTarHeader;
  Data: TBytes;
  R: TTarReader;
  H: TTarHeader;
  S: IStream;
  W: TTarWriter;
begin
  RandInit(4242);
  Data := RandomBytes(900);
  B1 := TarBuilder.Add('hello.txt', StringToBytes('hello')).AddDirectory('assets')
    .Add('assets/data.bin', Data).Finish;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('hello.txt', StringToBytes('hello'));
    W.AddDir('assets');
    W.AddFile('assets/data.bin', Data);
    W.Finish;
  finally
    W.Free;
  end;
  B2 := Snapshot(S);
  CheckTrue(BytesEqual(B1, B2), 'builder equals writer bytes');  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr.Name := 'streamed.bin';
  Hdr.Kind := tekRegular;
  Hdr.Size := Length(Data);
  S := CreateBytesStream;
  S.Write(Data[0], Length(Data));
  S.Seek(0, soBeginning);
  B1 := TarBuilder.Add('a.txt', StringToBytes('a')).AddEntryFromReader(Hdr, S as IReader).Finish;
  R := TTarReader.Create(B1);
  try
    CheckTrue(R.Next(H), 'first');
    CheckEqual('a.txt', H.Name, 'first name');
    CheckTrue(R.Next(H), 'streamed');
    CheckEqual('streamed.bin', H.Name, 'streamed name');
    CheckEqual(Int64(Length(Data)), H.Size, 'streamed size');
    CheckTrue(R.Next(H) = False, 'builder end');
  finally
    R.Free;
  end;
  SetLength(B1, 0);
  SetLength(B2, 0);
  SetLength(Data, 0);
end;

procedure TestFsDeterminismRestoreAndSpecial;
const
  C_NS: Int64 = Int64(1700000000) * 1000000000;
var
  Root, OutSkip, OutFull: string;
  A1, A2: TBytes;
  R: TTarReader;
  H: TTarHeader;
  FoundA, FoundB, FoundC: Boolean;
  Info: TFileInfo;
  O: TTarExtractOptions;
  S: IStream;
  W: TTarWriter;
  Arc: TBytes;
  Hdr: TTarHeader;
  EmptyFixture: TBytes;
begin
  Root := PathJoin([GetTempDir, 'nextpas_tar_fuzz_src']);
  OutSkip := PathJoin([GetTempDir, 'nextpas_tar_fuzz_skip']);
  OutFull := PathJoin([GetTempDir, 'nextpas_tar_fuzz_full']);
  RemoveAll(Root);
  RemoveAll(OutSkip);
  RemoveAll(OutFull);
  MkdirAll(PathJoin([Root, 'sub']), PermDirDefault);
  WriteFile(PathJoin([Root, 'b.txt']), StringToBytes('bravo'), PermDefault);
  WriteFile(PathJoin([Root, 'a.txt']), StringToBytes('alpha'), PermDefault);
  WriteFile(PathJoin([Root, 'sub', 'c.txt']), StringToBytes('charlie'), PermDefault);
  SetLength(EmptyFixture, 0);
  WriteFile(PathJoin([Root, 'empty.txt']), EmptyFixture, PermDefault);
  RandInit(9);
  WriteFile(PathJoin([Root, 'big.bin']), RandomBytes(6000), PermDefault);
  ArchiveRestoreFileMeta(PathJoin([Root, 'a.txt']), $1A4, C_NS, True);
  A1 := TarPackDir(Root);
  A2 := TarPackDir(Root);
  CheckTrue(BytesEqual(A1, A2), 'double pack deterministic');
  CheckTrue(Length(A1) mod 512 = 0, 'pack block aligned');
  FoundA := False;
  FoundB := False;
  FoundC := False;
  R := TTarReader.Create(A1);
  try
    while R.Next(H) do
    begin
      if H.Name = 'a.txt' then
        FoundA := True;
      if H.Name = 'b.txt' then
        FoundB := True;
      if H.Name = 'sub/c.txt' then
        FoundC := True;
    end;
  finally
    R.Free;
  end;
  CheckTrue(FoundA and FoundB and FoundC, 'all entries listed');
  TarExtractToDir(A1, OutSkip);
  CheckTrue(BytesEqual(StringToBytes('alpha'), ReadFile(PathJoin([OutSkip, 'a.txt']))), 'alpha restored');
  CheckTrue(BytesEqual(StringToBytes('bravo'), ReadFile(PathJoin([OutSkip, 'b.txt']))), 'bravo restored');
  CheckTrue(BytesEqual(StringToBytes('charlie'), ReadFile(PathJoin([OutSkip, 'sub', 'c.txt']))), 'charlie restored');
  Info := Stat(PathJoin([OutSkip, 'a.txt']));
  CheckEqual(C_NS, Info.ModTime, 'mtime restored');
  CheckEqual(Int64($1A4), Int64(Word(Info.Permission) and $0FFF), 'mode restored');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('target.txt', StringToBytes('through-link'));
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Name := 'link.txt';
    Hdr.Kind := tekSymlink;
    Hdr.Mode := $1A4;
    Hdr.LinkName := 'target.txt';
    W.AddEntry(Hdr, nil);
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Name := 'hard.txt';
    Hdr.Kind := tekHardLink;
    Hdr.Mode := $1A4;
    Hdr.LinkName := 'target.txt';
    W.AddEntry(Hdr, nil);
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Name := 'f.fifo';
    Hdr.Kind := tekFifo;
    Hdr.Mode := $1A4;
    W.AddEntry(Hdr, nil);
    W.Finish;
  finally
    W.Free;
  end;
  Arc := Snapshot(S);
  TarExtractToDir(Arc, OutSkip);
  CheckTrue(FileExists(PathJoin([OutSkip, 'target.txt'])), 'target lands under skip');
  CheckTrue(FileExists(PathJoin([OutSkip, 'link.txt'])) = False, 'symlink skipped');
  CheckTrue(FileExists(PathJoin([OutSkip, 'hard.txt'])) = False, 'hardlink skipped');
  CheckTrue(FileExists(PathJoin([OutSkip, 'f.fifo'])) = False, 'fifo skipped');
  O := DefaultTarExtractOptions;
  O.SkipSpecial := False;
  TarExtractToDirWithOptions(Arc, OutFull, O);
  CheckTrue(BytesEqual(StringToBytes('through-link'), ReadFile(PathJoin([OutFull, 'link.txt']))), 'symlink content');
  CheckTrue(BytesEqual(StringToBytes('through-link'), ReadFile(PathJoin([OutFull, 'hard.txt']))), 'hardlink content');
  CheckTrue(ArchiveIsSymlink(PathJoin([OutFull, 'link.txt'])), 'symlink lands as symlink');
  Info := Stat(PathJoin([OutFull, 'f.fifo']));
  CheckTrue(Info.FileType = ftFifo, 'fifo lands');
  Arc[0] := Ord('.');
  Arc[1] := Ord('.');
  Arc[2] := Ord('/');
  try
    TarExtractToDir(Arc, OutFull);
    CheckTrue(False, 'zip-slip must raise');
  except
    on E: EParseError do
      CheckTrue(True, 'zip-slip parse error');
    on E: EIOError do
      CheckTrue(True, 'zip-slip checksum fail-closed');
  end;
  SetLength(A1, 0);
  SetLength(A2, 0);
  SetLength(Arc, 0);
  SetLength(EmptyFixture, 0);
  RemoveAll(Root);
  RemoveAll(OutSkip);
  RemoveAll(OutFull);
end;

procedure TestZeroCopyConsistency;
var
  S: IStream;
  W: TTarWriter;
  Arc: TBytes;
  R: TTarReader;
  H: TTarHeader;
  Data: TBytes;
  LSlice: TByteSpan;
  P: PByte;
  C: SizeUInt;
  RS: IReader;
begin
  RandInit(31337);
  Data := RandomBytes(1000);
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('z.bin', Data);
    W.AddFile('empty.bin', nil);
    W.Finish;
  finally
    W.Free;
  end;
  Arc := Snapshot(S);
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'z present');
    CheckTrue(R.TrySlice(LSlice), 'z slice');
    CheckTrue(R.EntryDataSlice(P, C), 'z slice ptr');
    CheckTrue((P = LSlice.Data) and (C = LSlice.Len), 'views agree');
    CheckTrue(BytesEqual(Data, SpanClone(LSlice)), 'view payload');
    RS := R.OpenEntryStream;
    CheckTrue(BytesEqual(Data, ReadAll(RS, Length(Data))), 'held stream payload');
    CheckTrue(R.Next(H), 'empty present');
    CheckTrue(R.TrySlice(LSlice) = False, 'empty yields no view');
    CheckTrue(R.EntryDataSlice(P, C) = False, 'empty yields no ptr');
  finally
    R.Free;
  end;
  R := TTarReader.Create(Arc);
  try
    CheckTrue(R.Next(H), 'reopen present');
    RS := R.OpenEntryStream;
  finally
    R.Free;
  end;
  CheckTrue(BytesEqual(Data, ReadAll(RS, Length(Data))), 'held stream survives reader free');
  SetLength(Data, 0);
  SetLength(Arc, 0);
end;

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  Results: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('tar.fuzz');
  Suite.Test('random roundtrip metadata and links', @TestFuzzRoundTrip);
  Suite.Test('boundary sizes', @TestFuzzBoundarySizes);
  Suite.Test('corrupt input never crashes', @TestFuzzCorruptNoCrash);
  Suite.Test('corrupt sparse never crashes', @TestFuzzCorruptSparseNoCrash);
  Suite.Test('gnu L/K long names', @TestGnuLongNameLink);
  Suite.Test('pax full keywords', @TestPaxFullKeywords);
  Suite.Test('numeric full range', @TestNumericFullRange);
  Suite.Test('sparse read', @TestSparseRead);
  Suite.Test('sparse reject', @TestSparseReject);
  Suite.Test('bomb limits', @TestBombLimits);
  Suite.Test('malformed headers', @TestMalformedHeaders);
  Suite.Test('writer semantics', @TestWriterSemantics);
  Suite.Test('builder equivalence', @TestBuilderEquivalence);
  Suite.Test('fs determinism restore special', @TestFsDeterminismRestoreAndSpecial);
  Suite.Test('zero-copy consistency', @TestZeroCopyConsistency);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results) = 0) or (not Results[0].AllPassed) then
    Halt(1);
end.
