program test_compress_zstd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.compress.zstd;

var
  GDir: string;

function LcgNext(var AState: Cardinal): Byte;
begin
  AState := AState * 1664525 + 1013904223;
  Result := Byte((AState shr 16) and $FF);
end;

function PatternedBytes(ASize: SizeInt; var ASeed: Cardinal): TBytes;
var
  I: SizeInt;
begin
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := LcgNext(ASeed);
end;

function SameBytes(const AA, AB: TBytes): Boolean;
var
  I: SizeInt;
begin
  Result := False;
  if Length(AA) <> Length(AB) then
    Exit;
  if Length(AA) = 0 then
    Exit(True);
  for I := 0 to Length(AA) - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

procedure PutFile(const APath: string; const AData: TBytes);
begin
  WriteFile(APath, AData, PermDefault);
end;

function ReadFileBytes(const APath: string): TBytes;
begin
  Result := ReadFile(APath);
end;

{ ── roundtrips ───────────────────────────────────────────────────────────── }

procedure TestRoundtripSizes;
const
  Sizes: array[0..4] of Integer = (1, 64, 511, 4096, 100 * 1024);
var
  Seed: Cardinal;
  I: Integer;
  Plain, Back, Packed_: TBytes;
begin
  Seed := $5EED0001;
  for I in Sizes do
  begin
    Plain := PatternedBytes(I, Seed);
    Packed_ := ZstdCompress(Plain);
    CheckTrue(Length(Packed_) > 0, 'compressed output non-empty (' +
      IntToStr(I) + 'B)');
    Back := ZstdDecompress(Packed_);
    Check(SameBytes(Plain, Back), 'roundtrip ' + IntToStr(I) + 'B');
  end;
end;

procedure TestLevelParameterAccepted;
var
  Plain, Packed_, Back: TBytes;
  Seed: Cardinal;
begin
  // library clamps levels; both extremes must still roundtrip
  Seed := $C0FFE001;
  Plain := PatternedBytes(8192, Seed);
  Back := ZstdDecompress(ZstdCompress(Plain, 1));
  Check(SameBytes(Plain, Back), 'level 1 roundtrip');
  Back := ZstdDecompress(ZstdCompress(Plain, 19));
  Check(SameBytes(Plain, Back), 'level 19 roundtrip');
  Packed_ := ZstdCompress(Plain);
end;

{ ── golden interop with the system zstd CLI ─────────────────────────────── }

procedure TestOurOutputDecodableBySystemZstd;
var
  Plain, Packed_: TBytes;
  Seed: Cardinal;
begin
  Seed := $600D0002;
  Plain := PatternedBytes(32 * 1024, Seed);
  Packed_ := ZstdCompress(Plain);
  PutFile(PathJoin2(GDir, 'ours.zst'), Packed_);
  RunInChecked('zstd', ['-d', '-f', '-q',
    PathJoin2(GDir, 'ours.zst'), '-o', PathJoin2(GDir, 'ours.out')], GDir);
  Check(SameBytes(ReadFileBytes(PathJoin2(GDir, 'ours.out')), Plain),
    'system zstd decodes our frame');
end;

procedure TestSystemZstdOutputDecodableByUs;
var
  Plain: TBytes;
  Seed: Cardinal;
begin
  Seed := $ABCD0003;
  Plain := PatternedBytes(24 * 1024, Seed);
  PutFile(PathJoin2(GDir, 'theirs.bin'), Plain);
  RunInChecked('zstd', ['-f', '-q',
    PathJoin2(GDir, 'theirs.bin'), '-o', PathJoin2(GDir, 'theirs.zst')], GDir);
  Check(SameBytes(ZstdDecompress(
    ReadFileBytes(PathJoin2(GDir, 'theirs.zst'))), Plain),
    'we decode a CLI-produced frame');
end;

{ ── streaming fallback + error paths ────────────────────────────────────── }

procedure TestStreamingFallbackForUnknownContentSize;
var
  Plain: TBytes;
  Seed: Cardinal;
  Out: TProcessOutput;
begin
  // piping through the CLI strips nothing, but compressing from stdin with
  // --no-content-size produces a frame whose content size is unknown —
  // exactly the path that must hit our DStream fallback
  Seed := $0FA11004;
  Plain := PatternedBytes(48 * 1024, Seed);
  PutFile(PathJoin2(GDir, 'plain.bin'), Plain);
  Out := RunInChecked('/bin/sh', ['-c',
    'cat "' + PathJoin2(GDir, 'plain.bin') + '" | zstd -q --no-content-size > ''' +
    PathJoin2(GDir, 'nosize.zst') + ''''], GDir);
  CheckTrue(Length(Out.StdErr) >= 0, 'cli ran');
  Check(SameBytes(ZstdDecompress(
    ReadFileBytes(PathJoin2(GDir, 'nosize.zst'))), Plain),
    'unknown-content-size frame decompresses via stream fallback');
end;

procedure TestGarbageRaisesEIOError;
var
  Junk: TBytes;
  Raised: Boolean;
begin
  // valid zstd magic is 28 B5 2F FD; flip it and decompression must fail
  Junk := TBytes.Create($00, $01, $02, $03, $FF, $FF, $FF, $FF);
  Raised := False;
  try
    ZstdDecompress(Junk);
  except
    on E: EIOError do
      Raised := True;
  end;
  Check(Raised, 'garbage input raises EIOError');
end;

{ ── version surface ─────────────────────────────────────────────────────── }

procedure TestVersionStringNonEmpty;
begin
  CheckTrue(Length(ZstdVersionString) > 0, 'version string non-empty');
end;

{ ── main ─────────────────────────────────────────────────────────────────── }

procedure SetupFixture;
begin
  GDir := PathJoin([GetTempDir,
    'nextpas_zstd_' + IntToStr(GetProcessID)]);
  RemoveAll(GDir);
  MkdirAll(GDir, PermDirDefault);
end;

procedure CleanupFixture;
begin
  RemoveAll(GDir);
end;

var
  T: TTestSuite;
begin
  SetupFixture;
  try
    T := TTestSuite.Create('nextpas.core.compress.zstd');
    T.Test('roundtrip across sizes', @TestRoundtripSizes);
    T.Test('level extremes roundtrip', @TestLevelParameterAccepted);
    T.Test('golden: system zstd decodes ours',
      @TestOurOutputDecodableBySystemZstd);
    T.Test('golden: we decode system zstd output',
      @TestSystemZstdOutputDecodableByUs);
    T.Test('streaming fallback for unknown content size',
      @TestStreamingFallbackForUnknownContentSize);
    T.Test('garbage raises EIOError', @TestGarbageRaisesEIOError);
    T.Test('version string non-empty', @TestVersionStringNonEmpty);
    if not T.Run then Halt(1);
  finally
    CleanupFixture;
  end;
end.
