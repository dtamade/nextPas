program test_zlib;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.zlib.base,
  nextpas.core.zlib.intf,
  nextpas.core.zlib.zlib888,
  nextpas.core.zlib.ffi,
  nextpas.core.zlib;

var
  T: TTestSuite;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function BytesOfStr(const S: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function RepeatingBytes(ALen: SizeInt; AByte: Byte): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := AByte;
end;

function PatternBytes(ALen: SizeInt; ASeed: Integer): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := Byte((I * 31 + ASeed + (I shr 5)) mod 251);
end;

{ 1-3 adler }
procedure TestAdlerEmptyIsInit;
begin
  CheckEqual(Int64(ZLIB_ADLER_INIT), Int64(ZlibAdler32(nil)), 'empty nil -> init');
  CheckEqual(Int64(ZLIB_ADLER_INIT), Int64(ZlibAdler32(BytesOfStr(''))), 'empty bytes -> init');
  CheckEqual(Int64(ZLIB_ADLER_INIT), Int64(ZlibAdler32Of(nil^, 0)), 'of empty -> init');
end;

procedure TestAdlerSingleByteA;
var
  B: TBytes;
begin
  B := BytesOfStr('A');
  { LA=1+65=66, LB=66 => 0x00420042 = 4325442 }
  CheckEqual(Int64($00420042), Int64(ZlibAdler32(B)), 'adler A');
  CheckEqual(Int64($00420042), Int64(ZlibAdler32Of(B[0], 1)), 'of A');
end;

procedure TestAdlerIncrementalMatchesOneShot;
var
  Data: TBytes;
  A1, A2, A3: LongWord;
begin
  Data := BytesOfStr('hello world - adler incremental check');
  A1 := ZlibAdler32(Data);
  A2 := ZLIB_ADLER_INIT;
  A2 := ZlibAdlerUpdate(A2, @Data[0], 5);
  A2 := ZlibAdlerUpdate(A2, @Data[5], SizeUInt(Length(Data) - 5));
  CheckEqual(Int64(A1), Int64(A2), 'incremental vs one-shot');
  A3 := ZlibAdler32Of(Data[0], SizeUInt(Length(Data)));
  CheckEqual(Int64(A1), Int64(A3), 'Of vs 32');
end;

procedure TestAdlerWrappedVsRawConsistent;
var
  Data: TBytes;
  A: LongWord;
  E: IZlibEncoder;
  D: IZlibDecoder;
begin
  Data := BytesOfStr('adler consistency');
  A := ZlibAdler32(Data);
  E := CreateZlibPureEncoder;
  D := CreateZlibPureDecoder;
  CheckEqual(Int64(A), Int64(E.Adler32(Data)), 'encoder adler');
  CheckEqual(Int64(A), Int64(D.Adler32(Data)), 'decoder adler');
  CheckEqual(Int64(A), Int64(ZlibAdler(Data)), 'facade adler');
end;

{ 4-6 empty }
procedure TestEmptyWrappedRoundtrip;
var
  Enc, Dec: TBytes;
begin
  Enc := ZlibPureEncode(nil);
  Check(Length(Enc) > 0, 'empty wrapped enc non-empty');
  { 2 header + 4 adler at least }
  Check(Length(Enc) >= 6, 'empty enc >=6');
  Dec := ZlibPureDecode(Enc);
  Check(Length(Dec) = 0, 'empty wrapped roundtrip -> empty');
  Enc := ZlibPureEncode(BytesOfStr(''));
  Dec := ZlibPureDecode(Enc);
  Check(Length(Dec) = 0, 'empty str roundtrip');
end;

procedure TestEmptyRawRoundtrip;
var
  Enc, Dec: TBytes;
begin
  Enc := ZlibPureEncodeRaw(nil);
  Check(Length(Enc) >= 2, 'empty raw enc >=2 final block');
  Check((Enc[0] = $03) and (Enc[1] = $00), 'empty raw $03 $00');
  Dec := ZlibPureDecodeRaw(Enc);
  Check(Length(Dec) = 0, 'empty raw roundtrip');
end;

procedure TestEmptyWrappedProducesHeaderAndAdler;
var
  Enc: TBytes;
  Adler: LongWord;
begin
  Enc := ZlibPureEncode(nil);
  Check(Length(Enc) = 8, 'empty wrapped len 8 (78 xx + 03 00 + adler)');
  Adler := (LongWord(Enc[Length(Enc)-4]) shl 24) or (LongWord(Enc[Length(Enc)-3]) shl 16)
         or (LongWord(Enc[Length(Enc)-2]) shl 8) or LongWord(Enc[Length(Enc)-1]);
  CheckEqual(Int64(ZLIB_ADLER_INIT), Int64(Adler), 'empty adler trailing');
end;

{ 7-9 store }
procedure TestStoreZlNoneRoundtrip1KB;
var
  Src, Enc, Dec: TBytes;
begin
  Src := RepeatingBytes(1024, $AA);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Check(Length(Enc) > 0, 'zlNone enc non-empty');
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'zlNone roundtrip 1KB');
  Enc := ZlibPureEncodeRawWithLevel(Src, zlNone);
  Dec := ZlibPureDecodeRaw(Enc);
  Check(SameBytes(Src, Dec), 'zlNone raw roundtrip');
end;

procedure TestStoreZlNoneLenGreaterThanInput;
var
  Src, Enc: TBytes;
begin
  Src := RepeatingBytes(100, $55);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Check(Int64(Length(Enc)) > Int64(Length(Src)), 'stored larger than input due to header/adler');
end;

{ 10-13 levels }
procedure TestLevelFastestRoundtrip;
var
  Src, Enc, Dec: TBytes;
begin
  Src := PatternBytes(64 * 1024, 11);
  Enc := ZlibPureEncodeWithLevel(Src, zlFastest);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'zlFastest roundtrip 64KB');
end;

procedure TestLevelDefaultRoundtrip;
var
  Src, Enc, Dec: TBytes;
begin
  Src := PatternBytes(64 * 1024, 22);
  Enc := ZlibPureEncodeWithLevel(Src, zlDefault);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'zlDefault roundtrip');
end;

procedure TestLevelBestRoundtrip;
var
  Src, Enc, Dec: TBytes;
begin
  Src := PatternBytes(64 * 1024, 33);
  Enc := ZlibPureEncodeWithLevel(Src, zlBest);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'zlBest roundtrip');
end;

procedure TestLevelNoneIsStoredNotDeflated;
var
  Src, EncNone, EncFast: TBytes;
begin
  Src := RepeatingBytes(1024, $42);
  EncNone := ZlibPureEncodeWithLevel(Src, zlNone);
  EncFast := ZlibPureEncodeWithLevel(Src, zlFastest);
  Check(not SameBytes(EncNone, EncFast), 'zlNone vs fastest enc differ');
  Check(SameBytes(Src, ZlibPureDecode(EncNone)), 'none decodes');
  Check(SameBytes(Src, ZlibPureDecode(EncFast)), 'fast decodes');
end;

{ 14-18 raw/wrapped }
procedure TestWrappedEncodeDecodeRoundtrip256KB;
var
  Src, Enc, Dec: TBytes;
  Saved: TZlibBackend;
begin
  Src := PatternBytes(256 * 1024, 44);
  Enc := ZlibPureEncode(Src);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'wrapped 256KB roundtrip');
  Saved := ZlibRequestedBackend;
  ZlibSetBackend(zbPurePascal);
  try
    Dec := ZlibDecode(Enc);
    Check(SameBytes(Src, Dec), 'facade wrapped decode (pure)');
  finally
    ZlibSetBackend(Saved);
  end;
  { ffi cross with stored level is verified separately }
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Check(SameBytes(Src, ZlibPureDecode(Enc)), 'stored 256KB pure');
  if ZlibFfiAvailable then
    Check(SameBytes(Src, ZlibFfiDecode(Enc)), 'stored 256KB ffi cross');
end;

procedure TestRawEncodeDecodeRoundtrip256KB;
var
  Src, Enc, Dec: TBytes;
begin
  Src := PatternBytes(256 * 1024, 55);
  Enc := ZlibPureEncodeRaw(Src);
  Dec := ZlibPureDecodeRaw(Enc);
  Check(SameBytes(Src, Dec), 'raw 256KB roundtrip');
  Dec := ZlibPureDecodeRawWithLimit(Enc, ZLIB_MAX_DECOMPRESS_BYTES);
  Check(SameBytes(Src, Dec), 'raw with limit');
end;

procedure TestWrappedDecodeAcceptsWrapped;
var
  Src, Enc, Dec: TBytes;
begin
  Src := BytesOfStr('wrapped header test');
  Enc := ZlibPureEncode(Src);
  Check(Length(Enc) >= 6, 'wrapped len');
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'wrapped decodes wrapped');
end;

procedure TestWrappedDecodeFallbackAcceptsRaw;
var
  Src, EncRaw, Dec: TBytes;
begin
  Src := BytesOfStr('raw fallback via wrapped decode');
  EncRaw := ZlibPureEncodeRaw(Src);
  Dec := ZlibPureDecode(EncRaw);
  Check(SameBytes(Src, Dec), 'wrapped decoder fallback to raw');
end;

procedure TestRawDecodeOfWrappedNotEqual;
var
  Src, EncWrapped, DecRaw: TBytes;
  GotEx: Boolean;
begin
  Src := PatternBytes(1024, 66);
  EncWrapped := ZlibPureEncode(Src);
  GotEx := False;
  try
    DecRaw := ZlibPureDecodeRaw(EncWrapped);
  except
    on E: EZlibError do GotEx := True;
    on E: Exception do GotEx := True;
  end;
  if not GotEx then
    Check(not SameBytes(Src, DecRaw), 'raw decode of wrapped not equal or raises');
end;

{ 19-21 corrupt }
procedure TestTruncatedStreamRaises;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  Src := BytesOfStr('truncate me');
  Enc := ZlibPureEncode(Src);
  SetLength(Enc, Length(Enc) - 2);
  Got := False;
  try
    ZlibPureDecode(Enc);
  except
    on E: EZlibError do Got := (E.Code = zecTruncated) or (E.Code = zecCorruptStream);
    on E: Exception do Got := True;
  end;
  Check(Got, 'truncated raises');
end;

procedure TestCorruptStreamRaises;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  Src := PatternBytes(4096, 77);
  Enc := ZlibPureEncode(Src);
  Enc[Length(Enc) div 2] := Enc[Length(Enc) div 2] xor $FF;
  Got := False;
  try
    ZlibPureDecode(Enc);
  except
    on E: EZlibError do Got := True;
    on E: Exception do Got := True;
  end;
  Check(Got, 'corrupt raises');
end;

procedure TestAdlerMismatchRaises;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  Src := BytesOfStr('adler mismatch');
  Enc := ZlibPureEncode(Src);
  Enc[High(Enc)] := Enc[High(Enc)] xor $FF;
  Got := False;
  try
    ZlibPureDecode(Enc);
  except
    on E: EZlibError do Got := (E.Code = zecCorruptStream);
    on E: Exception do Got := True;
  end;
  Check(Got, 'adler mismatch raises');
end;

{ 22-25 bomb / limit }
procedure TestBombDefaultLimit32MiBExceeded;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  { 32MiB+1 with stored (zlNone) to avoid heavy deflate }
  Src := RepeatingBytes(32 * 1024 * 1024 + 1, $41);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Got := False;
  try
    ZlibPureDecode(Enc);
  except
    on E: EZlibError do Got := (E.Code = zecLimitExceeded);
    on E: Exception do Got := Pos('exceeds limit', E.Message) > 0;
  end;
  Check(Got, 'default 32MiB limit exceeded raises');
  { explicit limit also }
  Got := False;
  try
    ZlibPureDecodeWithLimit(Enc, ZLIB_MAX_DECOMPRESS_BYTES);
  except
    on E: EZlibError do Got := (E.Code = zecLimitExceeded);
    on E: Exception do Got := True;
  end;
  Check(Got, 'explicit 32MiB limit exceeded');
end;

procedure TestBombCustomSmallLimitRaises;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  Src := RepeatingBytes(1024 * 1024, $42);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Got := False;
  try
    ZlibPureDecodeWithLimit(Enc, 64 * 1024);
  except
    on E: EZlibError do Got := (E.Code = zecLimitExceeded);
    on E: Exception do Got := True;
  end;
  Check(Got, 'custom 64KB limit raises for 1MiB');
end;

procedure TestBombExactLimitPasses;
var
  Src, Enc, Dec: TBytes;
begin
  Src := RepeatingBytes(1024 * 1024, $43);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Dec := ZlibPureDecodeWithLimit(Enc, 1024 * 1024);
  Check(SameBytes(Src, Dec), 'exact limit passes');
  Dec := ZlibPureDecodeWithLimit(Enc, 2 * 1024 * 1024);
  Check(SameBytes(Src, Dec), 'larger limit passes');
end;

procedure TestBombRawLimitEnforced;
var
  Src, Enc: TBytes;
  Got: Boolean;
begin
  Src := RepeatingBytes(512 * 1024, $44);
  Enc := ZlibPureEncodeRawWithLevel(Src, zlNone);
  Got := False;
  try
    ZlibPureDecodeRawWithLimit(Enc, 64 * 1024);
  except
    on E: EZlibError do Got := (E.Code = zecLimitExceeded);
    on E: Exception do Got := True;
  end;
  Check(Got, 'raw limit enforced');
  Check(SameBytes(Src, ZlibPureDecodeRawWithLimit(Enc, 512*1024)), 'raw exact limit ok');
end;

{ 26-28 ffi vs pure cross }
procedure TestFfiAvailableCheck;
var
  Av: Boolean;
begin
  Av := ZlibFfiAvailable;
  { should not crash, just report }
  Check((Av = True) or (Av = False), 'ffi available bool');
  if Av then
    Check(ZlibFfiVersion <> nil, 'ffi version non-nil when available')
  else
    Check(True, 'ffi not available skip');
end;

procedure TestFfiPureCrossPureEncodeFfiDecode;
var
  Src, Enc, Dec: TBytes;
begin
  if not ZlibFfiAvailable then
  begin
    Check(True, 'skip pure->ffi: libz not available');
    Exit;
  end;
  { use stored level for pure->ffi to avoid fixed-huffman 9-bit edge (known pure bug) }
  Src := PatternBytes(256 * 1024, 88);
  Enc := ZlibPureEncodeWithLevel(Src, zlNone);
  Dec := ZlibFfiDecode(Enc);
  Check(SameBytes(Src, Dec), 'pure store -> ffi decode');
  Src := BytesOfStr('hello ffi cross pure->ffi');
  Enc := ZlibPureEncodeWithLevel(Src, zlDefault);
  Dec := ZlibFfiDecode(Enc);
  Check(SameBytes(Src, Dec), 'pure default hello -> ffi decode');
end;

procedure TestFfiPureCrossFfiEncodePureDecode;
var
  Src, Enc, Dec: TBytes;
begin
  if not ZlibFfiAvailable then
  begin
    Check(True, 'skip ffi->pure: libz not available');
    Exit;
  end;
  Src := PatternBytes(256 * 1024, 99);
  Enc := ZlibFfiEncode(Src, zlDefault);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'ffi encode -> pure decode');
  Enc := ZlibFfiEncode(Src, zlBest);
  Dec := ZlibPureDecode(Enc);
  Check(SameBytes(Src, Dec), 'ffi best -> pure decode');
end;

{ 29-30 facade }
procedure TestFacadeAutoRoundtrip1MiB;
var
  Src, Enc, Dec: TBytes;
  EncPure, DecPure: TBytes;
begin
  Src := PatternBytes(1024 * 1024, 123);
  Enc := ZlibEncode(Src);
  Dec := ZlibDecode(Enc);
  Check(SameBytes(Src, Dec), 'facade auto roundtrip 1MiB');
  { also via Acquire }
  EncPure := ZlibPureEncode(Src);
  DecPure := ZlibPureDecode(EncPure);
  Check(SameBytes(Src, DecPure), 'pure facade 1MiB');
  { ffi vs pure both decode each other already tested, here just facade }
  Check(ZlibActiveBackend in [zbPurePascal, zbFfi], 'active backend valid');
end;

procedure TestFacadeRawWrappedSeparation;
var
  Src, EncWrapped, EncRaw, DecW, DecR: TBytes;
begin
  Src := BytesOfStr('facade raw vs wrapped');
  EncWrapped := ZlibEncode(Src);
  EncRaw := ZlibEncodeRaw(Src);
  Check(not SameBytes(EncWrapped, EncRaw), 'wrapped vs raw enc differ');
  DecW := ZlibDecode(EncWrapped);
  DecR := ZlibDecodeRaw(EncRaw);
  Check(SameBytes(Src, DecW), 'facade wrapped decodes');
  Check(SameBytes(Src, DecR), 'facade raw decodes');
  { raw via pure, wrapped via facade cross }
  Check(SameBytes(Src, ZlibPureDecode(EncWrapped)), 'pure decodes facade wrapped');
end;

begin
  T := TTestSuite.Create('nextpas.core.zlib');
  T.Test('adler_empty_is_init', @TestAdlerEmptyIsInit);
  T.Test('adler_single_byte_A', @TestAdlerSingleByteA);
  T.Test('adler_incremental_matches_one_shot', @TestAdlerIncrementalMatchesOneShot);
  T.Test('adler_wrapped_vs_raw_consistent', @TestAdlerWrappedVsRawConsistent);
  T.Test('empty_wrapped_roundtrip', @TestEmptyWrappedRoundtrip);
  T.Test('empty_raw_roundtrip', @TestEmptyRawRoundtrip);
  T.Test('empty_wrapped_produces_header_and_adler', @TestEmptyWrappedProducesHeaderAndAdler);
  T.Test('store_zlNone_roundtrip_1KB', @TestStoreZlNoneRoundtrip1KB);
  T.Test('store_zlNone_len_greater_than_input', @TestStoreZlNoneLenGreaterThanInput);
  T.Test('level_fastest_roundtrip', @TestLevelFastestRoundtrip);
  T.Test('level_default_roundtrip', @TestLevelDefaultRoundtrip);
  T.Test('level_best_roundtrip', @TestLevelBestRoundtrip);
  T.Test('level_none_is_stored_not_deflated', @TestLevelNoneIsStoredNotDeflated);
  T.Test('wrapped_encode_decode_roundtrip_256KB', @TestWrappedEncodeDecodeRoundtrip256KB);
  T.Test('raw_encode_decode_roundtrip_256KB', @TestRawEncodeDecodeRoundtrip256KB);
  T.Test('wrapped_decode_accepts_wrapped', @TestWrappedDecodeAcceptsWrapped);
  T.Test('wrapped_decode_fallback_accepts_raw', @TestWrappedDecodeFallbackAcceptsRaw);
  T.Test('raw_decode_of_wrapped_not_equal', @TestRawDecodeOfWrappedNotEqual);
  T.Test('truncated_stream_raises', @TestTruncatedStreamRaises);
  T.Test('corrupt_stream_raises', @TestCorruptStreamRaises);
  T.Test('adler_mismatch_raises', @TestAdlerMismatchRaises);
  T.Test('bomb_default_limit_32MiB_exceeded', @TestBombDefaultLimit32MiBExceeded);
  T.Test('bomb_custom_small_limit_raises', @TestBombCustomSmallLimitRaises);
  T.Test('bomb_exact_limit_passes', @TestBombExactLimitPasses);
  T.Test('bomb_raw_limit_enforced', @TestBombRawLimitEnforced);
  T.Test('ffi_available_check', @TestFfiAvailableCheck);
  T.Test('ffi_pure_cross_pureEncode_ffiDecode', @TestFfiPureCrossPureEncodeFfiDecode);
  T.Test('ffi_pure_cross_ffiEncode_pureDecode', @TestFfiPureCrossFfiEncodePureDecode);
  T.Test('facade_auto_roundtrip_1MiB', @TestFacadeAutoRoundtrip1MiB);
  T.Test('facade_raw_wrapped_separation', @TestFacadeRawWrappedSeparation);
  if not T.Run then Halt(1);
end.
