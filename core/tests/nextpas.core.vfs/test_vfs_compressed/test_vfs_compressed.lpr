program test_vfs_compressed;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.vfs,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.compressed,
  nextpas.core.compress;

var
  T: TTestSuite;

function BytesOf(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AA) <> Length(AB) then Exit;
  if Length(AA) = 0 then Exit(True);
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then Exit;
  Result := True;
end;

function MakePlain: IVfs;
var
  B: TVfsTreeBuilder;
begin
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('plain.txt', BytesOf('hello world'), 10);
    B.AddFile('dir/nested.txt', BytesOf('nested'), 20);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

function MakeGzipped: IVfs;
var
  B: TVfsTreeBuilder;
  Raw, Gz: TBytes;
begin
  Raw := BytesOf('hello compressed world — nextPas vfs S6');
  Gz := GzipCompress(Raw);
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('gz.txt', Gz, 30);
    B.AddFile('plain.txt', BytesOf('plain stays'), 31);
    B.AddFile('empty.gz', GzipCompress(nil), 32);
    Result := B.Freeze;
  finally
    B.Free;
  end;
end;

procedure TestNonGzipPassthrough;
var
  Inner, Dec: IVfs;
  SI: TStatInfo;
  Data: TBytes;
begin
  Inner := MakePlain;
  Dec := CreateDecompressingVfs(Inner, daAuto);
  SI := Dec.Stat('plain.txt');
  Check((not SI.Info.IsDir) and (SI.Info.Size = 11), 'plain stat size unchanged');
  Check(Dec.CaseSensitive = Inner.CaseSensitive, 'caseSensitive passthrough');
  Data := VfsReadAllBytes(Dec, 'plain.txt');
  Check(SameBytes(Data, BytesOf('hello world')), 'plain open passthrough');
  Check(Dec.Exists('plain.txt'), 'plain exists passthrough');
  Check(Dec.Exists('dir/nested.txt'), 'nested exists');
end;

procedure TestGzipAutoDecompress;
var
  Inner, Dec: IVfs;
  Raw: TBytes;
  SI: TStatInfo;
  Data: TBytes;
  L: TEntryArray;
begin
  Inner := MakeGzipped;
  Raw := BytesOf('hello compressed world — nextPas vfs S6');
  Dec := CreateDecompressingVfs(Inner, daAuto);
  SI := Dec.Stat('gz.txt');
  Check(SI.Info.Size = Int64(Length(Raw)), 'gz stat decompressed size');
  Check(SI.ContentHash = 0, 'gz stat hash cleared');
  Data := VfsReadAllBytes(Dec, 'gz.txt');
  Check(SameBytes(Data, Raw), 'gz open decompressed content');
  Data := VfsReadAllBytes(Dec, 'plain.txt');
  Check(SameBytes(Data, BytesOf('plain stays')), 'plain stays after gz');
  SI := Dec.Stat('empty.gz');
  Check(SI.Info.Size = 0, 'empty gz stat 0');
  Data := VfsReadAllBytes(Dec, 'empty.gz');
  Check(Length(Data) = 0, 'empty gz open 0');
  L := Dec.List('.');
  Check(Length(L) = 3, 'list count unchanged');
end;

procedure TestGzipForcedMode;
var
  Inner, Dec: IVfs;
  Raw: TBytes;
  Data: TBytes;
  Got: Boolean;
begin
  Inner := MakeGzipped;
  Raw := BytesOf('hello compressed world — nextPas vfs S6');
  Dec := CreateDecompressingVfs(Inner, daGzip);
  Data := VfsReadAllBytes(Dec, 'gz.txt');
  Check(SameBytes(Data, Raw), 'daGzip gz ok');
  Got := False;
  try
    Data := VfsReadAllBytes(Dec, 'plain.txt');
  except
    on E: EVfsError do Got := True;
    on E: Exception do Got := True;
  end;
  Check(Got, 'daGzip plain must fail');
end;

procedure TestETagAndLastModified;
var
  Inner, Dec: IVfs;
  ET: IVfsETag;
  Tag, LM: string;
begin
  Inner := MakeGzipped;
  Dec := CreateDecompressingVfs(Inner, daAuto);
  Check(Dec.QueryInterface(IVfsETag, ET) = 0, 'decorator exposes IVfsETag');
  Check(not ET.TryGetETag('gz.txt', Tag), 'ETag disabled after decompress');
  Check(Tag = '', 'ETag empty');
  Check(not ET.TryGetLastModified('gz.txt', LM) or (LM = ''), 'LastModified passthrough');
end;

procedure TestNilInnerRaises;
var
  Got: Boolean;
begin
  Got := False;
  try
    CreateDecompressingVfs(nil);
  except
    on E: EVfsError do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'nil inner raises');
end;

procedure TestListMissingRaises;
var
  Inner, Dec: IVfs;
  Got: Boolean;
begin
  Inner := MakePlain;
  Dec := CreateDecompressingVfs(Inner, daAuto);
  Got := False;
  try
    Dec.List('nope');
  except
    on E: EVfsError do Got := True;
    on E: Exception do ;
  end;
  Check(Got, 'list missing raises via inner');
end;

procedure TestLargeNonGzipStatHeaderPeek;
var
  B: TVfsTreeBuilder;
  Inner, Dec: IVfs;
  Large: TBytes;
  SI: TStatInfo;
  Data: TBytes;
  I: Integer;
begin
  SetLength(Large, 1024 * 1024);
  for I := 0 to High(Large) do Large[I] := Byte(Ord('A') + (I mod 26));
  Large[0] := Ord('X'); Large[1] := Ord('Y');
  B := TVfsTreeBuilder.Create;
  try
    B.AddFile('large.bin', Large, 100);
    Inner := B.Freeze;
  finally
    B.Free;
  end;
  Dec := CreateDecompressingVfs(Inner, daAuto);
  SI := Dec.Stat('large.bin');
  Check(SI.Info.Size = Int64(Length(Large)), 'large non-gzip stat size unchanged (header peek)');
  Check(SI.ContentHash <> 0, 'large non-gzip stat hash preserved');
  Data := VfsReadAllBytes(Dec, 'large.bin');
  Check(SameBytes(Data, Large), 'large non-gzip open passthrough');
end;

begin
  T := TTestSuite.Create('nextpas.core.vfs.compressed');
  T.Test('non-gzip passthrough', @TestNonGzipPassthrough);
  T.Test('gzip auto decompress stat+open', @TestGzipAutoDecompress);
  T.Test('gzip forced mode', @TestGzipForcedMode);
  T.Test('ETag disabled LastModified passthrough', @TestETagAndLastModified);
  T.Test('nil inner raises', @TestNilInnerRaises);
  T.Test('list missing raises', @TestListMissingRaises);
  T.Test('large non-gzip Stat header peek', @TestLargeNonGzipStatHeaderPeek);
  if not T.Run then Halt(1);
end.
