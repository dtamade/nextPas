unit nextpas.core.audio.codec.mp3;

{ ============================================================================ }
{ 纯 Pascal MP3 解码器（minimp3 语义）                                          }
{                                                                              }
{ 来源：vendor/minimp3/minimp3.h 经 c2pas888 翻译为 Pascal，随后手工优化：      }
{   - mp3d_synth 内核 + PCM 转换：SSE 内联汇编（8 块蝶形 ×4 车道）              }
{   - mp3d_DCT_II：SSE 每 4 band 并行（标量回退保留在尾部）                     }
{   - L3_antialias / L3_imdct36 combine：SSE 4 车道                            }
{ 全部 SSE 核与 C NO_SIMD 标量路径逐位一致（IEEE 单精度运算顺序逐一对应）；     }
{ 与 C 参考解码输出 cmp 位精确（117 帧 lame CBR 测试流，Linux 与 win64-wine）。 }
{ 性能：约 86-88% of gcc -O2 C（200 遍基准）。                                  }
{ Win64 ABI：synth 累加器固定 XMM6/7 并在块外缘条件保存/恢复（非易失寄存器），  }
{ GPR 只用易失集——-gl 与否均位精确。                                            }
{ 注意：标量 mp3d_DCT_II 回退含 FPC 3.3.1 -O2 常量寄存器复用 bug 的规避写法。   }
{ ============================================================================ }


{$mode objfpc}{$H+}{$notes off}
{$PACKRECORDS C}

interface

type
  TSizeT = QWord;
  TPtrdiffT = Int64;
  TWcharT = LongInt;
  TXBuiltinVaList = Pointer;
  TInt8T = ShortInt;
  TUint8T = Byte;
  TInt16T = SmallInt;
  TUint16T = Word;
  TInt32T = LongInt;
  TUint32T = LongWord;
  TInt64T = Int64;
  TUint64T = QWord;
  TIntptrT = Int64;
  TUintptrT = QWord;
  TIntmaxT = Int64;
  TUintmaxT = QWord;
  PMp3decFrameInfoT = ^TMp3decFrameInfoT;
  PTMp3decFrameInfoT = PMp3decFrameInfoT;
  PMp3decT = ^TMp3decT;
  PTMp3decT = PMp3decT;
  TMp3dSampleT = TInt16T;
  PMp3dSampleT = ^TMp3dSampleT;
  PTMp3dSampleT = PMp3dSampleT;
  PUint8T = ^TUint8T;
  PTUint8T = PUint8T;
  PBsT = ^TBsT;
  PTBsT = PBsT;
  PL12ScaleInfo = ^TL12ScaleInfo;
  PTL12ScaleInfo = PL12ScaleInfo;
  PL12SubbandAllocT = ^TL12SubbandAllocT;
  PTL12SubbandAllocT = PL12SubbandAllocT;
  PL3GrInfoT = ^TL3GrInfoT;
  PTL3GrInfoT = PL3GrInfoT;
  PMp3decScratchT = ^TMp3decScratchT;
  PTMp3decScratchT = PMp3decScratchT;
  PPAnsiChar = ^PAnsiChar;
  PWcharT = ^TWcharT;
  PTWcharT = PWcharT;
  TRawProc9779B54A = function(p0: Pointer; p1: Pointer): LongInt; cdecl;
  TRawProcE21ED0E9 = procedure; cdecl;
  TMp3decFrameInfoT = record
    frame_bytes: LongInt;
    frame_offset: LongInt;
    channels: LongInt;
    hz: LongInt;
    layer: LongInt;
    bitrate_kbps: LongInt;
  end;
  TMp3decT = record
    mdct_overlap: array[0..1] of array[0..287] of Single;
    qmf_state: array[0..959] of Single;
    reserv: LongInt;
    free_format_bytes: LongInt;
    header: array[0..3] of Byte;
    reserv_buf: array[0..510] of Byte;
  end;
  TBsT = record
    buf: PUint8T;
    pos: LongInt;
    limit: LongInt;
  end;
  TL12ScaleInfo = record
    scf: array[0..191] of Single;
    total_bands: TUint8T;
    stereo_bands: TUint8T;
    bitalloc: array[0..63] of TUint8T;
    scfcod: array[0..63] of TUint8T;
  end;
  TL12SubbandAllocT = record
    tab_offset: TUint8T;
    code_tab_width: TUint8T;
    band_count: TUint8T;
  end;
  TL3GrInfoT = record
    sfbtab: PUint8T;
    part_23_length: TUint16T;
    big_values: TUint16T;
    scalefac_compress: TUint16T;
    global_gain: TUint8T;
    block_type: TUint8T;
    mixed_block_flag: TUint8T;
    n_long_sfb: TUint8T;
    n_short_sfb: TUint8T;
    table_select: array[0..2] of TUint8T;
    region_count: array[0..2] of TUint8T;
    subblock_gain: array[0..2] of TUint8T;
    preflag: TUint8T;
    scalefac_scale: TUint8T;
    count1_table: TUint8T;
    scfsi: TUint8T;
  end;
  TMp3decScratchT = record
    bs: TBsT;
    maindata: array[0..2814] of TUint8T;
    gr_info: array[0..3] of TL3GrInfoT;
    grbuf: array[0..1] of array[0..575] of Single;
    scf: array[0..39] of Single;
    syn: array[0..32] of array[0..63] of Single;
    ist_pos: array[0..1] of array[0..38] of TUint8T;
  end;

const
  MINIMP3_MAX_SAMPLES_PER_FRAME = 2304;
  MAX_FREE_FORMAT_FRAME_SIZE = 2304;
  MAX_FRAME_SYNC_MATCHES = 10;
  MAX_BITRESERVOIR_BYTES = 511;
  SHORT_BLOCK_TYPE = 2;
  STOP_BLOCK_TYPE = 3;
  MODE_MONO = 3;
  MODE_JOINT_STEREO = 1;
  HDR_SIZE = 4;
  BITS_DEQUANTIZER_OUT = -1;
  HAVE_SIMD = 0;
  HAVE_ARMV6 = 0;








procedure abort(); cdecl;

procedure exit_(status: LongInt); cdecl;

function atoi(nptr: PAnsiChar): LongInt; cdecl;

function atol(nptr: PAnsiChar): Int64; cdecl;

function atoll(nptr: PAnsiChar): Int64; cdecl;

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;

function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;

function atof(nptr: PAnsiChar): Double; cdecl;

function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function abs(j: LongInt): LongInt; cdecl; external 'c' name 'abs';

function labs(j: Int64): Int64; cdecl; external 'c' name 'labs';

function rand(): LongInt; cdecl;

procedure srand(seed: LongWord); cdecl;

procedure qsort(base: Pointer; nmemb: TSizeT; size: TSizeT; compar: TRawProc9779B54A); cdecl; external 'c' name 'qsort';

function getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';

function _wgetenv(name: PWcharT): PWcharT; cdecl; external 'c' name '_wgetenv';

function wcslen(s_2: PWcharT): TSizeT; cdecl; external 'c' name 'wcslen';

function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external 'c' name 'setenv';

function unsetenv(name: PAnsiChar): LongInt; cdecl; external 'c' name 'unsetenv';

function putenv(&string: PAnsiChar): LongInt; cdecl; external 'c' name 'putenv';

function system_(command: PAnsiChar): LongInt; cdecl; external 'c' name 'system';

function atexit(&function: TRawProcE21ED0E9): LongInt; cdecl; external 'c' name 'atexit';

function realpath(path: PAnsiChar; resolved_path: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'realpath';





















procedure mp3dec_init(dec: PMp3decT); cdecl;

function mp3dec_decode_frame(dec: PMp3decT; mp3: PUint8T; mp3_bytes: LongInt; pcm: PMp3dSampleT; info: PMp3decFrameInfoT): LongInt; cdecl;

implementation

{ ---- SIMD 门控：x86-64 SSE 与 aarch64 NEON 共用 MP3DEC_SIMD_ON，
  逐核在实现处按 cpux86_64/cpuaarch64 分派（位精确纪律见 sse 单元）。
  其余架构走纯标量回退，与 SIMD 版逐位一致。
  MP3DEC_NO_SIMD 可强制关闭 SIMD 用于验证/移植。 }
{$ifdef MP3DEC_NO_SIMD}
{$else}
{$if defined(cpux86_64) or defined(cpuaarch64)}
{$define MP3DEC_SIMD_ON}
{$ifend}
{$endif}
{$ifdef cpuaarch64}
{ ppcrossa64 3.3.1 快照在 -O2 下有寄存器分配错译：经 GOT 载入的常量表基址
  寄存器会被循环体当临时复用（L3_antialias 处崩溃；他处静默出错）。
  本单元在 aarch64 上整体回退保守优化——合成热路径由 NEON 汇编核承担，
  不受影响；x86-64/其余架构维持原优化级别 }
{$optimization off}
{$endif}

uses
  nextpas.core.math
  {$ifdef MP3DEC_SIMD_ON}
  {$ifdef cpuaarch64}
  , nextpas.core.audio.codec.mp3.sse
  , nextpas.core.audio.simd
  {$endif}
  {$endif}
  ;

function __c2p_mem_malloc(Size: SizeUInt): Pointer; cdecl;
begin
  if Size = 0 then
    System.Exit(nil);
  GetMem(Result, Size);
end;

function __c2p_mem_calloc(Count, Size: SizeUInt): Pointer; cdecl;
var
  TotalSize: SizeUInt;
begin
  if (Count = 0) or (Size = 0) then
    System.Exit(nil);
  TotalSize := Count * Size;
  if (Size <> 0) and (TotalSize div Size <> Count) then
    System.Exit(nil);
  GetMem(Result, TotalSize);
  FillChar(Result^, TotalSize, 0);
end;

function __c2p_mem_realloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  if Size = 0 then
  begin
    if Ptr <> nil then
      FreeMem(Ptr);
    System.Exit(nil);
  end;
  Result := Ptr;
  ReAllocMem(Result, Size);
end;

procedure __c2p_mem_free(Ptr: Pointer); cdecl;
begin
  if Ptr <> nil then
    FreeMem(Ptr);
end;

function __c2p_stdlib_memcpy(Dest, Src: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  Move(Src^, Dest^, Size);
end;

function __c2p_stdlib_memmove(Dest, Src: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  Move(Src^, Dest^, Size);
end;

function __c2p_stdlib_memset(Dest: Pointer; Value: LongInt; Size: SizeUInt): Pointer; cdecl;
begin
  Result := Dest;
  if Size = 0 then
    System.Exit;
  FillChar(Dest^, Size, Byte(Value));
end;

function __c2p_stdlib_memcmp(Left, Right: Pointer; Size: SizeUInt): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  if Size = 0 then
    System.Exit(0);
  for I := 0 to Size - 1 do
  begin
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
  end;
  Result := 0;
end;

function __c2p_stdlib_strlen(S: PAnsiChar): SizeUInt; cdecl; inline;
begin
  Result := SizeUInt(System.StrLen(S));
end;

function __c2p_stdlib_strcmp(Left, Right: PAnsiChar): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  I := 0;
  repeat
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
    if L = 0 then
      System.Exit(0);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strcpy(Dest, Src: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
begin
  I := 0;
  repeat
    Dest[I] := Src[I];
    if Src[I] = #0 then
      System.Exit(Dest);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strcat(Dest, Src: PAnsiChar): PAnsiChar; cdecl;
var
  DestIndex: SizeUInt;
  SrcIndex: SizeUInt;
begin
  DestIndex := 0;
  while Dest[DestIndex] <> #0 do
    Inc(DestIndex);
  SrcIndex := 0;
  repeat
    Dest[DestIndex + SrcIndex] := Src[SrcIndex];
    if Src[SrcIndex] = #0 then
      System.Exit(Dest);
    Inc(SrcIndex);
  until False;
end;

function __c2p_stdlib_strncat(Dest, Src: PAnsiChar; Count: SizeUInt): PAnsiChar; cdecl;
var
  DestIndex: SizeUInt;
  SrcIndex: SizeUInt;
begin
  DestIndex := 0;
  while Dest[DestIndex] <> #0 do
    Inc(DestIndex);
  SrcIndex := 0;
  while (SrcIndex < Count) and (Src[SrcIndex] <> #0) do
  begin
    Dest[DestIndex + SrcIndex] := Src[SrcIndex];
    Inc(SrcIndex);
  end;
  Dest[DestIndex + SrcIndex] := #0;
  Result := Dest;
end;

function __c2p_stdlib_strncpy(Dest, Src: PAnsiChar; Count: SizeUInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
begin
  Result := Dest;
  if Count = 0 then
    System.Exit;
  I := 0;
  repeat
    Dest[I] := Src[I];
    if Src[I] = #0 then
    begin
      Inc(I);
      while I < Count do
      begin
        Dest[I] := #0;
        Inc(I);
      end;
      System.Exit(Dest);
    end;
    Inc(I);
  until I = Count;
end;

function __c2p_stdlib_strchr(S: PAnsiChar; C: LongInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  I := 0;
  repeat
    if Byte(S[I]) = Target then
      System.Exit(@S[I]);
    if S[I] = #0 then
      System.Exit(nil);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strrchr(S: PAnsiChar; C: LongInt): PAnsiChar; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  I := 0;
  Result := nil;
  repeat
    if Byte(S[I]) = Target then
      Result := @S[I];
    if S[I] = #0 then
      System.Exit(Result);
    Inc(I);
  until False;
end;

function __c2p_stdlib_strstr(Haystack, Needle: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
begin
  if Needle[0] = #0 then
    System.Exit(Haystack);
  I := 0;
  repeat
    J := 0;
    while (Needle[J] <> #0) and (Haystack[I + J] = Needle[J]) do
      Inc(J);
    if Needle[J] = #0 then
      System.Exit(@Haystack[I]);
    if Haystack[I] = #0 then
      System.Exit(nil);
    Inc(I);
  until False;
end;

function __c2p_stdlib_memchr(S: Pointer; C: LongInt; Size: SizeUInt): Pointer; cdecl;
var
  I: SizeUInt;
  Target: Byte;
begin
  Target := Byte(C);
  if Size = 0 then
    System.Exit(nil);
  for I := 0 to Size - 1 do
    if PByte(S)[I] = Target then
      System.Exit(@PByte(S)[I]);
  Result := nil;
end;

function __c2p_stdlib_strspn(S, Accept: PAnsiChar): SizeUInt; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
  Matched: Boolean;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    Matched := False;
    J := 0;
    while Accept[J] <> #0 do
    begin
      if Byte(Accept[J]) = Ch then
      begin
        Matched := True;
        Break;
      end;
      Inc(J);
    end;
    if not Matched then
      System.Exit(I);
    Inc(I);
  end;
  Result := I;
end;

function __c2p_stdlib_strpbrk(S, Accept: PAnsiChar): PAnsiChar; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    J := 0;
    while Accept[J] <> #0 do
    begin
      if Byte(Accept[J]) = Ch then
        System.Exit(@S[I]);
      Inc(J);
    end;
    Inc(I);
  end;
  Result := nil;
end;

function __c2p_stdlib_strcspn(S, Reject: PAnsiChar): SizeUInt; cdecl;
var
  I: SizeUInt;
  J: SizeUInt;
  Ch: Byte;
begin
  I := 0;
  while S[I] <> #0 do
  begin
    Ch := Byte(S[I]);
    J := 0;
    while Reject[J] <> #0 do
    begin
      if Byte(Reject[J]) = Ch then
        System.Exit(I);
      Inc(J);
    end;
    Inc(I);
  end;
  Result := I;
end;

function __c2p_stdlib_isdigit(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('0')) and (C <= Ord('9')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isxdigit(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('0')) and (C <= Ord('9'))) or
     ((C >= Ord('A')) and (C <= Ord('F'))) or
     ((C >= Ord('a')) and (C <= Ord('f'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_tolower(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('A')) and (C <= Ord('Z')) then
    System.Exit(C + 32);
  Result := C;
end;

function __c2p_stdlib_toupper(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('a')) and (C <= Ord('z')) then
    System.Exit(C - 32);
  Result := C;
end;

function __c2p_stdlib_isalpha(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('A')) and (C <= Ord('Z'))) or
     ((C >= Ord('a')) and (C <= Ord('z'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isalnum(C: LongInt): LongInt; cdecl;
begin
  if ((C >= Ord('0')) and (C <= Ord('9'))) or
     ((C >= Ord('A')) and (C <= Ord('Z'))) or
     ((C >= Ord('a')) and (C <= Ord('z'))) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isspace(C: LongInt): LongInt; cdecl;
begin
  if (C = Ord(' ')) or (C = Ord(#9)) or (C = Ord(#10)) or
     (C = Ord(#11)) or (C = Ord(#12)) or (C = Ord(#13)) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isupper(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('A')) and (C <= Ord('Z')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_islower(C: LongInt): LongInt; cdecl;
begin
  if (C >= Ord('a')) and (C <= Ord('z')) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isprint(C: LongInt): LongInt; cdecl;
begin
  if (C >= 32) and (C <= 126) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_ispunct(C: LongInt): LongInt; cdecl;
begin
  if ((C >= 33) and (C <= 47)) or ((C >= 58) and (C <= 64)) or
     ((C >= 91) and (C <= 96)) or ((C >= 123) and (C <= 126)) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_iscntrl(C: LongInt): LongInt; cdecl;
begin
  if ((C >= 0) and (C <= 31)) or (C = 127) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_isgraph(C: LongInt): LongInt; cdecl;
begin
  if (C >= 33) and (C <= 126) then
    System.Exit(1);
  Result := 0;
end;

function __c2p_stdlib_abs(N: LongInt): LongInt; cdecl;
begin
  if N < 0 then
    System.Exit(-N);
  Result := N;
end;

function __c2p_stdlib_labs(N: LongInt): LongInt; cdecl;
begin
  if N < 0 then
    System.Exit(-N);
  Result := N;
end;

function __c2p_stdlib_floor(X: Double): Double; cdecl;
begin
  Result := System.Int(X);
  if (X < 0.0) and (X <> Result) then
    Result := Result - 1.0;
end;

function __c2p_stdlib_ceil(X: Double): Double; cdecl;
begin
  Result := System.Int(X);
  if (X > 0.0) and (X <> Result) then
    Result := Result + 1.0;
end;

function __c2p_stdlib_round(X: Double): Double; cdecl;
var
  Q: Int64;
  T: Int64;
begin
  Move(X, Q, 8);
  if (Q and $7FF0000000000000) = $7FF0000000000000 then Result := X
  else if (Q and $7FF0000000000000) >= $4330000000000000 then Result := X
  else if Q = $8000000000000000 then Result := X
  else
  begin
    T := System.Trunc(X);
    if X >= 0 then
    begin
      if (X - T) >= 0.5 then Result := T + 1
      else Result := T;
    end
    else
    begin
      if (T - X) >= 0.5 then Result := T - 1
      else if T = 0 then Result := -0.0
      else Result := T;
    end;
  end;
end;

function __c2p_stdlib_trunc(X: Double): Double; cdecl;
begin
  Result := Double(System.Trunc(X));
end;

function __c2p_stdlib_fabs(X: Double): Double; cdecl;
begin
  if X < 0.0 then
    System.Exit(-X);
  Result := X;
end;

function __c2p_math_sin(X: Double): Double; cdecl;
begin
  Result := Double(System.sin(X));
end;

function __c2p_math_cos(X: Double): Double; cdecl;
begin
  Result := Double(System.cos(X));
end;

function __c2p_math_tan(X: Double): Double; cdecl;
begin
  Result := Double(System.sin(X) / System.cos(X));
end;

function __c2p_math_asin(X: Double): Double; cdecl;
begin
  if (X >= 1.0) or (X <= -1.0) then
  begin
    if X > 0.0 then
      System.Exit(Double(System.arctan(1.0)) * 2.0);
    System.Exit(-Double(System.arctan(1.0)) * 2.0);
  end;
  Result := Double(System.arctan(X / System.sqrt(1.0 - X * X)));
end;

function __c2p_math_acos(X: Double): Double; cdecl;
begin
  Result := Double(System.arctan(1.0)) * 2.0 - __c2p_math_asin(X);
end;

function __c2p_math_atan(X: Double): Double; cdecl;
begin
  Result := Double(System.arctan(X));
end;

function __c2p_math_atan2(Y, X: Double): Double; cdecl;
begin
  if X * X > Y * Y then
  begin
    Result := Double(System.arctan(Y / X));
    if X < 0.0 then
    begin
      if Y >= 0.0 then
        Result := Result + Double(System.arctan(1.0)) * 4.0
      else
        Result := Result - Double(System.arctan(1.0)) * 4.0;
    end;
  end
  else if Y <> 0.0 then
  begin
    Result := -Double(System.arctan(X / Y));
    if Y > 0.0 then
      Result := Result + Double(System.arctan(1.0)) * 2.0
    else
      Result := Result - Double(System.arctan(1.0)) * 2.0;
  end
  else
    Result := 0.0;
end;

function __c2p_math_sqrt(X: Double): Double; cdecl;
begin
  Result := Double(System.sqrt(X));
end;

function __c2p_math_pow(Base, Exponent: Double): Double; cdecl;
begin
  if Base = 0.0 then
    System.Exit(0.0);
  if Exponent = 0.0 then
    System.Exit(1.0);
  Result := Double(System.exp(Exponent * System.ln(Base)));
end;

function __c2p_math_exp(X: Double): Double; cdecl;
begin
  Result := Double(System.exp(X));
end;

function __c2p_math_log(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X));
end;

function __c2p_math_log2(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X)) / Double(System.ln(2.0));
end;

function __c2p_math_log10(X: Double): Double; cdecl;
begin
  Result := Double(System.ln(X)) / Double(System.ln(10.0));
end;

function __c2p_math_fmod(Numerator, Denominator: Double): Double; cdecl;
begin
  if Denominator = 0.0 then
    System.Exit(0.0);
  Result := Numerator - Double(System.trunc(Numerator / Denominator)) * Denominator;
end;

function __c2p_stdlib_strncmp(Left, Right: PAnsiChar; Count: SizeUInt): LongInt; cdecl;
var
  I: SizeUInt;
  L: Byte;
  R: Byte;
begin
  if Count = 0 then
    System.Exit(0);
  for I := 0 to Count - 1 do
  begin
    L := PByte(Left)[I];
    R := PByte(Right)[I];
    if L <> R then
      System.Exit(LongInt(L) - LongInt(R));
    if L = 0 then
      System.Exit(0);
  end;
  Result := 0;
end;

function __c2p_bsf(X: SizeUInt): SizeUInt; cdecl;
begin
  if X = 0 then
    System.Exit(SizeOf(SizeUInt) * 8);
  Result := SizeUInt(System.BsfQWord(QWord(X)));
end;

function __c2p_bsr(X: SizeUInt): SizeUInt; cdecl;
begin
  if X = 0 then
    System.Exit(SizeOf(SizeUInt) * 8);
  Result := SizeUInt(System.BsrQWord(QWord(X)));
end;

procedure __c2p_memcpy_aligned(Dst, Src: Pointer; Size: SizeUInt); cdecl;
begin
  if Size = 0 then
    System.Exit;
  Move(Src^, Dst^, Size);
end;

procedure __c2p_memset_aligned(Dst: Pointer; Value: PtrUInt; Size: SizeUInt); cdecl;
begin
  if Size = 0 then
    System.Exit;
  FillChar(Dst^, Size, Byte(Value));
end;

function __c2p_sar_longint(Value: LongInt; Count: LongWord): LongInt; cdecl;
begin
  if Count = 0 then
    System.Exit(Value);
  if Count >= 32 then
  begin
    if Value < 0 then
      System.Exit(-1);
    System.Exit(0);
  end;
  if Value >= 0 then
    System.Exit(Value shr Count);
  Result := LongInt(LongWord(Value) shr Count) or LongInt(not ((not LongWord(0)) shr Count));
end;

function __c2p_sar_int64(Value: Int64; Count: LongWord): Int64; cdecl;
begin
  if Count = 0 then
    System.Exit(Value);
  if Count >= 64 then
  begin
    if Value < 0 then
      System.Exit(Int64(-1));
    System.Exit(Int64(0));
  end;
  if Value >= 0 then
    System.Exit(Value shr Count);
  Result := Int64(QWord(Value) shr Count) or Int64(not ((not QWord(0)) shr Count));
end;

procedure abort(); cdecl;
begin
  System.RunError(217);
end;

procedure exit_(status: LongInt); cdecl;
begin
  System.Halt(Status);
end;

function atoi(nptr: PAnsiChar): LongInt; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Acc := -Acc;
  Result := LongInt(Acc); { atoi 语义: strtol 随即截断为 int }
end;

function atol(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

function atoll(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

{ strtod 系的 ERANGE 模拟位：原翻译直连 glibc __errno_location（macOS/Win 无此符号）。
  解码路径不读取 errno，仅保留 C 库语义占位。 }
var
  MP3DErrno: LongInt;

const
  TENH: array[-307..308] of QWord = (
    $0031FA182C40C60D { 10^-307 hi },
    $0066789E3750F791 { 10^-306 hi },
    $009C16C5C5253575 { 10^-305 hi },
    $00D18E3B9B374169 { 10^-304 hi },
    $0105F1CA820511C3 { 10^-303 hi },
    $013B6E3D22865634 { 10^-302 hi },
    $017124E63593F5E1 { 10^-301 hi },
    $01A56E1FC2F8F359 { 10^-300 hi },
    $01DAC9A7B3B7302F { 10^-299 hi },
    $0210BE08D0527E1D { 10^-298 hi },
    $0244ED8B04671DA5 { 10^-297 hi },
    $027A28EDC580E50E { 10^-296 hi },
    $02B059949B708F29 { 10^-295 hi },
    $02E46FF9C24CB2F3 { 10^-294 hi },
    $03198BF832DFDFB0 { 10^-293 hi },
    $034FEEF63F97D79C { 10^-292 hi },
    $0383F559E7BEE6C1 { 10^-291 hi },
    $03B8F2B061AEA072 { 10^-290 hi },
    $03EF2F5C7A1A488E { 10^-289 hi },
    $04237D99CC506D59 { 10^-288 hi },
    $04585D003F6488AF { 10^-287 hi },
    $048E74404F3DAADB { 10^-286 hi },
    $04C308A831868AC9 { 10^-285 hi },
    $04F7CAD23DE82D7B { 10^-284 hi },
    $052DBD86CD6238D9 { 10^-283 hi },
    $05629674405D6388 { 10^-282 hi },
    $05973C115074BC6A { 10^-281 hi },
    $05CD0B15A491EB84 { 10^-280 hi },
    $060226ED86DB3333 { 10^-279 hi },
    $0636B0A8E891FFFF { 10^-278 hi },
    $066C5CD322B67FFF { 10^-277 hi },
    $06A1BA03F5B21000 { 10^-276 hi },
    $06D62884F31E93FF { 10^-275 hi },
    $070BB2A62FE638FF { 10^-274 hi },
    $07414FA7DDEFE3A0 { 10^-273 hi },
    $0775A391D56BDC87 { 10^-272 hi },
    $07AB0C764AC6D3A9 { 10^-271 hi },
    $07E0E7C9EEBC444A { 10^-270 hi },
    $081521BC6A6B555C { 10^-269 hi },
    $084A6A2B85062AB3 { 10^-268 hi },
    $0880825B3323DAB0 { 10^-267 hi },
    $08B4A2F1FFECD15C { 10^-266 hi },
    $08E9CBAE7FE805B3 { 10^-265 hi },
    $09201F4D0FF10390 { 10^-264 hi },
    $0954272053ED4474 { 10^-263 hi },
    $098930E868E89591 { 10^-262 hi },
    $09BF7D228322BAF5 { 10^-261 hi },
    $09F3AE3591F5B4D9 { 10^-260 hi },
    $0A2899C2F6732210 { 10^-259 hi },
    $0A5EC033B40FEA93 { 10^-258 hi },
    $0A9338205089F29C { 10^-257 hi },
    $0AC8062864AC6F43 { 10^-256 hi },
    $0AFE07B27DD78B14 { 10^-255 hi },
    $0B32C4CF8EA6B6EC { 10^-254 hi },
    $0B677603725064A8 { 10^-253 hi },
    $0B9D53844EE47DD1 { 10^-252 hi },
    $0BD25432B14ECEA3 { 10^-251 hi },
    $0C06E93F5DA2824C { 10^-250 hi },
    $0C3CA38F350B22DF { 10^-249 hi },
    $0C71E6398126F5CB { 10^-248 hi },
    $0CA65FC7E170B33E { 10^-247 hi },
    $0CDBF7B9D9CCE00D { 10^-246 hi },
    $0D117AD428200C08 { 10^-245 hi },
    $0D45D98932280F0A { 10^-244 hi },
    $0D7B4FEB7EB212CD { 10^-243 hi },
    $0DB111F32F2F4BC0 { 10^-242 hi },
    $0DE5566FFAFB1EB0 { 10^-241 hi },
    $0E1AAC0BF9B9E65C { 10^-240 hi },
    $0E50AB877C142FFA { 10^-239 hi },
    $0E84D6695B193BF8 { 10^-238 hi },
    $0EBA0C03B1DF8AF6 { 10^-237 hi },
    $0EF047824F2BB6DA { 10^-236 hi },
    $0F245962E2F6A490 { 10^-235 hi },
    $0F596FBB9BB44DB4 { 10^-234 hi },
    $0F8FCBAA82A16121 { 10^-233 hi },
    $0FC3DF4A91A4DCB5 { 10^-232 hi },
    $0FF8D71D360E13E2 { 10^-231 hi },
    $102F0CE4839198DB { 10^-230 hi },
    $1063680ED23AFF89 { 10^-229 hi },
    $1098421286C9BF6B { 10^-228 hi },
    $10CE5297287C2F45 { 10^-227 hi },
    $1102F39E794D9D8B { 10^-226 hi },
    $1137B08617A104EE { 10^-225 hi },
    $116D9CA79D89462A { 10^-224 hi },
    $11A281E8C275CBDA { 10^-223 hi },
    $11D72262F3133ED1 { 10^-222 hi },
    $120CEAFBAFD80E85 { 10^-221 hi },
    $124212DD4DE70913 { 10^-220 hi },
    $12769794A160CB58 { 10^-219 hi },
    $12AC3D79C9B8FE2E { 10^-218 hi },
    $12E1A66C1E139EDD { 10^-217 hi },
    $1316100725988694 { 10^-216 hi },
    $134B9408EEFEA839 { 10^-215 hi },
    $13813C85955F2923 { 10^-214 hi },
    $13B58BA6FAB6F36C { 10^-213 hi },
    $13EAEE90B964B047 { 10^-212 hi },
    $1420D51A73DEEE2D { 10^-211 hi },
    $14550A6110D6A9B8 { 10^-210 hi },
    $148A4CF9550C5426 { 10^-209 hi },
    $14C0701BD527B498 { 10^-208 hi },
    $14F48C22CA71A1BD { 10^-207 hi },
    $1529AF2B7D0E0A2D { 10^-206 hi },
    $15600D7B2E28C65C { 10^-205 hi },
    $159410D9F9B2F7F3 { 10^-204 hi },
    $15C91510781FB5F0 { 10^-203 hi },
    $15FF5A549627A36C { 10^-202 hi },
    $16339874DDD8C623 { 10^-201 hi },
    $16687E92154EF7AC { 10^-200 hi },
    $169E9E369AA2B597 { 10^-199 hi },
    $16D322E220A5B17E { 10^-198 hi },
    $1707EB9AA8CF1DDE { 10^-197 hi },
    $173DE6815302E556 { 10^-196 hi },
    $1772B010D3E1CF56 { 10^-195 hi },
    $17A75C1508DA432B { 10^-194 hi },
    $17DD331A4B10D3F6 { 10^-193 hi },
    $18123FF06EEA847A { 10^-192 hi },
    $1846CFEC8AA52598 { 10^-191 hi },
    $187C83E7AD4E6EFE { 10^-190 hi },
    $18B1D270CC51055F { 10^-189 hi },
    $18E6470CFF6546B6 { 10^-188 hi },
    $191BD8D03F3E9864 { 10^-187 hi },
    $1951678227871F3E { 10^-186 hi },
    $1985C162B168E70E { 10^-185 hi },
    $19BB31BB5DC320D2 { 10^-184 hi },
    $19F0FF151A99F483 { 10^-183 hi },
    $1A253EDA614071A4 { 10^-182 hi },
    $1A5A8E90F9908E0D { 10^-181 hi },
    $1A90991A9BFA58C8 { 10^-180 hi },
    $1AC4BF6142F8EEFA { 10^-179 hi },
    $1AF9EF3993B72AB8 { 10^-178 hi },
    $1B303583FC527AB3 { 10^-177 hi },
    $1B6442E4FB671960 { 10^-176 hi },
    $1B99539E3A40DFB8 { 10^-175 hi },
    $1BCFA885C8D117A6 { 10^-174 hi },
    $1C03C9539D82AEC8 { 10^-173 hi },
    $1C38BBA884E35A7A { 10^-172 hi },
    $1C6EEA92A61C3118 { 10^-171 hi },
    $1CA3529BA7D19EAF { 10^-170 hi },
    $1CD8274291C6065B { 10^-169 hi },
    $1D0E3113363787F2 { 10^-168 hi },
    $1D42DEAC01E2B4F7 { 10^-167 hi },
    $1D779657025B6235 { 10^-166 hi },
    $1DAD7BECC2F23AC2 { 10^-165 hi },
    $1DE26D73F9D764B9 { 10^-164 hi },
    $1E1708D0F84D3DE7 { 10^-163 hi },
    $1E4CCB0536608D61 { 10^-162 hi },
    $1E81FEE341FC585D { 10^-161 hi },
    $1EB67E9C127B6E74 { 10^-160 hi },
    $1EEC1E43171A4A11 { 10^-159 hi },
    $1F2192E9EE706E4B { 10^-158 hi },
    $1F55F7A46A0C89DD { 10^-157 hi },
    $1F8B758D848FAC55 { 10^-156 hi },
    $1FC1297872D9CBB5 { 10^-155 hi },
    $1FF573D68F903EA2 { 10^-154 hi },
    $202AD0CC33744E4B { 10^-153 hi },
    $2060C27FA028B0EF { 10^-152 hi },
    $2094F31F8832DD2A { 10^-151 hi },
    $20CA2FE76A3F9475 { 10^-150 hi },
    $21005DF0A267BCC9 { 10^-149 hi },
    $2134756CCB01ABFB { 10^-148 hi },
    $216992C7FDC216FA { 10^-147 hi },
    $219FF779FD329CB9 { 10^-146 hi },
    $21D3FAAC3E3FA1F3 { 10^-145 hi },
    $2208F9574DCF8A70 { 10^-144 hi },
    $223F37AD21436D0C { 10^-143 hi },
    $227382CC34CA2428 { 10^-142 hi },
    $22A8637F41FCAD32 { 10^-141 hi },
    $22DE7C5F127BD87E { 10^-140 hi },
    $23130DBB6B8D674F { 10^-139 hi },
    $2347D12A4670C123 { 10^-138 hi },
    $237DC574D80CF16B { 10^-137 hi },
    $23B29B69070816E3 { 10^-136 hi },
    $23E7424348CA1C9C { 10^-135 hi },
    $241D12D41AFCA3C3 { 10^-134 hi },
    $24522BC490DDE65A { 10^-133 hi },
    $2486B6B5B5155FF0 { 10^-132 hi },
    $24BC6463225AB7EC { 10^-131 hi },
    $24F1BEBDF578B2F4 { 10^-130 hi },
    $25262E6D72D6DFB0 { 10^-129 hi },
    $255BBA08CF8C979D { 10^-128 hi },
    $2591544581B7DEC2 { 10^-127 hi },
    $25C5A956E225D672 { 10^-126 hi },
    $25FB13AC9AAF4C0F { 10^-125 hi },
    $2630EC4BE0AD8F89 { 10^-124 hi },
    $2665275ED8D8F36C { 10^-123 hi },
    $269A71368F0F3047 { 10^-122 hi },
    $26D086C219697E2C { 10^-121 hi },
    $2704A8729FC3DDB7 { 10^-120 hi },
    $2739D28F47B4D525 { 10^-119 hi },
    $277023998CD10537 { 10^-118 hi },
    $27A42C7FF0054685 { 10^-117 hi },
    $27D9379FEC069826 { 10^-116 hi },
    $280F8587E7083E30 { 10^-115 hi },
    $2843B374F06526DE { 10^-114 hi },
    $2878A0522C7E7095 { 10^-113 hi },
    $28AEC866B79E0CBA { 10^-112 hi },
    $28E33D4032C2C7F5 { 10^-111 hi },
    $29180C903F7379F2 { 10^-110 hi },
    $294E0FB44F50586E { 10^-109 hi },
    $2982C9D0B1923745 { 10^-108 hi },
    $29B77C44DDF6C516 { 10^-107 hi },
    $29ED5B561574765B { 10^-106 hi },
    $2A225915CD68C9F9 { 10^-105 hi },
    $2A56EF5B40C2FC77 { 10^-104 hi },
    $2A8CAB3210F3BB95 { 10^-103 hi },
    $2AC1EAFF4A98553D { 10^-102 hi },
    $2AF665BF1D3E6A8D { 10^-101 hi },
    $2B2BFF2EE48E0530 { 10^-100 hi },
    $2B617F7D4ED8C33E { 10^-99 hi },
    $2B95DF5CA28EF40D { 10^-98 hi },
    $2BCB5733CB32B111 { 10^-97 hi },
    $2C0116805EFFAEAA { 10^-96 hi },
    $2C355C2076BF9A55 { 10^-95 hi },
    $2C6AB328946F80EA { 10^-94 hi },
    $2CA0AFF95CC5B092 { 10^-93 hi },
    $2CD4DBF7B3F71CB7 { 10^-92 hi },
    $2D0A12F5A0F4E3E5 { 10^-91 hi },
    $2D404BD984990E6F { 10^-90 hi },
    $2D745ECFE5BF520B { 10^-89 hi },
    $2DA97683DF2F268D { 10^-88 hi },
    $2DDFD424D6FAF031 { 10^-87 hi },
    $2E13E497065CD61F { 10^-86 hi },
    $2E48DDBCC7F40BA6 { 10^-85 hi },
    $2E7F152BF9F10E90 { 10^-84 hi },
    $2EB36D3B7C36A91A { 10^-83 hi },
    $2EE8488A5B445360 { 10^-82 hi },
    $2F1E5AACF2156838 { 10^-81 hi },
    $2F52F8AC174D6123 { 10^-80 hi },
    $2F87B6D71D20B96C { 10^-79 hi },
    $2FBDA48CE468E7C7 { 10^-78 hi },
    $2FF286D80EC190DC { 10^-77 hi },
    $3027288E1271F513 { 10^-76 hi },
    $305CF2B1970E7258 { 10^-75 hi },
    $309217AEFE690777 { 10^-74 hi },
    $30C69D9ABE034955 { 10^-73 hi },
    $30FC45016D841BAA { 10^-72 hi },
    $3131AB20E472914A { 10^-71 hi },
    $316615E91D8F359D { 10^-70 hi },
    $319B9B6364F30304 { 10^-69 hi },
    $31D1411E1F17E1E3 { 10^-68 hi },
    $32059165A6DDDA5B { 10^-67 hi },
    $323AF5BF109550F2 { 10^-66 hi },
    $3270D9976A5D5297 { 10^-65 hi },
    $32A50FFD44F4A73D { 10^-64 hi },
    $32DA53FC9631D10D { 10^-63 hi },
    $3310747DDDDF22A8 { 10^-62 hi },
    $3344919D5556EB52 { 10^-61 hi },
    $3379B604AAACA626 { 10^-60 hi },
    $33B011C2EAABE7D8 { 10^-59 hi },
    $33E41633A556E1CE { 10^-58 hi },
    $34191BC08EAC9A41 { 10^-57 hi },
    $344F62B0B257C0D2 { 10^-56 hi },
    $34839DAE6F76D883 { 10^-55 hi },
    $34B8851A0B548EA4 { 10^-54 hi },
    $34EEA6608E29B24D { 10^-53 hi },
    $352327FC58DA0F70 { 10^-52 hi },
    $3557F1FB6F10934C { 10^-51 hi },
    $358DEE7A4AD4B81F { 10^-50 hi },
    $35C2B50C6EC4F313 { 10^-49 hi },
    $35F7624F8A762FD8 { 10^-48 hi },
    $362D3AE36D13BBCE { 10^-47 hi },
    $366244CE242C5561 { 10^-46 hi },
    $3696D601AD376AB9 { 10^-45 hi },
    $36CC8B8218854567 { 10^-44 hi },
    $3701D7314F534B61 { 10^-43 hi },
    $37364CFDA3281E39 { 10^-42 hi },
    $376BE03D0BF225C7 { 10^-41 hi },
    $37A16C262777579C { 10^-40 hi },
    $37D5C72FB1552D83 { 10^-39 hi },
    $380B38FB9DAA78E4 { 10^-38 hi },
    $3841039D428A8B8F { 10^-37 hi },
    $38754484932D2E72 { 10^-36 hi },
    $38AA95A5B7F87A0F { 10^-35 hi },
    $38E09D8792FB4C49 { 10^-34 hi },
    $3914C4E977BA1F5C { 10^-33 hi },
    $3949F623D5A8A733 { 10^-32 hi },
    $398039D665896880 { 10^-31 hi },
    $39B4484BFEEBC2A0 { 10^-30 hi },
    $39E95A5EFEA6B347 { 10^-29 hi },
    $3A1FB0F6BE506019 { 10^-28 hi },
    $3A53CE9A36F23C10 { 10^-27 hi },
    $3A88C240C4AECB14 { 10^-26 hi },
    $3ABEF2D0F5DA7DD9 { 10^-25 hi },
    $3AF357C299A88EA7 { 10^-24 hi },
    $3B282DB34012B251 { 10^-23 hi },
    $3B5E392010175EE6 { 10^-22 hi },
    $3B92E3B40A0E9B4F { 10^-21 hi },
    $3BC79CA10C924223 { 10^-20 hi },
    $3BFD83C94FB6D2AC { 10^-19 hi },
    $3C32725DD1D243AC { 10^-18 hi },
    $3C670EF54646D497 { 10^-17 hi },
    $3C9CD2B297D889BC { 10^-16 hi },
    $3CD203AF9EE75616 { 10^-15 hi },
    $3D06849B86A12B9B { 10^-14 hi },
    $3D3C25C268497682 { 10^-13 hi },
    $3D719799812DEA11 { 10^-12 hi },
    $3DA5FD7FE1796495 { 10^-11 hi },
    $3DDB7CDFD9D7BDBB { 10^-10 hi },
    $3E112E0BE826D695 { 10^-9 hi },
    $3E45798EE2308C3A { 10^-8 hi },
    $3E7AD7F29ABCAF48 { 10^-7 hi },
    $3EB0C6F7A0B5ED8D { 10^-6 hi },
    $3EE4F8B588E368F1 { 10^-5 hi },
    $3F1A36E2EB1C432D { 10^-4 hi },
    $3F50624DD2F1A9FC { 10^-3 hi },
    $3F847AE147AE147B { 10^-2 hi },
    $3FB999999999999A { 10^-1 hi },
    $3FF0000000000000 { 10^0 hi },
    $4024000000000000 { 10^1 hi },
    $4059000000000000 { 10^2 hi },
    $408F400000000000 { 10^3 hi },
    $40C3880000000000 { 10^4 hi },
    $40F86A0000000000 { 10^5 hi },
    $412E848000000000 { 10^6 hi },
    $416312D000000000 { 10^7 hi },
    $4197D78400000000 { 10^8 hi },
    $41CDCD6500000000 { 10^9 hi },
    $4202A05F20000000 { 10^10 hi },
    $42374876E8000000 { 10^11 hi },
    $426D1A94A2000000 { 10^12 hi },
    $42A2309CE5400000 { 10^13 hi },
    $42D6BCC41E900000 { 10^14 hi },
    $430C6BF526340000 { 10^15 hi },
    $4341C37937E08000 { 10^16 hi },
    $4376345785D8A000 { 10^17 hi },
    $43ABC16D674EC800 { 10^18 hi },
    $43E158E460913D00 { 10^19 hi },
    $4415AF1D78B58C40 { 10^20 hi },
    $444B1AE4D6E2EF50 { 10^21 hi },
    $4480F0CF064DD592 { 10^22 hi },
    $44B52D02C7E14AF6 { 10^23 hi },
    $44EA784379D99DB4 { 10^24 hi },
    $45208B2A2C280291 { 10^25 hi },
    $4554ADF4B7320335 { 10^26 hi },
    $4589D971E4FE8402 { 10^27 hi },
    $45C027E72F1F1281 { 10^28 hi },
    $45F431E0FAE6D721 { 10^29 hi },
    $46293E5939A08CEA { 10^30 hi },
    $465F8DEF8808B024 { 10^31 hi },
    $4693B8B5B5056E17 { 10^32 hi },
    $46C8A6E32246C99C { 10^33 hi },
    $46FED09BEAD87C03 { 10^34 hi },
    $4733426172C74D82 { 10^35 hi },
    $476812F9CF7920E3 { 10^36 hi },
    $479E17B84357691B { 10^37 hi },
    $47D2CED32A16A1B1 { 10^38 hi },
    $48078287F49C4A1D { 10^39 hi },
    $483D6329F1C35CA5 { 10^40 hi },
    $48725DFA371A19E7 { 10^41 hi },
    $48A6F578C4E0A061 { 10^42 hi },
    $48DCB2D6F618C879 { 10^43 hi },
    $4911EFC659CF7D4C { 10^44 hi },
    $49466BB7F0435C9E { 10^45 hi },
    $497C06A5EC5433C6 { 10^46 hi },
    $49B18427B3B4A05C { 10^47 hi },
    $49E5E531A0A1C873 { 10^48 hi },
    $4A1B5E7E08CA3A8F { 10^49 hi },
    $4A511B0EC57E649A { 10^50 hi },
    $4A8561D276DDFDC0 { 10^51 hi },
    $4ABABA4714957D30 { 10^52 hi },
    $4AF0B46C6CDD6E3E { 10^53 hi },
    $4B24E1878814C9CE { 10^54 hi },
    $4B5A19E96A19FC41 { 10^55 hi },
    $4B905031E2503DA9 { 10^56 hi },
    $4BC4643E5AE44D13 { 10^57 hi },
    $4BF97D4DF19D6057 { 10^58 hi },
    $4C2FDCA16E04B86D { 10^59 hi },
    $4C63E9E4E4C2F344 { 10^60 hi },
    $4C98E45E1DF3B015 { 10^61 hi },
    $4CCF1D75A5709C1B { 10^62 hi },
    $4D03726987666191 { 10^63 hi },
    $4D384F03E93FF9F5 { 10^64 hi },
    $4D6E62C4E38FF872 { 10^65 hi },
    $4DA2FDBB0E39FB47 { 10^66 hi },
    $4DD7BD29D1C87A19 { 10^67 hi },
    $4E0DAC74463A989F { 10^68 hi },
    $4E428BC8ABE49F64 { 10^69 hi },
    $4E772EBAD6DDC73D { 10^70 hi },
    $4EACFA698C95390C { 10^71 hi },
    $4EE21C81F7DD43A7 { 10^72 hi },
    $4F16A3A275D49491 { 10^73 hi },
    $4F4C4C8B1349B9B5 { 10^74 hi },
    $4F81AFD6EC0E1411 { 10^75 hi },
    $4FB61BCCA7119916 { 10^76 hi },
    $4FEBA2BFD0D5FF5B { 10^77 hi },
    $502145B7E285BF99 { 10^78 hi },
    $50559725DB272F7F { 10^79 hi },
    $508AFCEF51F0FB5F { 10^80 hi },
    $50C0DE1593369D1B { 10^81 hi },
    $50F5159AF8044462 { 10^82 hi },
    $512A5B01B605557B { 10^83 hi },
    $516078E111C3556D { 10^84 hi },
    $5194971956342AC8 { 10^85 hi },
    $51C9BCDFABC1357A { 10^86 hi },
    $5200160BCB58C16C { 10^87 hi },
    $52341B8EBE2EF1C7 { 10^88 hi },
    $526922726DBAAE39 { 10^89 hi },
    $529F6B0F092959C7 { 10^90 hi },
    $52D3A2E965B9D81D { 10^91 hi },
    $53088BA3BF284E24 { 10^92 hi },
    $533EAE8CAEF261AD { 10^93 hi },
    $53732D17ED577D0C { 10^94 hi },
    $53A7F85DE8AD5C4F { 10^95 hi },
    $53DDF67562D8B363 { 10^96 hi },
    $5412BA095DC7701E { 10^97 hi },
    $5447688BB5394C25 { 10^98 hi },
    $547D42AEA2879F2E { 10^99 hi },
    $54B249AD2594C37D { 10^100 hi },
    $54E6DC186EF9F45C { 10^101 hi },
    $551C931E8AB87173 { 10^102 hi },
    $5551DBF316B346E8 { 10^103 hi },
    $558652EFDC6018A2 { 10^104 hi },
    $55BBE7ABD3781ECA { 10^105 hi },
    $55F170CB642B133F { 10^106 hi },
    $5625CCFE3D35D80E { 10^107 hi },
    $565B403DCC834E12 { 10^108 hi },
    $569108269FD210CB { 10^109 hi },
    $56C54A3047C694FE { 10^110 hi },
    $56FA9CBC59B83A3D { 10^111 hi },
    $5730A1F5B8132466 { 10^112 hi },
    $5764CA732617ED80 { 10^113 hi },
    $5799FD0FEF9DE8E0 { 10^114 hi },
    $57D03E29F5C2B18C { 10^115 hi },
    $58044DB473335DEF { 10^116 hi },
    $583961219000356B { 10^117 hi },
    $586FB969F40042C5 { 10^118 hi },
    $58A3D3E2388029BB { 10^119 hi },
    $58D8C8DAC6A0342A { 10^120 hi },
    $590EFB1178484135 { 10^121 hi },
    $59435CEAEB2D28C1 { 10^122 hi },
    $59783425A5F872F1 { 10^123 hi },
    $59AE412F0F768FAD { 10^124 hi },
    $59E2E8BD69AA19CC { 10^125 hi },
    $5A17A2ECC414A03F { 10^126 hi },
    $5A4D8BA7F519C84F { 10^127 hi },
    $5A827748F9301D32 { 10^128 hi },
    $5AB7151B377C247E { 10^129 hi },
    $5AECDA62055B2D9E { 10^130 hi },
    $5B22087D4358FC82 { 10^131 hi },
    $5B568A9C942F3BA3 { 10^132 hi },
    $5B8C2D43B93B0A8C { 10^133 hi },
    $5BC19C4A53C4E697 { 10^134 hi },
    $5BF6035CE8B6203D { 10^135 hi },
    $5C2B843422E3A84D { 10^136 hi },
    $5C6132A095CE4930 { 10^137 hi },
    $5C957F48BB41DB7C { 10^138 hi },
    $5CCADF1AEA12525B { 10^139 hi },
    $5D00CB70D24B7379 { 10^140 hi },
    $5D34FE4D06DE5057 { 10^141 hi },
    $5D6A3DE04895E46D { 10^142 hi },
    $5DA066AC2D5DAEC4 { 10^143 hi },
    $5DD4805738B51A75 { 10^144 hi },
    $5E09A06D06E26112 { 10^145 hi },
    $5E400444244D7CAB { 10^146 hi },
    $5E7405552D60DBD6 { 10^147 hi },
    $5EA906AA78B912CC { 10^148 hi },
    $5EDF485516E7577F { 10^149 hi },
    $5F138D352E5096AF { 10^150 hi },
    $5F48708279E4BC5B { 10^151 hi },
    $5F7E8CA3185DEB72 { 10^152 hi },
    $5FB317E5EF3AB327 { 10^153 hi },
    $5FE7DDDF6B095FF1 { 10^154 hi },
    $601DD55745CBB7ED { 10^155 hi },
    $6052A5568B9F52F4 { 10^156 hi },
    $60874EAC2E8727B1 { 10^157 hi },
    $60BD22573A28F19D { 10^158 hi },
    $60F2357684599702 { 10^159 hi },
    $6126C2D4256FFCC3 { 10^160 hi },
    $615C73892ECBFBF4 { 10^161 hi },
    $6191C835BD3F7D78 { 10^162 hi },
    $61C63A432C8F5CD6 { 10^163 hi },
    $61FBC8D3F7B3340C { 10^164 hi },
    $62315D847AD00087 { 10^165 hi },
    $6265B4E5998400A9 { 10^166 hi },
    $629B221EFFE500D4 { 10^167 hi },
    $62D0F5535FEF2084 { 10^168 hi },
    $630532A837EAE8A5 { 10^169 hi },
    $633A7F5245E5A2CF { 10^170 hi },
    $63708F936BAF85C1 { 10^171 hi },
    $63A4B378469B6732 { 10^172 hi },
    $63D9E056584240FE { 10^173 hi },
    $64102C35F729689F { 10^174 hi },
    $6444374374F3C2C6 { 10^175 hi },
    $647945145230B378 { 10^176 hi },
    $64AF965966BCE056 { 10^177 hi },
    $64E3BDF7E0360C36 { 10^178 hi },
    $6518AD75D8438F43 { 10^179 hi },
    $654ED8D34E547314 { 10^180 hi },
    $6583478410F4C7EC { 10^181 hi },
    $65B819651531F9E8 { 10^182 hi },
    $65EE1FBE5A7E7861 { 10^183 hi },
    $6622D3D6F88F0B3D { 10^184 hi },
    $665788CCB6B2CE0C { 10^185 hi },
    $668D6AFFE45F818F { 10^186 hi },
    $66C262DFEEBBB0F9 { 10^187 hi },
    $66F6FB97EA6A9D38 { 10^188 hi },
    $672CBA7DE5054486 { 10^189 hi },
    $6761F48EAF234AD4 { 10^190 hi },
    $679671B25AEC1D89 { 10^191 hi },
    $67CC0E1EF1A724EB { 10^192 hi },
    $680188D357087713 { 10^193 hi },
    $6835EB082CCA94D7 { 10^194 hi },
    $686B65CA37FD3A0D { 10^195 hi },
    $68A11F9E62FE4448 { 10^196 hi },
    $68D56785FBBDD55A { 10^197 hi },
    $690AC1677AAD4AB1 { 10^198 hi },
    $6940B8E0ACAC4EAF { 10^199 hi },
    $6974E718D7D7625A { 10^200 hi },
    $69AA20DF0DCD3AF1 { 10^201 hi },
    $69E0548B68A044D6 { 10^202 hi },
    $6A1469AE42C8560C { 10^203 hi },
    $6A498419D37A6B8F { 10^204 hi },
    $6A7FE52048590673 { 10^205 hi },
    $6AB3EF342D37A408 { 10^206 hi },
    $6AE8EB0138858D0A { 10^207 hi },
    $6B1F25C186A6F04C { 10^208 hi },
    $6B537798F4285630 { 10^209 hi },
    $6B88557F31326BBB { 10^210 hi },
    $6BBE6ADEFD7F06AA { 10^211 hi },
    $6BF302CB5E6F642A { 10^212 hi },
    $6C27C37E360B3D35 { 10^213 hi },
    $6C5DB45DC38E0C82 { 10^214 hi },
    $6C9290BA9A38C7D1 { 10^215 hi },
    $6CC734E940C6F9C6 { 10^216 hi },
    $6CFD022390F8B837 { 10^217 hi },
    $6D3221563A9B7323 { 10^218 hi },
    $6D66A9ABC9424FEB { 10^219 hi },
    $6D9C5416BB92E3E6 { 10^220 hi },
    $6DD1B48E353BCE70 { 10^221 hi },
    $6E0621B1C28AC20C { 10^222 hi },
    $6E3BAA1E332D728F { 10^223 hi },
    $6E714A52DFFC6799 { 10^224 hi },
    $6EA59CE797FB817F { 10^225 hi },
    $6EDB04217DFA61DF { 10^226 hi },
    $6F10E294EEBC7D2C { 10^227 hi },
    $6F451B3A2A6B9C76 { 10^228 hi },
    $6F7A6208B5068394 { 10^229 hi },
    $6FB07D457124123D { 10^230 hi },
    $6FE49C96CD6D16CC { 10^231 hi },
    $7019C3BC80C85C7F { 10^232 hi },
    $70501A55D07D39CF { 10^233 hi },
    $708420EB449C8843 { 10^234 hi },
    $70B9292615C3AA54 { 10^235 hi },
    $70EF736F9B3494E9 { 10^236 hi },
    $7123A825C100DD11 { 10^237 hi },
    $7158922F31411456 { 10^238 hi },
    $718EB6BAFD91596B { 10^239 hi },
    $71C33234DE7AD7E3 { 10^240 hi },
    $71F7FEC216198DDC { 10^241 hi },
    $722DFE729B9FF153 { 10^242 hi },
    $7262BF07A143F6D4 { 10^243 hi },
    $72976EC98994F489 { 10^244 hi },
    $72CD4A7BEBFA31AB { 10^245 hi },
    $73024E8D737C5F0B { 10^246 hi },
    $7336E230D05B76CD { 10^247 hi },
    $736C9ABD04725481 { 10^248 hi },
    $73A1E0B622C774D0 { 10^249 hi },
    $73D658E3AB795204 { 10^250 hi },
    $740BEF1C9657A686 { 10^251 hi },
    $74417571DDF6C814 { 10^252 hi },
    $7475D2CE55747A18 { 10^253 hi },
    $74AB4781EAD1989E { 10^254 hi },
    $74E10CB132C2FF63 { 10^255 hi },
    $75154FDD7F73BF3C { 10^256 hi },
    $754AA3D4DF50AF0B { 10^257 hi },
    $7580A6650B926D67 { 10^258 hi },
    $75B4CFFE4E7708C0 { 10^259 hi },
    $75EA03FDE214CAF1 { 10^260 hi },
    $7620427EAD4CFED6 { 10^261 hi },
    $7654531E58A03E8C { 10^262 hi },
    $768967E5EEC84E2F { 10^263 hi },
    $76BFC1DF6A7A61BB { 10^264 hi },
    $76F3D92BA28C7D15 { 10^265 hi },
    $7728CF768B2F9C5A { 10^266 hi },
    $775F03542DFB8370 { 10^267 hi },
    $779362149CBD3226 { 10^268 hi },
    $77C83A99C3EC7EB0 { 10^269 hi },
    $77FE494034E79E5C { 10^270 hi },
    $7832EDC82110C2F9 { 10^271 hi },
    $7867A93A2954F3B8 { 10^272 hi },
    $789D9388B3AA30A5 { 10^273 hi },
    $78D27C35704A5E67 { 10^274 hi },
    $79071B42CC5CF601 { 10^275 hi },
    $793CE2137F743382 { 10^276 hi },
    $79720D4C2FA8A031 { 10^277 hi },
    $79A6909F3B92C83D { 10^278 hi },
    $79DC34C70A777A4D { 10^279 hi },
    $7A11A0FC668AAC70 { 10^280 hi },
    $7A46093B802D578C { 10^281 hi },
    $7A7B8B8A6038AD6F { 10^282 hi },
    $7AB137367C236C65 { 10^283 hi },
    $7AE585041B2C477F { 10^284 hi },
    $7B1AE64521F7595E { 10^285 hi },
    $7B50CFEB353A97DB { 10^286 hi },
    $7B8503E602893DD2 { 10^287 hi },
    $7BBA44DF832B8D46 { 10^288 hi },
    $7BF06B0BB1FB384C { 10^289 hi },
    $7C2485CE9E7A065F { 10^290 hi },
    $7C59A742461887F6 { 10^291 hi },
    $7C9008896BCF54FA { 10^292 hi },
    $7CC40AABC6C32A38 { 10^293 hi },
    $7CF90D56B873F4C7 { 10^294 hi },
    $7D2F50AC6690F1F8 { 10^295 hi },
    $7D63926BC01A973B { 10^296 hi },
    $7D987706B0213D0A { 10^297 hi },
    $7DCE94C85C298C4C { 10^298 hi },
    $7E031CFD3999F7B0 { 10^299 hi },
    $7E37E43C8800759C { 10^300 hi },
    $7E6DDD4BAA009303 { 10^301 hi },
    $7EA2AA4F4A405BE2 { 10^302 hi },
    $7ED754E31CD072DA { 10^303 hi },
    $7F0D2A1BE4048F90 { 10^304 hi },
    $7F423A516E82D9BA { 10^305 hi },
    $7F76C8E5CA239029 { 10^306 hi },
    $7FAC7B1F3CAC7433 { 10^307 hi },
    $7FE1CCF385EBC8A0 { 10^308 hi }
  );
  TENL: array[-307..308] of Int64 = (
                        2 { 10^-307 lo },
     -9223372036854775802 { 10^-306 lo },
                        8 { 10^-305 lo },
                      587 { 10^-304 lo },
                    14064 { 10^-303 lo },
                    75109 { 10^-302 lo },
     -9223372036853429746 { 10^-301 lo },
     -9223372036849703791 { 10^-300 lo },
                 16388697 { 10^-299 lo },
               1774499711 { 10^-298 lo },
     -9223372028829969139 { 10^-297 lo },
     -9223372025326185851 { 10^-296 lo },
     -9223370822057248464 { 10^-295 lo },
     -9223368684972524575 { 10^-294 lo },
     -9223268149288085813 { 10^-293 lo },
     -9222333161187875860 { 10^-292 lo },
         7625641840482501 { 10^-291 lo },
     -9196612865613483899 { 10^-290 lo },
     -9193158972077837673 { 10^-289 lo },
     -9168126487163816472 { 10^-288 lo },
     -9159567556478990653 { 10^-287 lo },
     -9139021190299626438 { 10^-286 lo },
     -9121676111810153308 { 10^-285 lo },
     -9110995612505390181 { 10^-284 lo },
       129611968246199743 { 10^-283 lo },
     -9085782995664799326 { 10^-282 lo },
     -9070526033783629814 { 10^-281 lo },
       172912005781421181 { 10^-280 lo },
     -9033641515108289998 { 10^-279 lo },
       205315511206043970 { 10^-278 lo },
       216051202608657188 { 10^-277 lo },
     -8985206212962208763 { 10^-276 lo },
       250605974766649082 { 10^-275 lo },
       261466072743550649 { 10^-274 lo },
     -8940369019256394547 { 10^-273 lo },
       295890474250217472 { 10^-272 lo },
       306812698029584896 { 10^-271 lo },
     -8900948667801431680 { 10^-270 lo },
       337791449719276816 { 10^-269 lo },
       352433517924853332 { 10^-268 lo },
       360918037850841043 { 10^-267 lo },
       375712253555095495 { 10^-266 lo },
       390827323464885689 { 10^-265 lo },
     -8819067565059682087 { 10^-264 lo },
     -8804048555770133881 { 10^-263 lo },
     -8789289678046383319 { 10^-262 lo },
       450963315984297990 { 10^-261 lo },
       471566206793168388 { 10^-260 lo },
     -8732785731077775810 { 10^-259 lo },
       502533925459790387 { 10^-258 lo },
       513240875133344128 { 10^-257 lo },
       527941129817382896 { 10^-256 lo },
     -8688039948645490607 { 10^-255 lo },
       566796449001265530 { 10^-254 lo },
     -8643838104678395864 { 10^-253 lo },
       594011375692237774 { 10^-252 lo },
     -8623233848612830595 { 10^-251 lo },
     -8600105589081072441 { 10^-250 lo },
     -8585026465492974599 { 10^-249 lo },
       646928686026003986 { 10^-248 lo },
     -8561607616050813847 { 10^-247 lo },
       681815119974302879 { 10^-246 lo },
       699728127346696931 { 10^-245 lo },
       714782372411718556 { 10^-244 lo },
       712179856604746779 { 10^-243 lo },
       739389513124320548 { 10^-242 lo },
       754226005472164461 { 10^-241 lo },
       769393921186441481 { 10^-240 lo },
     -8433327747487827155 { 10^-239 lo },
       791504387155570747 { 10^-238 lo },
       806564516167638565 { 10^-237 lo },
     -8391744787821137259 { 10^-236 lo },
       846348282669347014 { 10^-235 lo },
       861108149186915964 { 10^-234 lo },
       875975003065657883 { 10^-233 lo },
     -8335631054736987298 { 10^-232 lo },
       897138486845911956 { 10^-231 lo },
     -8301829663439622174 { 10^-230 lo },
     -8284305333513558547 { 10^-229 lo },
     -8274072962800271663 { 10^-228 lo },
       967748299553233086 { 10^-227 lo },
       984833905780156278 { 10^-226 lo },
       995729301695086932 { 10^-225 lo },
     -8217901980252988242 { 10^-224 lo },
      1023276377962012179 { 10^-223 lo },
     -8181951212164995788 { 10^-222 lo },
     -8173561846573146878 { 10^-221 lo },
      1059419019484993404 { 10^-220 lo },
     -8139747247496079191 { 10^-219 lo },
     -8124457028393027734 { 10^-218 lo },
     -8103641642385194334 { 10^-217 lo },
     -8092799121503186101 { 10^-216 lo },
     -8078120070493833187 { 10^-215 lo },
      1165033315405014254 { 10^-214 lo },
      1175942567452454441 { 10^-213 lo },
      1190705032418597299 { 10^-212 lo },
     -8013563393791025168 { 10^-211 lo },
     -8002719308897327124 { 10^-210 lo },
     -7988038302873361945 { 10^-209 lo },
     -7967714443127485136 { 10^-208 lo },
      1268821672991141764 { 10^-207 lo },
     -7945869787490580169 { 10^-206 lo },
     -7952232640725206967 { 10^-205 lo },
     -7937314866633480612 { 10^-204 lo },
     -7899176346485036032 { 10^-203 lo },
     -7884505297715378432 { 10^-202 lo },
      1356461306567308192 { 10^-201 lo },
      1364476181109834273 { 10^-200 lo },
      1379155819642573141 { 10^-199 lo },
      1404608138080463210 { 10^-198 lo },
      1407051955071307540 { 10^-197 lo },
     -7793237502525671606 { 10^-196 lo },
     -7773343398918829426 { 10^-195 lo },
     -7769361567600872250 { 10^-194 lo },
     -7748084024683381634 { 10^-193 lo },
     -7728233976664758833 { 10^-192 lo },
     -7723958441425339126 { 10^-191 lo },
     -7709214837454533082 { 10^-190 lo },
     -7685941025099209620 { 10^-189 lo },
      1550486548008194681 { 10^-188 lo },
     -7666864347120933982 { 10^-187 lo },
      1584131222284665967 { 10^-186 lo },
      1582915802591669330 { 10^-185 lo },
     -7612123359789262573 { 10^-184 lo },
     -7612476066332640576 { 10^-183 lo },
     -7583466889431115369 { 10^-182 lo },
     -7568681469876961283 { 10^-181 lo },
     -7559121814836641800 { 10^-180 lo },
     -7543879626168082442 { 10^-179 lo },
      1699655362604722691 { 10^-178 lo },
      1714741637165188228 { 10^-177 lo },
      1713580448653192488 { 10^-176 lo },
      1728770295005247602 { 10^-175 lo },
      1743636479508585287 { 10^-174 lo },
     -7449773631068233795 { 10^-173 lo },
     -7434829489505242154 { 10^-172 lo },
      1797654312925896297 { 10^-171 lo },
      1812470527116117507 { 10^-170 lo },
     -7394486411352826818 { 10^-169 lo },
     -7373816329372311129 { 10^-168 lo },
     -7378349379204833017 { 10^-167 lo },
     -7345075913738045366 { 10^-166 lo },
     -7339392000097740429 { 10^-165 lo },
      1907657806960234508 { 10^-164 lo },
      1927498768518380039 { 10^-163 lo },
      1938747299587758217 { 10^-162 lo },
     -7272685023255879340 { 10^-161 lo },
      1959746700351171757 { 10^-160 lo },
      1974553614751377368 { 10^-159 lo },
     -7222534592737101370 { 10^-158 lo },
      2014937721198671816 { 10^-157 lo },
     -7195660364522599866 { 10^-156 lo },
     -7187267205058365010 { 10^-155 lo },
      2055031654800618483 { 10^-154 lo },
     -7150896248853878904 { 10^-153 lo },
     -7132626385169901387 { 10^-152 lo },
      2105214444971344158 { 10^-151 lo },
     -7118007202629126953 { 10^-150 lo },
      2128112808786557821 { 10^-149 lo },
      2150378704847931031 { 10^-148 lo },
      2160376628177293434 { 10^-147 lo },
     -7048696225447830680 { 10^-146 lo },
      2197369545894944623 { 10^-145 lo },
      2208531776897906507 { 10^-144 lo },
      2223610465558451486 { 10^-143 lo },
     -6985875133912107622 { 10^-142 lo },
     -6970941393175477888 { 10^-141 lo },
      2261481737768549439 { 10^-140 lo },
     -6943283478562891175 { 10^-139 lo },
     -6922929510352207753 { 10^-138 lo },
      2308085216923082454 { 10^-137 lo },
     -6917433106598114391 { 10^-136 lo },
     -6881320561845932811 { 10^-135 lo },
     -6866638945862932430 { 10^-134 lo },
     -6848568029603931873 { 10^-133 lo },
      2379872784373400165 { 10^-132 lo },
      2395002528442798846 { 10^-131 lo },
     -6801700238257017080 { 10^-130 lo },
      2435776599753213238 { 10^-129 lo },
     -6774827141061129859 { 10^-128 lo },
     -6763921467366679588 { 10^-127 lo },
      2478365411824158358 { 10^-126 lo },
     -6739809526770819311 { 10^-125 lo },
      2509728243035585317 { 10^-124 lo },
     -6699507609044543983 { 10^-123 lo },
     -6684408751134901354 { 10^-122 lo },
      2547201049757043466 { 10^-121 lo },
      2562504563619175885 { 10^-120 lo },
     -6649510319369241920 { 10^-119 lo },
      2589817179187686216 { 10^-118 lo },
     -6614253623653026573 { 10^-117 lo },
      2613423838358468417 { 10^-116 lo },
     -6580671501543130786 { 10^-115 lo },
     -6565692635521113125 { 10^-114 lo },
      2666993726254343773 { 10^-113 lo },
      2687499344461803514 { 10^-112 lo },
     -6517116040037961212 { 10^-111 lo },
     -6505958885777748348 { 10^-110 lo },
      2720468495323428714 { 10^-109 lo },
     -6477675614164716881 { 10^-108 lo },
     -6483645266140793429 { 10^-107 lo },
      2778484962396186215 { 10^-106 lo },
      2789684959541760001 { 10^-105 lo },
      2809780311493564929 { 10^-104 lo },
      2820922846565585025 { 10^-103 lo },
      2838874140091617873 { 10^-102 lo },
     -6371223741568980709 { 10^-101 lo },
     -6362413745387518268 { 10^-100 lo },
     -6347483914576816011 { 10^-99 lo },
      2898100922638176347 { 10^-98 lo },
     -6313526930651591794 { 10^-97 lo },
      2930955565638619335 { 10^-96 lo },
      2931907998147695589 { 10^-95 lo },
      2955788930666568248 { 10^-94 lo },
      2976082738276335715 { 10^-93 lo },
      2977399876241457645 { 10^-92 lo },
     -6227114761386606900 { 10^-91 lo },
      3001586934749545990 { 10^-90 lo },
     -6193495297407582961 { 10^-89 lo },
      3048464678931202519 { 10^-88 lo },
     -6168750817501021336 { 10^-87 lo },
     -6143385356664564080 { 10^-86 lo },
      3086154407076808599 { 10^-85 lo },
     -6119445957691251902 { 10^-84 lo },
     -6104572774925984750 { 10^-83 lo },
      3134751490642374261 { 10^-82 lo },
      3149449726929455634 { 10^-81 lo },
      3164444822567779478 { 10^-80 lo },
      3156645114622736260 { 10^-79 lo },
      3171423647473183410 { 10^-78 lo },
      3213423668297437269 { 10^-77 lo },
      3228649650581959787 { 10^-76 lo },
      3239800829089714566 { 10^-75 lo },
      3254865702131250663 { 10^-74 lo },
      3252741445267430150 { 10^-73 lo },
      3283565231004130844 { 10^-72 lo },
      3304228965786579666 { 10^-71 lo },
      3299896910559508579 { 10^-70 lo },
      3328766810794896232 { 10^-69 lo },
     -5875887842713295649 { 10^-68 lo },
      3361425932982415849 { 10^-67 lo },
      3370792248869510343 { 10^-66 lo },
      3393274059167405310 { 10^-65 lo },
      3403124768244593787 { 10^-64 lo },
     -5800764376180353229 { 10^-63 lo },
     -5789537391143715584 { 10^-62 lo },
     -5774377759941075904 { 10^-61 lo },
      3461970110699351216 { 10^-60 lo },
     -5747222420902737885 { 10^-59 lo },
     -5732349735972039402 { 10^-58 lo },
      3509535091037754066 { 10^-57 lo },
     -5699718155175692167 { 10^-56 lo },
      3525943175987022659 { 10^-55 lo },
     -5671380660079870914 { 10^-54 lo },
     -5656238187833260634 { 10^-53 lo },
     -5650602811629560768 { 10^-52 lo },
     -5635612432660503727 { 10^-51 lo },
     -5620372246814044654 { 10^-50 lo },
      3631430648259976141 { 10^-49 lo },
      3640480070600066433 { 10^-48 lo },
      3655509662310196961 { 10^-47 lo },
     -5553423596468199577 { 10^-46 lo },
      3682299265275852992 { 10^-45 lo },
      3704259509117775292 { 10^-44 lo },
     -5500895979609814165 { 10^-43 lo },
     -5490386432613360502 { 10^-42 lo },
     -5487876780380893516 { 10^-41 lo },
      3766752122278926810 { 10^-40 lo },
      3781824529517178960 { 10^-39 lo },
      3792783739217095781 { 10^-38 lo },
     -5412108435346033599 { 10^-37 lo },
      3825410887416450735 { 10^-36 lo },
     -5395845992869368529 { 10^-35 lo },
      3856671083969765240 { 10^-34 lo },
     -5353389510898767702 { 10^-33 lo },
     -5338405200598625580 { 10^-32 lo },
     -5320901836184265788 { 10^-31 lo },
     -5305676906553396554 { 10^-30 lo },
      3929936356769448093 { 10^-29 lo },
      3940768826356625604 { 10^-28 lo },
     -5265982804812254453 { 10^-27 lo },
     -5250868040867246105 { 10^-26 lo },
     -5236149060916603936 { 10^-25 lo },
      4006679902334268308 { 10^-24 lo },
      4017557959896326265 { 10^-23 lo },
     -5189706535989958807 { 10^-22 lo },
      4053088618013570910 { 10^-21 lo },
      4064309855427028278 { 10^-20 lo },
      4074159742176345351 { 10^-19 lo },
     -5127411775529120530 { 10^-18 lo },
     -5112228026728697815 { 10^-17 lo },
      4117896183574595481 { 10^-16 lo },
     -5081969668356835936 { 10^-15 lo },
      4129421565601463783 { 10^-14 lo },
     -5057879409136967787 { 10^-13 lo },
      4177509938886011014 { 10^-12 lo },
      4199597566440843434 { 10^-11 lo },
     -5011932077707260628 { 10^-10 lo },
     -4993570094577895365 { 10^-9 lo },
     -4985431856872862572 { 10^-8 lo },
      4257557416083959843 { 10^-7 lo },
      4272608056927624236 { 10^-6 lo },
     -4931749998473175452 { 10^-5 lo },
     -4920568101030369794 { 10^-4 lo },
     -4911013264060940550 { 10^-3 lo },
     -4895773082921918792 { 10^-2 lo },
     -4874696236665824870 { 10^-1 lo },
                        0 { 10^0 lo },
                        0 { 10^1 lo },
                        0 { 10^2 lo },
                        0 { 10^3 lo },
                        0 { 10^4 lo },
                        0 { 10^5 lo },
                        0 { 10^6 lo },
                        0 { 10^7 lo },
                        0 { 10^8 lo },
                        0 { 10^9 lo },
                        0 { 10^10 lo },
                        0 { 10^11 lo },
                        0 { 10^12 lo },
                        0 { 10^13 lo },
                        0 { 10^14 lo },
                        0 { 10^15 lo },
                        0 { 10^16 lo },
                        0 { 10^17 lo },
                        0 { 10^18 lo },
                        0 { 10^19 lo },
                        0 { 10^20 lo },
                        0 { 10^21 lo },
                        0 { 10^22 lo },
      4710765210229538816 { 10^23 lo },
      4715268809856909312 { 10^24 lo },
     -4482489004117196800 { 10^25 lo },
     -4471581848769658880 { 10^26 lo },
     -4465107924305313792 { 10^27 lo },
      4780645771244470272 { 10^28 lo },
      4800602457044418560 { 10^29 lo },
     -4417444370119131136 { 10^30 lo },
      4824677260566986752 { 10^31 lo },
     -4381139874854469632 { 10^32 lo },
      4857179894804643840 { 10^33 lo },
      4872391467718410240 { 10^34 lo },
      4883524634512719872 { 10^35 lo },
     -4322780941442351104 { 10^36 lo },
      4915961517140082688 { 10^37 lo },
      4926518402099445760 { 10^38 lo },
      4947636018668699648 { 10^39 lo },
     -4264885682169200640 { 10^40 lo },
     -4260289422739193856 { 10^41 lo },
     -4232661864668787200 { 10^42 lo },
     -4225271124803500544 { 10^43 lo },
     -4198339070503492880 { 10^44 lo },
      5038506455456638036 { 10^45 lo },
      5038319906572856136 { 10^46 lo },
     -4158041069000469699 { 10^47 lo },
     -4142947390359952378 { 10^48 lo },
      5096493544750428921 { 10^49 lo },
     -4109672288986812379 { 10^50 lo },
      5112961867177860753 { 10^51 lo },
      5127942638494901814 { 10^52 lo },
      5143200838688890850 { 10^53 lo },
     -4049453824984068859 { 10^54 lo },
     -4047821265268670184 { 10^55 lo },
     -4018616042527421396 { 10^56 lo },
     -4007708337187229897 { 10^57 lo },
      5231437703132034300 { 10^58 lo },
      5242260436232340027 { 10^59 lo },
      5260811358455337317 { 10^60 lo },
      5275599805665940926 { 10^61 lo },
     -3935124177120148269 { 10^62 lo },
     -3916930040107869436 { 10^63 lo },
     -3908372187110120567 { 10^64 lo },
      5323625835746936617 { 10^65 lo },
      5351038025413396254 { 10^66 lo },
      5358588297429754776 { 10^67 lo },
      5379895436365873951 { 10^68 lo },
     -3825742459394410996 { 10^69 lo },
     -3810526454637829233 { 10^70 lo },
     -3799387748040000397 { 10^71 lo },
      5441005738810886712 { 10^72 lo },
      5448138894227567384 { 10^73 lo },
      5469804492741534711 { 10^74 lo },
      5487468886786780795 { 10^75 lo },
     -3723704867926768153 { 10^76 lo },
      5508224084316221759 { 10^77 lo },
     -3705015043617495838 { 10^78 lo },
      5542071438375645305 { 10^79 lo },
     -3697297848379581936 { 10^80 lo },
      5577685379488012783 { 10^81 lo },
      5587784340134076631 { 10^82 lo },
     -3621667403428677900 { 10^83 lo },
     -3602558409137600212 { 10^84 lo },
     -3596769638475043363 { 10^85 lo },
     -3581731323737593516 { 10^86 lo },
      5663141587708117782 { 10^87 lo },
      5678307500522922971 { 10^88 lo },
      5679884581785203528 { 10^89 lo },
      5706896517143790083 { 10^90 lo },
     -3495878629083783490 { 10^91 lo },
     -3484890959576426898 { 10^92 lo },
     -3470030472785388535 { 10^93 lo },
     -3459907813468436970 { 10^94 lo },
     -3444842377311521842 { 10^95 lo },
     -3424167480645023647 { 10^96 lo },
     -3406742070601091780 { 10^97 lo },
      5809408818375143055 { 10^98 lo },
      5841511392415234258 { 10^99 lo },
     -3371801010376068620 { 10^100 lo },
      5869007220246249671 { 10^101 lo },
      5883848145480827129 { 10^102 lo },
     -3340623246721649085 { 10^103 lo },
     -3325724628735880237 { 10^104 lo },
      5935473250455630650 { 10^105 lo },
     -3270569817866145796 { 10^106 lo },
      5960653527999080458 { 10^107 lo },
     -3246900994591310086 { 10^108 lo },
      5987049862732030608 { 10^109 lo },
     -3219488607432541594 { 10^110 lo },
      6022635847818765184 { 10^111 lo },
      6040717016522513968 { 10^112 lo },
     -3177483718762223345 { 10^113 lo },
     -3162332615432932525 { 10^114 lo },
     -3147393787761911788 { 10^115 lo },
     -3132601501030441447 { 10^116 lo },
     -3109985017748389528 { 10^117 lo },
      6125770286988623422 { 10^118 lo },
      6144019587789745895 { 10^119 lo },
      6152439531315385665 { 10^120 lo },
     -3052078222701487433 { 10^121 lo },
     -3043279336276868406 { 10^122 lo },
      6197920679731074626 { 10^123 lo },
      6218386980831686121 { 10^124 lo },
      6235682018646938802 { 10^125 lo },
      6250993751027435998 { 10^126 lo },
      6262252117155159126 { 10^127 lo },
     -2942818903570211254 { 10^128 lo },
      6271183363525526621 { 10^129 lo },
     -2914089751168600236 { 10^130 lo },
      6326594571711135083 { 10^131 lo },
      6326935628266169905 { 10^132 lo },
     -2875916984470302703 { 10^133 lo },
      6370597604902122235 { 10^134 lo },
      6381114602043539315 { 10^135 lo },
     -2824579072555360168 { 10^136 lo },
     -2813525600035448722 { 10^137 lo },
     -2798582859478716790 { 10^138 lo },
     -2783282133503329748 { 10^139 lo },
     -2764665209935926738 { 10^140 lo },
     -2757981765230325019 { 10^141 lo },
     -2735929696574024216 { 10^142 lo },
     -2725785981832112445 { 10^143 lo },
     -2710733705315797446 { 10^144 lo },
      6522380884343060591 { 10^145 lo },
      6549120143124506321 { 10^146 lo },
      6557168882463097367 { 10^147 lo },
     -2646405176349729959 { 10^148 lo },
     -2631340626424745425 { 10^149 lo },
      6600869564198716042 { 10^150 lo },
     -2608076622153163565 { 10^151 lo },
     -2586908922816443134 { 10^152 lo },
      6617891749752725196 { 10^153 lo },
     -2558109114682113965 { 10^154 lo },
     -2553863620397432417 { 10^155 lo },
      6689635118904938366 { 10^156 lo },
      6704719235758830430 { 10^157 lo },
      6726332552995057677 { 10^158 lo },
      6743988035458870792 { 10^159 lo },
     -2479959329396673619 { 10^160 lo },
     -2453519974274445293 { 10^161 lo },
      6788024849156054516 { 10^162 lo },
      6802936600622187889 { 10^163 lo },
     -2428407539060103599 { 10^164 lo },
      6836307205845535296 { 10^165 lo },
      6847526947788242129 { 10^166 lo },
     -2363581497380342789 { 10^167 lo },
      6878180288986781571 { 10^168 lo },
      6893112902273744228 { 10^169 lo },
     -2319232948871384253 { 10^170 lo },
      6920755653331083244 { 10^171 lo },
     -2283652802272828403 { 10^172 lo },
     -2280460367429405632 { 10^173 lo },
     -2255152125300930006 { 10^174 lo },
      6982518012130186060 { 10^175 lo },
     -2239660513352827124 { 10^176 lo },
     -2224509502607739032 { 10^177 lo },
     -2197010944259824472 { 10^178 lo },
      7035010233023956060 { 10^179 lo },
     -2178459457511738085 { 10^180 lo },
      7074250895573587892 { 10^181 lo },
     -2135827874405473697 { 10^182 lo },
      7101326876339410185 { 10^183 lo },
     -2114567484804478102 { 10^184 lo },
      7125055747823104222 { 10^185 lo },
      7139782730942803221 { 10^186 lo },
      7164875495204004375 { 10^187 lo },
     -2052762650224809273 { 10^188 lo },
     -2037906256471820935 { 10^189 lo },
     -2015510141076237130 { 10^190 lo },
     -2000347819290846749 { 10^191 lo },
     -1989276216407007140 { 10^192 lo },
     -1971191925028135878 { 10^193 lo },
      7265953008968961208 { 10^194 lo },
      7275178623440543692 { 10^195 lo },
      7295308312253184992 { 10^196 lo },
      7310141167574771052 { 10^197 lo },
     -1904768273445174669 { 10^198 lo },
     -1878765979252208444 { 10^199 lo },
      7351786928465428502 { 10^200 lo },
     -1854989406989367310 { 10^201 lo },
      7389535513882014473 { 10^202 lo },
      7390553214977507116 { 10^203 lo },
      7405226470382092023 { 10^204 lo },
     -1800568927953557338 { 10^205 lo },
     -1780066375799959192 { 10^206 lo },
     -1765000480890275103 { 10^207 lo },
      7468193549396569294 { 10^208 lo },
     -1731172559048913408 { 10^209 lo },
      7507486656686235264 { 10^210 lo },
      7518742175219566113 { 10^211 lo },
      7538733424569326548 { 10^212 lo },
      7542067617601162022 { 10^213 lo },
      7563901724670788476 { 10^214 lo },
      7583846641578979885 { 10^215 lo },
     -1634268837453151601 { 10^216 lo },
      7607932478437570151 { 10^217 lo },
     -1595682660423078400 { 10^218 lo },
      7637122349227797761 { 10^219 lo },
      7637285979349467656 { 10^220 lo },
     -1554381575394684201 { 10^221 lo },
     -1539504987623781433 { 10^222 lo },
     -1524686767600595272 { 10^223 lo },
      7710998379181313434 { 10^224 lo },
      7731514096036767872 { 10^225 lo },
      7742481479065600672 { 10^226 lo },
     -1460225303981285796 { 10^227 lo },
      7776788537546717709 { 10^228 lo },
      7777443566502298754 { 10^229 lo },
     -1414812643094975834 { 10^230 lo },
     -1403724234051709617 { 10^231 lo },
     -1388737822840784221 { 10^232 lo },
      7844839795278712168 { 10^233 lo },
     -1366304042406080706 { 10^234 lo },
     -1344296962351928125 { 10^235 lo },
     -1329090432005011468 { 10^236 lo },
      7909777184276130567 { 10^237 lo },
     -1299982890856469961 { 10^238 lo },
      7927555536158797039 { 10^239 lo },
     -1278096064304659477 { 10^240 lo },
     -1254807474318889671 { 10^241 lo },
     -1239746570100565880 { 10^242 lo },
     -1222386819282796715 { 10^243 lo },
     -1207102050653348054 { 10^244 lo },
     -1195877389214435595 { 10^245 lo },
     -1178080082626325927 { 10^246 lo },
      8057988658405415185 { 10^247 lo },
     -1150854961185816405 { 10^248 lo },
      8091113990793215893 { 10^249 lo },
      8106412954591121275 { 10^250 lo },
     -1105550740174742361 { 10^251 lo },
     -1085597129957553688 { 10^252 lo },
      8149550550428492702 { 10^253 lo },
      8164821955346263173 { 10^254 lo },
      8168508878667849369 { 10^255 lo },
     -1033820050253003152 { 10^256 lo },
     -1018681385453496308 { 10^257 lo },
      -999507376594005116 { 10^258 lo },
      8240096742328358811 { 10^259 lo },
      -968662499998780802 { 10^260 lo },
      8269977678330400881 { 10^261 lo },
      -948096134511284791 { 10^262 lo },
      -932918589006358212 { 10^263 lo },
      -911626432758062109 { 10^264 lo },
      -894025693644464530 { 10^265 lo },
      -883984345900012526 { 10^266 lo },
      8353524032627828969 { 10^267 lo },
      8368405709970948498 { 10^268 lo },
      -836429182278502651 { 10^269 lo },
      -821482396386446138 { 10^270 lo },
      8417243843776749316 { 10^271 lo },
      -789276009973294789 { 10^272 lo },
      8447933695112687735 { 10^273 lo },
      8465129395903213130 { 10^274 lo },
      8475978919083309533 { 10^275 lo },
      -730964565005908052 { 10^276 lo },
      -734693648934921867 { 10^277 lo },
      8520154222361446403 { 10^278 lo },
      -685262872877450498 { 10^279 lo },
      -674182806188308034 { 10^280 lo },
      -659206822920037331 { 10^281 lo },
      -643939645134603876 { 10^282 lo },
      8596151911769212925 { 10^283 lo },
      -608349489051194622 { 10^284 lo },
      8620798535177573499 { 10^285 lo },
      -584347131941928141 { 10^286 lo },
      -563938291021428224 { 10^287 lo },
      -563826130167733248 { 10^288 lo },
      -535293119523626544 { 10^289 lo },
      -520497611701306812 { 10^290 lo },
      8715443047340349227 { 10^291 lo },
      -500284800902951895 { 10^292 lo },
      8749146895201199642 { 10^293 lo },
      -459934985830883232 { 10^294 lo },
      8769928034088087312 { 10^295 lo },
      8784919622776474324 { 10^296 lo },
      -423586102007307657 { 10^297 lo },
      8819814338074970427 { 10^298 lo },
      -386724635395810757 { 10^299 lo },
      -371941703467343670 { 10^300 lo },
      -356840738277287683 { 10^301 lo },
      -339556101781516386 { 10^302 lo },
      -364395930334296743 { 10^303 lo },
      8912599740500244377 { 10^304 lo },
      8927245410063936192 { 10^305 lo },
      -289281519602406847 { 10^306 lo },
      8947714589084859183 { 10^307 lo },
      -262288240075778555 { 10^308 lo }
  );
  BNH: array[-343..-303] of QWord = (
    $3BD7E53B957505FC { B(10^-343*2^1074) hi },
    $3C0DDE8A7AD2477B { B(10^-342*2^1074) hi },
    $3C42AB168CC36CAD { B(10^-341*2^1074) hi },
    $3C7755DC2FF447D8 { B(10^-340*2^1074) hi },
    $3CAD2B533BF159CE { B(10^-339*2^1074) hi },
    $3CE23B140576D821 { B(10^-338*2^1074) hi },
    $3D16C9D906D48E29 { B(10^-337*2^1074) hi },
    $3D4C7C4F4889B1B3 { B(10^-336*2^1074) hi },
    $3D81CDB18D560F10 { B(10^-335*2^1074) hi },
    $3DB6411DF0AB92D4 { B(10^-334*2^1074) hi },
    $3DEBD1656CD67789 { B(10^-333*2^1074) hi },
    $3E2162DF64060AB6 { B(10^-332*2^1074) hi },
    $3E55BB973D078D63 { B(10^-331*2^1074) hi },
    $3E8B2A7D0C4970BC { B(10^-330*2^1074) hi },
    $3EC0FA8E27ADE675 { B(10^-329*2^1074) hi },
    $3EF53931B1996013 { B(10^-328*2^1074) hi },
    $3F2A877E1DFFB817 { B(10^-327*2^1074) hi },
    $3F6094AED2BFD30F { B(10^-326*2^1074) hi },
    $3F94B9DA876FC7D2 { B(10^-325*2^1074) hi },
    $3FC9E851294BB9C7 { B(10^-324*2^1074) hi },
    $40003132B9CF541C { B(10^-323*2^1074) hi },
    $40343D7F68432923 { B(10^-322*2^1074) hi },
    $40694CDF4253F36C { B(10^-321*2^1074) hi },
    $409FA01712E8F047 { B(10^-320*2^1074) hi },
    $40D3C40E6BD1962C { B(10^-319*2^1074) hi },
    $4108B51206C5FBB8 { B(10^-318*2^1074) hi },
    $413EE25688777AA5 { B(10^-317*2^1074) hi },
    $41734D76154AACA7 { B(10^-316*2^1074) hi },
    $41A820D39A9D57D1 { B(10^-315*2^1074) hi },
    $41DE29088144ADC6 { B(10^-314*2^1074) hi },
    $4212D9A550CAEC9B { B(10^-313*2^1074) hi },
    $4247900EA4FDA7C2 { B(10^-312*2^1074) hi },
    $427D74124E3D11B3 { B(10^-311*2^1074) hi },
    $42B2688B70E62B10 { B(10^-310*2^1074) hi },
    $42E702AE4D1FB5D4 { B(10^-309*2^1074) hi },
    $431CC359E067A349 { B(10^-308*2^1074) hi },
    $4351FA182C40C60D { B(10^-307*2^1074) hi },
    $4386789E3750F791 { B(10^-306*2^1074) hi },
    $43BC16C5C5253575 { B(10^-305*2^1074) hi },
    $43F18E3B9B374169 { B(10^-304*2^1074) hi },
    $4425F1CA820511C3 { B(10^-303*2^1074) hi }
  );
  BNL: array[-343..-303] of Int64 = (
     -5159690598842135432 { B(10^-343*2^1074) lo },
     -5144695256522068074 { B(10^-342*2^1074) lo },
     -5125028576639503649 { B(10^-341*2^1074) lo },
     -5120253779779649958 { B(10^-340*2^1074) lo },
     -5105532331855544847 { B(10^-339*2^1074) lo },
     -5079114560109861970 { B(10^-338*2^1074) lo },
     -5070940431322719950 { B(10^-337*2^1074) lo },
      4163295982762877187 { B(10^-336*2^1074) lo },
     -5043573937215028386 { B(10^-335*2^1074) lo },
     -5028822827066092490 { B(10^-334*2^1074) lo },
     -5013761639100450493 { B(10^-333*2^1074) lo },
     -4986525345841316109 { B(10^-332*2^1074) lo },
     -4986883171666168455 { B(10^-331*2^1074) lo },
     -4961777912004831653 { B(10^-330*2^1074) lo },
      4279365447513825799 { B(10^-329*2^1074) lo },
     -4929246144139983497 { B(10^-328*2^1074) lo },
      4306074633698335019 { B(10^-327*2^1074) lo },
     -4896371613612738491 { B(10^-326*2^1074) lo },
      4334859888182940500 { B(10^-325*2^1074) lo },
     -4872704101112439828 { B(10^-324*2^1074) lo },
      4367127369014492441 { B(10^-323*2^1074) lo },
      4382275668879029808 { B(10^-322*2^1074) lo },
      4387872194296549103 { B(10^-321*2^1074) lo },
      4402850432394924715 { B(10^-320*2^1074) lo },
      4430436670406589163 { B(10^-319*2^1074) lo },
     -4779189300796307877 { B(10^-318*2^1074) lo },
      4457399451478370319 { B(10^-317*2^1074) lo },
      4474724517437917449 { B(10^-316*2^1074) lo },
      4485455048067495575 { B(10^-315*2^1074) lo },
     -4720816946395173406 { B(10^-314*2^1074) lo },
      4521140961542443859 { B(10^-313*2^1074) lo },
      4532281694526486568 { B(10^-312*2^1074) lo },
     -4687542359796783302 { B(10^-311*2^1074) lo },
     -4664101572729810878 { B(10^-310*2^1074) lo },
     -4649057963634351022 { B(10^-309*2^1074) lo },
     -4633917584274897228 { B(10^-308*2^1074) lo },
      4610944048293127120 { B(10^-307*2^1074) lo },
     -4605327493464365447 { B(10^-306*2^1074) lo },
      4620158362835091274 { B(10^-305*2^1074) lo },
      4648376717353203698 { B(10^-304*2^1074) lo },
      4668957652414722807 { B(10^-303*2^1074) lo }
  );

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  {$ifdef cpux86_64}
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
  {$endif}
  { 非 x86（ARM 等）默认不陷入 FP 异常，无需清理 }
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  Result := 0.0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      MP3DErrno := 34;
      Result := X;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      MP3DErrno := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            MP3DErrno := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      MP3DErrno := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    MP3DErrno := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    MP3DErrno := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    MP3DErrno := 34;
  Result := X;
end;


function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  {$ifdef cpux86_64}
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
  {$endif}
  { 非 x86（ARM 等）默认不陷入 FP 异常，无需清理 }
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  FBits: LongWord;
  QW64: QWord;
  AbsQ: QWord;
  S: LongInt;
  THo: Double;
  TLo: Double;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { 106-bit double-double -> correct float rounding (round-half-even).
    Rounding through an intermediate double flips at the float 0.5ulp
    boundary (double rounding); use the exact residue R=(Hi-F)+Lo to
    pick the direction (error ~2^-105, tie misread ~2^-80) }
  function FloatR2(Hi, Lo: Double): Single;
  var FB, FB2: LongWord;
      Fv: Single;
      D, Up, Half, R: Double;
  begin
    Fv := Single(Hi);
    Move(Fv, FB, 4);
    if (FB and $7FFFFFFF) = 0 then begin
      { F = +-0: direction set by Hi+Lo vs half of min subnormal }
      FB2 := 1;
      Move(FB2, Fv, 4);
      Half := Double(Fv) * 0.5; { 2^-150 }
      R := Hi + Lo;
      if (FB shr 31) <> 0 then begin
        if R < -Half then FB := $80000001;
      end else begin
        if R > Half then FB := 1;
      end;
      Move(FB, Result, 4);
      Exit;
    end;
    D := Double(Fv);
    R := (Hi - D) + Lo;
    { next float toward +inf: FB2 = FB+1.0 At FLT_MAX it is +-Inf
      (Half not representable; use exact 2^103 double; tie only at
      float extremes) }
    FB2 := FB + 1;
    if (FB2 and $7F800000) = $7F800000 then begin
      if (FB shr 31) <> 0 then
        Bits := QWord($C660000000000000) { -2^103 }
      else
        Bits := QWord($4660000000000000); { +2^103 }
      Move(Bits, Half, 8);
    end else begin
      Move(FB2, Fv, 4);
      Up := Double(Fv);
      Half := (Up - D) * 0.5;
    end;
    if R > Half then
      FB := FB + 1
    else if R < -Half then
      FB := FB - 1;
    Move(FB, Result, 4);
  end;
begin
  Result := 0.0;
  IsHex := False;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      MP3DErrno := 34;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    { value = M x 2^T, T = ExpBits - 4*DfHex + 4*CutHex.
      strtof version: round directly in the float domain (24-bit
      round-half-even); the double intermediate double-rounds
      boundary cases by 1ulp }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 127 then begin
      { float exponent overflow -> +-Inf + ERANGE }
      MP3DErrno := 34;
      FBits := $7F800000;
      if Neg then FBits := $FF800000;
      Move(FBits, Result, 4);
    end else if EvalI >= -126 then begin
      { float normal: 24-bit round-half-even }
      if L <= 23 then
        mant := M shl (23 - L)
      else begin
        BL := L - 23;
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 24) then begin
          { mantissa carry into 2^128: float overflow (FLT_MAX+0.5ulp tie) }
          mant := QWord(1) shl 23;
          Inc(EvalI);
          if EvalI > 127 then begin
            MP3DErrno := 34;
            FBits := $7F800000;
            if Neg then FBits := $FF800000;
            Move(FBits, Result, 4);
            Exit;
          end;
        end;
      end;
      { mant in [2^23, 2^24): exponent field EvalI+127 }
      FBits := LongWord((EvalI + 127) shl 23) or LongWord(mant and $7FFFFF);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
    end else begin
      { float subnormal: grid 2^-149, grid count = M x 2^Rg, Rg = T + 149
        (ERANGE only when rounding inexact; 0x1p-149 exact -> 0) }
      Rg := T + 149;
      HexExact := True;
      if Rg >= 0 then begin
        { subnormal domain: Rg < 23-L -> grid < 2^24: no QWord overflow }
        mant := M shl Rg;
      end else begin
        BL := LongInt(-Rg);
        if BL >= 64 then begin
          { grid count < 0.5: rounds to 0 }
          mant := 0;
          HexExact := False;
        end else begin
          remLW := M and ((QWord(1) shl BL) - 1);
          mant := M shr BL;
          half := QWord(1) shl (BL - 1);
          if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
            Inc(mant);
          if remLW <> 0 then HexExact := False;
        end;
      end;
      if HexLost then HexExact := False; { 64-bit truncation also inexact }
      if mant >= (QWord(1) shl 23) then
        FBits := $00800000 { carry into 2^-126 (min normal) }
      else
        FBits := LongWord(mant);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
      IsHex := True;
    if not HexExact then MP3DErrno := 34;
    end;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    MP3DErrno := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    MP3DErrno := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    THo := X;
    TLo := 0.0;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      MP3DErrno := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    MP3DErrno := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    MP3DErrno := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    MP3DErrno := 34;
  begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        MP3DErrno := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            MP3DErrno := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              MP3DErrno := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                MP3DErrno := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          MP3DErrno := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
end;


function atof(nptr: PAnsiChar): Double; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  {$ifdef cpux86_64}
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
  {$endif}
  { 非 x86（ARM 等）默认不陷入 FP 异常，无需清理 }
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  DummyEnd: PPAnsiChar;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  DummyEnd := nil;
  Result := 0.0;
  if nptr = nil then begin
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if DummyEnd <> nil then DummyEnd^ := P;
      MP3DErrno := 34;
      Result := X;
      Exit;
    end;
    if DummyEnd <> nil then DummyEnd^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      MP3DErrno := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            MP3DErrno := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: DummyEnd = original nptr (C99) }
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if DummyEnd <> nil then DummyEnd^ := P;
    MP3DErrno := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      MP3DErrno := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if DummyEnd <> nil then DummyEnd^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    MP3DErrno := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    MP3DErrno := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    MP3DErrno := 34;
  Result := X;
end;


function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      MP3DErrno := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      MP3DErrno := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      MP3DErrno := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      MP3DErrno := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

var __c2p_rand_state: array[0..30] of LongWord;
    __c2p_rand_fptr: LongInt;
    __c2p_rand_rptr: LongInt;

function rand(): LongInt; cdecl;
var
  Val: QWord;
begin
  Val := (__c2p_rand_state[__c2p_rand_fptr] + __c2p_rand_state[__c2p_rand_rptr]) and $ffffffff;
  __c2p_rand_state[__c2p_rand_fptr] := LongWord(Val);
  Result := LongInt(Val shr 1);
  __c2p_rand_fptr := (__c2p_rand_fptr + 1) mod 31;
  __c2p_rand_rptr := (__c2p_rand_rptr + 1) mod 31;
end;

procedure srand(seed: LongWord); cdecl;
var
  W: Int64;
  I: LongInt;
begin
  if Seed = 0 then Seed := 1;
  __c2p_rand_state[0] := Seed;
  W := Seed;
  for I := 1 to 30 do
  begin
    W := (16807 * W) mod 2147483647;
    __c2p_rand_state[I] := LongWord(W);
  end;
  __c2p_rand_fptr := 3;
  __c2p_rand_rptr := 0;
  for I := 1 to 310 do
    rand();
end;

type
  PInt16T = ^TInt16T;
  PTInt16T = PInt16T;

var
  g_pow43: array[0..144] of Single;
  _static_hdr_bitrate_kbps_halfrate: array[0..1] of array[0..2] of array[0..14] of TUint8T;
  _static_hdr_sample_rate_hz_g_hz: array[0..2] of LongWord;
  _static_L12_subband_alloc_table_g_alloc_L1: array[0..0] of TL12SubbandAllocT;
  _static_L12_subband_alloc_table_g_alloc_L2M2: array[0..2] of TL12SubbandAllocT;
  _static_L12_subband_alloc_table_g_alloc_L2M1: array[0..3] of TL12SubbandAllocT;
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate: array[0..1] of TL12SubbandAllocT;
  _static_L12_read_scalefactors_g_deq_L12: array[0..53] of Single;
  _static_L12_read_scale_info_g_bitalloc_code_tab: array[0..91] of TUint8T;
  _static_L3_read_side_info_g_scf_long: array[0..7] of array[0..22] of TUint8T;
  _static_L3_read_side_info_g_scf_short: array[0..7] of array[0..39] of TUint8T;
  _static_L3_read_side_info_g_scf_mixed: array[0..7] of array[0..39] of TUint8T;
  _static_L3_ldexp_q2_g_expfrac: array[0..3] of Single;
  _static_L3_decode_scalefactors_g_scf_partitions: array[0..2] of array[0..27] of TUint8T;
  _static_L3_decode_scalefactors_g_scfc_decode: array[0..15] of TUint8T;
  _static_L3_decode_scalefactors_g_mod: array[0..23] of TUint8T;
  _static_L3_decode_scalefactors_g_preamp: array[0..9] of TUint8T;
  _static_L3_huffman_tabs: array[0..2163] of TInt16T;
  _static_L3_huffman_tab32: array[0..27] of TUint8T;
  _static_L3_huffman_tab33: array[0..15] of TUint8T;
  _static_L3_huffman_tabindex: array[0..31] of TInt16T;
  _static_L3_huffman_g_linbits: array[0..31] of TUint8T;
  _static_L3_stereo_process_g_pan: array[0..13] of Single;
  _static_L3_antialias_g_aa: array[0..1] of array[0..7] of Single;
  _static_L3_imdct36_g_twid9: array[0..17] of Single;
  _static_L3_imdct12_g_twid3: array[0..5] of Single;
  _static_L3_imdct_gr_g_mdct_window: array[0..1] of array[0..17] of Single;
  _static_mp3d_DCT_II_g_sec: array[0..23] of Single;
  _static_mp3d_synth_g_win: array[0..239] of Single;

var __c2p_static_filled_mp3dec: Boolean = False;

procedure __c2p_static_fill_mp3dec; forward;

procedure bs_init(bs: PBsT; data: PUint8T; bytes: LongInt);
begin
  bs^.buf := data;
  bs^.pos := 0;
  bs^.limit := (bytes * 8);
end;

function get_bits(bs: PBsT; n: LongInt): TUint32T; inline;
var
  next_2: TUint32T;
  cache_2: TUint32T;
  s_2: TUint32T;
  &shl: LongInt;
  p: PUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: PUint8T;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: PUint8T;
begin
  cache_2 := TUint32T(0);
  s_2 := TUint32T((bs^.pos and 7));
  &shl := LongInt(LongWord((n + s_2)));
  p := (bs^.buf + SarLongInt(bs^.pos, 3));
  __c2p_tmp1 := (bs^.pos + n);
  bs^.pos := __c2p_tmp1;
  if (__c2p_tmp1 > bs^.limit) then
  begin
    Result := 0;
    System.Exit;
  end;
  __c2p_tmp2 := p;
  p := (p + 1);
  next_2 := TUint32T((LongInt(__c2p_tmp2^) and SarLongInt(255, s_2)));
  while True do
  begin
    __c2p_tmp3 := (&shl - 8);
    &shl := __c2p_tmp3;
    if ((__c2p_tmp3 > 0) = False) then
    begin
      Break;
    end;
    cache_2 := (cache_2 or (next_2 shl &shl));
    __c2p_tmp4 := p;
    p := (p + 1);
    next_2 := TUint32T(__c2p_tmp4^);
  end;
  Result := (cache_2 or (next_2 shr -&shl));
end;

function hdr_valid(h: PUint8T): LongInt; inline;
begin
  Result := LongInt((((((h[0] = 255) and (((LongInt(h[1]) and 240) = 240) or ((LongInt(h[1]) and 254) = 226))) and (((LongInt(h[1]) shr 1) and 3) <> 0)) and ((LongInt(h[2]) shr 4) <> 15)) and (((LongInt(h[2]) shr 2) and 3) <> 3)));
end;

function hdr_compare(h1: PUint8T; h2: PUint8T): LongInt; inline;
var
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
begin
  __c2p_tmp1 := LongInt(0);
  __c2p_tmp2 := LongInt(0);
  __c2p_tmp3 := LongInt(0);
  if (hdr_valid(h2) <> 0) then
  begin
    __c2p_tmp3 := LongInt((((LongInt(h1[1]) xor LongInt(h2[1])) and 254) = 0));
  end;
  if (__c2p_tmp3 <> 0) then
  begin
    __c2p_tmp2 := LongInt((((LongInt(h1[2]) xor LongInt(h2[2])) and 12) = 0));
  end;
  if (__c2p_tmp2 <> 0) then
  begin
    __c2p_tmp1 := LongInt(((LongInt(((LongInt(h1[2]) and 240) = 0)) xor LongInt(((LongInt(h2[2]) and 240) = 0))) = 0));
  end;
  Result := __c2p_tmp1;
end;

function hdr_bitrate_kbps(h: PUint8T): LongWord;
begin
  Result := (2 * LongInt(_static_hdr_bitrate_kbps_halfrate[LongInt(((LongInt(h[1]) and 8) <> 0))][(((LongInt(h[1]) shr 1) and 3) - 1)][(LongInt(h[2]) shr 4)]));
end;

function hdr_sample_rate_hz(h: PUint8T): LongWord; inline;
begin
  Result := ((_static_hdr_sample_rate_hz_g_hz[((LongInt(h[2]) shr 2) and 3)] shr LongInt(((LongInt(h[1]) and 8) = 0))) shr LongInt(((LongInt(h[1]) and 16) = 0)));
end;

function hdr_frame_samples(h: PUint8T): LongWord; inline;
var
  __c2p_tmp1: LongInt;
begin
  if ((LongInt(h[1]) and 6) = 6) then
  begin
    __c2p_tmp1 := 384;
  end
  else
  begin
    __c2p_tmp1 := SarLongInt(1152, LongInt(((LongInt(h[1]) and 14) = 2)));
  end;
  Result := __c2p_tmp1;
end;

function hdr_frame_bytes(h: PUint8T; free_format_size: LongInt): LongInt;
var
  frame_bytes: LongInt;
  __c2p_tmp1: LongInt;
begin
  frame_bytes := LongInt((LongWord((LongWord((hdr_frame_samples(h) * hdr_bitrate_kbps(h))) * LongWord(125))) div hdr_sample_rate_hz(h)));
  if ((LongInt(h[1]) and 6) = 6) then
  begin
    frame_bytes := (frame_bytes and LongInt(not 3));
  end;
  if (frame_bytes <> 0) then
  begin
    __c2p_tmp1 := frame_bytes;
  end
  else
  begin
    __c2p_tmp1 := free_format_size;
  end;
  Result := __c2p_tmp1;
end;

function hdr_padding(h: PUint8T): LongInt; inline;
var
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  if ((LongInt(h[2]) and 2) <> 0) then
  begin
    if ((LongInt(h[1]) and 6) = 6) then
    begin
      __c2p_tmp2 := 4;
    end
    else
    begin
      __c2p_tmp2 := 1;
    end;
    __c2p_tmp1 := __c2p_tmp2;
  end
  else
  begin
    __c2p_tmp1 := 0;
  end;
  Result := __c2p_tmp1;
end;

function L12_subband_alloc_table(hdr: PUint8T; sci: PL12ScaleInfo): PL12SubbandAllocT; inline;
var
  alloc: PL12SubbandAllocT;
  mode: LongInt;
  nbands: LongInt;
  stereo_bands: LongInt;
  sample_rate_idx: LongInt;
  kbps: LongWord;
  __c2p_tmp1: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
begin
  mode := ((LongInt(hdr[3]) shr 6) and 3);
  if (mode = 3) then
  begin
    __c2p_tmp1 := 0;
  end
  else
  begin
    if (mode = 1) then
    begin
      __c2p_tmp2 := ((((LongInt(hdr[3]) shr 4) and 3) shl 2) + 4);
    end
    else
    begin
      __c2p_tmp2 := 32;
    end;
    __c2p_tmp1 := __c2p_tmp2;
  end;
  stereo_bands := __c2p_tmp1;
  if ((LongInt(hdr[1]) and 6) = 6) then
  begin
    alloc := PL12SubbandAllocT(@_static_L12_subband_alloc_table_g_alloc_L1[0]);
    nbands := 32;
  end
  else
  begin
    if ((LongInt(hdr[1]) and 8) = 0) then
    begin
      alloc := PL12SubbandAllocT(@_static_L12_subband_alloc_table_g_alloc_L2M2[0]);
      nbands := 30;
    end
    else
    begin
      sample_rate_idx := ((LongInt(hdr[2]) shr 2) and 3);
      kbps := (hdr_bitrate_kbps(hdr) shr LongInt((mode <> 3)));
      if (kbps = 0) then
      begin
        kbps := LongWord(192);
      end;
      alloc := PL12SubbandAllocT(@_static_L12_subband_alloc_table_g_alloc_L2M1[0]);
      nbands := 27;
      if (kbps < LongWord(56)) then
      begin
        alloc := PL12SubbandAllocT(@_static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[0]);
        if (sample_rate_idx = 2) then
        begin
          __c2p_tmp3 := 12;
        end
        else
        begin
          __c2p_tmp3 := 8;
        end;
        nbands := __c2p_tmp3;
      end
      else
      begin
        if ((kbps >= LongWord(96)) and (sample_rate_idx <> 1)) then
        begin
          nbands := 30;
        end;
      end;
    end;
  end;
  sci^.total_bands := TUint8T(nbands);
  if (stereo_bands > nbands) then
  begin
    __c2p_tmp4 := nbands;
  end
  else
  begin
    __c2p_tmp4 := stereo_bands;
  end;
  sci^.stereo_bands := TUint8T(__c2p_tmp4);
  Result := alloc;
end;

procedure L12_read_scalefactors(bs: PBsT; pba_2: PUint8T; scfcod: PUint8T; bands: LongInt; scf: PSingle);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  m: LongInt;
  s_2: Single;
  ba_2: LongInt;
  mask: LongInt;
  b: LongInt;
  __c2p_tmp1: PUint8T;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: PSingle;
begin
  i := 0;
  while (i < bands) do
  begin
    s_2 := 0;
    __c2p_tmp1 := pba_2;
    pba_2 := (pba_2 + 1);
    ba_2 := LongInt(__c2p_tmp1^);
    if (ba_2 <> 0) then
    begin
      __c2p_tmp2 := (4 + (SarLongInt(19, LongInt(scfcod[i])) and 3));
    end
    else
    begin
      __c2p_tmp2 := 0;
    end;
    mask := __c2p_tmp2;
    m := 4;
    while (m <> 0) do
    begin
      if ((mask and m) <> 0) then
      begin
        b := LongInt(get_bits(bs, 6));
        s_2 := (_static_L12_read_scalefactors_g_deq_L12[(((ba_2 * 3) - 6) + (b mod 3))] * SarLongInt((1 shl 21), (b div 3)));
      end;
      __c2p_tmp3 := scf;
      scf := (scf + 1);
      __c2p_tmp3^ := s_2;
      _L__for1_step:
      m := SarLongInt(m, 1);
    end;
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L12_read_scale_info(hdr: PUint8T; bs: PBsT; sci: PL12ScaleInfo);
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  subband_alloc: PL12SubbandAllocT;
  i: LongInt;
  k: LongInt;
  ba_bits: LongInt;
  ba_code_tab: PUint8T;
  ba_2: TUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongWord;
  __c2p_tmp3: LongWord;
begin
  subband_alloc := PL12SubbandAllocT(L12_subband_alloc_table(hdr, sci));
  k := 0;
  ba_bits := 0;
  ba_code_tab := PUint8T(@_static_L12_read_scale_info_g_bitalloc_code_tab[0]);
  i := 0;
  while (i < sci^.total_bands) do
  begin
    if (i = k) then
    begin
      k := (k + subband_alloc^.band_count);
      ba_bits := LongInt(subband_alloc^.code_tab_width);
      ba_code_tab := (PUint8T(@_static_L12_read_scale_info_g_bitalloc_code_tab[0]) + LongInt(subband_alloc^.tab_offset));
      subband_alloc := (subband_alloc + 1);
    end;
    ba_2 := TUint8T(ba_code_tab[get_bits(bs, ba_bits)]);
    sci^.bitalloc[(2 * i)] := TUint8T(ba_2);
    if (i < sci^.stereo_bands) then
    begin
      ba_2 := TUint8T(ba_code_tab[get_bits(bs, ba_bits)]);
    end;
    if (LongInt(sci^.stereo_bands) <> 0) then
    begin
      __c2p_tmp1 := LongInt(ba_2);
    end
    else
    begin
      __c2p_tmp1 := 0;
    end;
    sci^.bitalloc[((2 * i) + 1)] := TUint8T(__c2p_tmp1);
    _L__for0_step:
    i := (i + 1);
  end;
  i := 0;
  while (i < (2 * LongInt(sci^.total_bands))) do
  begin
    if (LongInt(sci^.bitalloc[i]) <> 0) then
    begin
      if ((LongInt(hdr[1]) and 6) = 6) then
      begin
        __c2p_tmp3 := LongWord(2);
      end
      else
      begin
        __c2p_tmp3 := get_bits(bs, 2);
      end;
      __c2p_tmp2 := __c2p_tmp3;
    end
    else
    begin
      __c2p_tmp2 := LongWord(6);
    end;
    sci^.scfcod[i] := TUint8T(__c2p_tmp2);
    _L__for1_step:
    i := (i + 1);
  end;
  L12_read_scalefactors(bs, PUint8T(@sci^.bitalloc[0]), PUint8T(@sci^.scfcod[0]), (LongInt(sci^.total_bands) * 2), PSingle(@sci^.scf[0]));
  i := LongInt(sci^.stereo_bands);
  while (i < sci^.total_bands) do
  begin
    sci^.bitalloc[((2 * i) + 1)] := TUint8T(0);
    _L__for2_step:
    i := (i + 1);
  end;
end;

function L12_dequantize_granule(grbuf: PSingle; bs: PBsT; sci: PL12ScaleInfo; group_size: LongInt): LongInt;
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  i: LongInt;
  j: LongInt;
  k: LongInt;
  choff: LongInt;
  dst: PSingle;
  ba_2: LongInt;
  half: LongInt;
  &mod: LongWord;
  code: LongWord;
begin
  choff := 576;
  j := 0;
  while (j < 4) do
  begin
    dst := (grbuf + (group_size * j));
    i := 0;
    while (i < (2 * LongInt(sci^.total_bands))) do
    begin
      ba_2 := LongInt(sci^.bitalloc[i]);
      if (ba_2 <> 0) then
      begin
        if (ba_2 < 17) then
        begin
          half := ((1 shl (ba_2 - 1)) - 1);
          k := 0;
          while (k < group_size) do
          begin
            dst[k] := Single((LongInt(get_bits(bs, ba_2)) - half));
            _L__for2_step:
            k := (k + 1);
          end;
        end
        else
        begin
          &mod := LongWord(((2 shl (ba_2 - 17)) + 1));
          code := get_bits(bs, LongInt(LongWord((LongWord((&mod + LongWord(2))) - (&mod shr 3)))));
          k := 0;
          while (k < group_size) do
          begin
            dst[k] := Single(LongInt(LongWord(((code mod &mod) - (&mod div LongWord(2))))));
            _L__for3_step:
            k := (k + 1);
            code := (code div &mod);
          end;
        end;
      end;
      dst := (dst + choff);
      choff := (18 - choff);
      _L__for1_step:
      i := (i + 1);
    end;
    _L__for0_step:
    j := (j + 1);
  end;
  Result := (group_size * 4);
end;

procedure L12_apply_scf_384(sci: PL12ScaleInfo; scf: PSingle; dst: PSingle);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  k: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  __c2p_stdlib_memcpy(((dst + 576) + (LongInt(sci^.stereo_bands) * 18)), (dst + (LongInt(sci^.stereo_bands) * 18)), TSizeT(QWord((QWord(((LongInt(sci^.total_bands) - LongInt(sci^.stereo_bands)) * 18)) * 4))));
  i := 0;
  while (i < sci^.total_bands) do
  begin
    k := 0;
    while (k < 12) do
    begin
      __c2p_tmp1 := (k + 0);
      dst[__c2p_tmp1] := (dst[__c2p_tmp1] * scf[0]);
      __c2p_tmp2 := (k + 576);
      dst[__c2p_tmp2] := (dst[__c2p_tmp2] * scf[3]);
      _L__for1_step:
      k := (k + 1);
    end;
    _L__for0_step:
    i := (i + 1);
    dst := (dst + 18);
    scf := (scf + 6);
  end;
end;

function L3_read_side_info(bs: PBsT; gr: PL3GrInfoT; hdr: PUint8T): LongInt;
label _sw0_do_cond;
var
  tables: LongWord;
  scfsi: LongWord;
  main_data_begin: LongInt;
  part_23_sum: LongInt;
  sr_idx: LongInt;
  gr_count: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp5: LongWord;
  __c2p_tmp2: LongInt;
  __c2p_tmp4: LongInt;
begin
  scfsi := LongWord(0);
  part_23_sum := 0;
  sr_idx := (((LongInt(hdr[2]) shr 2) and 3) + ((((LongInt(hdr[1]) shr 3) and 1) + ((LongInt(hdr[1]) shr 4) and 1)) * 3));
  sr_idx := (sr_idx - LongInt((sr_idx <> 0)));
  if ((LongInt(hdr[3]) and 192) = 192) then
  begin
    __c2p_tmp1 := 1;
  end
  else
  begin
    __c2p_tmp1 := 2;
  end;
  gr_count := __c2p_tmp1;
  if ((LongInt(hdr[1]) and 8) <> 0) then
  begin
    gr_count := (gr_count * 2);
    main_data_begin := LongInt(get_bits(bs, 9));
    scfsi := get_bits(bs, (7 + gr_count));
  end
  else
  begin
    main_data_begin := LongInt((get_bits(bs, (8 + gr_count)) shr gr_count));
  end;
  repeat
    if ((LongInt(hdr[3]) and 192) = 192) then
    begin
      scfsi := (scfsi shl 4);
    end;
    gr^.part_23_length := TUint16T(get_bits(bs, 12));
    part_23_sum := (part_23_sum + gr^.part_23_length);
    gr^.big_values := TUint16T(get_bits(bs, 9));
    if (gr^.big_values > 288) then
    begin
      Result := -1;
      System.Exit;
    end;
    gr^.global_gain := TUint8T(get_bits(bs, 8));
    if ((LongInt(hdr[1]) and 8) <> 0) then
    begin
      __c2p_tmp3 := 4;
    end
    else
    begin
      __c2p_tmp3 := 9;
    end;
    gr^.scalefac_compress := TUint16T(get_bits(bs, __c2p_tmp3));
    gr^.sfbtab := PUint8T(@_static_L3_read_side_info_g_scf_long[sr_idx][0]);
    gr^.n_long_sfb := TUint8T(22);
    gr^.n_short_sfb := TUint8T(0);
    if (get_bits(bs, 1) <> 0) then
    begin
      gr^.block_type := TUint8T(get_bits(bs, 2));
      if (LongInt(gr^.block_type) = 0) then
      begin
        Result := -1;
        System.Exit;
      end;
      gr^.mixed_block_flag := TUint8T(get_bits(bs, 1));
      gr^.region_count[0] := TUint8T(7);
      gr^.region_count[1] := TUint8T(255);
      if (gr^.block_type = 2) then
      begin
        scfsi := (scfsi and LongWord(3855));
        if (LongInt(gr^.mixed_block_flag) = 0) then
        begin
          gr^.region_count[0] := TUint8T(8);
          gr^.sfbtab := PUint8T(@_static_L3_read_side_info_g_scf_short[sr_idx][0]);
          gr^.n_long_sfb := TUint8T(0);
          gr^.n_short_sfb := TUint8T(39);
        end
        else
        begin
          gr^.sfbtab := PUint8T(@_static_L3_read_side_info_g_scf_mixed[sr_idx][0]);
          if ((LongInt(hdr[1]) and 8) <> 0) then
          begin
            __c2p_tmp4 := 8;
          end
          else
          begin
            __c2p_tmp4 := 6;
          end;
          gr^.n_long_sfb := TUint8T(__c2p_tmp4);
          gr^.n_short_sfb := TUint8T(30);
        end;
      end;
      tables := get_bits(bs, 10);
      tables := (tables shl 5);
      gr^.subblock_gain[0] := TUint8T(get_bits(bs, 3));
      gr^.subblock_gain[1] := TUint8T(get_bits(bs, 3));
      gr^.subblock_gain[2] := TUint8T(get_bits(bs, 3));
    end
    else
    begin
      gr^.block_type := TUint8T(0);
      gr^.mixed_block_flag := TUint8T(0);
      tables := get_bits(bs, 15);
      gr^.region_count[0] := TUint8T(get_bits(bs, 4));
      gr^.region_count[1] := TUint8T(get_bits(bs, 3));
      gr^.region_count[2] := TUint8T(255);
    end;
    gr^.table_select[0] := TUint8T((tables shr 10));
    gr^.table_select[1] := TUint8T(((tables shr 5) and LongWord(31)));
    gr^.table_select[2] := TUint8T((tables and LongWord(31)));
    if ((LongInt(hdr[1]) and 8) <> 0) then
    begin
      __c2p_tmp5 := get_bits(bs, 1);
    end
    else
    begin
      __c2p_tmp5 := LongWord(LongInt((gr^.scalefac_compress >= 500)));
    end;
    gr^.preflag := TUint8T(__c2p_tmp5);
    gr^.scalefac_scale := TUint8T(get_bits(bs, 1));
    gr^.count1_table := TUint8T(get_bits(bs, 1));
    gr^.scfsi := TUint8T(((scfsi shr 12) and LongWord(15)));
    scfsi := (scfsi shl 4);
    gr := (gr + 1);
    _sw0_do_cond:
    gr_count := (gr_count - 1);
    __c2p_tmp2 := gr_count;
  until (__c2p_tmp2 = 0);
  if ((part_23_sum + bs^.pos) > (bs^.limit + (main_data_begin * 8))) then
  begin
    Result := -1;
    System.Exit;
  end;
  Result := main_data_begin;
end;

procedure L3_read_scalefactors(scf: PUint8T; ist_pos: PUint8T; scf_size: PUint8T; scf_count: PUint8T; bitbuf: PBsT; scfsi: LongInt);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  k: LongInt;
  cnt: LongInt;
  bits: LongInt;
  max_scf: LongInt;
  s_2: LongInt;
  __c2p_tmp3: TUint8T;
  __c2p_tmp4: TUint8T;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  i := 0;
  while ((i < 4) and (LongInt(scf_count[i]) <> 0)) do
  begin
    cnt := LongInt(scf_count[i]);
    if ((scfsi and 8) <> 0) then
    begin
      __c2p_stdlib_memcpy(scf, ist_pos, TSizeT(cnt));
    end
    else
    begin
      bits := LongInt(scf_size[i]);
      if (bits = 0) then
      begin
        __c2p_stdlib_memset(scf, 0, TSizeT(cnt));
        __c2p_stdlib_memset(ist_pos, 0, TSizeT(cnt));
      end
      else
      begin
        if (scfsi < 0) then
        begin
          __c2p_tmp1 := ((1 shl bits) - 1);
        end
        else
        begin
          __c2p_tmp1 := -1;
        end;
        max_scf := __c2p_tmp1;
        k := 0;
        while (k < cnt) do
        begin
          s_2 := LongInt(get_bits(bitbuf, bits));
          if (s_2 = max_scf) then
          begin
            __c2p_tmp2 := -1;
          end
          else
          begin
            __c2p_tmp2 := s_2;
          end;
          ist_pos[k] := TUint8T(__c2p_tmp2);
          scf[k] := TUint8T(s_2);
          _L__for1_step:
          k := (k + 1);
        end;
      end;
    end;
    ist_pos := (ist_pos + cnt);
    scf := (scf + cnt);
    _L__for0_step:
    i := (i + 1);
    scfsi := (scfsi * 2);
  end;
  __c2p_tmp4 := TUint8T(0);
  scf[2] := __c2p_tmp4;
  __c2p_tmp3 := TUint8T(__c2p_tmp4);
  scf[1] := __c2p_tmp3;
  scf[0] := TUint8T(__c2p_tmp3);
end;

function L3_ldexp_q2(__c2p_arg_y: Single; __c2p_arg_exp_q2: LongInt): Single; inline;
label _sw1_do_cond;
var
  e: LongInt;
  y: Single;
  exp_q2: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp1: LongInt;
begin
  y := __c2p_arg_y;
  exp_q2 := __c2p_arg_exp_q2;
  repeat
    if ((30 * 4) > exp_q2) then
    begin
      __c2p_tmp2 := exp_q2;
    end
    else
    begin
      __c2p_tmp2 := (30 * 4);
    end;
    e := __c2p_tmp2;
    y := (y * (_static_L3_ldexp_q2_g_expfrac[(e and 3)] * SarLongInt((1 shl 30), SarLongInt(e, 2))));
    _sw1_do_cond:
    __c2p_tmp1 := (exp_q2 - e);
    exp_q2 := __c2p_tmp1;
  until ((__c2p_tmp1 > 0) = False);
  Result := y;
end;

procedure L3_decode_scalefactors(hdr: PUint8T; ist_pos: PUint8T; bs: PBsT; gr: PL3GrInfoT; scf: PSingle; ch: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step, _L__for4_step;
var
  scf_partition: PUint8T;
  scf_size: array[0..3] of TUint8T;
  iscf: array[0..39] of TUint8T;
  i: LongInt;
  scf_shift: LongInt;
  gain_exp: LongInt;
  scfsi: LongInt;
  gain: Single;
  part: LongInt;
  k: LongInt;
  modprod: LongInt;
  sfc: LongInt;
  ist: LongInt;
  sh: LongInt;
  __c2p_tmp7: LongInt;
  __c2p_tmp1: TUint8T;
  __c2p_tmp2: TUint8T;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
begin
  scf_partition := PUint8T(@_static_L3_decode_scalefactors_g_scf_partitions[(LongInt((LongInt(gr^.n_short_sfb) <> 0)) + LongInt((LongInt(gr^.n_long_sfb) = 0)))][0]);
  scf_shift := (LongInt(gr^.scalefac_scale) + 1);
  scfsi := LongInt(gr^.scfsi);
  if ((LongInt(hdr[1]) and 8) <> 0) then
  begin
    part := LongInt(_static_L3_decode_scalefactors_g_scfc_decode[LongInt(gr^.scalefac_compress)]);
    __c2p_tmp1 := TUint8T(SarLongInt(part, 2));
    scf_size[0] := __c2p_tmp1;
    scf_size[1] := TUint8T(__c2p_tmp1);
    __c2p_tmp2 := TUint8T((part and 3));
    scf_size[2] := __c2p_tmp2;
    scf_size[3] := TUint8T(__c2p_tmp2);
  end
  else
  begin
    ist := LongInt((((LongInt(hdr[3]) and 16) <> 0) and (ch <> 0)));
    sfc := (LongInt(gr^.scalefac_compress) shr ist);
    k := ((ist * 3) * 4);
    while (sfc >= 0) do
    begin
      modprod := 1;
      i := 3;
      while (i >= 0) do
      begin
        scf_size[i] := TUint8T(((sfc div modprod) mod LongInt(_static_L3_decode_scalefactors_g_mod[(k + i)])));
        modprod := (modprod * _static_L3_decode_scalefactors_g_mod[(k + i)]);
        _L__for1_step:
        i := (i - 1);
      end;
      _L__for0_step:
      sfc := (sfc - modprod);
      k := (k + 4);
    end;
    scf_partition := (scf_partition + k);
    scfsi := -16;
  end;
  L3_read_scalefactors(PUint8T(@iscf[0]), ist_pos, PUint8T(@scf_size[0]), scf_partition, bs, scfsi);
  if (LongInt(gr^.n_short_sfb) <> 0) then
  begin
    sh := (3 - scf_shift);
    i := 0;
    while (i < gr^.n_short_sfb) do
    begin
      __c2p_tmp3 := ((LongInt(gr^.n_long_sfb) + i) + 0);
      iscf[__c2p_tmp3] := TUint8T((iscf[__c2p_tmp3] + (LongInt(gr^.subblock_gain[0]) shl sh)));
      __c2p_tmp4 := ((LongInt(gr^.n_long_sfb) + i) + 1);
      iscf[__c2p_tmp4] := TUint8T((iscf[__c2p_tmp4] + (LongInt(gr^.subblock_gain[1]) shl sh)));
      __c2p_tmp5 := ((LongInt(gr^.n_long_sfb) + i) + 2);
      iscf[__c2p_tmp5] := TUint8T((iscf[__c2p_tmp5] + (LongInt(gr^.subblock_gain[2]) shl sh)));
      _L__for2_step:
      i := (i + 3);
    end;
  end
  else
  begin
    if (LongInt(gr^.preflag) <> 0) then
    begin
      i := 0;
      while (i < 10) do
      begin
        __c2p_tmp6 := (11 + i);
        iscf[__c2p_tmp6] := TUint8T((iscf[__c2p_tmp6] + _static_L3_decode_scalefactors_g_preamp[i]));
        _L__for3_step:
        i := (i + 1);
      end;
    end;
  end;
  if ((LongInt(hdr[3]) and 224) = 96) then
  begin
    __c2p_tmp7 := 2;
  end
  else
  begin
    __c2p_tmp7 := 0;
  end;
  gain_exp := (((LongInt(gr^.global_gain) + (-1 * 4)) - 210) - __c2p_tmp7);
  gain := L3_ldexp_q2((1 shl (((((255 + (-1 * 4)) - 210) + 3) and LongInt(not 3)) div 4)), (((((255 + (-1 * 4)) - 210) + 3) and LongInt(not 3)) - gain_exp));
  i := 0;
  while (i < LongInt((LongInt(gr^.n_long_sfb) + LongInt(gr^.n_short_sfb)))) do
  begin
    scf[i] := L3_ldexp_q2(gain, (LongInt(iscf[i]) shl scf_shift));
    _L__for4_step:
    i := (i + 1);
  end;
end;

function L3_pow_43(x: LongInt): Single;
var
  frac: Single;
  sign: LongInt;
  mult: LongInt;
begin
  mult := 256;
  if (x < 129) then
  begin
    Result := g_pow43[(16 + x)];
    System.Exit;
  end;
  if (x < 1024) then
  begin
    mult := 16;
    x := (x shl 3);
  end;
  sign := ((2 * x) and 64);
  frac := (Single(((x and 63) - sign)) / ((x and LongInt(not 63)) + sign));
  Result := ((g_pow43[(16 + SarLongInt((x + sign), 6))] * (Single(1.0) + (frac * ((Single(4.0) / 3) + (frac * (Single(2.0) / 9)))))) * mult);
end;

procedure L3_huffman(dst: PSingle; bs: PBsT; gr_info: PL3GrInfoT; scf: PSingle; layer3gr_limit: LongInt);
label _sw2_do_cond, _sw3_do_cond, _L__for0_step, _sw4_do_cond, _sw5_do_cond, _L__for1_step, _L__for2_step;
var
  one: Single;
  ireg: LongInt;
  big_val_cnt: LongInt;
  sfb: PUint8T;
  bs_next_ptr: PUint8T;
  bs_cache: TUint32T;
  pairs_to_decode: LongInt;
  np: LongInt;
  bs_sh: LongInt;
  tab_num: LongInt;
  sfb_cnt: LongInt;
  codebook: PInt16T;
  linbits: LongInt;
  j: LongInt;
  w: LongInt;
  leaf: LongInt;
  lsb: LongInt;
  j_2: LongInt;
  w_2: LongInt;
  leaf_2: LongInt;
  lsb_2: LongInt;
  codebook_count1: PUint8T;
  leaf_3: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp5: PUint8T;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: PSingle;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp8: LongInt;
  __c2p_tmp11: LongInt;
  __c2p_tmp12: LongInt;
  __c2p_tmp10: LongInt;
  __c2p_tmp9: PUint8T;
  __c2p_tmp13: PUint8T;
  __c2p_tmp4: LongInt;
  __c2p_tmp17: PUint8T;
  __c2p_tmp18: LongInt;
  __c2p_tmp19: PSingle;
  __c2p_tmp14: LongInt;
  __c2p_tmp15: LongInt;
  __c2p_tmp20: LongInt;
  __c2p_tmp21: LongInt;
  __c2p_tmp22: LongInt;
  __c2p_tmp23: PUint8T;
  __c2p_tmp16: LongInt;
  __c2p_tmp24: PUint8T;
  __c2p_tmp25: LongInt;
  __c2p_tmp30: LongInt;
  __c2p_tmp26: PUint8T;
  __c2p_tmp27: PSingle;
  __c2p_tmp28: Single;
  __c2p_tmp29: Single;
  __c2p_tmp31: PUint8T;
  __c2p_tmp32: PSingle;
  __c2p_tmp33: Single;
  __c2p_tmp34: Single;
  __c2p_tmp35: PUint8T;
begin
  one := Single(0.0);
  ireg := 0;
  big_val_cnt := LongInt(gr_info^.big_values);
  sfb := gr_info^.sfbtab;
  bs_next_ptr := (bs^.buf + (bs^.pos div 8));
  bs_cache := (LongWord((LongWord((LongWord((LongWord((LongWord((LongWord((LongWord(LongInt(bs_next_ptr[0])) * LongWord(256))) + LongInt(bs_next_ptr[1]))) * LongWord(256))) + LongInt(bs_next_ptr[2]))) * LongWord(256))) + LongInt(bs_next_ptr[3]))) shl (bs^.pos and 7));
  bs_sh := ((bs^.pos and 7) - 8);
  bs_next_ptr := (bs_next_ptr + 4);
  while (big_val_cnt > 0) do
  begin
    tab_num := LongInt(gr_info^.table_select[ireg]);
    __c2p_tmp1 := ireg;
    ireg := (ireg + 1);
    sfb_cnt := LongInt(gr_info^.region_count[__c2p_tmp1]);
    codebook := (PInt16T(@_static_L3_huffman_tabs[0]) + LongInt(_static_L3_huffman_tabindex[tab_num]));
    linbits := LongInt(_static_L3_huffman_g_linbits[tab_num]);
    if (linbits <> 0) then
    begin
      repeat
        __c2p_tmp5 := sfb;
        sfb := (sfb + 1);
        np := (LongInt(__c2p_tmp5^) div 2);
        if (big_val_cnt > np) then
        begin
          __c2p_tmp6 := np;
        end
        else
        begin
          __c2p_tmp6 := big_val_cnt;
        end;
        pairs_to_decode := __c2p_tmp6;
        __c2p_tmp7 := scf;
        scf := (scf + 1);
        one := __c2p_tmp7^;
        repeat
          w := 5;
          leaf := LongInt(codebook[(bs_cache shr (32 - w))]);
          while (leaf < 0) do
          begin
            bs_cache := (bs_cache shl w);
            bs_sh := (bs_sh + w);
            w := (leaf and 7);
            leaf := LongInt(codebook[LongWord(((bs_cache shr (32 - w)) - SarLongInt(leaf, 3)))]);
          end;
          bs_cache := (bs_cache shl SarLongInt(leaf, 8));
          bs_sh := (bs_sh + SarLongInt(leaf, 8));
          j := 0;
          while (j < 2) do
          begin
            lsb := (leaf and 15);
            if (lsb = 15) then
            begin
              lsb := LongInt((LongWord(lsb) + (bs_cache shr (32 - linbits))));
              bs_cache := (bs_cache shl linbits);
              bs_sh := (bs_sh + linbits);
              while (bs_sh >= 0) do
              begin
                __c2p_tmp9 := bs_next_ptr;
                bs_next_ptr := (bs_next_ptr + 1);
                bs_cache := (bs_cache or (TUint32T(__c2p_tmp9^) shl bs_sh));
                bs_sh := (bs_sh - 8);
              end;
              if (TInt32T(bs_cache) < 0) then
              begin
                __c2p_tmp10 := -1;
              end
              else
              begin
                __c2p_tmp10 := 1;
              end;
              dst^ := ((one * L3_pow_43(lsb)) * __c2p_tmp10);
            end
            else
            begin
              dst^ := (g_pow43[LongWord(((16 + lsb) - LongWord((LongWord(16) * (bs_cache shr 31)))))] * one);
            end;
            if (lsb <> 0) then
            begin
              __c2p_tmp11 := 1;
            end
            else
            begin
              __c2p_tmp11 := 0;
            end;
            bs_cache := (bs_cache shl __c2p_tmp11);
            if (lsb <> 0) then
            begin
              __c2p_tmp12 := 1;
            end
            else
            begin
              __c2p_tmp12 := 0;
            end;
            bs_sh := (bs_sh + __c2p_tmp12);
            _L__for0_step:
            j := (j + 1);
            dst := (dst + 1);
            leaf := SarLongInt(leaf, 4);
          end;
          while (bs_sh >= 0) do
          begin
            __c2p_tmp13 := bs_next_ptr;
            bs_next_ptr := (bs_next_ptr + 1);
            bs_cache := (bs_cache or (TUint32T(__c2p_tmp13^) shl bs_sh));
            bs_sh := (bs_sh - 8);
          end;
          _sw3_do_cond:
          pairs_to_decode := (pairs_to_decode - 1);
          __c2p_tmp8 := pairs_to_decode;
        until (__c2p_tmp8 = 0);
        _sw2_do_cond:
        __c2p_tmp2 := LongInt(0);
        __c2p_tmp3 := (big_val_cnt - np);
        big_val_cnt := __c2p_tmp3;
        if (__c2p_tmp3 > 0) then
        begin
          sfb_cnt := (sfb_cnt - 1);
          __c2p_tmp4 := sfb_cnt;
          __c2p_tmp2 := LongInt((__c2p_tmp4 >= 0));
        end;
      until (__c2p_tmp2 = 0);
    end
    else
    begin
      repeat
        __c2p_tmp17 := sfb;
        sfb := (sfb + 1);
        np := (LongInt(__c2p_tmp17^) div 2);
        if (big_val_cnt > np) then
        begin
          __c2p_tmp18 := np;
        end
        else
        begin
          __c2p_tmp18 := big_val_cnt;
        end;
        pairs_to_decode := __c2p_tmp18;
        __c2p_tmp19 := scf;
        scf := (scf + 1);
        one := __c2p_tmp19^;
        repeat
          w_2 := 5;
          leaf_2 := LongInt(codebook[(bs_cache shr (32 - w_2))]);
          while (leaf_2 < 0) do
          begin
            bs_cache := (bs_cache shl w_2);
            bs_sh := (bs_sh + w_2);
            w_2 := (leaf_2 and 7);
            leaf_2 := LongInt(codebook[LongWord(((bs_cache shr (32 - w_2)) - SarLongInt(leaf_2, 3)))]);
          end;
          bs_cache := (bs_cache shl SarLongInt(leaf_2, 8));
          bs_sh := (bs_sh + SarLongInt(leaf_2, 8));
          j_2 := 0;
          while (j_2 < 2) do
          begin
            lsb_2 := (leaf_2 and 15);
            dst^ := (g_pow43[LongWord(((16 + lsb_2) - LongWord((LongWord(16) * (bs_cache shr 31)))))] * one);
            if (lsb_2 <> 0) then
            begin
              __c2p_tmp21 := 1;
            end
            else
            begin
              __c2p_tmp21 := 0;
            end;
            bs_cache := (bs_cache shl __c2p_tmp21);
            if (lsb_2 <> 0) then
            begin
              __c2p_tmp22 := 1;
            end
            else
            begin
              __c2p_tmp22 := 0;
            end;
            bs_sh := (bs_sh + __c2p_tmp22);
            _L__for1_step:
            j_2 := (j_2 + 1);
            dst := (dst + 1);
            leaf_2 := SarLongInt(leaf_2, 4);
          end;
          while (bs_sh >= 0) do
          begin
            __c2p_tmp23 := bs_next_ptr;
            bs_next_ptr := (bs_next_ptr + 1);
            bs_cache := (bs_cache or (TUint32T(__c2p_tmp23^) shl bs_sh));
            bs_sh := (bs_sh - 8);
          end;
          _sw5_do_cond:
          pairs_to_decode := (pairs_to_decode - 1);
          __c2p_tmp20 := pairs_to_decode;
        until (__c2p_tmp20 = 0);
        _sw4_do_cond:
        __c2p_tmp14 := LongInt(0);
        __c2p_tmp15 := (big_val_cnt - np);
        big_val_cnt := __c2p_tmp15;
        if (__c2p_tmp15 > 0) then
        begin
          sfb_cnt := (sfb_cnt - 1);
          __c2p_tmp16 := sfb_cnt;
          __c2p_tmp14 := LongInt((__c2p_tmp16 >= 0));
        end;
      until (__c2p_tmp14 = 0);
    end;
  end;
  np := (1 - big_val_cnt);
  while True do
  begin
    if (LongInt(gr_info^.count1_table) <> 0) then
    begin
      __c2p_tmp24 := PUint8T(@_static_L3_huffman_tab33[0]);
    end
    else
    begin
      __c2p_tmp24 := PUint8T(@_static_L3_huffman_tab32[0]);
    end;
    codebook_count1 := __c2p_tmp24;
    leaf_3 := LongInt(codebook_count1[(bs_cache shr (32 - 4))]);
    if ((leaf_3 and 8) = 0) then
    begin
      leaf_3 := LongInt(codebook_count1[LongWord((SarLongInt(leaf_3, 3) + ((bs_cache shl 4) shr (32 - (leaf_3 and 3)))))]);
    end;
    bs_cache := (bs_cache shl (leaf_3 and 7));
    bs_sh := (bs_sh + (leaf_3 and 7));
    if ((((Int64((Int64(PtrUInt(bs_next_ptr) - PtrUInt(bs^.buf)))) * Int64(8)) - Int64(24)) + Int64(bs_sh)) > Int64(layer3gr_limit)) then
    begin
      Break;
    end;
    np := (np - 1);
    __c2p_tmp25 := np;
    if (__c2p_tmp25 = 0) then
    begin
      __c2p_tmp26 := sfb;
      sfb := (sfb + 1);
      np := (LongInt(__c2p_tmp26^) div 2);
      if (np = 0) then
      begin
        Break;
      end;
      __c2p_tmp27 := scf;
      scf := (scf + 1);
      one := __c2p_tmp27^;
    end;
    if ((leaf_3 and SarLongInt(128, 0)) <> 0) then
    begin
      if (TInt32T(bs_cache) < 0) then
      begin
        __c2p_tmp28 := -one;
      end
      else
      begin
        __c2p_tmp28 := one;
      end;
      dst[0] := __c2p_tmp28;
      bs_cache := (bs_cache shl 1);
      bs_sh := (bs_sh + 1);
    end;
    if ((leaf_3 and SarLongInt(128, 1)) <> 0) then
    begin
      if (TInt32T(bs_cache) < 0) then
      begin
        __c2p_tmp29 := -one;
      end
      else
      begin
        __c2p_tmp29 := one;
      end;
      dst[1] := __c2p_tmp29;
      bs_cache := (bs_cache shl 1);
      bs_sh := (bs_sh + 1);
    end;
    np := (np - 1);
    __c2p_tmp30 := np;
    if (__c2p_tmp30 = 0) then
    begin
      __c2p_tmp31 := sfb;
      sfb := (sfb + 1);
      np := (LongInt(__c2p_tmp31^) div 2);
      if (np = 0) then
      begin
        Break;
      end;
      __c2p_tmp32 := scf;
      scf := (scf + 1);
      one := __c2p_tmp32^;
    end;
    if ((leaf_3 and SarLongInt(128, 2)) <> 0) then
    begin
      if (TInt32T(bs_cache) < 0) then
      begin
        __c2p_tmp33 := -one;
      end
      else
      begin
        __c2p_tmp33 := one;
      end;
      dst[2] := __c2p_tmp33;
      bs_cache := (bs_cache shl 1);
      bs_sh := (bs_sh + 1);
    end;
    if ((leaf_3 and SarLongInt(128, 3)) <> 0) then
    begin
      if (TInt32T(bs_cache) < 0) then
      begin
        __c2p_tmp34 := -one;
      end
      else
      begin
        __c2p_tmp34 := one;
      end;
      dst[3] := __c2p_tmp34;
      bs_cache := (bs_cache shl 1);
      bs_sh := (bs_sh + 1);
    end;
    while (bs_sh >= 0) do
    begin
      __c2p_tmp35 := bs_next_ptr;
      bs_next_ptr := (bs_next_ptr + 1);
      bs_cache := (bs_cache or (TUint32T(__c2p_tmp35^) shl bs_sh));
      bs_sh := (bs_sh - 8);
    end;
    _L__for2_step:
    dst := (dst + 4);
  end;
  bs^.pos := layer3gr_limit;
end;

procedure L3_midside_stereo(left: PSingle; n: LongInt); inline;
label _L__for0_step;
var
  i: LongInt;
  right: PSingle;
  a: Single;
  b: Single;
begin
  i := 0;
  right := (left + 576);
  while (i < n) do
  begin
    a := left[i];
    b := right[i];
    left[i] := (a + b);
    right[i] := (a - b);
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L3_intensity_stereo_band(left: PSingle; n: LongInt; kl: Single; kr: Single);
label _L__for0_step;
var
  i: LongInt;
begin
  i := 0;
  while (i < n) do
  begin
    left[(i + 576)] := (left[i] * kr);
    left[i] := (left[i] * kl);
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L3_stereo_top_band(__c2p_arg_right: PSingle; sfb: PUint8T; nbands: LongInt; max_band: PLongInt); inline;
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  k: LongInt;
  right: PSingle;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
begin
  right := __c2p_arg_right;
  __c2p_tmp2 := -1;
  max_band[2] := __c2p_tmp2;
  __c2p_tmp1 := __c2p_tmp2;
  max_band[1] := __c2p_tmp1;
  max_band[0] := __c2p_tmp1;
  i := 0;
  while (i < nbands) do
  begin
    k := 0;
    while (k < sfb[i]) do
    begin
      if ((right[k] <> 0) or (right[(k + 1)] <> 0)) then
      begin
        max_band[(i mod 3)] := i;
        Break;
      end;
      _L__for1_step:
      k := (k + 2);
    end;
    right := (right + sfb[i]);
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L3_stereo_process(__c2p_arg_left: PSingle; ist_pos: PUint8T; sfb: PUint8T; hdr: PUint8T; max_band: PLongInt; mpeg2_sh: LongInt); inline;
label _L__for0_step;
var
  i: LongWord;
  max_pos: LongWord;
  ipos: LongWord;
  kl: Single;
  kr: Single;
  s_2: Single;
  left: PSingle;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: Single;
begin
  left := __c2p_arg_left;
  if ((LongInt(hdr[1]) and 8) <> 0) then
  begin
    __c2p_tmp1 := 7;
  end
  else
  begin
    __c2p_tmp1 := 64;
  end;
  max_pos := LongWord(__c2p_tmp1);
  i := LongWord(0);
  while (LongInt(sfb[i]) <> 0) do
  begin
    ipos := LongWord(ist_pos[i]);
    if ((LongInt(i) > max_band[(i mod LongWord(3))]) and (ipos < max_pos)) then
    begin
      if ((LongInt(hdr[3]) and 32) <> 0) then
      begin
        __c2p_tmp2 := Single(1.41421356);
      end
      else
      begin
        __c2p_tmp2 := 1;
      end;
      s_2 := __c2p_tmp2;
      if ((LongInt(hdr[1]) and 8) <> 0) then
      begin
        kl := _static_L3_stereo_process_g_pan[LongWord((LongWord(2) * ipos))];
        kr := _static_L3_stereo_process_g_pan[LongWord((LongWord((LongWord(2) * ipos)) + 1))];
      end
      else
      begin
        kl := 1;
        kr := L3_ldexp_q2(1, LongInt(((LongWord((ipos + 1)) shr 1) shl mpeg2_sh)));
        if ((ipos and LongWord(1)) <> 0) then
        begin
          kl := kr;
          kr := 1;
        end;
      end;
      L3_intensity_stereo_band(left, LongInt(sfb[i]), (kl * s_2), (kr * s_2));
    end
    else
    begin
      if ((LongInt(hdr[3]) and 32) <> 0) then
      begin
        L3_midside_stereo(left, LongInt(sfb[i]));
      end;
    end;
    left := (left + sfb[i]);
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L3_intensity_stereo(left: PSingle; ist_pos: PUint8T; gr: PL3GrInfoT; hdr: PUint8T); inline;
label _L__for0_step;
var
  max_band: array[0..2] of LongInt;
  n_sfb: LongInt;
  i: LongInt;
  max_blocks: LongInt;
  default_pos: LongInt;
  itop: LongInt;
  prev: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
  __c2p_tmp7: LongInt;
  __c2p_tmp8: LongInt;
begin
  n_sfb := (LongInt(gr^.n_long_sfb) + LongInt(gr^.n_short_sfb));
  if (LongInt(gr^.n_short_sfb) <> 0) then
  begin
    __c2p_tmp1 := 3;
  end
  else
  begin
    __c2p_tmp1 := 1;
  end;
  max_blocks := __c2p_tmp1;
  L3_stereo_top_band((left + 576), gr^.sfbtab, n_sfb, PLongInt(@max_band[0]));
  if (LongInt(gr^.n_long_sfb) <> 0) then
  begin
    if (max_band[0] < max_band[1]) then
    begin
      __c2p_tmp5 := max_band[1];
    end
    else
    begin
      __c2p_tmp5 := max_band[0];
    end;
    if (__c2p_tmp5 < max_band[2]) then
    begin
      __c2p_tmp4 := max_band[2];
    end
    else
    begin
      if (max_band[0] < max_band[1]) then
      begin
        __c2p_tmp6 := max_band[1];
      end
      else
      begin
        __c2p_tmp6 := max_band[0];
      end;
      __c2p_tmp4 := __c2p_tmp6;
    end;
    __c2p_tmp3 := __c2p_tmp4;
    max_band[2] := __c2p_tmp3;
    __c2p_tmp2 := __c2p_tmp3;
    max_band[1] := __c2p_tmp2;
    max_band[0] := __c2p_tmp2;
  end;
  i := 0;
  while (i < max_blocks) do
  begin
    if ((LongInt(hdr[1]) and 8) <> 0) then
    begin
      __c2p_tmp7 := 3;
    end
    else
    begin
      __c2p_tmp7 := 0;
    end;
    default_pos := __c2p_tmp7;
    itop := ((n_sfb - max_blocks) + i);
    prev := (itop - max_blocks);
    if (max_band[i] >= prev) then
    begin
      __c2p_tmp8 := default_pos;
    end
    else
    begin
      __c2p_tmp8 := LongInt(ist_pos[prev]);
    end;
    ist_pos[itop] := TUint8T(__c2p_tmp8);
    _L__for0_step:
    i := (i + 1);
  end;
  L3_stereo_process(left, ist_pos, gr^.sfbtab, hdr, PLongInt(@max_band[0]), (LongInt(gr[1].scalefac_compress) and 1));
end;

procedure L3_reorder(grbuf: PSingle; scratch_2: PSingle; sfb: PUint8T);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  len: LongInt;
  src: PSingle;
  dst: PSingle;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: PSingle;
  __c2p_tmp3: PSingle;
  __c2p_tmp4: PSingle;
begin
  src := grbuf;
  dst := scratch_2;
  while True do
  begin
    __c2p_tmp1 := LongInt(sfb^);
    len := __c2p_tmp1;
    if (0 = __c2p_tmp1) then
    begin
      Break;
    end;
    i := 0;
    while (i < len) do
    begin
      __c2p_tmp2 := dst;
      dst := (dst + 1);
      __c2p_tmp2^ := src[(0 * len)];
      __c2p_tmp3 := dst;
      dst := (dst + 1);
      __c2p_tmp3^ := src[(1 * len)];
      __c2p_tmp4 := dst;
      dst := (dst + 1);
      __c2p_tmp4^ := src[(2 * len)];
      _L__for1_step:
      i := (i + 1);
      src := (src + 1);
    end;
    _L__for0_step:
    sfb := (sfb + 3);
    src := (src + (2 * len));
  end;
  __c2p_stdlib_memcpy(grbuf, scratch_2, TSizeT(QWord((QWord(Int64(((Int64(PtrUInt(dst) - PtrUInt(scratch_2))) div 4))) * 4))));
end;

const
  { antialias SSE 常量（g_aa 两行按 4 车道分组，x86 侧直取） }
  AA_0A: array[0..3] of Single = (0.85749293,0.88174200,0.94962865,0.98331459);
  AA_0B: array[0..3] of Single = (0.99551782,0.99916056,0.99989920,0.99999316);
  AA_1A: array[0..3] of Single = (0.51449576,0.47173197,0.31337745,0.18191320);
  AA_1B: array[0..3] of Single = (0.09457419,0.04096558,0.01419856,0.00369997);

{$ifdef MP3DEC_SIMD_ON}
{$ifdef cpux86_64}
procedure L3_antialias(grbuf: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  u: Single;
  d: Single;
begin
  while (nbands > 0) do
  begin

    asm
      movq    grbuf, %r10
      movups  AA_0A(%rip), %xmm12
      movups  AA_1A(%rip), %xmm13
      movups  AA_0B(%rip), %xmm14
      movups  AA_1B(%rip), %xmm15
{ 组 0：i=0..3 }
      movups  72(%r10), %xmm0            { vu }
      movups  56(%r10), %xmm1            { [d0..d3] 升序 }
      pshufd $27, %xmm1, %xmm1           { 反转 → [d3,d2,d1,d0] }
      movaps  %xmm0, %xmm2
      mulps   %xmm12, %xmm2
      movaps  %xmm1, %xmm3
      mulps   %xmm13, %xmm3
      subps   %xmm3, %xmm2               { u*c0 - d*c1 }
      movups  %xmm2, 72(%r10)
      movaps  %xmm0, %xmm2
      mulps   %xmm13, %xmm2
      movaps  %xmm1, %xmm3
      mulps   %xmm12, %xmm3
      addps   %xmm3, %xmm2               { u*c1 + d*c0 }
      pshufd $27, %xmm2, %xmm2
      movups  %xmm2, 56(%r10)
{ 组 1：i=4..7 }
      movups  88(%r10), %xmm0
      movups  40(%r10), %xmm1
      pshufd $27, %xmm1, %xmm1
      movaps  %xmm0, %xmm2
      mulps   %xmm14, %xmm2
      movaps  %xmm1, %xmm3
      mulps   %xmm15, %xmm3
      subps   %xmm3, %xmm2
      movups  %xmm2, 88(%r10)
      movaps  %xmm0, %xmm2
      mulps   %xmm15, %xmm2
      movaps  %xmm1, %xmm3
      mulps   %xmm14, %xmm3
      addps   %xmm3, %xmm2
      pshufd $27, %xmm2, %xmm2
      movups  %xmm2, 40(%r10)
    end;
    _L__for0_step:
    nbands := (nbands - 1);
    grbuf := (grbuf + 18);
  end;
end;
{$endif cpux86_64}
{$ifdef cpuaarch64}
procedure L3_antialias(grbuf: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step;
var
  i: LongInt; u, d: Single;
begin
  if AudioUseNeon then
  begin
    mp3d_antialias_neon(grbuf, @_static_L3_antialias_g_aa[0][0], @_static_L3_antialias_g_aa[1][0], nbands);
    Exit;
  end;
  while (nbands > 0) do
  begin
    i := 0;
    while (i < 8) do
    begin
      u := grbuf[(18 + i)];
      d := grbuf[(17 - i)];
      grbuf[(18 + i)] := ((u * _static_L3_antialias_g_aa[0][i]) - (d * _static_L3_antialias_g_aa[1][i]));
      grbuf[(17 - i)] := ((u * _static_L3_antialias_g_aa[1][i]) + (d * _static_L3_antialias_g_aa[0][i]));
      _L__for1_step:
      i := (i + 1);
    end;
    _L__for0_step:
    nbands := (nbands - 1);
    grbuf := (grbuf + 18);
  end;
end;
{$endif cpuaarch64}
{$else}
procedure L3_antialias(grbuf: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  u: Single;
  d: Single;
begin
  while (nbands > 0) do
  begin
    i := 0;
    while (i < 8) do
    begin
      u := grbuf[(18 + i)];
      d := grbuf[(17 - i)];
      grbuf[(18 + i)] := ((u * _static_L3_antialias_g_aa[0][i]) - (d * _static_L3_antialias_g_aa[1][i]));
      grbuf[(17 - i)] := ((u * _static_L3_antialias_g_aa[1][i]) + (d * _static_L3_antialias_g_aa[0][i]));
      _L__for1_step:
      i := (i + 1);
    end;
    _L__for0_step:
    nbands := (nbands - 1);
    grbuf := (grbuf + 18);
  end;
end;
{$endif MP3DEC_SIMD_ON}

procedure L3_dct3_9(y: PSingle);
var
  s0: Single;
  s1: Single;
  s2: Single;
  s3: Single;
  s4: Single;
  s5: Single;
  s6: Single;
  s7: Single;
  s8: Single;
  t0: Single;
  t2: Single;
  t4: Single;
begin
  s0 := y[0];
  s2 := y[2];
  s4 := y[4];
  s6 := y[6];
  s8 := y[8];
  t0 := (s0 + (s6 * Single(0.5)));
  s0 := (s0 - s6);
  t4 := ((s4 + s2) * Single(0.93969262));
  t2 := ((s8 + s2) * Single(0.76604444));
  s6 := ((s4 - s8) * Single(0.17364818));
  s4 := (s4 + (s8 - s2));
  s2 := (s0 - (s4 * Single(0.5)));
  y[4] := (s4 + s0);
  s8 := ((t0 - t2) + s6);
  s0 := ((t0 - t4) + t2);
  s4 := ((t0 + t4) - s6);
  s1 := y[1];
  s3 := y[3];
  s5 := y[5];
  s7 := y[7];
  s3 := (s3 * Single(0.86602540));
  t0 := ((s5 + s1) * Single(0.98480775));
  t4 := ((s5 - s7) * Single(0.34202014));
  t2 := ((s1 + s7) * Single(0.64278761));
  s1 := (((s1 - s5) - s7) * Single(0.86602540));
  s5 := ((t0 - s3) - t2);
  s7 := ((t4 - s3) - t0);
  s3 := ((t4 + s3) - t2);
  y[0] := (s4 - s7);
  y[1] := (s2 + s1);
  y[2] := (s0 - s3);
  y[3] := (s8 + s5);
  y[5] := (s8 - s5);
  y[6] := (s0 + s3);
  y[7] := (s2 - s1);
  y[8] := (s4 + s7);
end;

{$if defined(MP3DEC_SIMD_ON) and defined(cpux86_64)}
procedure L3_imdct36(grbuf: PSingle; overlap: PSingle; window: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  i: LongInt;
  j: LongInt;
  co: array[0..8] of Single;
  si: array[0..8] of Single;
  ovl: Single;
  sum: Single;
  pco: PSingle;
  psi: PSingle;
begin
  j := 0;
  while (j < nbands) do
  begin
    co[0] := -grbuf[0];
    si[0] := grbuf[17];
    i := 0;
    while (i < 4) do
    begin
      si[(8 - (2 * i))] := (grbuf[((4 * i) + 1)] - grbuf[((4 * i) + 2)]);
      co[(1 + (2 * i))] := (grbuf[((4 * i) + 1)] + grbuf[((4 * i) + 2)]);
      si[(7 - (2 * i))] := (grbuf[((4 * i) + 4)] - grbuf[((4 * i) + 3)]);
      co[(2 + (2 * i))] := -(grbuf[((4 * i) + 3)] + grbuf[((4 * i) + 4)]);
      _L__for1_step:
      i := (i + 1);
    end;
    L3_dct3_9(PSingle(@co[0]));
    L3_dct3_9(PSingle(@si[0]));
    si[1] := -si[1];
    si[3] := -si[3];
    si[5] := -si[5];
    si[7] := -si[7];
    { SSE combine：车道 = 连续 i，结合顺序与标量一致（位精确） }
    pco := PSingle(@co[0]);
    psi := PSingle(@si[0]);
    asm
      movq    pco, %r10
      movq    psi, %r11
{ 组 0：i=0..3 }
      movups  (%r10), %xmm0              { co }
      movups  (%r11), %xmm1              { si }
      movups  _static_L3_imdct36_g_twid9(%rip), %xmm2      { tw[0..3] }
      movups  _static_L3_imdct36_g_twid9+36(%rip), %xmm3   { tw[9..12] }
      movaps  %xmm0, %xmm4
      mulps   %xmm3, %xmm4               { co*tw9 }
      movaps  %xmm1, %xmm5
      mulps   %xmm2, %xmm5               { si*tw0 }
      movaps  %xmm4, %xmm6
      addps   %xmm5, %xmm6               { sum }
      movaps  %xmm0, %xmm7
      mulps   %xmm2, %xmm7               { co*tw0 }
      movaps  %xmm1, %xmm5
      mulps   %xmm3, %xmm5               { si*tw9 }
      subps   %xmm5, %xmm7               { ov = co*tw0 - si*tw9 }
      movq    overlap, %rax
      movups  (%rax), %xmm1              { ovl }
      movups  %xmm7, 0(%rax)
      movq    window, %rcx
      movq    grbuf, %r9
      movups  (%rcx), %xmm2              { w[0..3] }
      movups  36(%rcx), %xmm3            { w[9..12] }
      movaps  %xmm1, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm6, %xmm7
      mulps   %xmm3, %xmm7
      subps   %xmm7, %xmm5               { ovl*w0 - sum*w9 }
      movups  %xmm5, 0(%r9)
      movaps  %xmm1, %xmm5
      mulps   %xmm3, %xmm5
      movaps  %xmm6, %xmm7
      mulps   %xmm2, %xmm7
      addps   %xmm7, %xmm5               { ovl*w9 + sum*w0 }
      pshufd  $27, %xmm5, %xmm5
      movups  %xmm5, 56(%r9)             { slots 14..17 ← 反转 }
{ 组 1：i=4..7 }
      movups  16(%r10), %xmm0            { co+4 }
      movups  16(%r11), %xmm1            { si+4 }
      leaq    _static_L3_imdct36_g_twid9(%rip), %rsi
      movups  16(%rsi), %xmm2            { tw[4..7] }
      movups  52(%rsi), %xmm3            { tw[13..16] }
      movaps  %xmm0, %xmm4
      mulps   %xmm3, %xmm4
      movaps  %xmm1, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm6
      addps   %xmm5, %xmm6               { sum }
      movaps  %xmm0, %xmm7
      mulps   %xmm2, %xmm7
      movaps  %xmm1, %xmm8
      mulps   %xmm3, %xmm8
      subps   %xmm8, %xmm7
      movq    overlap, %rax
      movups  16(%rax), %xmm1
      movups  %xmm7, 16(%rax)
      movq    window, %rcx
      movups  16(%rcx), %xmm2
      movups  52(%rcx), %xmm3
      movaps  %xmm1, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm6, %xmm7
      mulps   %xmm3, %xmm7
      subps   %xmm7, %xmm5
      movups  %xmm5, 16(%r9)
      movaps  %xmm1, %xmm5
      mulps   %xmm3, %xmm5
      movaps  %xmm6, %xmm7
      mulps   %xmm2, %xmm7
      addps   %xmm7, %xmm5
      pshufd  $27, %xmm5, %xmm5
      movups  %xmm5, 40(%r9)             { slots 10..13 }
    end;
    { 尾部 i=8（标量） }
    ovl := overlap[8];
    sum := ((co[8] * _static_L3_imdct36_g_twid9[17]) + (si[8] * _static_L3_imdct36_g_twid9[8]));
    overlap[8] := ((co[8] * _static_L3_imdct36_g_twid9[8]) - (si[8] * _static_L3_imdct36_g_twid9[17]));
    grbuf[8] := ((ovl * window[8]) - (sum * window[17]));
    grbuf[9] := ((ovl * window[17]) + (sum * window[8]));
    _L__for0_step:
    j := (j + 1);
    grbuf := (grbuf + 18);
    overlap := (overlap + 9);
  end;
end;
{$elseif defined(MP3DEC_SIMD_ON) and defined(cpuaarch64)}
procedure L3_imdct36(grbuf: PSingle; overlap: PSingle; window: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  j: LongInt;
  co: array[0..8] of Single;
  si: array[0..8] of Single;
begin
  j := 0;
  while (j < nbands) do
  begin
    co[0] := -grbuf[0];
    si[0] := grbuf[17];
    i := 0;
    while (i < 4) do
    begin
      si[(8 - (2 * i))] := (grbuf[((4 * i) + 1)] - grbuf[((4 * i) + 2)]);
      co[(1 + (2 * i))] := (grbuf[((4 * i) + 1)] + grbuf[((4 * i) + 2)]);
      si[(7 - (2 * i))] := (grbuf[((4 * i) + 4)] - grbuf[((4 * i) + 3)]);
      co[(2 + (2 * i))] := -(grbuf[((4 * i) + 3)] + grbuf[((4 * i) + 4)]);
      _L__for1_step:
      i := (i + 1);
    end;
    L3_dct3_9(PSingle(@co[0]));
    L3_dct3_9(PSingle(@si[0]));
    si[1] := -si[1];
    si[3] := -si[3];
    si[5] := -si[5];
    si[7] := -si[7];
    mp3d_imdct36_combine_neon(@co[0], @si[0], overlap, window, grbuf, @_static_L3_imdct36_g_twid9[0]);
    _L__for0_step:
    j := (j + 1);
    grbuf := (grbuf + 18);
    overlap := (overlap + 9);
  end;
end;
{$else}
procedure L3_imdct36(grbuf: PSingle; overlap: PSingle; window: PSingle; nbands: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  i: LongInt;
  j: LongInt;
  co: array[0..8] of Single;
  si: array[0..8] of Single;
  ovl: Single;
  sum: Single;
begin
  j := 0;
  while (j < nbands) do
  begin
    co[0] := -grbuf[0];
    si[0] := grbuf[17];
    i := 0;
    while (i < 4) do
    begin
      si[(8 - (2 * i))] := (grbuf[((4 * i) + 1)] - grbuf[((4 * i) + 2)]);
      co[(1 + (2 * i))] := (grbuf[((4 * i) + 1)] + grbuf[((4 * i) + 2)]);
      si[(7 - (2 * i))] := (grbuf[((4 * i) + 4)] - grbuf[((4 * i) + 3)]);
      co[(2 + (2 * i))] := -(grbuf[((4 * i) + 3)] + grbuf[((4 * i) + 4)]);
      _L__for1_step:
      i := (i + 1);
    end;
    L3_dct3_9(PSingle(@co[0]));
    L3_dct3_9(PSingle(@si[0]));
    si[1] := -si[1];
    si[3] := -si[3];
    si[5] := -si[5];
    si[7] := -si[7];
    i := 0;
    while (i < 9) do
    begin
      ovl := overlap[i];
      sum := ((co[i] * _static_L3_imdct36_g_twid9[(9 + i)]) + (si[i] * _static_L3_imdct36_g_twid9[(0 + i)]));
      overlap[i] := ((co[i] * _static_L3_imdct36_g_twid9[(0 + i)]) - (si[i] * _static_L3_imdct36_g_twid9[(9 + i)]));
      grbuf[i] := ((ovl * window[(0 + i)]) - (sum * window[(9 + i)]));
      grbuf[(17 - i)] := ((ovl * window[(9 + i)]) + (sum * window[(0 + i)]));
      _L__for2_step:
      i := (i + 1);
    end;
    _L__for0_step:
    j := (j + 1);
    grbuf := (grbuf + 18);
    overlap := (overlap + 9);
  end;
end;
{$endif MP3DEC_SIMD_ON}

procedure L3_idct3(x0: Single; x1: Single; x2: Single; dst: PSingle);
var
  m1: Single;
  a1: Single;
begin
  m1 := (x1 * Single(0.86602540));
  a1 := (x0 - (x2 * Single(0.5)));
  dst[1] := (x0 + x2);
  dst[0] := (a1 + m1);
  dst[2] := (a1 - m1);
end;

procedure L3_imdct12(x: PSingle; dst: PSingle; overlap: PSingle);
label _L__for0_step;
var
  co: array[0..2] of Single;
  si: array[0..2] of Single;
  i: LongInt;
  ovl: Single;
  sum: Single;
begin
  L3_idct3(-x[0], (x[6] + x[3]), (x[12] + x[9]), PSingle(@co[0]));
  L3_idct3(x[15], (x[12] - x[9]), (x[6] - x[3]), PSingle(@si[0]));
  si[1] := -si[1];
  i := 0;
  while (i < 3) do
  begin
    ovl := overlap[i];
    sum := ((co[i] * _static_L3_imdct12_g_twid3[(3 + i)]) + (si[i] * _static_L3_imdct12_g_twid3[(0 + i)]));
    overlap[i] := ((co[i] * _static_L3_imdct12_g_twid3[(0 + i)]) - (si[i] * _static_L3_imdct12_g_twid3[(3 + i)]));
    dst[i] := ((ovl * _static_L3_imdct12_g_twid3[(2 - i)]) - (sum * _static_L3_imdct12_g_twid3[(5 - i)]));
    dst[(5 - i)] := ((ovl * _static_L3_imdct12_g_twid3[(5 - i)]) + (sum * _static_L3_imdct12_g_twid3[(2 - i)]));
    _L__for0_step:
    i := (i + 1);
  end;
end;

procedure L3_imdct_short(__c2p_arg_grbuf: PSingle; __c2p_arg_overlap: PSingle; __c2p_arg_nbands: LongInt); inline;
label _L__for0_step;
var
  tmp: array[0..17] of Single;
  grbuf: PSingle;
  overlap: PSingle;
  nbands: LongInt;
begin
  grbuf := __c2p_arg_grbuf;
  overlap := __c2p_arg_overlap;
  nbands := __c2p_arg_nbands;
  while (nbands > 0) do
  begin
    __c2p_stdlib_memcpy(Pointer(@tmp[0]), grbuf, TSizeT(72));
    __c2p_stdlib_memcpy(grbuf, overlap, TSizeT(QWord((QWord(6) * 4))));
    L3_imdct12(PSingle(@tmp[0]), (grbuf + 6), (overlap + 6));
    L3_imdct12((PSingle(@tmp[0]) + 1), (grbuf + 12), (overlap + 6));
    L3_imdct12((PSingle(@tmp[0]) + 2), overlap, (overlap + 6));
    _L__for0_step:
    nbands := (nbands - 1);
    overlap := (overlap + 9);
    grbuf := (grbuf + 18);
  end;
end;

procedure L3_change_sign(__c2p_arg_grbuf: PSingle); inline;
label _L__for0_step, _L__for1_step;
var
  b: LongInt;
  i: LongInt;
  grbuf: PSingle;
begin
  grbuf := __c2p_arg_grbuf;
  b := 0;
  grbuf := (grbuf + 18);
  while (b < 32) do
  begin
    i := 1;
    while (i < 18) do
    begin
      grbuf[i] := -grbuf[i];
      _L__for1_step:
      i := (i + 2);
    end;
    _L__for0_step:
    b := (b + 2);
    grbuf := (grbuf + 36);
  end;
end;

procedure L3_imdct_gr(grbuf: PSingle; overlap: PSingle; block_type: LongWord; n_long_bands: LongWord);
begin
  if (n_long_bands <> 0) then
  begin
    L3_imdct36(grbuf, overlap, PSingle(@_static_L3_imdct_gr_g_mdct_window[0][0]), LongInt(n_long_bands));
    grbuf := (grbuf + LongWord((LongWord(18) * n_long_bands)));
    overlap := (overlap + LongWord((LongWord(9) * n_long_bands)));
  end;
  if (block_type = LongWord(2)) then
  begin
    L3_imdct_short(grbuf, overlap, LongInt(LongWord((LongWord(32) - n_long_bands))));
  end
  else
  begin
    L3_imdct36(grbuf, overlap, PSingle(@_static_L3_imdct_gr_g_mdct_window[LongInt((block_type = LongWord(3)))][0]), LongInt(LongWord((LongWord(32) - n_long_bands))));
  end;
end;

procedure L3_save_reservoir(h: PMp3decT; s_2: PMp3decScratchT);
var
  pos: LongInt;
  remains: LongInt;
begin
  pos := LongInt((LongWord((s_2^.bs.pos + 7)) div LongWord(8)));
  remains := LongInt(LongWord(((LongWord(s_2^.bs.limit) div LongWord(8)) - pos)));
  if (remains > 511) then
  begin
    pos := (pos + (remains - 511));
    remains := 511;
  end;
  if (remains > 0) then
  begin
    __c2p_stdlib_memmove(Pointer(@h^.reserv_buf[0]), (PUint8T(@s_2^.maindata[0]) + pos), TSizeT(remains));
  end;
  h^.reserv := remains;
end;

function L3_restore_reservoir(h: PMp3decT; bs: PBsT; s_2: PMp3decScratchT; main_data_begin: LongInt): LongInt;
var
  frame_bytes: LongInt;
  bytes_have: LongInt;
  __c2p_tmp1: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
begin
  frame_bytes := ((bs^.limit - bs^.pos) div 8);
  if (h^.reserv > main_data_begin) then
  begin
    __c2p_tmp1 := main_data_begin;
  end
  else
  begin
    __c2p_tmp1 := h^.reserv;
  end;
  bytes_have := __c2p_tmp1;
  if (0 < (h^.reserv - main_data_begin)) then
  begin
    __c2p_tmp2 := (h^.reserv - main_data_begin);
  end
  else
  begin
    __c2p_tmp2 := 0;
  end;
  if (h^.reserv > main_data_begin) then
  begin
    __c2p_tmp3 := main_data_begin;
  end
  else
  begin
    __c2p_tmp3 := h^.reserv;
  end;
  __c2p_stdlib_memcpy(Pointer(@s_2^.maindata[0]), (PByte(@h^.reserv_buf[0]) + __c2p_tmp2), TSizeT(__c2p_tmp3));
  __c2p_stdlib_memcpy((PUint8T(@s_2^.maindata[0]) + bytes_have), (bs^.buf + (bs^.pos div 8)), TSizeT(frame_bytes));
  bs_init(@s_2^.bs, PUint8T(@s_2^.maindata[0]), (bytes_have + frame_bytes));
  Result := LongInt((h^.reserv >= main_data_begin));
end;

procedure L3_decode(h: PMp3decT; s_2: PMp3decScratchT; gr_info: PL3GrInfoT; nch: LongInt);
label _L__for0_step, _L__for1_step;
var
  ch: LongInt;
  layer3gr_limit: LongInt;
  aa_bands: LongInt;
  n_long_bands: LongInt;
  __c2p_tmp1: LongInt;
begin
  ch := 0;
  while (ch < nch) do
  begin
    layer3gr_limit := (s_2^.bs.pos + LongInt(gr_info[ch].part_23_length));
    L3_decode_scalefactors(PUint8T(@h^.header[0]), PUint8T(@s_2^.ist_pos[ch][0]), @s_2^.bs, (gr_info + ch), PSingle(@s_2^.scf[0]), ch);
    L3_huffman(PSingle(@s_2^.grbuf[ch][0]), @s_2^.bs, (gr_info + ch), PSingle(@s_2^.scf[0]), layer3gr_limit);
    _L__for0_step:
    ch := (ch + 1);
  end;
  if ((LongInt(h^.header[3]) and 16) <> 0) then
  begin
    L3_intensity_stereo(PSingle(@s_2^.grbuf[0][0]), PUint8T(@s_2^.ist_pos[1][0]), gr_info, PUint8T(@h^.header[0]));
  end
  else
  begin
    if ((LongInt(h^.header[3]) and 224) = 96) then
    begin
      L3_midside_stereo(PSingle(@s_2^.grbuf[0][0]), 576);
    end;
  end;
  ch := 0;
  while (ch < nch) do
  begin
    aa_bands := 31;
    if (LongInt(gr_info^.mixed_block_flag) <> 0) then
    begin
      __c2p_tmp1 := 2;
    end
    else
    begin
      __c2p_tmp1 := 0;
    end;
    n_long_bands := (__c2p_tmp1 shl LongInt(((((LongInt(h^.header[2]) shr 2) and 3) + ((((LongInt(h^.header[1]) shr 3) and 1) + ((LongInt(h^.header[1]) shr 4) and 1)) * 3)) = 2)));
    if (LongInt(gr_info^.n_short_sfb) <> 0) then
    begin
      aa_bands := (n_long_bands - 1);
      L3_reorder((PSingle(@s_2^.grbuf[ch][0]) + (n_long_bands * 18)), PSingle(@s_2^.syn[0][0]), (gr_info^.sfbtab + LongInt(gr_info^.n_long_sfb)));
    end;
    L3_antialias(PSingle(@s_2^.grbuf[ch][0]), aa_bands);
    L3_imdct_gr(PSingle(@s_2^.grbuf[ch][0]), PSingle(@h^.mdct_overlap[ch][0]), LongWord(gr_info^.block_type), LongWord(n_long_bands));
    L3_change_sign(PSingle(@s_2^.grbuf[ch][0]));
    _L__for1_step:
    ch := (ch + 1);
    gr_info := (gr_info + 1);
  end;
end;

const
  { DCT-II SSE 常量：g_sec 广播向量与蝶形系数广播向量 }
  DCT_GSEC_B: array[0..95] of Single = (
    10.19000816,10.19000816,10.19000816,10.19000816,
    0.50060302,0.50060302,0.50060302,0.50060302,
    0.50241929,0.50241929,0.50241929,0.50241929,
    3.40760851,3.40760851,3.40760851,3.40760851,
    0.50547093,0.50547093,0.50547093,0.50547093,
    0.52249861,0.52249861,0.52249861,0.52249861,
    2.05778098,2.05778098,2.05778098,2.05778098,
    0.51544732,0.51544732,0.51544732,0.51544732,
    0.56694406,0.56694406,0.56694406,0.56694406,
    1.48416460,1.48416460,1.48416460,1.48416460,
    0.53104258,0.53104258,0.53104258,0.53104258,
    0.64682180,0.64682180,0.64682180,0.64682180,
    1.16943991,1.16943991,1.16943991,1.16943991,
    0.55310392,0.55310392,0.55310392,0.55310392,
    0.78815460,0.78815460,0.78815460,0.78815460,
    0.97256821,0.97256821,0.97256821,0.97256821,
    0.58293498,0.58293498,0.58293498,0.58293498,
    1.06067765,1.06067765,1.06067765,1.06067765,
    0.83934963,0.83934963,0.83934963,0.83934963,
    0.62250412,0.62250412,0.62250412,0.62250412,
    1.72244716,1.72244716,1.72244716,1.72244716,
    0.74453628,0.74453628,0.74453628,0.74453628,
    0.67480832,0.67480832,0.67480832,0.67480832,
    5.10114861,5.10114861,5.10114861,5.10114861);
  DCT_W707: array[0..3] of Single = (0.70710677,0.70710677,0.70710677,0.70710677);
  DCT_W198: array[0..3] of Single = (0.198912367,0.198912367,0.198912367,0.198912367);
  DCT_W382: array[0..3] of Single = (0.382683432,0.382683432,0.382683432,0.382683432);
  DCT_W509: array[0..3] of Single = (0.50979561,0.50979561,0.50979561,0.50979561);
  DCT_W541: array[0..3] of Single = (0.54119611,0.54119611,0.54119611,0.54119611);
  DCT_W601: array[0..3] of Single = (0.60134488,0.60134488,0.60134488,0.60134488);
  DCT_W899: array[0..3] of Single = (0.89997619,0.89997619,0.89997619,0.89997619);
  DCT_W1306: array[0..3] of Single = (1.30656302,1.30656302,1.30656302,1.30656302);
  DCT_W2562: array[0..3] of Single = (2.56291556,2.56291556,2.56291556,2.56291556);
  DCT_WTAB: array[0..35] of Single = (
    0.70710677,0.70710677,0.70710677,0.70710677,
    0.198912367,0.198912367,0.198912367,0.198912367,
    0.382683432,0.382683432,0.382683432,0.382683432,
    0.50979561,0.50979561,0.50979561,0.50979561,
    0.54119611,0.54119611,0.54119611,0.54119611,
    0.60134488,0.60134488,0.60134488,0.60134488,
    0.89997619,0.89997619,0.89997619,0.89997619,
    1.30656302,1.30656302,1.30656302,1.30656302,
    2.56291556,2.56291556,2.56291556,2.56291556);

{$if defined(MP3DEC_SIMD_ON) and defined(cpux86_64)}
procedure mp3d_DCT_II(grbuf: PSingle; n: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  mp3dC707: Single;
  mp3dC509: Single;
  mp3dC541: Single;
  mp3dC601: Single;
  mp3dC900: Single;
  mp3dC130: Single;
  mp3dC256: Single;
  mp3dC198: Single;
  mp3dC382: Single;
  i: LongInt;
  k: LongInt;
  t: array[0..3] of array[0..7] of Single;
  x: PSingle;
  y: PSingle;
  x0: Single;
  x1: Single;
  x2: Single;
  x3: Single;
  t0: Single;
  t1: Single;
  t2: Single;
  t3: Single;
  x0_2: Single;
  x1_2: Single;
  x2_2: Single;
  x3_2: Single;
  x4: Single;
  x5: Single;
  x6: Single;
  x7: Single;
  xt: Single;
begin
  k := 0;
  { ---- SSE 主路径：每轮 4 个 band 并行（与 C SIMD 路径逐位一致）---- }
  k := 0;
  while (k + 4 <= n) do
  begin
    asm
      subq    $512, %rsp
      movslq  k, %rax
      shlq    $2, %rax
      movq    grbuf, %r10
      leaq    (%r10,%rax), %r10      { r10 = y = grbuf + k }
      movups  0(%r10), %xmm0
      movups  1080(%r10), %xmm1
      movups  1152(%r10), %xmm2
      movups  2232(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+0(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+16(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 0(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+32(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 128(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 256(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 384(%rsp)    { T[3][i] }
      movups  72(%r10), %xmm0
      movups  1008(%r10), %xmm1
      movups  1224(%r10), %xmm2
      movups  2160(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+48(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+64(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 16(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+80(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 144(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 272(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 400(%rsp)    { T[3][i] }
      movups  144(%r10), %xmm0
      movups  936(%r10), %xmm1
      movups  1296(%r10), %xmm2
      movups  2088(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+96(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+112(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 32(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+128(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 160(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 288(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 416(%rsp)    { T[3][i] }
      movups  216(%r10), %xmm0
      movups  864(%r10), %xmm1
      movups  1368(%r10), %xmm2
      movups  2016(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+144(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+160(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 48(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+176(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 176(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 304(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 432(%rsp)    { T[3][i] }
      movups  288(%r10), %xmm0
      movups  792(%r10), %xmm1
      movups  1440(%r10), %xmm2
      movups  1944(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+192(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+208(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 64(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+224(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 192(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 320(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 448(%rsp)    { T[3][i] }
      movups  360(%r10), %xmm0
      movups  720(%r10), %xmm1
      movups  1512(%r10), %xmm2
      movups  1872(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+240(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+256(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 80(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+272(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 208(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 336(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 464(%rsp)    { T[3][i] }
      movups  432(%r10), %xmm0
      movups  648(%r10), %xmm1
      movups  1584(%r10), %xmm2
      movups  1800(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+288(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+304(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 96(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+320(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 224(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 352(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 480(%rsp)    { T[3][i] }
      movups  504(%r10), %xmm0
      movups  576(%r10), %xmm1
      movups  1656(%r10), %xmm2
      movups  1728(%r10), %xmm3
      movaps  %xmm0, %xmm4
      addps   %xmm3, %xmm4            { t0 }
      movaps  %xmm1, %xmm5
      addps   %xmm2, %xmm5            { t1 }
      movaps  %xmm1, %xmm6
      subps   %xmm2, %xmm6
      movups  DCT_GSEC_B+336(%rip), %xmm9
      mulps   %xmm9, %xmm6            { t2 }
      movaps  %xmm0, %xmm7
      subps   %xmm3, %xmm7
      movups  DCT_GSEC_B+352(%rip), %xmm9
      mulps   %xmm9, %xmm7            { t3 }
      movaps  %xmm4, %xmm0
      addps   %xmm5, %xmm0
      movups  %xmm0, 112(%rsp)         { T[0][i] }
      movaps  %xmm4, %xmm1
      subps   %xmm5, %xmm1
      movups  DCT_GSEC_B+368(%rip), %xmm9
      mulps   %xmm9, %xmm1
      movups  %xmm1, 240(%rsp)     { T[1][i] }
      movaps  %xmm7, %xmm2
      addps   %xmm6, %xmm2
      movups  %xmm2, 368(%rsp)    { T[2][i] }
      movaps  %xmm7, %xmm3
      subps   %xmm6, %xmm3
      mulps   %xmm9, %xmm3
      movups  %xmm3, 496(%rsp)    { T[3][i] }
      movups  0(%rsp), %xmm0
      movups  16(%rsp), %xmm1
      movups  32(%rsp), %xmm2
      movups  48(%rsp), %xmm3
      movups  64(%rsp), %xmm4
      movups  80(%rsp), %xmm5
      movups  96(%rsp), %xmm6
      movups  112(%rsp), %xmm7
      movaps  %xmm0, %xmm8
      subps   %xmm7, %xmm8
      addps   %xmm7, %xmm0
      movaps  %xmm1, %xmm7
      subps   %xmm6, %xmm7
      addps   %xmm6, %xmm1
      movaps  %xmm2, %xmm6
      subps   %xmm5, %xmm6
      addps   %xmm5, %xmm2
      movaps  %xmm3, %xmm5
      subps   %xmm4, %xmm5
      addps   %xmm4, %xmm3
      movaps  %xmm0, %xmm4
      subps   %xmm3, %xmm4
      addps   %xmm3, %xmm0
      movaps  %xmm1, %xmm3
      subps   %xmm2, %xmm3
      addps   %xmm2, %xmm1
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movups  %xmm9, 0(%rsp)
      movaps  %xmm0, %xmm9
      subps   %xmm1, %xmm9
      movups  DCT_W707(%rip), %xmm10
      mulps   %xmm10, %xmm9
      movups  %xmm9, 64(%rsp)
      addps   %xmm6, %xmm5
      movaps  %xmm6, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm6
      addps   %xmm8, %xmm7
      movaps  %xmm3, %xmm9
      addps   %xmm4, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm3
      movups  DCT_W198(%rip), %xmm11
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movups  DCT_W382(%rip), %xmm12
      movaps  %xmm5, %xmm9
      mulps   %xmm12, %xmm9
      addps   %xmm9, %xmm7
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movaps  %xmm8, %xmm0
      subps   %xmm6, %xmm0
      addps   %xmm6, %xmm8
      movups  DCT_W509(%rip), %xmm13
      movaps  %xmm8, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm13, %xmm9
      movups  %xmm9, 16(%rsp)
      movups  DCT_W541(%rip), %xmm14
      movaps  %xmm4, %xmm9
      addps   %xmm3, %xmm9
      mulps   %xmm14, %xmm9
      movups  %xmm9, 32(%rsp)
      movups  DCT_W601(%rip), %xmm15
      movaps  %xmm0, %xmm9
      subps   %xmm5, %xmm9
      mulps   %xmm15, %xmm9
      movups  %xmm9, 48(%rsp)
      movups  DCT_W899(%rip), %xmm9
      movaps  %xmm0, %xmm10
      addps   %xmm5, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 80(%rsp)
      movups  DCT_W1306(%rip), %xmm9
      movaps  %xmm4, %xmm10
      subps   %xmm3, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 96(%rsp)
      movups  DCT_W2562(%rip), %xmm9
      movaps  %xmm8, %xmm10
      subps   %xmm7, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 112(%rsp)
      movups  128(%rsp), %xmm0
      movups  144(%rsp), %xmm1
      movups  160(%rsp), %xmm2
      movups  176(%rsp), %xmm3
      movups  192(%rsp), %xmm4
      movups  208(%rsp), %xmm5
      movups  224(%rsp), %xmm6
      movups  240(%rsp), %xmm7
      movaps  %xmm0, %xmm8
      subps   %xmm7, %xmm8
      addps   %xmm7, %xmm0
      movaps  %xmm1, %xmm7
      subps   %xmm6, %xmm7
      addps   %xmm6, %xmm1
      movaps  %xmm2, %xmm6
      subps   %xmm5, %xmm6
      addps   %xmm5, %xmm2
      movaps  %xmm3, %xmm5
      subps   %xmm4, %xmm5
      addps   %xmm4, %xmm3
      movaps  %xmm0, %xmm4
      subps   %xmm3, %xmm4
      addps   %xmm3, %xmm0
      movaps  %xmm1, %xmm3
      subps   %xmm2, %xmm3
      addps   %xmm2, %xmm1
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movups  %xmm9, 128(%rsp)
      movaps  %xmm0, %xmm9
      subps   %xmm1, %xmm9
      movups  DCT_W707(%rip), %xmm10
      mulps   %xmm10, %xmm9
      movups  %xmm9, 192(%rsp)
      addps   %xmm6, %xmm5
      movaps  %xmm6, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm6
      addps   %xmm8, %xmm7
      movaps  %xmm3, %xmm9
      addps   %xmm4, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm3
      movups  DCT_W198(%rip), %xmm11
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movups  DCT_W382(%rip), %xmm12
      movaps  %xmm5, %xmm9
      mulps   %xmm12, %xmm9
      addps   %xmm9, %xmm7
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movaps  %xmm8, %xmm0
      subps   %xmm6, %xmm0
      addps   %xmm6, %xmm8
      movups  DCT_W509(%rip), %xmm13
      movaps  %xmm8, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm13, %xmm9
      movups  %xmm9, 144(%rsp)
      movups  DCT_W541(%rip), %xmm14
      movaps  %xmm4, %xmm9
      addps   %xmm3, %xmm9
      mulps   %xmm14, %xmm9
      movups  %xmm9, 160(%rsp)
      movups  DCT_W601(%rip), %xmm15
      movaps  %xmm0, %xmm9
      subps   %xmm5, %xmm9
      mulps   %xmm15, %xmm9
      movups  %xmm9, 176(%rsp)
      movups  DCT_W899(%rip), %xmm9
      movaps  %xmm0, %xmm10
      addps   %xmm5, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 208(%rsp)
      movups  DCT_W1306(%rip), %xmm9
      movaps  %xmm4, %xmm10
      subps   %xmm3, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 224(%rsp)
      movups  DCT_W2562(%rip), %xmm9
      movaps  %xmm8, %xmm10
      subps   %xmm7, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 240(%rsp)
      movups  256(%rsp), %xmm0
      movups  272(%rsp), %xmm1
      movups  288(%rsp), %xmm2
      movups  304(%rsp), %xmm3
      movups  320(%rsp), %xmm4
      movups  336(%rsp), %xmm5
      movups  352(%rsp), %xmm6
      movups  368(%rsp), %xmm7
      movaps  %xmm0, %xmm8
      subps   %xmm7, %xmm8
      addps   %xmm7, %xmm0
      movaps  %xmm1, %xmm7
      subps   %xmm6, %xmm7
      addps   %xmm6, %xmm1
      movaps  %xmm2, %xmm6
      subps   %xmm5, %xmm6
      addps   %xmm5, %xmm2
      movaps  %xmm3, %xmm5
      subps   %xmm4, %xmm5
      addps   %xmm4, %xmm3
      movaps  %xmm0, %xmm4
      subps   %xmm3, %xmm4
      addps   %xmm3, %xmm0
      movaps  %xmm1, %xmm3
      subps   %xmm2, %xmm3
      addps   %xmm2, %xmm1
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movups  %xmm9, 256(%rsp)
      movaps  %xmm0, %xmm9
      subps   %xmm1, %xmm9
      movups  DCT_W707(%rip), %xmm10
      mulps   %xmm10, %xmm9
      movups  %xmm9, 320(%rsp)
      addps   %xmm6, %xmm5
      movaps  %xmm6, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm6
      addps   %xmm8, %xmm7
      movaps  %xmm3, %xmm9
      addps   %xmm4, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm3
      movups  DCT_W198(%rip), %xmm11
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movups  DCT_W382(%rip), %xmm12
      movaps  %xmm5, %xmm9
      mulps   %xmm12, %xmm9
      addps   %xmm9, %xmm7
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movaps  %xmm8, %xmm0
      subps   %xmm6, %xmm0
      addps   %xmm6, %xmm8
      movups  DCT_W509(%rip), %xmm13
      movaps  %xmm8, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm13, %xmm9
      movups  %xmm9, 272(%rsp)
      movups  DCT_W541(%rip), %xmm14
      movaps  %xmm4, %xmm9
      addps   %xmm3, %xmm9
      mulps   %xmm14, %xmm9
      movups  %xmm9, 288(%rsp)
      movups  DCT_W601(%rip), %xmm15
      movaps  %xmm0, %xmm9
      subps   %xmm5, %xmm9
      mulps   %xmm15, %xmm9
      movups  %xmm9, 304(%rsp)
      movups  DCT_W899(%rip), %xmm9
      movaps  %xmm0, %xmm10
      addps   %xmm5, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 336(%rsp)
      movups  DCT_W1306(%rip), %xmm9
      movaps  %xmm4, %xmm10
      subps   %xmm3, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 352(%rsp)
      movups  DCT_W2562(%rip), %xmm9
      movaps  %xmm8, %xmm10
      subps   %xmm7, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 368(%rsp)
      movups  384(%rsp), %xmm0
      movups  400(%rsp), %xmm1
      movups  416(%rsp), %xmm2
      movups  432(%rsp), %xmm3
      movups  448(%rsp), %xmm4
      movups  464(%rsp), %xmm5
      movups  480(%rsp), %xmm6
      movups  496(%rsp), %xmm7
      movaps  %xmm0, %xmm8
      subps   %xmm7, %xmm8
      addps   %xmm7, %xmm0
      movaps  %xmm1, %xmm7
      subps   %xmm6, %xmm7
      addps   %xmm6, %xmm1
      movaps  %xmm2, %xmm6
      subps   %xmm5, %xmm6
      addps   %xmm5, %xmm2
      movaps  %xmm3, %xmm5
      subps   %xmm4, %xmm5
      addps   %xmm4, %xmm3
      movaps  %xmm0, %xmm4
      subps   %xmm3, %xmm4
      addps   %xmm3, %xmm0
      movaps  %xmm1, %xmm3
      subps   %xmm2, %xmm3
      addps   %xmm2, %xmm1
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movaps  %xmm0, %xmm9
      addps   %xmm1, %xmm9
      movups  %xmm9, 384(%rsp)
      movaps  %xmm0, %xmm9
      subps   %xmm1, %xmm9
      movups  DCT_W707(%rip), %xmm10
      mulps   %xmm10, %xmm9
      movups  %xmm9, 448(%rsp)
      addps   %xmm6, %xmm5
      movaps  %xmm6, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm6
      addps   %xmm8, %xmm7
      movaps  %xmm3, %xmm9
      addps   %xmm4, %xmm9
      mulps   %xmm10, %xmm9
      movaps  %xmm9, %xmm3
      movups  DCT_W198(%rip), %xmm11
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movups  DCT_W382(%rip), %xmm12
      movaps  %xmm5, %xmm9
      mulps   %xmm12, %xmm9
      addps   %xmm9, %xmm7
      movaps  %xmm7, %xmm9
      mulps   %xmm11, %xmm9
      subps   %xmm9, %xmm5
      movaps  %xmm8, %xmm0
      subps   %xmm6, %xmm0
      addps   %xmm6, %xmm8
      movups  DCT_W509(%rip), %xmm13
      movaps  %xmm8, %xmm9
      addps   %xmm7, %xmm9
      mulps   %xmm13, %xmm9
      movups  %xmm9, 400(%rsp)
      movups  DCT_W541(%rip), %xmm14
      movaps  %xmm4, %xmm9
      addps   %xmm3, %xmm9
      mulps   %xmm14, %xmm9
      movups  %xmm9, 416(%rsp)
      movups  DCT_W601(%rip), %xmm15
      movaps  %xmm0, %xmm9
      subps   %xmm5, %xmm9
      mulps   %xmm15, %xmm9
      movups  %xmm9, 432(%rsp)
      movups  DCT_W899(%rip), %xmm9
      movaps  %xmm0, %xmm10
      addps   %xmm5, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 464(%rsp)
      movups  DCT_W1306(%rip), %xmm9
      movaps  %xmm4, %xmm10
      subps   %xmm3, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 480(%rsp)
      movups  DCT_W2562(%rip), %xmm9
      movaps  %xmm8, %xmm10
      subps   %xmm7, %xmm10
      mulps   %xmm9, %xmm10
      movups  %xmm10, 496(%rsp)
      movq    %r10, %r11
      movups  384(%rsp), %xmm1     { T[3][i] }
      movups  400(%rsp), %xmm2     { T[3][i+1] }
      movups  256(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 72(%r11)
      movups  272(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 216(%r11)
      movups  0(%rsp), %xmm0
      movups  %xmm0, 0(%r11)
      movups  128(%rsp), %xmm0
      movups  144(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 144(%r11)
      movups  400(%rsp), %xmm1     { T[3][i] }
      movups  416(%rsp), %xmm2     { T[3][i+1] }
      movups  272(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 360(%r11)
      movups  288(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 504(%r11)
      movups  16(%rsp), %xmm0
      movups  %xmm0, 288(%r11)
      movups  144(%rsp), %xmm0
      movups  160(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 432(%r11)
      movups  416(%rsp), %xmm1     { T[3][i] }
      movups  432(%rsp), %xmm2     { T[3][i+1] }
      movups  288(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 648(%r11)
      movups  304(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 792(%r11)
      movups  32(%rsp), %xmm0
      movups  %xmm0, 576(%r11)
      movups  160(%rsp), %xmm0
      movups  176(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 720(%r11)
      movups  432(%rsp), %xmm1     { T[3][i] }
      movups  448(%rsp), %xmm2     { T[3][i+1] }
      movups  304(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 936(%r11)
      movups  320(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 1080(%r11)
      movups  48(%rsp), %xmm0
      movups  %xmm0, 864(%r11)
      movups  176(%rsp), %xmm0
      movups  192(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 1008(%r11)
      movups  448(%rsp), %xmm1     { T[3][i] }
      movups  464(%rsp), %xmm2     { T[3][i+1] }
      movups  320(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 1224(%r11)
      movups  336(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 1368(%r11)
      movups  64(%rsp), %xmm0
      movups  %xmm0, 1152(%r11)
      movups  192(%rsp), %xmm0
      movups  208(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 1296(%r11)
      movups  464(%rsp), %xmm1     { T[3][i] }
      movups  480(%rsp), %xmm2     { T[3][i+1] }
      movups  336(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 1512(%r11)
      movups  352(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 1656(%r11)
      movups  80(%rsp), %xmm0
      movups  %xmm0, 1440(%r11)
      movups  208(%rsp), %xmm0
      movups  224(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 1584(%r11)
      movups  480(%rsp), %xmm1     { T[3][i] }
      movups  496(%rsp), %xmm2     { T[3][i+1] }
      movups  352(%rsp), %xmm0     { T[2][i] }
      addps   %xmm1, %xmm0                 { T2i+T3i }
      addps   %xmm2, %xmm0                 { +T3[i+1] }
      movups  %xmm0, 1800(%r11)
      movups  368(%rsp), %xmm0     { T[2][i+1] }
      addps   %xmm1, %xmm0                 { T2[i+1]+T3i }
      addps   %xmm2, %xmm0
      movups  %xmm0, 1944(%r11)
      movups  96(%rsp), %xmm0
      movups  %xmm0, 1728(%r11)
      movups  224(%rsp), %xmm0
      movups  240(%rsp), %xmm1
      addps   %xmm1, %xmm0
      movups  %xmm0, 1872(%r11)
      movups  112(%rsp), %xmm2            { T[0][7] }
      movups  %xmm2, 2016(%r11)
      movups  368(%rsp), %xmm2            { T[2][7] }
      movups  496(%rsp), %xmm0            { T[3][7] }
      addps   %xmm0, %xmm2
      movups  %xmm2, 2088(%r11)
      movups  240(%rsp), %xmm2            { T[1][7] }
      movups  %xmm2, 2160(%r11)
      movups  496(%rsp), %xmm2            { T[3][7] }
      movups  %xmm2, 2232(%r11)
      addq    $512, %rsp
    end;
    k := k + 4;
  end;
  while (k < n) do
  begin
    { FPC 3.3.1 codegen 规避：常量驻留 xmm 跨循环回边被复用（见 wave17 笔记），
      改为每次迭代显式刷新的局部变量，保证 -O2 下位精确 }
    mp3dC707 := 0.70710677; mp3dC509 := 0.50979561; mp3dC541 := 0.54119611;
    mp3dC601 := 0.60134488; mp3dC900 := 0.89997619; mp3dC130 := 1.30656302;
    mp3dC256 := 2.56291556; mp3dC198 := 0.198912367; mp3dC382 := 0.382683432;
    y := (grbuf + k);
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 8) do
    begin
      x0 := y[(i * 18)];
      x1 := y[((15 - i) * 18)];
      x2 := y[((16 + i) * 18)];
      x3 := y[((31 - i) * 18)];
      t0 := (x0 + x3);
      t1 := (x1 + x2);
      t2 := ((x1 - x2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 0)]);
      t3 := ((x0 - x3) * _static_mp3d_DCT_II_g_sec[((3 * i) + 1)]);
      x[0] := (t0 + t1);
      x[8] := ((t0 - t1) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      x[16] := (t3 + t2);
      x[24] := ((t3 - t2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      _L__for1_step:
      i := (i + 1);
      x := (x + 1);
    end;
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 4) do
    begin
      x0_2 := x[0];
      x1_2 := x[1];
      x2_2 := x[2];
      x3_2 := x[3];
      x4 := x[4];
      x5 := x[5];
      x6 := x[6];
      x7 := x[7];
      xt := (x0_2 - x7);
      x0_2 := (x0_2 + x7);
      x7 := (x1_2 - x6);
      x1_2 := (x1_2 + x6);
      x6 := (x2_2 - x5);
      x2_2 := (x2_2 + x5);
      x5 := (x3_2 - x4);
      x3_2 := (x3_2 + x4);
      x4 := (x0_2 - x3_2);
      x0_2 := (x0_2 + x3_2);
      x3_2 := (x1_2 - x2_2);
      x1_2 := (x1_2 + x2_2);
      x[0] := (x0_2 + x1_2);
      x[4] := ((x0_2 - x1_2) * mp3dC707);
      x5 := (x5 + x6);
      x6 := ((x6 + x7) * mp3dC707);
      x7 := (x7 + xt);
      x3_2 := ((x3_2 + x4) * mp3dC707);
      x5 := (x5 - (x7 * mp3dC198));
      x7 := (x7 + (x5 * mp3dC382));
      x5 := (x5 - (x7 * mp3dC198));
      x0_2 := (xt - x6);
      xt := (xt + x6);
      x[1] := ((xt + x7) * mp3dC509);
      x[2] := ((x4 + x3_2) * mp3dC541);
      x[3] := ((x0_2 - x5) * mp3dC601);
      x[5] := ((x0_2 + x5) * mp3dC900);
      x[6] := ((x4 - x3_2) * mp3dC130);
      x[7] := ((xt - x7) * mp3dC256);
      _L__for2_step:
      i := (i + 1);
      x := (x + 8);
    end;
    i := 0;
    while (i < 7) do
    begin
      y[(0 * 18)] := t[0][i];
      y[(1 * 18)] := ((t[2][i] + t[3][i]) + t[3][(i + 1)]);
      y[(2 * 18)] := (t[1][i] + t[1][(i + 1)]);
      y[(3 * 18)] := ((t[2][(i + 1)] + t[3][i]) + t[3][(i + 1)]);
      _L__for3_step:
      i := (i + 1);
      y := (y + (4 * 18));
    end;
    y[(0 * 18)] := t[0][7];
    y[(1 * 18)] := (t[2][7] + t[3][7]);
    y[(2 * 18)] := t[1][7];
    y[(3 * 18)] := t[3][7];
    _L__for0_step:
    k := (k + 1);
  end;
end;
{$elseif defined(MP3DEC_SIMD_ON) and defined(cpuaarch64)}
procedure mp3d_DCT_II(grbuf: PSingle; n: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  mp3dC707: Single;
  mp3dC509: Single;
  mp3dC541: Single;
  mp3dC601: Single;
  mp3dC900: Single;
  mp3dC130: Single;
  mp3dC256: Single;
  mp3dC198: Single;
  mp3dC382: Single;
  i: LongInt;
  k: LongInt;
  t: array[0..3] of array[0..7] of Single;
  tmp: array[0..127] of Single;
  x: PSingle;
  y: PSingle;
  x0: Single;
  x1: Single;
  x2: Single;
  x3: Single;
  t0: Single;
  t1: Single;
  t2: Single;
  t3: Single;
  x0_2: Single;
  x1_2: Single;
  x2_2: Single;
  x3_2: Single;
  x4: Single;
  x5: Single;
  x6: Single;
  x7: Single;
  xt: Single;
begin
  k := 0;
  while (k + 4 <= n) do
  begin
    mp3d_DCT_II_4_neon(grbuf + k, PSingle(@DCT_GSEC_B[0]), PSingle(@DCT_WTAB[0]), PSingle(@tmp[0]));
    k := k + 4;
  end;
  while (k < n) do
  begin
    { FPC 3.3.1 codegen 规避：常量驻留 xmm 跨循环回边被复用（见 wave17 笔记），
      改为每次迭代显式刷新的局部变量，保证 -O2 下位精确 }
    mp3dC707 := 0.70710677; mp3dC509 := 0.50979561; mp3dC541 := 0.54119611;
    mp3dC601 := 0.60134488; mp3dC900 := 0.89997619; mp3dC130 := 1.30656302;
    mp3dC256 := 2.56291556; mp3dC198 := 0.198912367; mp3dC382 := 0.382683432;
    y := (grbuf + k);
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 8) do
    begin
      x0 := y[(i * 18)];
      x1 := y[((15 - i) * 18)];
      x2 := y[((16 + i) * 18)];
      x3 := y[((31 - i) * 18)];
      t0 := (x0 + x3);
      t1 := (x1 + x2);
      t2 := ((x1 - x2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 0)]);
      t3 := ((x0 - x3) * _static_mp3d_DCT_II_g_sec[((3 * i) + 1)]);
      x[0] := (t0 + t1);
      x[8] := ((t0 - t1) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      x[16] := (t3 + t2);
      x[24] := ((t3 - t2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      _L__for1_step:
      i := (i + 1);
      x := (x + 1);
    end;
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 4) do
    begin
      x0_2 := x[0];
      x1_2 := x[1];
      x2_2 := x[2];
      x3_2 := x[3];
      x4 := x[4];
      x5 := x[5];
      x6 := x[6];
      x7 := x[7];
      xt := (x0_2 - x7);
      x0_2 := (x0_2 + x7);
      x7 := (x1_2 - x6);
      x1_2 := (x1_2 + x6);
      x6 := (x2_2 - x5);
      x2_2 := (x2_2 + x5);
      x5 := (x3_2 - x4);
      x3_2 := (x3_2 + x4);
      x4 := (x0_2 - x3_2);
      x0_2 := (x0_2 + x3_2);
      x3_2 := (x1_2 - x2_2);
      x1_2 := (x1_2 + x2_2);
      x[0] := (x0_2 + x1_2);
      x[4] := ((x0_2 - x1_2) * mp3dC707);
      x5 := (x5 + x6);
      x6 := ((x6 + x7) * mp3dC707);
      x7 := (x7 + xt);
      x3_2 := ((x3_2 + x4) * mp3dC707);
      x5 := (x5 - (x7 * mp3dC198));
      x7 := (x7 + (x5 * mp3dC382));
      x5 := (x5 - (x7 * mp3dC198));
      x0_2 := (xt - x6);
      xt := (xt + x6);
      x[1] := ((xt + x7) * mp3dC509);
      x[2] := ((x4 + x3_2) * mp3dC541);
      x[3] := ((x0_2 - x5) * mp3dC601);
      x[5] := ((x0_2 + x5) * mp3dC900);
      x[6] := ((x4 - x3_2) * mp3dC130);
      x[7] := ((xt - x7) * mp3dC256);
      _L__for2_step:
      i := (i + 1);
      x := (x + 8);
    end;
    i := 0;
    while (i < 7) do
    begin
      y[(0 * 18)] := t[0][i];
      y[(1 * 18)] := ((t[2][i] + t[3][i]) + t[3][(i + 1)]);
      y[(2 * 18)] := (t[1][i] + t[1][(i + 1)]);
      y[(3 * 18)] := ((t[2][(i + 1)] + t[3][i]) + t[3][(i + 1)]);
      _L__for3_step:
      i := (i + 1);
      y := (y + (4 * 18));
    end;
    y[(0 * 18)] := t[0][7];
    y[(1 * 18)] := (t[2][7] + t[3][7]);
    y[(2 * 18)] := t[1][7];
    y[(3 * 18)] := t[3][7];
    _L__for0_step:
    k := (k + 1);
  end;
end;
{$else}
procedure mp3d_DCT_II(grbuf: PSingle; n: LongInt);
label _L__for0_step, _L__for1_step, _L__for2_step, _L__for3_step;
var
  mp3dC707: Single;
  mp3dC509: Single;
  mp3dC541: Single;
  mp3dC601: Single;
  mp3dC900: Single;
  mp3dC130: Single;
  mp3dC256: Single;
  mp3dC198: Single;
  mp3dC382: Single;
  i: LongInt;
  k: LongInt;
  t: array[0..3] of array[0..7] of Single;
  x: PSingle;
  y: PSingle;
  x0: Single;
  x1: Single;
  x2: Single;
  x3: Single;
  t0: Single;
  t1: Single;
  t2: Single;
  t3: Single;
  x0_2: Single;
  x1_2: Single;
  x2_2: Single;
  x3_2: Single;
  x4: Single;
  x5: Single;
  x6: Single;
  x7: Single;
  xt: Single;
begin
  k := 0;
  while (k < n) do
  begin
    { FPC 3.3.1 codegen 规避：常量驻留 xmm 跨循环回边被复用（见 wave17 笔记），
      改为每次迭代显式刷新的局部变量，保证 -O2 下位精确 }
    mp3dC707 := 0.70710677; mp3dC509 := 0.50979561; mp3dC541 := 0.54119611;
    mp3dC601 := 0.60134488; mp3dC900 := 0.89997619; mp3dC130 := 1.30656302;
    mp3dC256 := 2.56291556; mp3dC198 := 0.198912367; mp3dC382 := 0.382683432;
    y := (grbuf + k);
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 8) do
    begin
      x0 := y[(i * 18)];
      x1 := y[((15 - i) * 18)];
      x2 := y[((16 + i) * 18)];
      x3 := y[((31 - i) * 18)];
      t0 := (x0 + x3);
      t1 := (x1 + x2);
      t2 := ((x1 - x2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 0)]);
      t3 := ((x0 - x3) * _static_mp3d_DCT_II_g_sec[((3 * i) + 1)]);
      x[0] := (t0 + t1);
      x[8] := ((t0 - t1) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      x[16] := (t3 + t2);
      x[24] := ((t3 - t2) * _static_mp3d_DCT_II_g_sec[((3 * i) + 2)]);
      _L__for1_step:
      i := (i + 1);
      x := (x + 1);
    end;
    x := PSingle(@t[0][0]);
    i := 0;
    while (i < 4) do
    begin
      x0_2 := x[0];
      x1_2 := x[1];
      x2_2 := x[2];
      x3_2 := x[3];
      x4 := x[4];
      x5 := x[5];
      x6 := x[6];
      x7 := x[7];
      xt := (x0_2 - x7);
      x0_2 := (x0_2 + x7);
      x7 := (x1_2 - x6);
      x1_2 := (x1_2 + x6);
      x6 := (x2_2 - x5);
      x2_2 := (x2_2 + x5);
      x5 := (x3_2 - x4);
      x3_2 := (x3_2 + x4);
      x4 := (x0_2 - x3_2);
      x0_2 := (x0_2 + x3_2);
      x3_2 := (x1_2 - x2_2);
      x1_2 := (x1_2 + x2_2);
      x[0] := (x0_2 + x1_2);
      x[4] := ((x0_2 - x1_2) * mp3dC707);
      x5 := (x5 + x6);
      x6 := ((x6 + x7) * mp3dC707);
      x7 := (x7 + xt);
      x3_2 := ((x3_2 + x4) * mp3dC707);
      x5 := (x5 - (x7 * mp3dC198));
      x7 := (x7 + (x5 * mp3dC382));
      x5 := (x5 - (x7 * mp3dC198));
      x0_2 := (xt - x6);
      xt := (xt + x6);
      x[1] := ((xt + x7) * mp3dC509);
      x[2] := ((x4 + x3_2) * mp3dC541);
      x[3] := ((x0_2 - x5) * mp3dC601);
      x[5] := ((x0_2 + x5) * mp3dC900);
      x[6] := ((x4 - x3_2) * mp3dC130);
      x[7] := ((xt - x7) * mp3dC256);
      _L__for2_step:
      i := (i + 1);
      x := (x + 8);
    end;
    i := 0;
    while (i < 7) do
    begin
      y[(0 * 18)] := t[0][i];
      y[(1 * 18)] := ((t[2][i] + t[3][i]) + t[3][(i + 1)]);
      y[(2 * 18)] := (t[1][i] + t[1][(i + 1)]);
      y[(3 * 18)] := ((t[2][(i + 1)] + t[3][i]) + t[3][(i + 1)]);
      _L__for3_step:
      i := (i + 1);
      y := (y + (4 * 18));
    end;
    y[(0 * 18)] := t[0][7];
    y[(1 * 18)] := (t[2][7] + t[3][7]);
    y[(2 * 18)] := t[1][7];
    y[(3 * 18)] := t[3][7];
    _L__for0_step:
    k := (k + 1);
  end;
end;
{$endif MP3DEC_SIMD_ON}

function mp3d_scale_pcm(sample: Single): TInt16T; inline;
var
  s_2: TInt16T;
begin
  if (sample >= 32766.5) then
  begin
    Result := TInt16T(32767);
    System.Exit;
  end;
  if (sample <= -32767.5) then
  begin
    Result := TInt16T(-32768);
    System.Exit;
  end;
  s_2 := TInt16T(System.Trunc((sample + Single(0.5))));
  s_2 := TInt16T((LongInt(s_2) - LongInt((LongInt(s_2) < 0))));
  Result := TInt16T(s_2);
end;

procedure mp3d_synth_pair(pcm: PMp3dSampleT; nch: LongInt; z: PSingle);
var
  a: Single;
begin
  a := ((z[(14 * 64)] - z[0]) * 29);
  a := (a + ((z[(1 * 64)] + z[(13 * 64)]) * 213));
  a := (a + ((z[(12 * 64)] - z[(2 * 64)]) * 459));
  a := (a + ((z[(3 * 64)] + z[(11 * 64)]) * 2037));
  a := (a + ((z[(10 * 64)] - z[(4 * 64)]) * 5153));
  a := (a + ((z[(5 * 64)] + z[(9 * 64)]) * 6574));
  a := (a + ((z[(8 * 64)] - z[(6 * 64)]) * 37489));
  a := (a + (z[(7 * 64)] * 75038));
  pcm[0] := TMp3dSampleT(mp3d_scale_pcm(a));
  z := (z + 2);
  a := (z[(14 * 64)] * 104);
  a := (a + (z[(12 * 64)] * 1567));
  a := (a + (z[(10 * 64)] * 9727));
  a := (a + (z[(8 * 64)] * 64019));
  a := (a + (z[(6 * 64)] * -9975));
  a := (a + (z[(4 * 64)] * -45));
  a := (a + (z[(2 * 64)] * 146));
  a := (a + (z[(0 * 64)] * -5));
  pcm[(16 * nch)] := TMp3dSampleT(mp3d_scale_pcm(a));
end;

const
  { SSE PCM 转换常量：语义对应标量 mp3d_scale_pcm }
  SSEPCM_HI: array[0..3] of Single = (32766.5, 32766.5, 32766.5, 32766.5);
  SSEPCM_LO: array[0..3] of Single = (-32767.5, -32767.5, -32767.5, -32767.5);
  SSEPCM_HALF: array[0..3] of Single = (0.5, 0.5, 0.5, 0.5);
  SSEPCM_I32767: array[0..3] of LongInt = (32767, 32767, 32767, 32767);
  SSEPCM_IM32768: array[0..3] of LongInt = (-32768, -32768, -32768, -32768);

{$if defined(MP3DEC_SIMD_ON) and defined(cpux86_64)}
procedure mp3d_synth(xl: PSingle; dstl: PMp3dSampleT; nch: LongInt; lins: PSingle);
{ 手工优化核 v3：SSE 四车道并行，车道内运算顺序与 minimp3 标量宏一致（位精确）。
  寄存器纪律：XMM0-5 易失临时；XMM6/7 为 B/A 累加器（跨块存活，Win64 ABI 非易失，
  故块外缘按目标平台条件保存/恢复）；GPR 仅用易失集。PCM 转换并入尾部：
  min/max 钳制 + cvttps2dq 截断与标量 scale_pcm 逐位等价。 }
var
  i: LongInt;
  xr: PSingle;
  dstr: PMp3dSampleT;
  zlin: PSingle;
  w: PSingle;
  UOff, VOff, POff, QOff: Int64;
begin
  xr := (xl + (576 * (nch - 1)));
  dstr := (dstl + (nch - 1));
  zlin := (lins + (15 * 64));
  w := PSingle(@_static_mp3d_synth_g_win[0]);
  zlin[(4 * 15)] := xl[(18 * 16)];
  zlin[((4 * 15) + 1)] := xr[(18 * 16)];
  zlin[((4 * 15) + 2)] := xl[0];
  zlin[((4 * 15) + 3)] := xr[0];
  zlin[(4 * 31)] := xl[(1 + (18 * 16))];
  zlin[((4 * 31) + 1)] := xr[(1 + (18 * 16))];
  zlin[((4 * 31) + 2)] := xl[1];
  zlin[((4 * 31) + 3)] := xr[1];
  mp3d_synth_pair(dstr, nch, ((lins + (4 * 15)) + 1));
  mp3d_synth_pair((dstr + (32 * nch)), nch, (((lins + (4 * 15)) + 64) + 1));
  mp3d_synth_pair(dstl, nch, (lins + (4 * 15)));
  mp3d_synth_pair((dstl + (32 * nch)), nch, ((lins + (4 * 15)) + 64));
  i := 14;
  while (i >= 0) do
  begin
    zlin[(4 * i)] := xl[(18 * (31 - i))];
    zlin[((4 * i) + 1)] := xr[(18 * (31 - i))];
    zlin[((4 * i) + 2)] := xl[(1 + (18 * (31 - i)))];
    zlin[((4 * i) + 3)] := xr[(1 + (18 * (31 - i)))];
    zlin[(4 * (i + 16))] := xl[(1 + (18 * (1 + i)))];
    zlin[((4 * (i + 16)) + 1)] := xr[(1 + (18 * (1 + i)))];
    zlin[((4 * (i - 16)) + 2)] := xl[(18 * (1 + i))];
    zlin[((4 * (i - 16)) + 3)] := xr[(18 * (1 + i))];
    UOff := (15 - i) * nch * 2;
    VOff := (17 + i) * nch * 2;
    POff := (47 - i) * nch * 2;
    QOff := (49 + i) * nch * 2;

    asm
      {$ifdef windows}
      subq    $32, %rsp
      movups  %xmm6, (%rsp)
      movups  %xmm7, 16(%rsp)
      {$endif}
      movslq  i, %rax
      shlq    $4, %rax
      movq    zlin, %r10
      leaq    (%r10,%rax), %r11
      movq    w, %r8
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  0(%r11), %xmm3
      movups  -3840(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      movaps  %xmm5, %xmm6
      movaps  %xmm3, %xmm5
      mulps   %xmm1, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm2, %xmm0
      subps   %xmm0, %xmm5
      movaps  %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -256(%r11), %xmm3
      movups  -3584(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm4, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm3, %xmm0
      mulps   %xmm1, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -512(%r11), %xmm3
      movups  -3328(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm3, %xmm5
      mulps   %xmm1, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm2, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -768(%r11), %xmm3
      movups  -3072(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm4, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm3, %xmm0
      mulps   %xmm1, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -1024(%r11), %xmm3
      movups  -2816(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm3, %xmm5
      mulps   %xmm1, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm2, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -1280(%r11), %xmm3
      movups  -2560(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm4, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm3, %xmm0
      mulps   %xmm1, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -1536(%r11), %xmm3
      movups  -2304(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm3, %xmm5
      mulps   %xmm1, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm2, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    (%r8), %xmm0
      addq    $8, %r8
      pshufd  $0x00, %xmm0, %xmm1
      pshufd  $0x55, %xmm0, %xmm2
      movups  -1792(%r11), %xmm3
      movups  -2048(%r11), %xmm4
      movaps  %xmm3, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm4, %xmm0
      mulps   %xmm1, %xmm0
      addps   %xmm0, %xmm5
      addps   %xmm5, %xmm6
      movaps  %xmm4, %xmm5
      mulps   %xmm2, %xmm5
      movaps  %xmm3, %xmm0
      mulps   %xmm1, %xmm0
      subps   %xmm0, %xmm5
      addps   %xmm5, %xmm7
      movq    %r8, w
{ ---- PCM 转换：min/max 钳制 + 截断，与标量 scale_pcm 逐位等价 ---- }
      movaps  %xmm6, %xmm0
      movups  SSEPCM_LO(%rip), %xmm1
      maxps   %xmm1, %xmm0
      movups  SSEPCM_HI(%rip), %xmm1
      minps   %xmm1, %xmm0
      movups  SSEPCM_HALF(%rip), %xmm1
      addps   %xmm1, %xmm0
      cvttps2dq %xmm0, %xmm0
      movaps  %xmm0, %xmm1
      psrad   $31, %xmm1
      paddd   %xmm1, %xmm0
      movaps  %xmm7, %xmm2
      movups  SSEPCM_LO(%rip), %xmm1
      maxps   %xmm1, %xmm2
      movups  SSEPCM_HI(%rip), %xmm1
      minps   %xmm1, %xmm2
      movups  SSEPCM_HALF(%rip), %xmm1
      addps   %xmm1, %xmm2
      cvttps2dq %xmm2, %xmm2
      movaps  %xmm2, %xmm3
      psrad   $31, %xmm3
      paddd   %xmm3, %xmm2
      packssdw %xmm0, %xmm2
      movq    dstr, %r11
      movq    dstl, %r10
      movq    UOff, %r9
      movq    VOff, %rcx
      movq    POff, %rdx
      movq    QOff, %r8
      pextrw  $0, %xmm2, %eax
      movw    %ax, (%r10,%r9)
      pextrw  $1, %xmm2, %eax
      movw    %ax, (%r11,%r9)
      pextrw  $2, %xmm2, %eax
      movw    %ax, (%r10,%rdx)
      pextrw  $3, %xmm2, %eax
      movw    %ax, (%r11,%rdx)
      pextrw  $4, %xmm2, %eax
      movw    %ax, (%r10,%rcx)
      pextrw  $5, %xmm2, %eax
      movw    %ax, (%r11,%rcx)
      pextrw  $6, %xmm2, %eax
      movw    %ax, (%r10,%r8)
      pextrw  $7, %xmm2, %eax
      movw    %ax, (%r11,%r8)
      {$ifdef windows}
      movups  (%rsp), %xmm6
      movups  16(%rsp), %xmm7
      addq    $32, %rsp
      {$endif}
    end;

    i := (i - 1);
  end;
end;
{$else}
{$ifdef cpuaarch64}
function mp3d_synth_a64(zlin16i: PSingle; wwin: PSingle; outblk: PSingle): PSingle; assembler; nostackframe;
{ NEON 合成核（蝶形部分）：与 x86-64 SSE 内核逐句同构、运算顺序一致（位精确）。
  8 个累加结果以 Single 写回 outblk[a0..a3,b0..b3]，尾部 PCM 转换由调用方复用标量
  mp3d_scale_pcm 完成；返回推进后的窗指针。仅用 caller-saved 寄存器，AAPCS64 通用。 }
asm
  mov     x12, x2
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  ld1     {v3.4s}, [x0]
  sub     x9, x0, #3840
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  mov     v6.16b, v5.16b
  fmul    v5.4s, v3.4s, v1.4s
  fmul    v0.4s, v4.4s, v2.4s
  fsub    v5.4s, v5.4s, v0.4s
  mov     v7.16b, v5.16b
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #256
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #3584
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v4.4s, v2.4s
  fmul    v0.4s, v3.4s, v1.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #512
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #3328
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v3.4s, v1.4s
  fmul    v0.4s, v4.4s, v2.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #768
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #3072
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v4.4s, v2.4s
  fmul    v0.4s, v3.4s, v1.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #1024
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #2816
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v3.4s, v1.4s
  fmul    v0.4s, v4.4s, v2.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #1280
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #2560
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v4.4s, v2.4s
  fmul    v0.4s, v3.4s, v1.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #1536
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #2304
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v3.4s, v1.4s
  fmul    v0.4s, v4.4s, v2.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  ld1r    {v1.4s}, [x1], #4
  ld1r    {v2.4s}, [x1], #4
  sub     x9, x0, #1792
  ld1     {v3.4s}, [x9]
  sub     x9, x0, #2048
  ld1     {v4.4s}, [x9]
  fmul    v5.4s, v3.4s, v2.4s
  fmul    v0.4s, v4.4s, v1.4s
  fadd    v5.4s, v5.4s, v0.4s
  fadd    v6.4s, v6.4s, v5.4s
  fmul    v5.4s, v4.4s, v2.4s
  fmul    v0.4s, v3.4s, v1.4s
  fsub    v5.4s, v5.4s, v0.4s
  fadd    v7.4s, v7.4s, v5.4s
  st1     {v7.4s}, [x12]
  add     x12, x12, #16
  st1     {v6.4s}, [x12]
  mov     x0, x1
  ret
end;

procedure mp3d_synth(xl: PSingle; dstl: PMp3dSampleT; nch: LongInt; lins: PSingle);
{ aarch64 版：蝶形 NEON + PCM 钳制/截断 NEON，8 样本向量化，与 x86 SSE 尾部同构位精确。 }
var
  i: LongInt;
  xr: PSingle;
  dstr: PMp3dSampleT;
  zlin: PSingle;
  w: PSingle;
  zi, xa, xb: Int64;
  UOff, VOff, POff, QOff: Int64;
  OutBlk: array[0..7] of Single;
begin
  xr := (xl + (576 * (nch - 1)));
  dstr := (dstl + (nch - 1));
  zlin := (lins + (15 * 64));
  w := PSingle(@_static_mp3d_synth_g_win[0]);
  zlin[(4 * 15)] := xl[(18 * 16)];
  zlin[((4 * 15) + 1)] := xr[(18 * 16)];
  zlin[((4 * 15) + 2)] := xl[0];
  zlin[((4 * 15) + 3)] := xr[0];
  zlin[(4 * 31)] := xl[(1 + (18 * 16))];
  zlin[((4 * 31) + 1)] := xr[(1 + (18 * 16))];
  zlin[((4 * 31) + 2)] := xl[1];
  zlin[((4 * 31) + 3)] := xr[1];
  mp3d_synth_pair(dstr, nch, ((lins + (4 * 15)) + 1));
  mp3d_synth_pair((dstr + (32 * nch)), nch, (((lins + (4 * 15)) + 64) + 1));
  mp3d_synth_pair(dstl, nch, (lins + (4 * 15)));
  mp3d_synth_pair((dstl + (32 * nch)), nch, ((lins + (4 * 15)) + 64));
  i := 14;
  while (i >= 0) do
  begin
    zi := (4 * i);
    xa := (18 * (31 - i));
    xb := (18 * (1 + i));
    zlin[zi] := xl[xa];
    zlin[(zi + 1)] := xr[xa];
    zlin[(zi + 2)] := xl[(xa + 1)];
    zlin[(zi + 3)] := xr[(xa + 1)];
    zlin[(zi + 64)] := xl[(xb + 1)];
    zlin[(zi + 65)] := xr[(xb + 1)];
    zlin[(zi - 62)] := xl[xb];
    zlin[(zi - 61)] := xr[xb];
    w := mp3d_synth_a64(@zlin[zi], w, PSingle(@OutBlk[0]));
    UOff := (15 - i) * nch * 2;
    VOff := (17 + i) * nch * 2;
    POff := (47 - i) * nch * 2;
    QOff := (49 + i) * nch * 2;
    mp3d_synth_pcm_neon(@OutBlk[0], dstl, dstr, nch, UOff, VOff, POff, QOff);
    i := (i - 1);
  end;
end;
{$else}
procedure mp3d_synth(xl: PSingle; dstl: PMp3dSampleT; nch: LongInt; lins: PSingle);
{ 手工优化核（可移植标量）：逐车道走完全部蝶形块，每车道活跃浮点集仅 6 个，
  pv/py/w 指针按块步进；v/y 每块单次加载（FPC 不做跨语句 CSE）.
  加数序列与翻译版逐一相同，位精确。窗口基址 wb 每迭代推进 16 float。 }
var
  i: LongInt;
  xr: PSingle;
  dstr: PMp3dSampleT;
  zlin: PSingle;
  w: PSingle;
  p, q, wb: PSingle;
  w0, w1, v, y: Single;
  a0, a1, a2, a3: Single;
  b0, b1, b2, b3: Single;
  zi, xa, xb: Int64;
  UOff, VOff, POff, QOff: Int64;
begin
  xr := (xl + (576 * (nch - 1)));
  dstr := (dstl + (nch - 1));
  zlin := (lins + (15 * 64));
  zlin[(4 * 15)] := xl[(18 * 16)];
  zlin[((4 * 15) + 1)] := xr[(18 * 16)];
  zlin[((4 * 15) + 2)] := xl[0];
  zlin[((4 * 15) + 3)] := xr[0];
  zlin[(4 * 31)] := xl[(1 + (18 * 16))];
  zlin[((4 * 31) + 1)] := xr[(1 + (18 * 16))];
  zlin[((4 * 31) + 2)] := xl[1];
  zlin[((4 * 31) + 3)] := xr[1];
  mp3d_synth_pair(dstr, nch, ((lins + (4 * 15)) + 1));
  mp3d_synth_pair((dstr + (32 * nch)), nch, (((lins + (4 * 15)) + 64) + 1));
  mp3d_synth_pair(dstl, nch, (lins + (4 * 15)));
  mp3d_synth_pair((dstl + (32 * nch)), nch, ((lins + (4 * 15)) + 64));
  wb := PSingle(@_static_mp3d_synth_g_win[0]);
  i := 14;
  while (i >= 0) do
  begin
    zi := (4 * i);
    xa := (18 * (31 - i));
    xb := (18 * (1 + i));
    zlin[zi] := xl[xa];
    zlin[(zi + 1)] := xr[xa];
    zlin[(zi + 2)] := xl[(xa + 1)];
    zlin[(zi + 3)] := xr[(xa + 1)];
    zlin[(zi + 64)] := xl[(xb + 1)];
    zlin[(zi + 65)] := xr[(xb + 1)];
    zlin[(zi - 62)] := xl[xb];
    zlin[(zi - 61)] := xr[xb];

    { 车道 0 }
    p := @zlin[zi];
    q := @zlin[(zi - (15 * 64))];
    w := wb;
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := ((v * w1) + (y * w0));
    a0 := ((v * w0) - (y * w1));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[0];
    y := q[0];
    b0 := (b0 + ((v * w1) + (y * w0)));
    a0 := (a0 + ((y * w1) - (v * w0)));

    { 车道 1 }
    p := @zlin[zi];
    q := @zlin[(zi - (15 * 64))];
    w := wb;
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := ((v * w1) + (y * w0));
    a1 := ((v * w0) - (y * w1));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[1];
    y := q[1];
    b1 := (b1 + ((v * w1) + (y * w0)));
    a1 := (a1 + ((y * w1) - (v * w0)));

    { 车道 2 }
    p := @zlin[zi];
    q := @zlin[(zi - (15 * 64))];
    w := wb;
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := ((v * w1) + (y * w0));
    a2 := ((v * w0) - (y * w1));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[2];
    y := q[2];
    b2 := (b2 + ((v * w1) + (y * w0)));
    a2 := (a2 + ((y * w1) - (v * w0)));

    { 车道 3 }
    p := @zlin[zi];
    q := @zlin[(zi - (15 * 64))];
    w := wb;
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := ((v * w1) + (y * w0));
    a3 := ((v * w0) - (y * w1));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((y * w1) - (v * w0)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((v * w0) - (y * w1)));
    Dec(p, 64);
    Inc(q, 64);
    w0 := w[0];
    w1 := w[1];
    Inc(w, 2);
    v := p[3];
    y := q[3];
    b3 := (b3 + ((v * w1) + (y * w0)));
    a3 := (a3 + ((y * w1) - (v * w0)));

    UOff := ((15 - i) * nch);
    VOff := ((17 + i) * nch);
    POff := ((47 - i) * nch);
    QOff := ((49 + i) * nch);
    dstr[UOff] := TMp3dSampleT(mp3d_scale_pcm(a1));
    dstr[VOff] := TMp3dSampleT(mp3d_scale_pcm(b1));
    dstl[UOff] := TMp3dSampleT(mp3d_scale_pcm(a0));
    dstl[VOff] := TMp3dSampleT(mp3d_scale_pcm(b0));
    dstr[POff] := TMp3dSampleT(mp3d_scale_pcm(a3));
    dstr[QOff] := TMp3dSampleT(mp3d_scale_pcm(b3));
    dstl[POff] := TMp3dSampleT(mp3d_scale_pcm(a2));
    dstl[QOff] := TMp3dSampleT(mp3d_scale_pcm(b2));
    Inc(wb, 16);
    i := (i - 1);
  end;
end;
{$endif}
{$endif MP3DEC_SIMD_ON}

procedure mp3d_synth_granule(qmf_state: PSingle; grbuf: PSingle; nbands: LongInt; nch: LongInt; pcm: PMp3dSampleT; lins: PSingle);
label _L__for0_step, _L__for1_step, _L__for2_step;
var
  i: LongInt;
begin
  i := 0;
  while (i < nch) do
  begin
    mp3d_DCT_II((grbuf + (576 * i)), nbands);
    _L__for0_step:
    i := (i + 1);
  end;
  __c2p_stdlib_memcpy(lins, qmf_state, TSizeT(QWord((QWord((4 * QWord(15))) * QWord(64)))));
  i := 0;
  while (i < nbands) do
  begin
    mp3d_synth((grbuf + i), (pcm + ((32 * nch) * i)), nch, (lins + (i * 64)));
    _L__for1_step:
    i := (i + 2);
  end;
  if (nch = 1) then
  begin
    i := 0;
    while (i < (15 * 64)) do
    begin
      qmf_state[i] := lins[((nbands * 64) + i)];
      _L__for2_step:
      i := (i + 2);
    end;
  end
  else
  begin
    __c2p_stdlib_memcpy(qmf_state, (lins + (nbands * 64)), TSizeT(QWord((QWord((4 * QWord(15))) * QWord(64)))));
  end;
end;

function mp3d_match_frame(hdr: PUint8T; mp3_bytes: LongInt; frame_bytes: LongInt): LongInt; inline;
label _L__for0_step;
var
  i: LongInt;
  nmatch: LongInt;
begin
  i := 0;
  nmatch := 0;
  while (nmatch < 10) do
  begin
    i := (i + (hdr_frame_bytes((hdr + i), frame_bytes) + hdr_padding((hdr + i))));
    if ((i + 4) > mp3_bytes) then
    begin
      Result := LongInt((nmatch > 0));
      System.Exit;
    end;
    if (hdr_compare(hdr, (hdr + i)) = 0) then
    begin
      Result := 0;
      System.Exit;
    end;
    _L__for0_step:
    nmatch := (nmatch + 1);
  end;
  Result := 1;
end;

function mp3d_find_frame(mp3: PUint8T; mp3_bytes: LongInt; free_format_bytes: PLongInt; ptr_frame_bytes: PLongInt): LongInt;
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  k: LongInt;
  frame_bytes: LongInt;
  frame_and_padding: LongInt;
  fb: LongInt;
  nextfb: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp1: LongInt;
begin
  i := 0;
  while (i < (mp3_bytes - 4)) do
  begin
    if (hdr_valid(mp3) <> 0) then
    begin
      frame_bytes := hdr_frame_bytes(mp3, free_format_bytes^);
      frame_and_padding := (frame_bytes + hdr_padding(mp3));
      k := 4;
      while (((frame_bytes = 0) and (k < 2304)) and ((i + (2 * k)) < (mp3_bytes - 4))) do
      begin
        if (hdr_compare(mp3, (mp3 + k)) <> 0) then
        begin
          fb := (k - hdr_padding(mp3));
          nextfb := (fb + hdr_padding((mp3 + k)));
          __c2p_tmp1 := LongInt(1);
          if (((((i + k) + nextfb) + 4) > mp3_bytes) = False) then
          begin
            __c2p_tmp1 := LongInt((hdr_compare(mp3, ((mp3 + k) + nextfb)) = 0));
          end;
          if (__c2p_tmp1 <> 0) then
          begin
            goto _L__for1_step;
          end;
          frame_and_padding := k;
          frame_bytes := fb;
          free_format_bytes^ := fb;
        end;
        _L__for1_step:
        k := (k + 1);
      end;
      __c2p_tmp2 := LongInt(1);
      __c2p_tmp3 := LongInt(0);
      if ((frame_bytes <> 0) and ((i + frame_and_padding) <= mp3_bytes)) then
      begin
        __c2p_tmp3 := LongInt((mp3d_match_frame(mp3, (mp3_bytes - i), frame_bytes) <> 0));
      end;
      if (__c2p_tmp3 = 0) then
      begin
        __c2p_tmp2 := LongInt(((i = 0) and (frame_and_padding = mp3_bytes)));
      end;
      if (__c2p_tmp2 <> 0) then
      begin
        ptr_frame_bytes^ := frame_and_padding;
        Result := i;
        System.Exit;
      end;
      free_format_bytes^ := 0;
    end;
    _L__for0_step:
    i := (i + 1);
    mp3 := (mp3 + 1);
  end;
  ptr_frame_bytes^ := 0;
  Result := mp3_bytes;
end;

procedure mp3dec_init(dec: PMp3decT); cdecl; public name 'mp3dec_init'; inline;
begin
  dec^.header[0] := Byte(0);
end;

function mp3dec_decode_frame(dec: PMp3decT; mp3: PUint8T; mp3_bytes: LongInt; pcm: PMp3dSampleT; info: PMp3decFrameInfoT): LongInt; cdecl; public name 'mp3dec_decode_frame';
label _L__for0_step, _L__for1_step;
var
  i: LongInt;
  igr: LongInt;
  frame_size: LongInt;
  success: LongInt;
  hdr: PUint8T;
  bs_frame: array[0..0] of TBsT;
  scratch_2: TMp3decScratchT;
  main_data_begin: LongInt;
  sci: array[0..0] of TL12ScaleInfo;
  __c2p_tmp1: LongInt;
  __c2p_tmp4: LongInt;
  __c2p_tmp2: LongInt;
  __c2p_tmp3: LongInt;
  __c2p_tmp5: LongInt;
  __c2p_tmp6: LongInt;
begin
  i := 0;
  frame_size := 0;
  success := 1;
  __c2p_tmp1 := LongInt(0);
  if ((mp3_bytes > 4) and (dec^.header[0] = 255)) then
  begin
    __c2p_tmp1 := LongInt((hdr_compare(PUint8T(@dec^.header[0]), mp3) <> 0));
  end;
  if (__c2p_tmp1 <> 0) then
  begin
    frame_size := (hdr_frame_bytes(mp3, dec^.free_format_bytes) + hdr_padding(mp3));
    __c2p_tmp2 := LongInt(0);
    if (frame_size <> mp3_bytes) then
    begin
      __c2p_tmp3 := LongInt(1);
      if (((frame_size + 4) > mp3_bytes) = False) then
      begin
        __c2p_tmp3 := LongInt((hdr_compare(mp3, (mp3 + frame_size)) = 0));
      end;
      __c2p_tmp2 := LongInt((__c2p_tmp3 <> 0));
    end;
    if (__c2p_tmp2 <> 0) then
    begin
      frame_size := 0;
    end;
  end;
  if (frame_size = 0) then
  begin
    __c2p_stdlib_memset(dec, 0, TSizeT(6668));
    i := mp3d_find_frame(mp3, mp3_bytes, @dec^.free_format_bytes, @frame_size);
    if ((frame_size = 0) or ((i + frame_size) > mp3_bytes)) then
    begin
      info^.frame_bytes := i;
      Result := 0;
      System.Exit;
    end;
  end;
  hdr := (mp3 + i);
  __c2p_stdlib_memcpy(Pointer(@dec^.header[0]), hdr, TSizeT(4));
  info^.frame_bytes := (i + frame_size);
  info^.frame_offset := i;
  if ((LongInt(hdr[3]) and 192) = 192) then
  begin
    __c2p_tmp4 := 1;
  end
  else
  begin
    __c2p_tmp4 := 2;
  end;
  info^.channels := __c2p_tmp4;
  info^.hz := LongInt(hdr_sample_rate_hz(hdr));
  info^.layer := (4 - ((LongInt(hdr[1]) shr 1) and 3));
  info^.bitrate_kbps := LongInt(hdr_bitrate_kbps(hdr));
  if (pcm = nil) then
  begin
    Result := hdr_frame_samples(hdr);
    System.Exit;
  end;
  bs_init(PBsT(@bs_frame[0]), (hdr + 4), (frame_size - 4));
  if ((LongInt(hdr[1]) and 1) = 0) then
  begin
    get_bits(PBsT(@bs_frame[0]), 16);
  end;
  if (info^.layer = 3) then
  begin
    main_data_begin := L3_read_side_info(PBsT(@bs_frame[0]), PL3GrInfoT(@scratch_2.gr_info[0]), hdr);
    if ((main_data_begin < 0) or (bs_frame[0].pos > bs_frame[0].limit)) then
    begin
      mp3dec_init(dec);
      Result := 0;
      System.Exit;
    end;
    success := L3_restore_reservoir(dec, PBsT(@bs_frame[0]), @scratch_2, main_data_begin);
    if (success <> 0) then
    begin
      igr := 0;
      while True do
      begin
        if ((LongInt(hdr[1]) and 8) <> 0) then
        begin
          __c2p_tmp5 := 2;
        end
        else
        begin
          __c2p_tmp5 := 1;
        end;
        if ((igr < __c2p_tmp5) = False) then
        begin
          Break;
        end;
        __c2p_stdlib_memset(Pointer(@scratch_2.grbuf[0][0]), 0, TSizeT(QWord((QWord((576 * 2)) * 4))));
        L3_decode(dec, @scratch_2, (PL3GrInfoT(@scratch_2.gr_info[0]) + (igr * info^.channels)), info^.channels);
        mp3d_synth_granule(PSingle(@dec^.qmf_state[0]), PSingle(@scratch_2.grbuf[0][0]), 18, info^.channels, pcm, PSingle(@scratch_2.syn[0][0]));
        _L__for0_step:
        igr := (igr + 1);
        pcm := (pcm + (576 * info^.channels));
      end;
    end;
    L3_save_reservoir(dec, @scratch_2);
  end
  else
  begin
    L12_read_scale_info(hdr, PBsT(@bs_frame[0]), PL12ScaleInfo(@sci[0]));
    __c2p_stdlib_memset(Pointer(@scratch_2.grbuf[0][0]), 0, TSizeT(QWord((QWord((576 * 2)) * 4))));
    i := 0;
    igr := 0;
    while (igr < 3) do
    begin
      __c2p_tmp6 := (i + L12_dequantize_granule((PSingle(@scratch_2.grbuf[0][0]) + i), PBsT(@bs_frame[0]), PL12ScaleInfo(@sci[0]), (info^.layer or 1)));
      i := __c2p_tmp6;
      if (12 = __c2p_tmp6) then
      begin
        i := 0;
        L12_apply_scf_384(PL12ScaleInfo(@sci[0]), (PSingle(@sci[0].scf[0]) + igr), PSingle(@scratch_2.grbuf[0][0]));
        mp3d_synth_granule(PSingle(@dec^.qmf_state[0]), PSingle(@scratch_2.grbuf[0][0]), 12, info^.channels, pcm, PSingle(@scratch_2.syn[0][0]));
        __c2p_stdlib_memset(Pointer(@scratch_2.grbuf[0][0]), 0, TSizeT(QWord((QWord((576 * 2)) * 4))));
        pcm := (pcm + (384 * info^.channels));
      end;
      if (bs_frame[0].pos > bs_frame[0].limit) then
      begin
        mp3dec_init(dec);
        Result := 0;
        System.Exit;
      end;
      _L__for1_step:
      igr := (igr + 1);
    end;
  end;
  Result := LongWord((LongWord(success) * hdr_frame_samples(PUint8T(@dec^.header[0]))));
end;

procedure __c2p_static_fill_mp3dec;
begin
  if __c2p_static_filled_mp3dec then Exit;
  __c2p_static_filled_mp3dec := True;
  FillChar(g_pow43, SizeOf(g_pow43), 0);
  g_pow43[0] := 0;
  g_pow43[1] := -1;
  g_pow43[2] := -Single(2.519842);
  g_pow43[3] := -Single(4.326749);
  g_pow43[4] := -Single(6.349604);
  g_pow43[5] := -Single(8.549880);
  g_pow43[6] := -Single(10.902724);
  g_pow43[7] := -Single(13.390518);
  g_pow43[8] := -Single(16.000000);
  g_pow43[9] := -Single(18.720754);
  g_pow43[10] := -Single(21.544347);
  g_pow43[11] := -Single(24.463781);
  g_pow43[12] := -Single(27.473142);
  g_pow43[13] := -Single(30.567351);
  g_pow43[14] := -Single(33.741992);
  g_pow43[15] := -Single(36.993181);
  g_pow43[16] := 0;
  g_pow43[17] := 1;
  g_pow43[18] := Single(2.519842);
  g_pow43[19] := Single(4.326749);
  g_pow43[20] := Single(6.349604);
  g_pow43[21] := Single(8.549880);
  g_pow43[22] := Single(10.902724);
  g_pow43[23] := Single(13.390518);
  g_pow43[24] := Single(16.000000);
  g_pow43[25] := Single(18.720754);
  g_pow43[26] := Single(21.544347);
  g_pow43[27] := Single(24.463781);
  g_pow43[28] := Single(27.473142);
  g_pow43[29] := Single(30.567351);
  g_pow43[30] := Single(33.741992);
  g_pow43[31] := Single(36.993181);
  g_pow43[32] := Single(40.317474);
  g_pow43[33] := Single(43.711787);
  g_pow43[34] := Single(47.173345);
  g_pow43[35] := Single(50.699631);
  g_pow43[36] := Single(54.288352);
  g_pow43[37] := Single(57.937408);
  g_pow43[38] := Single(61.644865);
  g_pow43[39] := Single(65.408941);
  g_pow43[40] := Single(69.227979);
  g_pow43[41] := Single(73.100443);
  g_pow43[42] := Single(77.024898);
  g_pow43[43] := Single(81.000000);
  g_pow43[44] := Single(85.024491);
  g_pow43[45] := Single(89.097188);
  g_pow43[46] := Single(93.216975);
  g_pow43[47] := Single(97.382800);
  g_pow43[48] := Single(101.593667);
  g_pow43[49] := Single(105.848633);
  g_pow43[50] := Single(110.146801);
  g_pow43[51] := Single(114.487321);
  g_pow43[52] := Single(118.869381);
  g_pow43[53] := Single(123.292209);
  g_pow43[54] := Single(127.755065);
  g_pow43[55] := Single(132.257246);
  g_pow43[56] := Single(136.798076);
  g_pow43[57] := Single(141.376907);
  g_pow43[58] := Single(145.993119);
  g_pow43[59] := Single(150.646117);
  g_pow43[60] := Single(155.335327);
  g_pow43[61] := Single(160.060199);
  g_pow43[62] := Single(164.820202);
  g_pow43[63] := Single(169.614826);
  g_pow43[64] := Single(174.443577);
  g_pow43[65] := Single(179.305980);
  g_pow43[66] := Single(184.201575);
  g_pow43[67] := Single(189.129918);
  g_pow43[68] := Single(194.090580);
  g_pow43[69] := Single(199.083145);
  g_pow43[70] := Single(204.107210);
  g_pow43[71] := Single(209.162385);
  g_pow43[72] := Single(214.248292);
  g_pow43[73] := Single(219.364564);
  g_pow43[74] := Single(224.510845);
  g_pow43[75] := Single(229.686789);
  g_pow43[76] := Single(234.892058);
  g_pow43[77] := Single(240.126328);
  g_pow43[78] := Single(245.389280);
  g_pow43[79] := Single(250.680604);
  g_pow43[80] := Single(256.000000);
  g_pow43[81] := Single(261.347174);
  g_pow43[82] := Single(266.721841);
  g_pow43[83] := Single(272.123723);
  g_pow43[84] := Single(277.552547);
  g_pow43[85] := Single(283.008049);
  g_pow43[86] := Single(288.489971);
  g_pow43[87] := Single(293.998060);
  g_pow43[88] := Single(299.532071);
  g_pow43[89] := Single(305.091761);
  g_pow43[90] := Single(310.676898);
  g_pow43[91] := Single(316.287249);
  g_pow43[92] := Single(321.922592);
  g_pow43[93] := Single(327.582707);
  g_pow43[94] := Single(333.267377);
  g_pow43[95] := Single(338.976394);
  g_pow43[96] := Single(344.709550);
  g_pow43[97] := Single(350.466646);
  g_pow43[98] := Single(356.247482);
  g_pow43[99] := Single(362.051866);
  g_pow43[100] := Single(367.879608);
  g_pow43[101] := Single(373.730522);
  g_pow43[102] := Single(379.604427);
  g_pow43[103] := Single(385.501143);
  g_pow43[104] := Single(391.420496);
  g_pow43[105] := Single(397.362314);
  g_pow43[106] := Single(403.326427);
  g_pow43[107] := Single(409.312672);
  g_pow43[108] := Single(415.320884);
  g_pow43[109] := Single(421.350905);
  g_pow43[110] := Single(427.402579);
  g_pow43[111] := Single(433.475750);
  g_pow43[112] := Single(439.570269);
  g_pow43[113] := Single(445.685987);
  g_pow43[114] := Single(451.822757);
  g_pow43[115] := Single(457.980436);
  g_pow43[116] := Single(464.158883);
  g_pow43[117] := Single(470.357960);
  g_pow43[118] := Single(476.577530);
  g_pow43[119] := Single(482.817459);
  g_pow43[120] := Single(489.077615);
  g_pow43[121] := Single(495.357868);
  g_pow43[122] := Single(501.658090);
  g_pow43[123] := Single(507.978156);
  g_pow43[124] := Single(514.317941);
  g_pow43[125] := Single(520.677324);
  g_pow43[126] := Single(527.056184);
  g_pow43[127] := Single(533.454404);
  g_pow43[128] := Single(539.871867);
  g_pow43[129] := Single(546.308458);
  g_pow43[130] := Single(552.764065);
  g_pow43[131] := Single(559.238575);
  g_pow43[132] := Single(565.731879);
  g_pow43[133] := Single(572.243870);
  g_pow43[134] := Single(578.774440);
  g_pow43[135] := Single(585.323483);
  g_pow43[136] := Single(591.890898);
  g_pow43[137] := Single(598.476581);
  g_pow43[138] := Single(605.080431);
  g_pow43[139] := Single(611.702349);
  g_pow43[140] := Single(618.342238);
  g_pow43[141] := Single(625.000000);
  g_pow43[142] := Single(631.675540);
  g_pow43[143] := Single(638.368763);
  g_pow43[144] := Single(645.079578);
  FillChar(_static_hdr_bitrate_kbps_halfrate, SizeOf(_static_hdr_bitrate_kbps_halfrate), 0);
  _static_hdr_bitrate_kbps_halfrate[0][0][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[0][0][1] := TUint8T(4);
  _static_hdr_bitrate_kbps_halfrate[0][0][2] := TUint8T(8);
  _static_hdr_bitrate_kbps_halfrate[0][0][3] := TUint8T(12);
  _static_hdr_bitrate_kbps_halfrate[0][0][4] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[0][0][5] := TUint8T(20);
  _static_hdr_bitrate_kbps_halfrate[0][0][6] := TUint8T(24);
  _static_hdr_bitrate_kbps_halfrate[0][0][7] := TUint8T(28);
  _static_hdr_bitrate_kbps_halfrate[0][0][8] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[0][0][9] := TUint8T(40);
  _static_hdr_bitrate_kbps_halfrate[0][0][10] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[0][0][11] := TUint8T(56);
  _static_hdr_bitrate_kbps_halfrate[0][0][12] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[0][0][13] := TUint8T(72);
  _static_hdr_bitrate_kbps_halfrate[0][0][14] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[0][1][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[0][1][1] := TUint8T(4);
  _static_hdr_bitrate_kbps_halfrate[0][1][2] := TUint8T(8);
  _static_hdr_bitrate_kbps_halfrate[0][1][3] := TUint8T(12);
  _static_hdr_bitrate_kbps_halfrate[0][1][4] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[0][1][5] := TUint8T(20);
  _static_hdr_bitrate_kbps_halfrate[0][1][6] := TUint8T(24);
  _static_hdr_bitrate_kbps_halfrate[0][1][7] := TUint8T(28);
  _static_hdr_bitrate_kbps_halfrate[0][1][8] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[0][1][9] := TUint8T(40);
  _static_hdr_bitrate_kbps_halfrate[0][1][10] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[0][1][11] := TUint8T(56);
  _static_hdr_bitrate_kbps_halfrate[0][1][12] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[0][1][13] := TUint8T(72);
  _static_hdr_bitrate_kbps_halfrate[0][1][14] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[0][2][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[0][2][1] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[0][2][2] := TUint8T(24);
  _static_hdr_bitrate_kbps_halfrate[0][2][3] := TUint8T(28);
  _static_hdr_bitrate_kbps_halfrate[0][2][4] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[0][2][5] := TUint8T(40);
  _static_hdr_bitrate_kbps_halfrate[0][2][6] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[0][2][7] := TUint8T(56);
  _static_hdr_bitrate_kbps_halfrate[0][2][8] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[0][2][9] := TUint8T(72);
  _static_hdr_bitrate_kbps_halfrate[0][2][10] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[0][2][11] := TUint8T(88);
  _static_hdr_bitrate_kbps_halfrate[0][2][12] := TUint8T(96);
  _static_hdr_bitrate_kbps_halfrate[0][2][13] := TUint8T(112);
  _static_hdr_bitrate_kbps_halfrate[0][2][14] := TUint8T(128);
  _static_hdr_bitrate_kbps_halfrate[1][0][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[1][0][1] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[1][0][2] := TUint8T(20);
  _static_hdr_bitrate_kbps_halfrate[1][0][3] := TUint8T(24);
  _static_hdr_bitrate_kbps_halfrate[1][0][4] := TUint8T(28);
  _static_hdr_bitrate_kbps_halfrate[1][0][5] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[1][0][6] := TUint8T(40);
  _static_hdr_bitrate_kbps_halfrate[1][0][7] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[1][0][8] := TUint8T(56);
  _static_hdr_bitrate_kbps_halfrate[1][0][9] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[1][0][10] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[1][0][11] := TUint8T(96);
  _static_hdr_bitrate_kbps_halfrate[1][0][12] := TUint8T(112);
  _static_hdr_bitrate_kbps_halfrate[1][0][13] := TUint8T(128);
  _static_hdr_bitrate_kbps_halfrate[1][0][14] := TUint8T(160);
  _static_hdr_bitrate_kbps_halfrate[1][1][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[1][1][1] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[1][1][2] := TUint8T(24);
  _static_hdr_bitrate_kbps_halfrate[1][1][3] := TUint8T(28);
  _static_hdr_bitrate_kbps_halfrate[1][1][4] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[1][1][5] := TUint8T(40);
  _static_hdr_bitrate_kbps_halfrate[1][1][6] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[1][1][7] := TUint8T(56);
  _static_hdr_bitrate_kbps_halfrate[1][1][8] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[1][1][9] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[1][1][10] := TUint8T(96);
  _static_hdr_bitrate_kbps_halfrate[1][1][11] := TUint8T(112);
  _static_hdr_bitrate_kbps_halfrate[1][1][12] := TUint8T(128);
  _static_hdr_bitrate_kbps_halfrate[1][1][13] := TUint8T(160);
  _static_hdr_bitrate_kbps_halfrate[1][1][14] := TUint8T(192);
  _static_hdr_bitrate_kbps_halfrate[1][2][0] := TUint8T(0);
  _static_hdr_bitrate_kbps_halfrate[1][2][1] := TUint8T(16);
  _static_hdr_bitrate_kbps_halfrate[1][2][2] := TUint8T(32);
  _static_hdr_bitrate_kbps_halfrate[1][2][3] := TUint8T(48);
  _static_hdr_bitrate_kbps_halfrate[1][2][4] := TUint8T(64);
  _static_hdr_bitrate_kbps_halfrate[1][2][5] := TUint8T(80);
  _static_hdr_bitrate_kbps_halfrate[1][2][6] := TUint8T(96);
  _static_hdr_bitrate_kbps_halfrate[1][2][7] := TUint8T(112);
  _static_hdr_bitrate_kbps_halfrate[1][2][8] := TUint8T(128);
  _static_hdr_bitrate_kbps_halfrate[1][2][9] := TUint8T(144);
  _static_hdr_bitrate_kbps_halfrate[1][2][10] := TUint8T(160);
  _static_hdr_bitrate_kbps_halfrate[1][2][11] := TUint8T(176);
  _static_hdr_bitrate_kbps_halfrate[1][2][12] := TUint8T(192);
  _static_hdr_bitrate_kbps_halfrate[1][2][13] := TUint8T(208);
  _static_hdr_bitrate_kbps_halfrate[1][2][14] := TUint8T(224);
  FillChar(_static_hdr_sample_rate_hz_g_hz, SizeOf(_static_hdr_sample_rate_hz_g_hz), 0);
  _static_hdr_sample_rate_hz_g_hz[0] := LongWord(44100);
  _static_hdr_sample_rate_hz_g_hz[1] := LongWord(48000);
  _static_hdr_sample_rate_hz_g_hz[2] := LongWord(32000);
  FillChar(_static_L12_subband_alloc_table_g_alloc_L1, SizeOf(_static_L12_subband_alloc_table_g_alloc_L1), 0);
  _static_L12_subband_alloc_table_g_alloc_L1[0].tab_offset := TUint8T(76);
  _static_L12_subband_alloc_table_g_alloc_L1[0].code_tab_width := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L1[0].band_count := TUint8T(32);
  FillChar(_static_L12_subband_alloc_table_g_alloc_L2M2, SizeOf(_static_L12_subband_alloc_table_g_alloc_L2M2), 0);
  _static_L12_subband_alloc_table_g_alloc_L2M2[0].tab_offset := TUint8T(60);
  _static_L12_subband_alloc_table_g_alloc_L2M2[0].code_tab_width := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L2M2[0].band_count := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L2M2[1].tab_offset := TUint8T(44);
  _static_L12_subband_alloc_table_g_alloc_L2M2[1].code_tab_width := TUint8T(3);
  _static_L12_subband_alloc_table_g_alloc_L2M2[1].band_count := TUint8T(7);
  _static_L12_subband_alloc_table_g_alloc_L2M2[2].tab_offset := TUint8T(44);
  _static_L12_subband_alloc_table_g_alloc_L2M2[2].code_tab_width := TUint8T(2);
  _static_L12_subband_alloc_table_g_alloc_L2M2[2].band_count := TUint8T(19);
  FillChar(_static_L12_subband_alloc_table_g_alloc_L2M1, SizeOf(_static_L12_subband_alloc_table_g_alloc_L2M1), 0);
  _static_L12_subband_alloc_table_g_alloc_L2M1[0].tab_offset := TUint8T(0);
  _static_L12_subband_alloc_table_g_alloc_L2M1[0].code_tab_width := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L2M1[0].band_count := TUint8T(3);
  _static_L12_subband_alloc_table_g_alloc_L2M1[1].tab_offset := TUint8T(16);
  _static_L12_subband_alloc_table_g_alloc_L2M1[1].code_tab_width := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L2M1[1].band_count := TUint8T(8);
  _static_L12_subband_alloc_table_g_alloc_L2M1[2].tab_offset := TUint8T(32);
  _static_L12_subband_alloc_table_g_alloc_L2M1[2].code_tab_width := TUint8T(3);
  _static_L12_subband_alloc_table_g_alloc_L2M1[2].band_count := TUint8T(12);
  _static_L12_subband_alloc_table_g_alloc_L2M1[3].tab_offset := TUint8T(40);
  _static_L12_subband_alloc_table_g_alloc_L2M1[3].code_tab_width := TUint8T(2);
  _static_L12_subband_alloc_table_g_alloc_L2M1[3].band_count := TUint8T(7);
  FillChar(_static_L12_subband_alloc_table_g_alloc_L2M1_lowrate, SizeOf(_static_L12_subband_alloc_table_g_alloc_L2M1_lowrate), 0);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[0].tab_offset := TUint8T(44);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[0].code_tab_width := TUint8T(4);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[0].band_count := TUint8T(2);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[1].tab_offset := TUint8T(44);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[1].code_tab_width := TUint8T(3);
  _static_L12_subband_alloc_table_g_alloc_L2M1_lowrate[1].band_count := TUint8T(10);
  FillChar(_static_L12_read_scalefactors_g_deq_L12, SizeOf(_static_L12_read_scalefactors_g_deq_L12), 0);
  _static_L12_read_scalefactors_g_deq_L12[0] := (Single(9.53674316e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[1] := (Single(7.56931807e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[2] := (Single(6.00777173e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[3] := (Single(9.53674316e-07) / 7);
  _static_L12_read_scalefactors_g_deq_L12[4] := (Single(7.56931807e-07) / 7);
  _static_L12_read_scalefactors_g_deq_L12[5] := (Single(6.00777173e-07) / 7);
  _static_L12_read_scalefactors_g_deq_L12[6] := (Single(9.53674316e-07) / 15);
  _static_L12_read_scalefactors_g_deq_L12[7] := (Single(7.56931807e-07) / 15);
  _static_L12_read_scalefactors_g_deq_L12[8] := (Single(6.00777173e-07) / 15);
  _static_L12_read_scalefactors_g_deq_L12[9] := (Single(9.53674316e-07) / 31);
  _static_L12_read_scalefactors_g_deq_L12[10] := (Single(7.56931807e-07) / 31);
  _static_L12_read_scalefactors_g_deq_L12[11] := (Single(6.00777173e-07) / 31);
  _static_L12_read_scalefactors_g_deq_L12[12] := (Single(9.53674316e-07) / 63);
  _static_L12_read_scalefactors_g_deq_L12[13] := (Single(7.56931807e-07) / 63);
  _static_L12_read_scalefactors_g_deq_L12[14] := (Single(6.00777173e-07) / 63);
  _static_L12_read_scalefactors_g_deq_L12[15] := (Single(9.53674316e-07) / 127);
  _static_L12_read_scalefactors_g_deq_L12[16] := (Single(7.56931807e-07) / 127);
  _static_L12_read_scalefactors_g_deq_L12[17] := (Single(6.00777173e-07) / 127);
  _static_L12_read_scalefactors_g_deq_L12[18] := (Single(9.53674316e-07) / 255);
  _static_L12_read_scalefactors_g_deq_L12[19] := (Single(7.56931807e-07) / 255);
  _static_L12_read_scalefactors_g_deq_L12[20] := (Single(6.00777173e-07) / 255);
  _static_L12_read_scalefactors_g_deq_L12[21] := (Single(9.53674316e-07) / 511);
  _static_L12_read_scalefactors_g_deq_L12[22] := (Single(7.56931807e-07) / 511);
  _static_L12_read_scalefactors_g_deq_L12[23] := (Single(6.00777173e-07) / 511);
  _static_L12_read_scalefactors_g_deq_L12[24] := (Single(9.53674316e-07) / 1023);
  _static_L12_read_scalefactors_g_deq_L12[25] := (Single(7.56931807e-07) / 1023);
  _static_L12_read_scalefactors_g_deq_L12[26] := (Single(6.00777173e-07) / 1023);
  _static_L12_read_scalefactors_g_deq_L12[27] := (Single(9.53674316e-07) / 2047);
  _static_L12_read_scalefactors_g_deq_L12[28] := (Single(7.56931807e-07) / 2047);
  _static_L12_read_scalefactors_g_deq_L12[29] := (Single(6.00777173e-07) / 2047);
  _static_L12_read_scalefactors_g_deq_L12[30] := (Single(9.53674316e-07) / 4095);
  _static_L12_read_scalefactors_g_deq_L12[31] := (Single(7.56931807e-07) / 4095);
  _static_L12_read_scalefactors_g_deq_L12[32] := (Single(6.00777173e-07) / 4095);
  _static_L12_read_scalefactors_g_deq_L12[33] := (Single(9.53674316e-07) / 8191);
  _static_L12_read_scalefactors_g_deq_L12[34] := (Single(7.56931807e-07) / 8191);
  _static_L12_read_scalefactors_g_deq_L12[35] := (Single(6.00777173e-07) / 8191);
  _static_L12_read_scalefactors_g_deq_L12[36] := (Single(9.53674316e-07) / 16383);
  _static_L12_read_scalefactors_g_deq_L12[37] := (Single(7.56931807e-07) / 16383);
  _static_L12_read_scalefactors_g_deq_L12[38] := (Single(6.00777173e-07) / 16383);
  _static_L12_read_scalefactors_g_deq_L12[39] := (Single(9.53674316e-07) / 32767);
  _static_L12_read_scalefactors_g_deq_L12[40] := (Single(7.56931807e-07) / 32767);
  _static_L12_read_scalefactors_g_deq_L12[41] := (Single(6.00777173e-07) / 32767);
  _static_L12_read_scalefactors_g_deq_L12[42] := (Single(9.53674316e-07) / 65535);
  _static_L12_read_scalefactors_g_deq_L12[43] := (Single(7.56931807e-07) / 65535);
  _static_L12_read_scalefactors_g_deq_L12[44] := (Single(6.00777173e-07) / 65535);
  _static_L12_read_scalefactors_g_deq_L12[45] := (Single(9.53674316e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[46] := (Single(7.56931807e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[47] := (Single(6.00777173e-07) / 3);
  _static_L12_read_scalefactors_g_deq_L12[48] := (Single(9.53674316e-07) / 5);
  _static_L12_read_scalefactors_g_deq_L12[49] := (Single(7.56931807e-07) / 5);
  _static_L12_read_scalefactors_g_deq_L12[50] := (Single(6.00777173e-07) / 5);
  _static_L12_read_scalefactors_g_deq_L12[51] := (Single(9.53674316e-07) / 9);
  _static_L12_read_scalefactors_g_deq_L12[52] := (Single(7.56931807e-07) / 9);
  _static_L12_read_scalefactors_g_deq_L12[53] := (Single(6.00777173e-07) / 9);
  FillChar(_static_L12_read_scale_info_g_bitalloc_code_tab, SizeOf(_static_L12_read_scale_info_g_bitalloc_code_tab), 0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[0] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[1] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[2] := TUint8T(3);
  _static_L12_read_scale_info_g_bitalloc_code_tab[3] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[4] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[5] := TUint8T(6);
  _static_L12_read_scale_info_g_bitalloc_code_tab[6] := TUint8T(7);
  _static_L12_read_scale_info_g_bitalloc_code_tab[7] := TUint8T(8);
  _static_L12_read_scale_info_g_bitalloc_code_tab[8] := TUint8T(9);
  _static_L12_read_scale_info_g_bitalloc_code_tab[9] := TUint8T(10);
  _static_L12_read_scale_info_g_bitalloc_code_tab[10] := TUint8T(11);
  _static_L12_read_scale_info_g_bitalloc_code_tab[11] := TUint8T(12);
  _static_L12_read_scale_info_g_bitalloc_code_tab[12] := TUint8T(13);
  _static_L12_read_scale_info_g_bitalloc_code_tab[13] := TUint8T(14);
  _static_L12_read_scale_info_g_bitalloc_code_tab[14] := TUint8T(15);
  _static_L12_read_scale_info_g_bitalloc_code_tab[15] := TUint8T(16);
  _static_L12_read_scale_info_g_bitalloc_code_tab[16] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[17] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[18] := TUint8T(18);
  _static_L12_read_scale_info_g_bitalloc_code_tab[19] := TUint8T(3);
  _static_L12_read_scale_info_g_bitalloc_code_tab[20] := TUint8T(19);
  _static_L12_read_scale_info_g_bitalloc_code_tab[21] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[22] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[23] := TUint8T(6);
  _static_L12_read_scale_info_g_bitalloc_code_tab[24] := TUint8T(7);
  _static_L12_read_scale_info_g_bitalloc_code_tab[25] := TUint8T(8);
  _static_L12_read_scale_info_g_bitalloc_code_tab[26] := TUint8T(9);
  _static_L12_read_scale_info_g_bitalloc_code_tab[27] := TUint8T(10);
  _static_L12_read_scale_info_g_bitalloc_code_tab[28] := TUint8T(11);
  _static_L12_read_scale_info_g_bitalloc_code_tab[29] := TUint8T(12);
  _static_L12_read_scale_info_g_bitalloc_code_tab[30] := TUint8T(13);
  _static_L12_read_scale_info_g_bitalloc_code_tab[31] := TUint8T(16);
  _static_L12_read_scale_info_g_bitalloc_code_tab[32] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[33] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[34] := TUint8T(18);
  _static_L12_read_scale_info_g_bitalloc_code_tab[35] := TUint8T(3);
  _static_L12_read_scale_info_g_bitalloc_code_tab[36] := TUint8T(19);
  _static_L12_read_scale_info_g_bitalloc_code_tab[37] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[38] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[39] := TUint8T(16);
  _static_L12_read_scale_info_g_bitalloc_code_tab[40] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[41] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[42] := TUint8T(18);
  _static_L12_read_scale_info_g_bitalloc_code_tab[43] := TUint8T(16);
  _static_L12_read_scale_info_g_bitalloc_code_tab[44] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[45] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[46] := TUint8T(18);
  _static_L12_read_scale_info_g_bitalloc_code_tab[47] := TUint8T(19);
  _static_L12_read_scale_info_g_bitalloc_code_tab[48] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[49] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[50] := TUint8T(6);
  _static_L12_read_scale_info_g_bitalloc_code_tab[51] := TUint8T(7);
  _static_L12_read_scale_info_g_bitalloc_code_tab[52] := TUint8T(8);
  _static_L12_read_scale_info_g_bitalloc_code_tab[53] := TUint8T(9);
  _static_L12_read_scale_info_g_bitalloc_code_tab[54] := TUint8T(10);
  _static_L12_read_scale_info_g_bitalloc_code_tab[55] := TUint8T(11);
  _static_L12_read_scale_info_g_bitalloc_code_tab[56] := TUint8T(12);
  _static_L12_read_scale_info_g_bitalloc_code_tab[57] := TUint8T(13);
  _static_L12_read_scale_info_g_bitalloc_code_tab[58] := TUint8T(14);
  _static_L12_read_scale_info_g_bitalloc_code_tab[59] := TUint8T(15);
  _static_L12_read_scale_info_g_bitalloc_code_tab[60] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[61] := TUint8T(17);
  _static_L12_read_scale_info_g_bitalloc_code_tab[62] := TUint8T(18);
  _static_L12_read_scale_info_g_bitalloc_code_tab[63] := TUint8T(3);
  _static_L12_read_scale_info_g_bitalloc_code_tab[64] := TUint8T(19);
  _static_L12_read_scale_info_g_bitalloc_code_tab[65] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[66] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[67] := TUint8T(6);
  _static_L12_read_scale_info_g_bitalloc_code_tab[68] := TUint8T(7);
  _static_L12_read_scale_info_g_bitalloc_code_tab[69] := TUint8T(8);
  _static_L12_read_scale_info_g_bitalloc_code_tab[70] := TUint8T(9);
  _static_L12_read_scale_info_g_bitalloc_code_tab[71] := TUint8T(10);
  _static_L12_read_scale_info_g_bitalloc_code_tab[72] := TUint8T(11);
  _static_L12_read_scale_info_g_bitalloc_code_tab[73] := TUint8T(12);
  _static_L12_read_scale_info_g_bitalloc_code_tab[74] := TUint8T(13);
  _static_L12_read_scale_info_g_bitalloc_code_tab[75] := TUint8T(14);
  _static_L12_read_scale_info_g_bitalloc_code_tab[76] := TUint8T(0);
  _static_L12_read_scale_info_g_bitalloc_code_tab[77] := TUint8T(2);
  _static_L12_read_scale_info_g_bitalloc_code_tab[78] := TUint8T(3);
  _static_L12_read_scale_info_g_bitalloc_code_tab[79] := TUint8T(4);
  _static_L12_read_scale_info_g_bitalloc_code_tab[80] := TUint8T(5);
  _static_L12_read_scale_info_g_bitalloc_code_tab[81] := TUint8T(6);
  _static_L12_read_scale_info_g_bitalloc_code_tab[82] := TUint8T(7);
  _static_L12_read_scale_info_g_bitalloc_code_tab[83] := TUint8T(8);
  _static_L12_read_scale_info_g_bitalloc_code_tab[84] := TUint8T(9);
  _static_L12_read_scale_info_g_bitalloc_code_tab[85] := TUint8T(10);
  _static_L12_read_scale_info_g_bitalloc_code_tab[86] := TUint8T(11);
  _static_L12_read_scale_info_g_bitalloc_code_tab[87] := TUint8T(12);
  _static_L12_read_scale_info_g_bitalloc_code_tab[88] := TUint8T(13);
  _static_L12_read_scale_info_g_bitalloc_code_tab[89] := TUint8T(14);
  _static_L12_read_scale_info_g_bitalloc_code_tab[90] := TUint8T(15);
  _static_L12_read_scale_info_g_bitalloc_code_tab[91] := TUint8T(16);
  FillChar(_static_L3_read_side_info_g_scf_long, SizeOf(_static_L3_read_side_info_g_scf_long), 0);
  _static_L3_read_side_info_g_scf_long[0][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[0][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[0][7] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[0][8] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[0][9] := TUint8T(14);
  _static_L3_read_side_info_g_scf_long[0][10] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[0][11] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[0][12] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[0][13] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[0][14] := TUint8T(32);
  _static_L3_read_side_info_g_scf_long[0][15] := TUint8T(38);
  _static_L3_read_side_info_g_scf_long[0][16] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[0][17] := TUint8T(52);
  _static_L3_read_side_info_g_scf_long[0][18] := TUint8T(60);
  _static_L3_read_side_info_g_scf_long[0][19] := TUint8T(68);
  _static_L3_read_side_info_g_scf_long[0][20] := TUint8T(58);
  _static_L3_read_side_info_g_scf_long[0][21] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[0][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[1][0] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][1] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][2] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][3] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][4] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][5] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[1][6] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[1][7] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[1][8] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[1][9] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[1][10] := TUint8T(32);
  _static_L3_read_side_info_g_scf_long[1][11] := TUint8T(40);
  _static_L3_read_side_info_g_scf_long[1][12] := TUint8T(48);
  _static_L3_read_side_info_g_scf_long[1][13] := TUint8T(56);
  _static_L3_read_side_info_g_scf_long[1][14] := TUint8T(64);
  _static_L3_read_side_info_g_scf_long[1][15] := TUint8T(76);
  _static_L3_read_side_info_g_scf_long[1][16] := TUint8T(90);
  _static_L3_read_side_info_g_scf_long[1][17] := TUint8T(2);
  _static_L3_read_side_info_g_scf_long[1][18] := TUint8T(2);
  _static_L3_read_side_info_g_scf_long[1][19] := TUint8T(2);
  _static_L3_read_side_info_g_scf_long[1][20] := TUint8T(2);
  _static_L3_read_side_info_g_scf_long[1][21] := TUint8T(2);
  _static_L3_read_side_info_g_scf_long[1][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[2][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[2][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[2][7] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[2][8] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[2][9] := TUint8T(14);
  _static_L3_read_side_info_g_scf_long[2][10] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[2][11] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[2][12] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[2][13] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[2][14] := TUint8T(32);
  _static_L3_read_side_info_g_scf_long[2][15] := TUint8T(38);
  _static_L3_read_side_info_g_scf_long[2][16] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[2][17] := TUint8T(52);
  _static_L3_read_side_info_g_scf_long[2][18] := TUint8T(60);
  _static_L3_read_side_info_g_scf_long[2][19] := TUint8T(68);
  _static_L3_read_side_info_g_scf_long[2][20] := TUint8T(58);
  _static_L3_read_side_info_g_scf_long[2][21] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[2][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[3][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[3][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[3][7] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[3][8] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[3][9] := TUint8T(14);
  _static_L3_read_side_info_g_scf_long[3][10] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[3][11] := TUint8T(18);
  _static_L3_read_side_info_g_scf_long[3][12] := TUint8T(22);
  _static_L3_read_side_info_g_scf_long[3][13] := TUint8T(26);
  _static_L3_read_side_info_g_scf_long[3][14] := TUint8T(32);
  _static_L3_read_side_info_g_scf_long[3][15] := TUint8T(38);
  _static_L3_read_side_info_g_scf_long[3][16] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[3][17] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[3][18] := TUint8T(62);
  _static_L3_read_side_info_g_scf_long[3][19] := TUint8T(70);
  _static_L3_read_side_info_g_scf_long[3][20] := TUint8T(76);
  _static_L3_read_side_info_g_scf_long[3][21] := TUint8T(36);
  _static_L3_read_side_info_g_scf_long[3][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[4][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[4][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[4][7] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[4][8] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[4][9] := TUint8T(14);
  _static_L3_read_side_info_g_scf_long[4][10] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[4][11] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[4][12] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[4][13] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[4][14] := TUint8T(32);
  _static_L3_read_side_info_g_scf_long[4][15] := TUint8T(38);
  _static_L3_read_side_info_g_scf_long[4][16] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[4][17] := TUint8T(52);
  _static_L3_read_side_info_g_scf_long[4][18] := TUint8T(60);
  _static_L3_read_side_info_g_scf_long[4][19] := TUint8T(68);
  _static_L3_read_side_info_g_scf_long[4][20] := TUint8T(58);
  _static_L3_read_side_info_g_scf_long[4][21] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[4][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[5][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[5][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[5][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[5][8] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[5][9] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[5][10] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[5][11] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[5][12] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[5][13] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[5][14] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[5][15] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[5][16] := TUint8T(34);
  _static_L3_read_side_info_g_scf_long[5][17] := TUint8T(42);
  _static_L3_read_side_info_g_scf_long[5][18] := TUint8T(50);
  _static_L3_read_side_info_g_scf_long[5][19] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[5][20] := TUint8T(76);
  _static_L3_read_side_info_g_scf_long[5][21] := TUint8T(158);
  _static_L3_read_side_info_g_scf_long[5][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[6][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[6][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[6][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[6][8] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[6][9] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[6][10] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[6][11] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[6][12] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[6][13] := TUint8T(18);
  _static_L3_read_side_info_g_scf_long[6][14] := TUint8T(22);
  _static_L3_read_side_info_g_scf_long[6][15] := TUint8T(28);
  _static_L3_read_side_info_g_scf_long[6][16] := TUint8T(34);
  _static_L3_read_side_info_g_scf_long[6][17] := TUint8T(40);
  _static_L3_read_side_info_g_scf_long[6][18] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[6][19] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[6][20] := TUint8T(54);
  _static_L3_read_side_info_g_scf_long[6][21] := TUint8T(192);
  _static_L3_read_side_info_g_scf_long[6][22] := TUint8T(0);
  _static_L3_read_side_info_g_scf_long[7][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_long[7][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[7][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_long[7][8] := TUint8T(8);
  _static_L3_read_side_info_g_scf_long[7][9] := TUint8T(10);
  _static_L3_read_side_info_g_scf_long[7][10] := TUint8T(12);
  _static_L3_read_side_info_g_scf_long[7][11] := TUint8T(16);
  _static_L3_read_side_info_g_scf_long[7][12] := TUint8T(20);
  _static_L3_read_side_info_g_scf_long[7][13] := TUint8T(24);
  _static_L3_read_side_info_g_scf_long[7][14] := TUint8T(30);
  _static_L3_read_side_info_g_scf_long[7][15] := TUint8T(38);
  _static_L3_read_side_info_g_scf_long[7][16] := TUint8T(46);
  _static_L3_read_side_info_g_scf_long[7][17] := TUint8T(56);
  _static_L3_read_side_info_g_scf_long[7][18] := TUint8T(68);
  _static_L3_read_side_info_g_scf_long[7][19] := TUint8T(84);
  _static_L3_read_side_info_g_scf_long[7][20] := TUint8T(102);
  _static_L3_read_side_info_g_scf_long[7][21] := TUint8T(26);
  _static_L3_read_side_info_g_scf_long[7][22] := TUint8T(0);
  FillChar(_static_L3_read_side_info_g_scf_short, SizeOf(_static_L3_read_side_info_g_scf_short), 0);
  _static_L3_read_side_info_g_scf_short[0][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[0][9] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[0][10] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[0][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[0][12] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[0][13] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[0][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[0][15] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[0][16] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[0][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[0][18] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[0][19] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[0][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[0][21] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[0][22] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[0][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[0][24] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][25] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][26] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][27] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[0][28] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[0][29] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[0][30] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[0][31] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[0][32] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[0][33] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[0][34] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[0][35] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[0][36] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][37] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][38] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[0][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[1][0] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][1] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][2] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][3] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][4] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][5] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][7] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][8] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[1][9] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[1][10] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[1][11] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[1][12] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[1][13] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[1][14] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[1][15] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[1][16] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[1][17] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[1][18] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[1][19] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[1][20] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[1][21] := TUint8T(28);
  _static_L3_read_side_info_g_scf_short[1][22] := TUint8T(28);
  _static_L3_read_side_info_g_scf_short[1][23] := TUint8T(28);
  _static_L3_read_side_info_g_scf_short[1][24] := TUint8T(36);
  _static_L3_read_side_info_g_scf_short[1][25] := TUint8T(36);
  _static_L3_read_side_info_g_scf_short[1][26] := TUint8T(36);
  _static_L3_read_side_info_g_scf_short[1][27] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][28] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][29] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][30] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][31] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][32] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][33] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][34] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][35] := TUint8T(2);
  _static_L3_read_side_info_g_scf_short[1][36] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[1][37] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[1][38] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[1][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[2][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[2][9] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][10] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][14] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[2][15] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[2][16] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[2][17] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[2][18] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[2][19] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[2][20] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[2][21] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[2][22] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[2][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[2][24] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][25] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][26] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][27] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[2][28] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[2][29] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[2][30] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[2][31] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[2][32] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[2][33] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[2][34] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[2][35] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[2][36] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][37] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][38] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[2][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[3][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[3][9] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[3][10] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[3][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[3][12] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[3][13] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[3][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[3][15] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[3][16] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[3][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[3][18] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][19] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][21] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[3][22] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[3][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[3][24] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[3][25] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[3][26] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[3][27] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[3][28] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[3][29] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[3][30] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[3][31] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[3][32] := TUint8T(32);
  _static_L3_read_side_info_g_scf_short[3][33] := TUint8T(44);
  _static_L3_read_side_info_g_scf_short[3][34] := TUint8T(44);
  _static_L3_read_side_info_g_scf_short[3][35] := TUint8T(44);
  _static_L3_read_side_info_g_scf_short[3][36] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][37] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][38] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[3][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[4][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[4][9] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[4][10] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[4][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[4][12] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[4][13] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[4][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[4][15] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[4][16] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[4][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[4][18] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[4][19] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[4][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[4][21] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[4][22] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[4][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[4][24] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][25] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][26] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][27] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[4][28] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[4][29] := TUint8T(24);
  _static_L3_read_side_info_g_scf_short[4][30] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[4][31] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[4][32] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[4][33] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[4][34] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[4][35] := TUint8T(40);
  _static_L3_read_side_info_g_scf_short[4][36] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][37] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][38] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[4][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[5][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][11] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[5][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[5][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[5][14] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[5][15] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[5][16] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[5][17] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[5][18] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[5][19] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[5][20] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[5][21] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[5][22] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[5][23] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[5][24] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[5][25] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[5][26] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[5][27] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[5][28] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[5][29] := TUint8T(18);
  _static_L3_read_side_info_g_scf_short[5][30] := TUint8T(22);
  _static_L3_read_side_info_g_scf_short[5][31] := TUint8T(22);
  _static_L3_read_side_info_g_scf_short[5][32] := TUint8T(22);
  _static_L3_read_side_info_g_scf_short[5][33] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[5][34] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[5][35] := TUint8T(30);
  _static_L3_read_side_info_g_scf_short[5][36] := TUint8T(56);
  _static_L3_read_side_info_g_scf_short[5][37] := TUint8T(56);
  _static_L3_read_side_info_g_scf_short[5][38] := TUint8T(56);
  _static_L3_read_side_info_g_scf_short[5][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[6][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][11] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[6][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][14] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][15] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][16] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][17] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[6][18] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[6][19] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[6][20] := TUint8T(10);
  _static_L3_read_side_info_g_scf_short[6][21] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[6][22] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[6][23] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[6][24] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[6][25] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[6][26] := TUint8T(14);
  _static_L3_read_side_info_g_scf_short[6][27] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[6][28] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[6][29] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[6][30] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[6][31] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[6][32] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[6][33] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[6][34] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[6][35] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[6][36] := TUint8T(66);
  _static_L3_read_side_info_g_scf_short[6][37] := TUint8T(66);
  _static_L3_read_side_info_g_scf_short[6][38] := TUint8T(66);
  _static_L3_read_side_info_g_scf_short[6][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_short[7][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][6] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][7] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][11] := TUint8T(4);
  _static_L3_read_side_info_g_scf_short[7][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[7][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[7][14] := TUint8T(6);
  _static_L3_read_side_info_g_scf_short[7][15] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[7][16] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[7][17] := TUint8T(8);
  _static_L3_read_side_info_g_scf_short[7][18] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][19] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][21] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[7][22] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[7][23] := TUint8T(16);
  _static_L3_read_side_info_g_scf_short[7][24] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[7][25] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[7][26] := TUint8T(20);
  _static_L3_read_side_info_g_scf_short[7][27] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[7][28] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[7][29] := TUint8T(26);
  _static_L3_read_side_info_g_scf_short[7][30] := TUint8T(34);
  _static_L3_read_side_info_g_scf_short[7][31] := TUint8T(34);
  _static_L3_read_side_info_g_scf_short[7][32] := TUint8T(34);
  _static_L3_read_side_info_g_scf_short[7][33] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[7][34] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[7][35] := TUint8T(42);
  _static_L3_read_side_info_g_scf_short[7][36] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][37] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][38] := TUint8T(12);
  _static_L3_read_side_info_g_scf_short[7][39] := TUint8T(0);
  FillChar(_static_L3_read_side_info_g_scf_mixed, SizeOf(_static_L3_read_side_info_g_scf_mixed), 0);
  _static_L3_read_side_info_g_scf_mixed[0][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][8] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[0][9] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[0][10] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[0][11] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[0][12] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[0][13] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[0][14] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[0][15] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[0][16] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[0][17] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[0][18] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[0][19] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[0][20] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[0][21] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][22] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][23] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][24] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[0][25] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[0][26] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[0][27] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[0][28] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[0][29] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[0][30] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[0][31] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[0][32] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[0][33] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][34] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][35] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[0][36] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[1][0] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][1] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][2] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[1][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[1][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[1][6] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[1][7] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[1][8] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[1][9] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][10] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][11] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[1][12] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[1][13] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[1][14] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[1][15] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[1][16] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[1][17] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[1][18] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[1][19] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[1][20] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[1][21] := TUint8T(28);
  _static_L3_read_side_info_g_scf_mixed[1][22] := TUint8T(28);
  _static_L3_read_side_info_g_scf_mixed[1][23] := TUint8T(28);
  _static_L3_read_side_info_g_scf_mixed[1][24] := TUint8T(36);
  _static_L3_read_side_info_g_scf_mixed[1][25] := TUint8T(36);
  _static_L3_read_side_info_g_scf_mixed[1][26] := TUint8T(36);
  _static_L3_read_side_info_g_scf_mixed[1][27] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][28] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][29] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][30] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][31] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][32] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][33] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][34] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][35] := TUint8T(2);
  _static_L3_read_side_info_g_scf_mixed[1][36] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[1][37] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[1][38] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[1][39] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[2][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][8] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][9] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][10] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[2][12] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[2][13] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[2][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[2][15] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[2][16] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[2][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[2][18] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[2][19] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[2][20] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[2][21] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][22] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][23] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][24] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[2][25] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[2][26] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[2][27] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[2][28] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[2][29] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[2][30] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[2][31] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[2][32] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[2][33] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][34] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][35] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[2][36] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[3][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][8] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[3][9] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[3][10] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[3][11] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[3][12] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[3][13] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[3][14] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[3][15] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][16] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][17] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][18] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[3][19] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[3][20] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[3][21] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[3][22] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[3][23] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[3][24] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[3][25] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[3][26] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[3][27] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[3][28] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[3][29] := TUint8T(32);
  _static_L3_read_side_info_g_scf_mixed[3][30] := TUint8T(44);
  _static_L3_read_side_info_g_scf_mixed[3][31] := TUint8T(44);
  _static_L3_read_side_info_g_scf_mixed[3][32] := TUint8T(44);
  _static_L3_read_side_info_g_scf_mixed[3][33] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][34] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][35] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[3][36] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[4][0] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][1] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][2] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][3] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][4] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][5] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][8] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[4][9] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[4][10] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[4][11] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[4][12] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[4][13] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[4][14] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[4][15] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[4][16] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[4][17] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[4][18] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[4][19] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[4][20] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[4][21] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][22] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][23] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][24] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[4][25] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[4][26] := TUint8T(24);
  _static_L3_read_side_info_g_scf_mixed[4][27] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[4][28] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[4][29] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[4][30] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[4][31] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[4][32] := TUint8T(40);
  _static_L3_read_side_info_g_scf_mixed[4][33] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][34] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][35] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[4][36] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[5][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[5][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[5][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[5][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[5][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[5][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[5][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[5][15] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[5][16] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[5][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[5][18] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[5][19] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[5][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[5][21] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[5][22] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[5][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[5][24] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[5][25] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[5][26] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[5][27] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[5][28] := TUint8T(18);
  _static_L3_read_side_info_g_scf_mixed[5][29] := TUint8T(22);
  _static_L3_read_side_info_g_scf_mixed[5][30] := TUint8T(22);
  _static_L3_read_side_info_g_scf_mixed[5][31] := TUint8T(22);
  _static_L3_read_side_info_g_scf_mixed[5][32] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[5][33] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[5][34] := TUint8T(30);
  _static_L3_read_side_info_g_scf_mixed[5][35] := TUint8T(56);
  _static_L3_read_side_info_g_scf_mixed[5][36] := TUint8T(56);
  _static_L3_read_side_info_g_scf_mixed[5][37] := TUint8T(56);
  _static_L3_read_side_info_g_scf_mixed[5][38] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[6][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[6][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][14] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][15] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][16] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[6][17] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[6][18] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[6][19] := TUint8T(10);
  _static_L3_read_side_info_g_scf_mixed[6][20] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[6][21] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[6][22] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[6][23] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[6][24] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[6][25] := TUint8T(14);
  _static_L3_read_side_info_g_scf_mixed[6][26] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[6][27] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[6][28] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[6][29] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[6][30] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[6][31] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[6][32] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[6][33] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[6][34] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[6][35] := TUint8T(66);
  _static_L3_read_side_info_g_scf_mixed[6][36] := TUint8T(66);
  _static_L3_read_side_info_g_scf_mixed[6][37] := TUint8T(66);
  _static_L3_read_side_info_g_scf_mixed[6][38] := TUint8T(0);
  _static_L3_read_side_info_g_scf_mixed[7][0] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][1] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][2] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][3] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][4] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][5] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][6] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[7][7] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[7][8] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][9] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][10] := TUint8T(4);
  _static_L3_read_side_info_g_scf_mixed[7][11] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[7][12] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[7][13] := TUint8T(6);
  _static_L3_read_side_info_g_scf_mixed[7][14] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[7][15] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[7][16] := TUint8T(8);
  _static_L3_read_side_info_g_scf_mixed[7][17] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][18] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][19] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][20] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[7][21] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[7][22] := TUint8T(16);
  _static_L3_read_side_info_g_scf_mixed[7][23] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[7][24] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[7][25] := TUint8T(20);
  _static_L3_read_side_info_g_scf_mixed[7][26] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[7][27] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[7][28] := TUint8T(26);
  _static_L3_read_side_info_g_scf_mixed[7][29] := TUint8T(34);
  _static_L3_read_side_info_g_scf_mixed[7][30] := TUint8T(34);
  _static_L3_read_side_info_g_scf_mixed[7][31] := TUint8T(34);
  _static_L3_read_side_info_g_scf_mixed[7][32] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[7][33] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[7][34] := TUint8T(42);
  _static_L3_read_side_info_g_scf_mixed[7][35] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][36] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][37] := TUint8T(12);
  _static_L3_read_side_info_g_scf_mixed[7][38] := TUint8T(0);
  FillChar(_static_L3_ldexp_q2_g_expfrac, SizeOf(_static_L3_ldexp_q2_g_expfrac), 0);
  _static_L3_ldexp_q2_g_expfrac[0] := Single(9.31322575e-10);
  _static_L3_ldexp_q2_g_expfrac[1] := Single(7.83145814e-10);
  _static_L3_ldexp_q2_g_expfrac[2] := Single(6.58544508e-10);
  _static_L3_ldexp_q2_g_expfrac[3] := Single(5.53767716e-10);
  FillChar(_static_L3_decode_scalefactors_g_scf_partitions, SizeOf(_static_L3_decode_scalefactors_g_scf_partitions), 0);
  _static_L3_decode_scalefactors_g_scf_partitions[0][0] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][1] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][2] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][3] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][4] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][5] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][6] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][7] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][8] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][9] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][10] := TUint8T(7);
  _static_L3_decode_scalefactors_g_scf_partitions[0][11] := TUint8T(3);
  _static_L3_decode_scalefactors_g_scf_partitions[0][12] := TUint8T(11);
  _static_L3_decode_scalefactors_g_scf_partitions[0][13] := TUint8T(10);
  _static_L3_decode_scalefactors_g_scf_partitions[0][14] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[0][15] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[0][16] := TUint8T(7);
  _static_L3_decode_scalefactors_g_scf_partitions[0][17] := TUint8T(7);
  _static_L3_decode_scalefactors_g_scf_partitions[0][18] := TUint8T(7);
  _static_L3_decode_scalefactors_g_scf_partitions[0][19] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[0][20] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][21] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][22] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[0][23] := TUint8T(3);
  _static_L3_decode_scalefactors_g_scf_partitions[0][24] := TUint8T(8);
  _static_L3_decode_scalefactors_g_scf_partitions[0][25] := TUint8T(8);
  _static_L3_decode_scalefactors_g_scf_partitions[0][26] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scf_partitions[0][27] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[1][0] := TUint8T(8);
  _static_L3_decode_scalefactors_g_scf_partitions[1][1] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][2] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][3] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[1][4] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][5] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][6] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][7] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][8] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][9] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][10] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[1][11] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][12] := TUint8T(15);
  _static_L3_decode_scalefactors_g_scf_partitions[1][13] := TUint8T(18);
  _static_L3_decode_scalefactors_g_scf_partitions[1][14] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[1][15] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[1][16] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][17] := TUint8T(15);
  _static_L3_decode_scalefactors_g_scf_partitions[1][18] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[1][19] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[1][20] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][21] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[1][22] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][23] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][24] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[1][25] := TUint8T(18);
  _static_L3_decode_scalefactors_g_scf_partitions[1][26] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[1][27] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[2][0] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][1] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][2] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[2][3] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][4] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][5] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][6] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][7] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][8] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][9] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][10] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][11] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[2][12] := TUint8T(18);
  _static_L3_decode_scalefactors_g_scf_partitions[2][13] := TUint8T(18);
  _static_L3_decode_scalefactors_g_scf_partitions[2][14] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[2][15] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[2][16] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][17] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][18] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][19] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scf_partitions[2][20] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][21] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][22] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][23] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scf_partitions[2][24] := TUint8T(15);
  _static_L3_decode_scalefactors_g_scf_partitions[2][25] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scf_partitions[2][26] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scf_partitions[2][27] := TUint8T(0);
  FillChar(_static_L3_decode_scalefactors_g_scfc_decode, SizeOf(_static_L3_decode_scalefactors_g_scfc_decode), 0);
  _static_L3_decode_scalefactors_g_scfc_decode[0] := TUint8T(0);
  _static_L3_decode_scalefactors_g_scfc_decode[1] := TUint8T(1);
  _static_L3_decode_scalefactors_g_scfc_decode[2] := TUint8T(2);
  _static_L3_decode_scalefactors_g_scfc_decode[3] := TUint8T(3);
  _static_L3_decode_scalefactors_g_scfc_decode[4] := TUint8T(12);
  _static_L3_decode_scalefactors_g_scfc_decode[5] := TUint8T(5);
  _static_L3_decode_scalefactors_g_scfc_decode[6] := TUint8T(6);
  _static_L3_decode_scalefactors_g_scfc_decode[7] := TUint8T(7);
  _static_L3_decode_scalefactors_g_scfc_decode[8] := TUint8T(9);
  _static_L3_decode_scalefactors_g_scfc_decode[9] := TUint8T(10);
  _static_L3_decode_scalefactors_g_scfc_decode[10] := TUint8T(11);
  _static_L3_decode_scalefactors_g_scfc_decode[11] := TUint8T(13);
  _static_L3_decode_scalefactors_g_scfc_decode[12] := TUint8T(14);
  _static_L3_decode_scalefactors_g_scfc_decode[13] := TUint8T(15);
  _static_L3_decode_scalefactors_g_scfc_decode[14] := TUint8T(18);
  _static_L3_decode_scalefactors_g_scfc_decode[15] := TUint8T(19);
  FillChar(_static_L3_decode_scalefactors_g_mod, SizeOf(_static_L3_decode_scalefactors_g_mod), 0);
  _static_L3_decode_scalefactors_g_mod[0] := TUint8T(5);
  _static_L3_decode_scalefactors_g_mod[1] := TUint8T(5);
  _static_L3_decode_scalefactors_g_mod[2] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[3] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[4] := TUint8T(5);
  _static_L3_decode_scalefactors_g_mod[5] := TUint8T(5);
  _static_L3_decode_scalefactors_g_mod[6] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[7] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[8] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[9] := TUint8T(3);
  _static_L3_decode_scalefactors_g_mod[10] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[11] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[12] := TUint8T(5);
  _static_L3_decode_scalefactors_g_mod[13] := TUint8T(6);
  _static_L3_decode_scalefactors_g_mod[14] := TUint8T(6);
  _static_L3_decode_scalefactors_g_mod[15] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[16] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[17] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[18] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[19] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[20] := TUint8T(4);
  _static_L3_decode_scalefactors_g_mod[21] := TUint8T(3);
  _static_L3_decode_scalefactors_g_mod[22] := TUint8T(1);
  _static_L3_decode_scalefactors_g_mod[23] := TUint8T(1);
  FillChar(_static_L3_decode_scalefactors_g_preamp, SizeOf(_static_L3_decode_scalefactors_g_preamp), 0);
  _static_L3_decode_scalefactors_g_preamp[0] := TUint8T(1);
  _static_L3_decode_scalefactors_g_preamp[1] := TUint8T(1);
  _static_L3_decode_scalefactors_g_preamp[2] := TUint8T(1);
  _static_L3_decode_scalefactors_g_preamp[3] := TUint8T(1);
  _static_L3_decode_scalefactors_g_preamp[4] := TUint8T(2);
  _static_L3_decode_scalefactors_g_preamp[5] := TUint8T(2);
  _static_L3_decode_scalefactors_g_preamp[6] := TUint8T(3);
  _static_L3_decode_scalefactors_g_preamp[7] := TUint8T(3);
  _static_L3_decode_scalefactors_g_preamp[8] := TUint8T(3);
  _static_L3_decode_scalefactors_g_preamp[9] := TUint8T(2);
  FillChar(_static_L3_huffman_tabs, SizeOf(_static_L3_huffman_tabs), 0);
  _static_L3_huffman_tabs[0] := TInt16T(0);
  _static_L3_huffman_tabs[1] := TInt16T(0);
  _static_L3_huffman_tabs[2] := TInt16T(0);
  _static_L3_huffman_tabs[3] := TInt16T(0);
  _static_L3_huffman_tabs[4] := TInt16T(0);
  _static_L3_huffman_tabs[5] := TInt16T(0);
  _static_L3_huffman_tabs[6] := TInt16T(0);
  _static_L3_huffman_tabs[7] := TInt16T(0);
  _static_L3_huffman_tabs[8] := TInt16T(0);
  _static_L3_huffman_tabs[9] := TInt16T(0);
  _static_L3_huffman_tabs[10] := TInt16T(0);
  _static_L3_huffman_tabs[11] := TInt16T(0);
  _static_L3_huffman_tabs[12] := TInt16T(0);
  _static_L3_huffman_tabs[13] := TInt16T(0);
  _static_L3_huffman_tabs[14] := TInt16T(0);
  _static_L3_huffman_tabs[15] := TInt16T(0);
  _static_L3_huffman_tabs[16] := TInt16T(0);
  _static_L3_huffman_tabs[17] := TInt16T(0);
  _static_L3_huffman_tabs[18] := TInt16T(0);
  _static_L3_huffman_tabs[19] := TInt16T(0);
  _static_L3_huffman_tabs[20] := TInt16T(0);
  _static_L3_huffman_tabs[21] := TInt16T(0);
  _static_L3_huffman_tabs[22] := TInt16T(0);
  _static_L3_huffman_tabs[23] := TInt16T(0);
  _static_L3_huffman_tabs[24] := TInt16T(0);
  _static_L3_huffman_tabs[25] := TInt16T(0);
  _static_L3_huffman_tabs[26] := TInt16T(0);
  _static_L3_huffman_tabs[27] := TInt16T(0);
  _static_L3_huffman_tabs[28] := TInt16T(0);
  _static_L3_huffman_tabs[29] := TInt16T(0);
  _static_L3_huffman_tabs[30] := TInt16T(0);
  _static_L3_huffman_tabs[31] := TInt16T(0);
  _static_L3_huffman_tabs[32] := TInt16T(785);
  _static_L3_huffman_tabs[33] := TInt16T(785);
  _static_L3_huffman_tabs[34] := TInt16T(785);
  _static_L3_huffman_tabs[35] := TInt16T(785);
  _static_L3_huffman_tabs[36] := TInt16T(784);
  _static_L3_huffman_tabs[37] := TInt16T(784);
  _static_L3_huffman_tabs[38] := TInt16T(784);
  _static_L3_huffman_tabs[39] := TInt16T(784);
  _static_L3_huffman_tabs[40] := TInt16T(513);
  _static_L3_huffman_tabs[41] := TInt16T(513);
  _static_L3_huffman_tabs[42] := TInt16T(513);
  _static_L3_huffman_tabs[43] := TInt16T(513);
  _static_L3_huffman_tabs[44] := TInt16T(513);
  _static_L3_huffman_tabs[45] := TInt16T(513);
  _static_L3_huffman_tabs[46] := TInt16T(513);
  _static_L3_huffman_tabs[47] := TInt16T(513);
  _static_L3_huffman_tabs[48] := TInt16T(256);
  _static_L3_huffman_tabs[49] := TInt16T(256);
  _static_L3_huffman_tabs[50] := TInt16T(256);
  _static_L3_huffman_tabs[51] := TInt16T(256);
  _static_L3_huffman_tabs[52] := TInt16T(256);
  _static_L3_huffman_tabs[53] := TInt16T(256);
  _static_L3_huffman_tabs[54] := TInt16T(256);
  _static_L3_huffman_tabs[55] := TInt16T(256);
  _static_L3_huffman_tabs[56] := TInt16T(256);
  _static_L3_huffman_tabs[57] := TInt16T(256);
  _static_L3_huffman_tabs[58] := TInt16T(256);
  _static_L3_huffman_tabs[59] := TInt16T(256);
  _static_L3_huffman_tabs[60] := TInt16T(256);
  _static_L3_huffman_tabs[61] := TInt16T(256);
  _static_L3_huffman_tabs[62] := TInt16T(256);
  _static_L3_huffman_tabs[63] := TInt16T(256);
  _static_L3_huffman_tabs[64] := TInt16T(-255);
  _static_L3_huffman_tabs[65] := TInt16T(1313);
  _static_L3_huffman_tabs[66] := TInt16T(1298);
  _static_L3_huffman_tabs[67] := TInt16T(1282);
  _static_L3_huffman_tabs[68] := TInt16T(785);
  _static_L3_huffman_tabs[69] := TInt16T(785);
  _static_L3_huffman_tabs[70] := TInt16T(785);
  _static_L3_huffman_tabs[71] := TInt16T(785);
  _static_L3_huffman_tabs[72] := TInt16T(784);
  _static_L3_huffman_tabs[73] := TInt16T(784);
  _static_L3_huffman_tabs[74] := TInt16T(784);
  _static_L3_huffman_tabs[75] := TInt16T(784);
  _static_L3_huffman_tabs[76] := TInt16T(769);
  _static_L3_huffman_tabs[77] := TInt16T(769);
  _static_L3_huffman_tabs[78] := TInt16T(769);
  _static_L3_huffman_tabs[79] := TInt16T(769);
  _static_L3_huffman_tabs[80] := TInt16T(256);
  _static_L3_huffman_tabs[81] := TInt16T(256);
  _static_L3_huffman_tabs[82] := TInt16T(256);
  _static_L3_huffman_tabs[83] := TInt16T(256);
  _static_L3_huffman_tabs[84] := TInt16T(256);
  _static_L3_huffman_tabs[85] := TInt16T(256);
  _static_L3_huffman_tabs[86] := TInt16T(256);
  _static_L3_huffman_tabs[87] := TInt16T(256);
  _static_L3_huffman_tabs[88] := TInt16T(256);
  _static_L3_huffman_tabs[89] := TInt16T(256);
  _static_L3_huffman_tabs[90] := TInt16T(256);
  _static_L3_huffman_tabs[91] := TInt16T(256);
  _static_L3_huffman_tabs[92] := TInt16T(256);
  _static_L3_huffman_tabs[93] := TInt16T(256);
  _static_L3_huffman_tabs[94] := TInt16T(256);
  _static_L3_huffman_tabs[95] := TInt16T(256);
  _static_L3_huffman_tabs[96] := TInt16T(290);
  _static_L3_huffman_tabs[97] := TInt16T(288);
  _static_L3_huffman_tabs[98] := TInt16T(-255);
  _static_L3_huffman_tabs[99] := TInt16T(1313);
  _static_L3_huffman_tabs[100] := TInt16T(1298);
  _static_L3_huffman_tabs[101] := TInt16T(1282);
  _static_L3_huffman_tabs[102] := TInt16T(769);
  _static_L3_huffman_tabs[103] := TInt16T(769);
  _static_L3_huffman_tabs[104] := TInt16T(769);
  _static_L3_huffman_tabs[105] := TInt16T(769);
  _static_L3_huffman_tabs[106] := TInt16T(529);
  _static_L3_huffman_tabs[107] := TInt16T(529);
  _static_L3_huffman_tabs[108] := TInt16T(529);
  _static_L3_huffman_tabs[109] := TInt16T(529);
  _static_L3_huffman_tabs[110] := TInt16T(529);
  _static_L3_huffman_tabs[111] := TInt16T(529);
  _static_L3_huffman_tabs[112] := TInt16T(529);
  _static_L3_huffman_tabs[113] := TInt16T(529);
  _static_L3_huffman_tabs[114] := TInt16T(528);
  _static_L3_huffman_tabs[115] := TInt16T(528);
  _static_L3_huffman_tabs[116] := TInt16T(528);
  _static_L3_huffman_tabs[117] := TInt16T(528);
  _static_L3_huffman_tabs[118] := TInt16T(528);
  _static_L3_huffman_tabs[119] := TInt16T(528);
  _static_L3_huffman_tabs[120] := TInt16T(528);
  _static_L3_huffman_tabs[121] := TInt16T(528);
  _static_L3_huffman_tabs[122] := TInt16T(512);
  _static_L3_huffman_tabs[123] := TInt16T(512);
  _static_L3_huffman_tabs[124] := TInt16T(512);
  _static_L3_huffman_tabs[125] := TInt16T(512);
  _static_L3_huffman_tabs[126] := TInt16T(512);
  _static_L3_huffman_tabs[127] := TInt16T(512);
  _static_L3_huffman_tabs[128] := TInt16T(512);
  _static_L3_huffman_tabs[129] := TInt16T(512);
  _static_L3_huffman_tabs[130] := TInt16T(290);
  _static_L3_huffman_tabs[131] := TInt16T(288);
  _static_L3_huffman_tabs[132] := TInt16T(-253);
  _static_L3_huffman_tabs[133] := TInt16T(-318);
  _static_L3_huffman_tabs[134] := TInt16T(-351);
  _static_L3_huffman_tabs[135] := TInt16T(-367);
  _static_L3_huffman_tabs[136] := TInt16T(785);
  _static_L3_huffman_tabs[137] := TInt16T(785);
  _static_L3_huffman_tabs[138] := TInt16T(785);
  _static_L3_huffman_tabs[139] := TInt16T(785);
  _static_L3_huffman_tabs[140] := TInt16T(784);
  _static_L3_huffman_tabs[141] := TInt16T(784);
  _static_L3_huffman_tabs[142] := TInt16T(784);
  _static_L3_huffman_tabs[143] := TInt16T(784);
  _static_L3_huffman_tabs[144] := TInt16T(769);
  _static_L3_huffman_tabs[145] := TInt16T(769);
  _static_L3_huffman_tabs[146] := TInt16T(769);
  _static_L3_huffman_tabs[147] := TInt16T(769);
  _static_L3_huffman_tabs[148] := TInt16T(256);
  _static_L3_huffman_tabs[149] := TInt16T(256);
  _static_L3_huffman_tabs[150] := TInt16T(256);
  _static_L3_huffman_tabs[151] := TInt16T(256);
  _static_L3_huffman_tabs[152] := TInt16T(256);
  _static_L3_huffman_tabs[153] := TInt16T(256);
  _static_L3_huffman_tabs[154] := TInt16T(256);
  _static_L3_huffman_tabs[155] := TInt16T(256);
  _static_L3_huffman_tabs[156] := TInt16T(256);
  _static_L3_huffman_tabs[157] := TInt16T(256);
  _static_L3_huffman_tabs[158] := TInt16T(256);
  _static_L3_huffman_tabs[159] := TInt16T(256);
  _static_L3_huffman_tabs[160] := TInt16T(256);
  _static_L3_huffman_tabs[161] := TInt16T(256);
  _static_L3_huffman_tabs[162] := TInt16T(256);
  _static_L3_huffman_tabs[163] := TInt16T(256);
  _static_L3_huffman_tabs[164] := TInt16T(819);
  _static_L3_huffman_tabs[165] := TInt16T(818);
  _static_L3_huffman_tabs[166] := TInt16T(547);
  _static_L3_huffman_tabs[167] := TInt16T(547);
  _static_L3_huffman_tabs[168] := TInt16T(275);
  _static_L3_huffman_tabs[169] := TInt16T(275);
  _static_L3_huffman_tabs[170] := TInt16T(275);
  _static_L3_huffman_tabs[171] := TInt16T(275);
  _static_L3_huffman_tabs[172] := TInt16T(561);
  _static_L3_huffman_tabs[173] := TInt16T(560);
  _static_L3_huffman_tabs[174] := TInt16T(515);
  _static_L3_huffman_tabs[175] := TInt16T(546);
  _static_L3_huffman_tabs[176] := TInt16T(289);
  _static_L3_huffman_tabs[177] := TInt16T(274);
  _static_L3_huffman_tabs[178] := TInt16T(288);
  _static_L3_huffman_tabs[179] := TInt16T(258);
  _static_L3_huffman_tabs[180] := TInt16T(-254);
  _static_L3_huffman_tabs[181] := TInt16T(-287);
  _static_L3_huffman_tabs[182] := TInt16T(1329);
  _static_L3_huffman_tabs[183] := TInt16T(1299);
  _static_L3_huffman_tabs[184] := TInt16T(1314);
  _static_L3_huffman_tabs[185] := TInt16T(1312);
  _static_L3_huffman_tabs[186] := TInt16T(1057);
  _static_L3_huffman_tabs[187] := TInt16T(1057);
  _static_L3_huffman_tabs[188] := TInt16T(1042);
  _static_L3_huffman_tabs[189] := TInt16T(1042);
  _static_L3_huffman_tabs[190] := TInt16T(1026);
  _static_L3_huffman_tabs[191] := TInt16T(1026);
  _static_L3_huffman_tabs[192] := TInt16T(784);
  _static_L3_huffman_tabs[193] := TInt16T(784);
  _static_L3_huffman_tabs[194] := TInt16T(784);
  _static_L3_huffman_tabs[195] := TInt16T(784);
  _static_L3_huffman_tabs[196] := TInt16T(529);
  _static_L3_huffman_tabs[197] := TInt16T(529);
  _static_L3_huffman_tabs[198] := TInt16T(529);
  _static_L3_huffman_tabs[199] := TInt16T(529);
  _static_L3_huffman_tabs[200] := TInt16T(529);
  _static_L3_huffman_tabs[201] := TInt16T(529);
  _static_L3_huffman_tabs[202] := TInt16T(529);
  _static_L3_huffman_tabs[203] := TInt16T(529);
  _static_L3_huffman_tabs[204] := TInt16T(769);
  _static_L3_huffman_tabs[205] := TInt16T(769);
  _static_L3_huffman_tabs[206] := TInt16T(769);
  _static_L3_huffman_tabs[207] := TInt16T(769);
  _static_L3_huffman_tabs[208] := TInt16T(768);
  _static_L3_huffman_tabs[209] := TInt16T(768);
  _static_L3_huffman_tabs[210] := TInt16T(768);
  _static_L3_huffman_tabs[211] := TInt16T(768);
  _static_L3_huffman_tabs[212] := TInt16T(563);
  _static_L3_huffman_tabs[213] := TInt16T(560);
  _static_L3_huffman_tabs[214] := TInt16T(306);
  _static_L3_huffman_tabs[215] := TInt16T(306);
  _static_L3_huffman_tabs[216] := TInt16T(291);
  _static_L3_huffman_tabs[217] := TInt16T(259);
  _static_L3_huffman_tabs[218] := TInt16T(-252);
  _static_L3_huffman_tabs[219] := TInt16T(-413);
  _static_L3_huffman_tabs[220] := TInt16T(-477);
  _static_L3_huffman_tabs[221] := TInt16T(-542);
  _static_L3_huffman_tabs[222] := TInt16T(1298);
  _static_L3_huffman_tabs[223] := TInt16T(-575);
  _static_L3_huffman_tabs[224] := TInt16T(1041);
  _static_L3_huffman_tabs[225] := TInt16T(1041);
  _static_L3_huffman_tabs[226] := TInt16T(784);
  _static_L3_huffman_tabs[227] := TInt16T(784);
  _static_L3_huffman_tabs[228] := TInt16T(784);
  _static_L3_huffman_tabs[229] := TInt16T(784);
  _static_L3_huffman_tabs[230] := TInt16T(769);
  _static_L3_huffman_tabs[231] := TInt16T(769);
  _static_L3_huffman_tabs[232] := TInt16T(769);
  _static_L3_huffman_tabs[233] := TInt16T(769);
  _static_L3_huffman_tabs[234] := TInt16T(256);
  _static_L3_huffman_tabs[235] := TInt16T(256);
  _static_L3_huffman_tabs[236] := TInt16T(256);
  _static_L3_huffman_tabs[237] := TInt16T(256);
  _static_L3_huffman_tabs[238] := TInt16T(256);
  _static_L3_huffman_tabs[239] := TInt16T(256);
  _static_L3_huffman_tabs[240] := TInt16T(256);
  _static_L3_huffman_tabs[241] := TInt16T(256);
  _static_L3_huffman_tabs[242] := TInt16T(256);
  _static_L3_huffman_tabs[243] := TInt16T(256);
  _static_L3_huffman_tabs[244] := TInt16T(256);
  _static_L3_huffman_tabs[245] := TInt16T(256);
  _static_L3_huffman_tabs[246] := TInt16T(256);
  _static_L3_huffman_tabs[247] := TInt16T(256);
  _static_L3_huffman_tabs[248] := TInt16T(256);
  _static_L3_huffman_tabs[249] := TInt16T(256);
  _static_L3_huffman_tabs[250] := TInt16T(-383);
  _static_L3_huffman_tabs[251] := TInt16T(-399);
  _static_L3_huffman_tabs[252] := TInt16T(1107);
  _static_L3_huffman_tabs[253] := TInt16T(1092);
  _static_L3_huffman_tabs[254] := TInt16T(1106);
  _static_L3_huffman_tabs[255] := TInt16T(1061);
  _static_L3_huffman_tabs[256] := TInt16T(849);
  _static_L3_huffman_tabs[257] := TInt16T(849);
  _static_L3_huffman_tabs[258] := TInt16T(789);
  _static_L3_huffman_tabs[259] := TInt16T(789);
  _static_L3_huffman_tabs[260] := TInt16T(1104);
  _static_L3_huffman_tabs[261] := TInt16T(1091);
  _static_L3_huffman_tabs[262] := TInt16T(773);
  _static_L3_huffman_tabs[263] := TInt16T(773);
  _static_L3_huffman_tabs[264] := TInt16T(1076);
  _static_L3_huffman_tabs[265] := TInt16T(1075);
  _static_L3_huffman_tabs[266] := TInt16T(341);
  _static_L3_huffman_tabs[267] := TInt16T(340);
  _static_L3_huffman_tabs[268] := TInt16T(325);
  _static_L3_huffman_tabs[269] := TInt16T(309);
  _static_L3_huffman_tabs[270] := TInt16T(834);
  _static_L3_huffman_tabs[271] := TInt16T(804);
  _static_L3_huffman_tabs[272] := TInt16T(577);
  _static_L3_huffman_tabs[273] := TInt16T(577);
  _static_L3_huffman_tabs[274] := TInt16T(532);
  _static_L3_huffman_tabs[275] := TInt16T(532);
  _static_L3_huffman_tabs[276] := TInt16T(516);
  _static_L3_huffman_tabs[277] := TInt16T(516);
  _static_L3_huffman_tabs[278] := TInt16T(832);
  _static_L3_huffman_tabs[279] := TInt16T(818);
  _static_L3_huffman_tabs[280] := TInt16T(803);
  _static_L3_huffman_tabs[281] := TInt16T(816);
  _static_L3_huffman_tabs[282] := TInt16T(561);
  _static_L3_huffman_tabs[283] := TInt16T(561);
  _static_L3_huffman_tabs[284] := TInt16T(531);
  _static_L3_huffman_tabs[285] := TInt16T(531);
  _static_L3_huffman_tabs[286] := TInt16T(515);
  _static_L3_huffman_tabs[287] := TInt16T(546);
  _static_L3_huffman_tabs[288] := TInt16T(289);
  _static_L3_huffman_tabs[289] := TInt16T(289);
  _static_L3_huffman_tabs[290] := TInt16T(288);
  _static_L3_huffman_tabs[291] := TInt16T(258);
  _static_L3_huffman_tabs[292] := TInt16T(-252);
  _static_L3_huffman_tabs[293] := TInt16T(-429);
  _static_L3_huffman_tabs[294] := TInt16T(-493);
  _static_L3_huffman_tabs[295] := TInt16T(-559);
  _static_L3_huffman_tabs[296] := TInt16T(1057);
  _static_L3_huffman_tabs[297] := TInt16T(1057);
  _static_L3_huffman_tabs[298] := TInt16T(1042);
  _static_L3_huffman_tabs[299] := TInt16T(1042);
  _static_L3_huffman_tabs[300] := TInt16T(529);
  _static_L3_huffman_tabs[301] := TInt16T(529);
  _static_L3_huffman_tabs[302] := TInt16T(529);
  _static_L3_huffman_tabs[303] := TInt16T(529);
  _static_L3_huffman_tabs[304] := TInt16T(529);
  _static_L3_huffman_tabs[305] := TInt16T(529);
  _static_L3_huffman_tabs[306] := TInt16T(529);
  _static_L3_huffman_tabs[307] := TInt16T(529);
  _static_L3_huffman_tabs[308] := TInt16T(784);
  _static_L3_huffman_tabs[309] := TInt16T(784);
  _static_L3_huffman_tabs[310] := TInt16T(784);
  _static_L3_huffman_tabs[311] := TInt16T(784);
  _static_L3_huffman_tabs[312] := TInt16T(769);
  _static_L3_huffman_tabs[313] := TInt16T(769);
  _static_L3_huffman_tabs[314] := TInt16T(769);
  _static_L3_huffman_tabs[315] := TInt16T(769);
  _static_L3_huffman_tabs[316] := TInt16T(512);
  _static_L3_huffman_tabs[317] := TInt16T(512);
  _static_L3_huffman_tabs[318] := TInt16T(512);
  _static_L3_huffman_tabs[319] := TInt16T(512);
  _static_L3_huffman_tabs[320] := TInt16T(512);
  _static_L3_huffman_tabs[321] := TInt16T(512);
  _static_L3_huffman_tabs[322] := TInt16T(512);
  _static_L3_huffman_tabs[323] := TInt16T(512);
  _static_L3_huffman_tabs[324] := TInt16T(-382);
  _static_L3_huffman_tabs[325] := TInt16T(1077);
  _static_L3_huffman_tabs[326] := TInt16T(-415);
  _static_L3_huffman_tabs[327] := TInt16T(1106);
  _static_L3_huffman_tabs[328] := TInt16T(1061);
  _static_L3_huffman_tabs[329] := TInt16T(1104);
  _static_L3_huffman_tabs[330] := TInt16T(849);
  _static_L3_huffman_tabs[331] := TInt16T(849);
  _static_L3_huffman_tabs[332] := TInt16T(789);
  _static_L3_huffman_tabs[333] := TInt16T(789);
  _static_L3_huffman_tabs[334] := TInt16T(1091);
  _static_L3_huffman_tabs[335] := TInt16T(1076);
  _static_L3_huffman_tabs[336] := TInt16T(1029);
  _static_L3_huffman_tabs[337] := TInt16T(1075);
  _static_L3_huffman_tabs[338] := TInt16T(834);
  _static_L3_huffman_tabs[339] := TInt16T(834);
  _static_L3_huffman_tabs[340] := TInt16T(597);
  _static_L3_huffman_tabs[341] := TInt16T(581);
  _static_L3_huffman_tabs[342] := TInt16T(340);
  _static_L3_huffman_tabs[343] := TInt16T(340);
  _static_L3_huffman_tabs[344] := TInt16T(339);
  _static_L3_huffman_tabs[345] := TInt16T(324);
  _static_L3_huffman_tabs[346] := TInt16T(804);
  _static_L3_huffman_tabs[347] := TInt16T(833);
  _static_L3_huffman_tabs[348] := TInt16T(532);
  _static_L3_huffman_tabs[349] := TInt16T(532);
  _static_L3_huffman_tabs[350] := TInt16T(832);
  _static_L3_huffman_tabs[351] := TInt16T(772);
  _static_L3_huffman_tabs[352] := TInt16T(818);
  _static_L3_huffman_tabs[353] := TInt16T(803);
  _static_L3_huffman_tabs[354] := TInt16T(817);
  _static_L3_huffman_tabs[355] := TInt16T(787);
  _static_L3_huffman_tabs[356] := TInt16T(816);
  _static_L3_huffman_tabs[357] := TInt16T(771);
  _static_L3_huffman_tabs[358] := TInt16T(290);
  _static_L3_huffman_tabs[359] := TInt16T(290);
  _static_L3_huffman_tabs[360] := TInt16T(290);
  _static_L3_huffman_tabs[361] := TInt16T(290);
  _static_L3_huffman_tabs[362] := TInt16T(288);
  _static_L3_huffman_tabs[363] := TInt16T(258);
  _static_L3_huffman_tabs[364] := TInt16T(-253);
  _static_L3_huffman_tabs[365] := TInt16T(-349);
  _static_L3_huffman_tabs[366] := TInt16T(-414);
  _static_L3_huffman_tabs[367] := TInt16T(-447);
  _static_L3_huffman_tabs[368] := TInt16T(-463);
  _static_L3_huffman_tabs[369] := TInt16T(1329);
  _static_L3_huffman_tabs[370] := TInt16T(1299);
  _static_L3_huffman_tabs[371] := TInt16T(-479);
  _static_L3_huffman_tabs[372] := TInt16T(1314);
  _static_L3_huffman_tabs[373] := TInt16T(1312);
  _static_L3_huffman_tabs[374] := TInt16T(1057);
  _static_L3_huffman_tabs[375] := TInt16T(1057);
  _static_L3_huffman_tabs[376] := TInt16T(1042);
  _static_L3_huffman_tabs[377] := TInt16T(1042);
  _static_L3_huffman_tabs[378] := TInt16T(1026);
  _static_L3_huffman_tabs[379] := TInt16T(1026);
  _static_L3_huffman_tabs[380] := TInt16T(785);
  _static_L3_huffman_tabs[381] := TInt16T(785);
  _static_L3_huffman_tabs[382] := TInt16T(785);
  _static_L3_huffman_tabs[383] := TInt16T(785);
  _static_L3_huffman_tabs[384] := TInt16T(784);
  _static_L3_huffman_tabs[385] := TInt16T(784);
  _static_L3_huffman_tabs[386] := TInt16T(784);
  _static_L3_huffman_tabs[387] := TInt16T(784);
  _static_L3_huffman_tabs[388] := TInt16T(769);
  _static_L3_huffman_tabs[389] := TInt16T(769);
  _static_L3_huffman_tabs[390] := TInt16T(769);
  _static_L3_huffman_tabs[391] := TInt16T(769);
  _static_L3_huffman_tabs[392] := TInt16T(768);
  _static_L3_huffman_tabs[393] := TInt16T(768);
  _static_L3_huffman_tabs[394] := TInt16T(768);
  _static_L3_huffman_tabs[395] := TInt16T(768);
  _static_L3_huffman_tabs[396] := TInt16T(-319);
  _static_L3_huffman_tabs[397] := TInt16T(851);
  _static_L3_huffman_tabs[398] := TInt16T(821);
  _static_L3_huffman_tabs[399] := TInt16T(-335);
  _static_L3_huffman_tabs[400] := TInt16T(836);
  _static_L3_huffman_tabs[401] := TInt16T(850);
  _static_L3_huffman_tabs[402] := TInt16T(805);
  _static_L3_huffman_tabs[403] := TInt16T(849);
  _static_L3_huffman_tabs[404] := TInt16T(341);
  _static_L3_huffman_tabs[405] := TInt16T(340);
  _static_L3_huffman_tabs[406] := TInt16T(325);
  _static_L3_huffman_tabs[407] := TInt16T(336);
  _static_L3_huffman_tabs[408] := TInt16T(533);
  _static_L3_huffman_tabs[409] := TInt16T(533);
  _static_L3_huffman_tabs[410] := TInt16T(579);
  _static_L3_huffman_tabs[411] := TInt16T(579);
  _static_L3_huffman_tabs[412] := TInt16T(564);
  _static_L3_huffman_tabs[413] := TInt16T(564);
  _static_L3_huffman_tabs[414] := TInt16T(773);
  _static_L3_huffman_tabs[415] := TInt16T(832);
  _static_L3_huffman_tabs[416] := TInt16T(578);
  _static_L3_huffman_tabs[417] := TInt16T(548);
  _static_L3_huffman_tabs[418] := TInt16T(563);
  _static_L3_huffman_tabs[419] := TInt16T(516);
  _static_L3_huffman_tabs[420] := TInt16T(321);
  _static_L3_huffman_tabs[421] := TInt16T(276);
  _static_L3_huffman_tabs[422] := TInt16T(306);
  _static_L3_huffman_tabs[423] := TInt16T(291);
  _static_L3_huffman_tabs[424] := TInt16T(304);
  _static_L3_huffman_tabs[425] := TInt16T(259);
  _static_L3_huffman_tabs[426] := TInt16T(-251);
  _static_L3_huffman_tabs[427] := TInt16T(-572);
  _static_L3_huffman_tabs[428] := TInt16T(-733);
  _static_L3_huffman_tabs[429] := TInt16T(-830);
  _static_L3_huffman_tabs[430] := TInt16T(-863);
  _static_L3_huffman_tabs[431] := TInt16T(-879);
  _static_L3_huffman_tabs[432] := TInt16T(1041);
  _static_L3_huffman_tabs[433] := TInt16T(1041);
  _static_L3_huffman_tabs[434] := TInt16T(784);
  _static_L3_huffman_tabs[435] := TInt16T(784);
  _static_L3_huffman_tabs[436] := TInt16T(784);
  _static_L3_huffman_tabs[437] := TInt16T(784);
  _static_L3_huffman_tabs[438] := TInt16T(769);
  _static_L3_huffman_tabs[439] := TInt16T(769);
  _static_L3_huffman_tabs[440] := TInt16T(769);
  _static_L3_huffman_tabs[441] := TInt16T(769);
  _static_L3_huffman_tabs[442] := TInt16T(256);
  _static_L3_huffman_tabs[443] := TInt16T(256);
  _static_L3_huffman_tabs[444] := TInt16T(256);
  _static_L3_huffman_tabs[445] := TInt16T(256);
  _static_L3_huffman_tabs[446] := TInt16T(256);
  _static_L3_huffman_tabs[447] := TInt16T(256);
  _static_L3_huffman_tabs[448] := TInt16T(256);
  _static_L3_huffman_tabs[449] := TInt16T(256);
  _static_L3_huffman_tabs[450] := TInt16T(256);
  _static_L3_huffman_tabs[451] := TInt16T(256);
  _static_L3_huffman_tabs[452] := TInt16T(256);
  _static_L3_huffman_tabs[453] := TInt16T(256);
  _static_L3_huffman_tabs[454] := TInt16T(256);
  _static_L3_huffman_tabs[455] := TInt16T(256);
  _static_L3_huffman_tabs[456] := TInt16T(256);
  _static_L3_huffman_tabs[457] := TInt16T(256);
  _static_L3_huffman_tabs[458] := TInt16T(-511);
  _static_L3_huffman_tabs[459] := TInt16T(-527);
  _static_L3_huffman_tabs[460] := TInt16T(-543);
  _static_L3_huffman_tabs[461] := TInt16T(1396);
  _static_L3_huffman_tabs[462] := TInt16T(1351);
  _static_L3_huffman_tabs[463] := TInt16T(1381);
  _static_L3_huffman_tabs[464] := TInt16T(1366);
  _static_L3_huffman_tabs[465] := TInt16T(1395);
  _static_L3_huffman_tabs[466] := TInt16T(1335);
  _static_L3_huffman_tabs[467] := TInt16T(1380);
  _static_L3_huffman_tabs[468] := TInt16T(-559);
  _static_L3_huffman_tabs[469] := TInt16T(1334);
  _static_L3_huffman_tabs[470] := TInt16T(1138);
  _static_L3_huffman_tabs[471] := TInt16T(1138);
  _static_L3_huffman_tabs[472] := TInt16T(1063);
  _static_L3_huffman_tabs[473] := TInt16T(1063);
  _static_L3_huffman_tabs[474] := TInt16T(1350);
  _static_L3_huffman_tabs[475] := TInt16T(1392);
  _static_L3_huffman_tabs[476] := TInt16T(1031);
  _static_L3_huffman_tabs[477] := TInt16T(1031);
  _static_L3_huffman_tabs[478] := TInt16T(1062);
  _static_L3_huffman_tabs[479] := TInt16T(1062);
  _static_L3_huffman_tabs[480] := TInt16T(1364);
  _static_L3_huffman_tabs[481] := TInt16T(1363);
  _static_L3_huffman_tabs[482] := TInt16T(1120);
  _static_L3_huffman_tabs[483] := TInt16T(1120);
  _static_L3_huffman_tabs[484] := TInt16T(1333);
  _static_L3_huffman_tabs[485] := TInt16T(1348);
  _static_L3_huffman_tabs[486] := TInt16T(881);
  _static_L3_huffman_tabs[487] := TInt16T(881);
  _static_L3_huffman_tabs[488] := TInt16T(881);
  _static_L3_huffman_tabs[489] := TInt16T(881);
  _static_L3_huffman_tabs[490] := TInt16T(375);
  _static_L3_huffman_tabs[491] := TInt16T(374);
  _static_L3_huffman_tabs[492] := TInt16T(359);
  _static_L3_huffman_tabs[493] := TInt16T(373);
  _static_L3_huffman_tabs[494] := TInt16T(343);
  _static_L3_huffman_tabs[495] := TInt16T(358);
  _static_L3_huffman_tabs[496] := TInt16T(341);
  _static_L3_huffman_tabs[497] := TInt16T(325);
  _static_L3_huffman_tabs[498] := TInt16T(791);
  _static_L3_huffman_tabs[499] := TInt16T(791);
  _static_L3_huffman_tabs[500] := TInt16T(1123);
  _static_L3_huffman_tabs[501] := TInt16T(1122);
  _static_L3_huffman_tabs[502] := TInt16T(-703);
  _static_L3_huffman_tabs[503] := TInt16T(1105);
  _static_L3_huffman_tabs[504] := TInt16T(1045);
  _static_L3_huffman_tabs[505] := TInt16T(-719);
  _static_L3_huffman_tabs[506] := TInt16T(865);
  _static_L3_huffman_tabs[507] := TInt16T(865);
  _static_L3_huffman_tabs[508] := TInt16T(790);
  _static_L3_huffman_tabs[509] := TInt16T(790);
  _static_L3_huffman_tabs[510] := TInt16T(774);
  _static_L3_huffman_tabs[511] := TInt16T(774);
  _static_L3_huffman_tabs[512] := TInt16T(1104);
  _static_L3_huffman_tabs[513] := TInt16T(1029);
  _static_L3_huffman_tabs[514] := TInt16T(338);
  _static_L3_huffman_tabs[515] := TInt16T(293);
  _static_L3_huffman_tabs[516] := TInt16T(323);
  _static_L3_huffman_tabs[517] := TInt16T(308);
  _static_L3_huffman_tabs[518] := TInt16T(-799);
  _static_L3_huffman_tabs[519] := TInt16T(-815);
  _static_L3_huffman_tabs[520] := TInt16T(833);
  _static_L3_huffman_tabs[521] := TInt16T(788);
  _static_L3_huffman_tabs[522] := TInt16T(772);
  _static_L3_huffman_tabs[523] := TInt16T(818);
  _static_L3_huffman_tabs[524] := TInt16T(803);
  _static_L3_huffman_tabs[525] := TInt16T(816);
  _static_L3_huffman_tabs[526] := TInt16T(322);
  _static_L3_huffman_tabs[527] := TInt16T(292);
  _static_L3_huffman_tabs[528] := TInt16T(307);
  _static_L3_huffman_tabs[529] := TInt16T(320);
  _static_L3_huffman_tabs[530] := TInt16T(561);
  _static_L3_huffman_tabs[531] := TInt16T(531);
  _static_L3_huffman_tabs[532] := TInt16T(515);
  _static_L3_huffman_tabs[533] := TInt16T(546);
  _static_L3_huffman_tabs[534] := TInt16T(289);
  _static_L3_huffman_tabs[535] := TInt16T(274);
  _static_L3_huffman_tabs[536] := TInt16T(288);
  _static_L3_huffman_tabs[537] := TInt16T(258);
  _static_L3_huffman_tabs[538] := TInt16T(-251);
  _static_L3_huffman_tabs[539] := TInt16T(-525);
  _static_L3_huffman_tabs[540] := TInt16T(-605);
  _static_L3_huffman_tabs[541] := TInt16T(-685);
  _static_L3_huffman_tabs[542] := TInt16T(-765);
  _static_L3_huffman_tabs[543] := TInt16T(-831);
  _static_L3_huffman_tabs[544] := TInt16T(-846);
  _static_L3_huffman_tabs[545] := TInt16T(1298);
  _static_L3_huffman_tabs[546] := TInt16T(1057);
  _static_L3_huffman_tabs[547] := TInt16T(1057);
  _static_L3_huffman_tabs[548] := TInt16T(1312);
  _static_L3_huffman_tabs[549] := TInt16T(1282);
  _static_L3_huffman_tabs[550] := TInt16T(785);
  _static_L3_huffman_tabs[551] := TInt16T(785);
  _static_L3_huffman_tabs[552] := TInt16T(785);
  _static_L3_huffman_tabs[553] := TInt16T(785);
  _static_L3_huffman_tabs[554] := TInt16T(784);
  _static_L3_huffman_tabs[555] := TInt16T(784);
  _static_L3_huffman_tabs[556] := TInt16T(784);
  _static_L3_huffman_tabs[557] := TInt16T(784);
  _static_L3_huffman_tabs[558] := TInt16T(769);
  _static_L3_huffman_tabs[559] := TInt16T(769);
  _static_L3_huffman_tabs[560] := TInt16T(769);
  _static_L3_huffman_tabs[561] := TInt16T(769);
  _static_L3_huffman_tabs[562] := TInt16T(512);
  _static_L3_huffman_tabs[563] := TInt16T(512);
  _static_L3_huffman_tabs[564] := TInt16T(512);
  _static_L3_huffman_tabs[565] := TInt16T(512);
  _static_L3_huffman_tabs[566] := TInt16T(512);
  _static_L3_huffman_tabs[567] := TInt16T(512);
  _static_L3_huffman_tabs[568] := TInt16T(512);
  _static_L3_huffman_tabs[569] := TInt16T(512);
  _static_L3_huffman_tabs[570] := TInt16T(1399);
  _static_L3_huffman_tabs[571] := TInt16T(1398);
  _static_L3_huffman_tabs[572] := TInt16T(1383);
  _static_L3_huffman_tabs[573] := TInt16T(1367);
  _static_L3_huffman_tabs[574] := TInt16T(1382);
  _static_L3_huffman_tabs[575] := TInt16T(1396);
  _static_L3_huffman_tabs[576] := TInt16T(1351);
  _static_L3_huffman_tabs[577] := TInt16T(-511);
  _static_L3_huffman_tabs[578] := TInt16T(1381);
  _static_L3_huffman_tabs[579] := TInt16T(1366);
  _static_L3_huffman_tabs[580] := TInt16T(1139);
  _static_L3_huffman_tabs[581] := TInt16T(1139);
  _static_L3_huffman_tabs[582] := TInt16T(1079);
  _static_L3_huffman_tabs[583] := TInt16T(1079);
  _static_L3_huffman_tabs[584] := TInt16T(1124);
  _static_L3_huffman_tabs[585] := TInt16T(1124);
  _static_L3_huffman_tabs[586] := TInt16T(1364);
  _static_L3_huffman_tabs[587] := TInt16T(1349);
  _static_L3_huffman_tabs[588] := TInt16T(1363);
  _static_L3_huffman_tabs[589] := TInt16T(1333);
  _static_L3_huffman_tabs[590] := TInt16T(882);
  _static_L3_huffman_tabs[591] := TInt16T(882);
  _static_L3_huffman_tabs[592] := TInt16T(882);
  _static_L3_huffman_tabs[593] := TInt16T(882);
  _static_L3_huffman_tabs[594] := TInt16T(807);
  _static_L3_huffman_tabs[595] := TInt16T(807);
  _static_L3_huffman_tabs[596] := TInt16T(807);
  _static_L3_huffman_tabs[597] := TInt16T(807);
  _static_L3_huffman_tabs[598] := TInt16T(1094);
  _static_L3_huffman_tabs[599] := TInt16T(1094);
  _static_L3_huffman_tabs[600] := TInt16T(1136);
  _static_L3_huffman_tabs[601] := TInt16T(1136);
  _static_L3_huffman_tabs[602] := TInt16T(373);
  _static_L3_huffman_tabs[603] := TInt16T(341);
  _static_L3_huffman_tabs[604] := TInt16T(535);
  _static_L3_huffman_tabs[605] := TInt16T(535);
  _static_L3_huffman_tabs[606] := TInt16T(881);
  _static_L3_huffman_tabs[607] := TInt16T(775);
  _static_L3_huffman_tabs[608] := TInt16T(867);
  _static_L3_huffman_tabs[609] := TInt16T(822);
  _static_L3_huffman_tabs[610] := TInt16T(774);
  _static_L3_huffman_tabs[611] := TInt16T(-591);
  _static_L3_huffman_tabs[612] := TInt16T(324);
  _static_L3_huffman_tabs[613] := TInt16T(338);
  _static_L3_huffman_tabs[614] := TInt16T(-671);
  _static_L3_huffman_tabs[615] := TInt16T(849);
  _static_L3_huffman_tabs[616] := TInt16T(550);
  _static_L3_huffman_tabs[617] := TInt16T(550);
  _static_L3_huffman_tabs[618] := TInt16T(866);
  _static_L3_huffman_tabs[619] := TInt16T(864);
  _static_L3_huffman_tabs[620] := TInt16T(609);
  _static_L3_huffman_tabs[621] := TInt16T(609);
  _static_L3_huffman_tabs[622] := TInt16T(293);
  _static_L3_huffman_tabs[623] := TInt16T(336);
  _static_L3_huffman_tabs[624] := TInt16T(534);
  _static_L3_huffman_tabs[625] := TInt16T(534);
  _static_L3_huffman_tabs[626] := TInt16T(789);
  _static_L3_huffman_tabs[627] := TInt16T(835);
  _static_L3_huffman_tabs[628] := TInt16T(773);
  _static_L3_huffman_tabs[629] := TInt16T(-751);
  _static_L3_huffman_tabs[630] := TInt16T(834);
  _static_L3_huffman_tabs[631] := TInt16T(804);
  _static_L3_huffman_tabs[632] := TInt16T(308);
  _static_L3_huffman_tabs[633] := TInt16T(307);
  _static_L3_huffman_tabs[634] := TInt16T(833);
  _static_L3_huffman_tabs[635] := TInt16T(788);
  _static_L3_huffman_tabs[636] := TInt16T(832);
  _static_L3_huffman_tabs[637] := TInt16T(772);
  _static_L3_huffman_tabs[638] := TInt16T(562);
  _static_L3_huffman_tabs[639] := TInt16T(562);
  _static_L3_huffman_tabs[640] := TInt16T(547);
  _static_L3_huffman_tabs[641] := TInt16T(547);
  _static_L3_huffman_tabs[642] := TInt16T(305);
  _static_L3_huffman_tabs[643] := TInt16T(275);
  _static_L3_huffman_tabs[644] := TInt16T(560);
  _static_L3_huffman_tabs[645] := TInt16T(515);
  _static_L3_huffman_tabs[646] := TInt16T(290);
  _static_L3_huffman_tabs[647] := TInt16T(290);
  _static_L3_huffman_tabs[648] := TInt16T(-252);
  _static_L3_huffman_tabs[649] := TInt16T(-397);
  _static_L3_huffman_tabs[650] := TInt16T(-477);
  _static_L3_huffman_tabs[651] := TInt16T(-557);
  _static_L3_huffman_tabs[652] := TInt16T(-622);
  _static_L3_huffman_tabs[653] := TInt16T(-653);
  _static_L3_huffman_tabs[654] := TInt16T(-719);
  _static_L3_huffman_tabs[655] := TInt16T(-735);
  _static_L3_huffman_tabs[656] := TInt16T(-750);
  _static_L3_huffman_tabs[657] := TInt16T(1329);
  _static_L3_huffman_tabs[658] := TInt16T(1299);
  _static_L3_huffman_tabs[659] := TInt16T(1314);
  _static_L3_huffman_tabs[660] := TInt16T(1057);
  _static_L3_huffman_tabs[661] := TInt16T(1057);
  _static_L3_huffman_tabs[662] := TInt16T(1042);
  _static_L3_huffman_tabs[663] := TInt16T(1042);
  _static_L3_huffman_tabs[664] := TInt16T(1312);
  _static_L3_huffman_tabs[665] := TInt16T(1282);
  _static_L3_huffman_tabs[666] := TInt16T(1024);
  _static_L3_huffman_tabs[667] := TInt16T(1024);
  _static_L3_huffman_tabs[668] := TInt16T(785);
  _static_L3_huffman_tabs[669] := TInt16T(785);
  _static_L3_huffman_tabs[670] := TInt16T(785);
  _static_L3_huffman_tabs[671] := TInt16T(785);
  _static_L3_huffman_tabs[672] := TInt16T(784);
  _static_L3_huffman_tabs[673] := TInt16T(784);
  _static_L3_huffman_tabs[674] := TInt16T(784);
  _static_L3_huffman_tabs[675] := TInt16T(784);
  _static_L3_huffman_tabs[676] := TInt16T(769);
  _static_L3_huffman_tabs[677] := TInt16T(769);
  _static_L3_huffman_tabs[678] := TInt16T(769);
  _static_L3_huffman_tabs[679] := TInt16T(769);
  _static_L3_huffman_tabs[680] := TInt16T(-383);
  _static_L3_huffman_tabs[681] := TInt16T(1127);
  _static_L3_huffman_tabs[682] := TInt16T(1141);
  _static_L3_huffman_tabs[683] := TInt16T(1111);
  _static_L3_huffman_tabs[684] := TInt16T(1126);
  _static_L3_huffman_tabs[685] := TInt16T(1140);
  _static_L3_huffman_tabs[686] := TInt16T(1095);
  _static_L3_huffman_tabs[687] := TInt16T(1110);
  _static_L3_huffman_tabs[688] := TInt16T(869);
  _static_L3_huffman_tabs[689] := TInt16T(869);
  _static_L3_huffman_tabs[690] := TInt16T(883);
  _static_L3_huffman_tabs[691] := TInt16T(883);
  _static_L3_huffman_tabs[692] := TInt16T(1079);
  _static_L3_huffman_tabs[693] := TInt16T(1109);
  _static_L3_huffman_tabs[694] := TInt16T(882);
  _static_L3_huffman_tabs[695] := TInt16T(882);
  _static_L3_huffman_tabs[696] := TInt16T(375);
  _static_L3_huffman_tabs[697] := TInt16T(374);
  _static_L3_huffman_tabs[698] := TInt16T(807);
  _static_L3_huffman_tabs[699] := TInt16T(868);
  _static_L3_huffman_tabs[700] := TInt16T(838);
  _static_L3_huffman_tabs[701] := TInt16T(881);
  _static_L3_huffman_tabs[702] := TInt16T(791);
  _static_L3_huffman_tabs[703] := TInt16T(-463);
  _static_L3_huffman_tabs[704] := TInt16T(867);
  _static_L3_huffman_tabs[705] := TInt16T(822);
  _static_L3_huffman_tabs[706] := TInt16T(368);
  _static_L3_huffman_tabs[707] := TInt16T(263);
  _static_L3_huffman_tabs[708] := TInt16T(852);
  _static_L3_huffman_tabs[709] := TInt16T(837);
  _static_L3_huffman_tabs[710] := TInt16T(836);
  _static_L3_huffman_tabs[711] := TInt16T(-543);
  _static_L3_huffman_tabs[712] := TInt16T(610);
  _static_L3_huffman_tabs[713] := TInt16T(610);
  _static_L3_huffman_tabs[714] := TInt16T(550);
  _static_L3_huffman_tabs[715] := TInt16T(550);
  _static_L3_huffman_tabs[716] := TInt16T(352);
  _static_L3_huffman_tabs[717] := TInt16T(336);
  _static_L3_huffman_tabs[718] := TInt16T(534);
  _static_L3_huffman_tabs[719] := TInt16T(534);
  _static_L3_huffman_tabs[720] := TInt16T(865);
  _static_L3_huffman_tabs[721] := TInt16T(774);
  _static_L3_huffman_tabs[722] := TInt16T(851);
  _static_L3_huffman_tabs[723] := TInt16T(821);
  _static_L3_huffman_tabs[724] := TInt16T(850);
  _static_L3_huffman_tabs[725] := TInt16T(805);
  _static_L3_huffman_tabs[726] := TInt16T(593);
  _static_L3_huffman_tabs[727] := TInt16T(533);
  _static_L3_huffman_tabs[728] := TInt16T(579);
  _static_L3_huffman_tabs[729] := TInt16T(564);
  _static_L3_huffman_tabs[730] := TInt16T(773);
  _static_L3_huffman_tabs[731] := TInt16T(832);
  _static_L3_huffman_tabs[732] := TInt16T(578);
  _static_L3_huffman_tabs[733] := TInt16T(578);
  _static_L3_huffman_tabs[734] := TInt16T(548);
  _static_L3_huffman_tabs[735] := TInt16T(548);
  _static_L3_huffman_tabs[736] := TInt16T(577);
  _static_L3_huffman_tabs[737] := TInt16T(577);
  _static_L3_huffman_tabs[738] := TInt16T(307);
  _static_L3_huffman_tabs[739] := TInt16T(276);
  _static_L3_huffman_tabs[740] := TInt16T(306);
  _static_L3_huffman_tabs[741] := TInt16T(291);
  _static_L3_huffman_tabs[742] := TInt16T(516);
  _static_L3_huffman_tabs[743] := TInt16T(560);
  _static_L3_huffman_tabs[744] := TInt16T(259);
  _static_L3_huffman_tabs[745] := TInt16T(259);
  _static_L3_huffman_tabs[746] := TInt16T(-250);
  _static_L3_huffman_tabs[747] := TInt16T(-2107);
  _static_L3_huffman_tabs[748] := TInt16T(-2507);
  _static_L3_huffman_tabs[749] := TInt16T(-2764);
  _static_L3_huffman_tabs[750] := TInt16T(-2909);
  _static_L3_huffman_tabs[751] := TInt16T(-2974);
  _static_L3_huffman_tabs[752] := TInt16T(-3007);
  _static_L3_huffman_tabs[753] := TInt16T(-3023);
  _static_L3_huffman_tabs[754] := TInt16T(1041);
  _static_L3_huffman_tabs[755] := TInt16T(1041);
  _static_L3_huffman_tabs[756] := TInt16T(1040);
  _static_L3_huffman_tabs[757] := TInt16T(1040);
  _static_L3_huffman_tabs[758] := TInt16T(769);
  _static_L3_huffman_tabs[759] := TInt16T(769);
  _static_L3_huffman_tabs[760] := TInt16T(769);
  _static_L3_huffman_tabs[761] := TInt16T(769);
  _static_L3_huffman_tabs[762] := TInt16T(256);
  _static_L3_huffman_tabs[763] := TInt16T(256);
  _static_L3_huffman_tabs[764] := TInt16T(256);
  _static_L3_huffman_tabs[765] := TInt16T(256);
  _static_L3_huffman_tabs[766] := TInt16T(256);
  _static_L3_huffman_tabs[767] := TInt16T(256);
  _static_L3_huffman_tabs[768] := TInt16T(256);
  _static_L3_huffman_tabs[769] := TInt16T(256);
  _static_L3_huffman_tabs[770] := TInt16T(256);
  _static_L3_huffman_tabs[771] := TInt16T(256);
  _static_L3_huffman_tabs[772] := TInt16T(256);
  _static_L3_huffman_tabs[773] := TInt16T(256);
  _static_L3_huffman_tabs[774] := TInt16T(256);
  _static_L3_huffman_tabs[775] := TInt16T(256);
  _static_L3_huffman_tabs[776] := TInt16T(256);
  _static_L3_huffman_tabs[777] := TInt16T(256);
  _static_L3_huffman_tabs[778] := TInt16T(-767);
  _static_L3_huffman_tabs[779] := TInt16T(-1052);
  _static_L3_huffman_tabs[780] := TInt16T(-1213);
  _static_L3_huffman_tabs[781] := TInt16T(-1277);
  _static_L3_huffman_tabs[782] := TInt16T(-1358);
  _static_L3_huffman_tabs[783] := TInt16T(-1405);
  _static_L3_huffman_tabs[784] := TInt16T(-1469);
  _static_L3_huffman_tabs[785] := TInt16T(-1535);
  _static_L3_huffman_tabs[786] := TInt16T(-1550);
  _static_L3_huffman_tabs[787] := TInt16T(-1582);
  _static_L3_huffman_tabs[788] := TInt16T(-1614);
  _static_L3_huffman_tabs[789] := TInt16T(-1647);
  _static_L3_huffman_tabs[790] := TInt16T(-1662);
  _static_L3_huffman_tabs[791] := TInt16T(-1694);
  _static_L3_huffman_tabs[792] := TInt16T(-1726);
  _static_L3_huffman_tabs[793] := TInt16T(-1759);
  _static_L3_huffman_tabs[794] := TInt16T(-1774);
  _static_L3_huffman_tabs[795] := TInt16T(-1807);
  _static_L3_huffman_tabs[796] := TInt16T(-1822);
  _static_L3_huffman_tabs[797] := TInt16T(-1854);
  _static_L3_huffman_tabs[798] := TInt16T(-1886);
  _static_L3_huffman_tabs[799] := TInt16T(1565);
  _static_L3_huffman_tabs[800] := TInt16T(-1919);
  _static_L3_huffman_tabs[801] := TInt16T(-1935);
  _static_L3_huffman_tabs[802] := TInt16T(-1951);
  _static_L3_huffman_tabs[803] := TInt16T(-1967);
  _static_L3_huffman_tabs[804] := TInt16T(1731);
  _static_L3_huffman_tabs[805] := TInt16T(1730);
  _static_L3_huffman_tabs[806] := TInt16T(1580);
  _static_L3_huffman_tabs[807] := TInt16T(1717);
  _static_L3_huffman_tabs[808] := TInt16T(-1983);
  _static_L3_huffman_tabs[809] := TInt16T(1729);
  _static_L3_huffman_tabs[810] := TInt16T(1564);
  _static_L3_huffman_tabs[811] := TInt16T(-1999);
  _static_L3_huffman_tabs[812] := TInt16T(1548);
  _static_L3_huffman_tabs[813] := TInt16T(-2015);
  _static_L3_huffman_tabs[814] := TInt16T(-2031);
  _static_L3_huffman_tabs[815] := TInt16T(1715);
  _static_L3_huffman_tabs[816] := TInt16T(1595);
  _static_L3_huffman_tabs[817] := TInt16T(-2047);
  _static_L3_huffman_tabs[818] := TInt16T(1714);
  _static_L3_huffman_tabs[819] := TInt16T(-2063);
  _static_L3_huffman_tabs[820] := TInt16T(1610);
  _static_L3_huffman_tabs[821] := TInt16T(-2079);
  _static_L3_huffman_tabs[822] := TInt16T(1609);
  _static_L3_huffman_tabs[823] := TInt16T(-2095);
  _static_L3_huffman_tabs[824] := TInt16T(1323);
  _static_L3_huffman_tabs[825] := TInt16T(1323);
  _static_L3_huffman_tabs[826] := TInt16T(1457);
  _static_L3_huffman_tabs[827] := TInt16T(1457);
  _static_L3_huffman_tabs[828] := TInt16T(1307);
  _static_L3_huffman_tabs[829] := TInt16T(1307);
  _static_L3_huffman_tabs[830] := TInt16T(1712);
  _static_L3_huffman_tabs[831] := TInt16T(1547);
  _static_L3_huffman_tabs[832] := TInt16T(1641);
  _static_L3_huffman_tabs[833] := TInt16T(1700);
  _static_L3_huffman_tabs[834] := TInt16T(1699);
  _static_L3_huffman_tabs[835] := TInt16T(1594);
  _static_L3_huffman_tabs[836] := TInt16T(1685);
  _static_L3_huffman_tabs[837] := TInt16T(1625);
  _static_L3_huffman_tabs[838] := TInt16T(1442);
  _static_L3_huffman_tabs[839] := TInt16T(1442);
  _static_L3_huffman_tabs[840] := TInt16T(1322);
  _static_L3_huffman_tabs[841] := TInt16T(1322);
  _static_L3_huffman_tabs[842] := TInt16T(-780);
  _static_L3_huffman_tabs[843] := TInt16T(-973);
  _static_L3_huffman_tabs[844] := TInt16T(-910);
  _static_L3_huffman_tabs[845] := TInt16T(1279);
  _static_L3_huffman_tabs[846] := TInt16T(1278);
  _static_L3_huffman_tabs[847] := TInt16T(1277);
  _static_L3_huffman_tabs[848] := TInt16T(1262);
  _static_L3_huffman_tabs[849] := TInt16T(1276);
  _static_L3_huffman_tabs[850] := TInt16T(1261);
  _static_L3_huffman_tabs[851] := TInt16T(1275);
  _static_L3_huffman_tabs[852] := TInt16T(1215);
  _static_L3_huffman_tabs[853] := TInt16T(1260);
  _static_L3_huffman_tabs[854] := TInt16T(1229);
  _static_L3_huffman_tabs[855] := TInt16T(-959);
  _static_L3_huffman_tabs[856] := TInt16T(974);
  _static_L3_huffman_tabs[857] := TInt16T(974);
  _static_L3_huffman_tabs[858] := TInt16T(989);
  _static_L3_huffman_tabs[859] := TInt16T(989);
  _static_L3_huffman_tabs[860] := TInt16T(-943);
  _static_L3_huffman_tabs[861] := TInt16T(735);
  _static_L3_huffman_tabs[862] := TInt16T(478);
  _static_L3_huffman_tabs[863] := TInt16T(478);
  _static_L3_huffman_tabs[864] := TInt16T(495);
  _static_L3_huffman_tabs[865] := TInt16T(463);
  _static_L3_huffman_tabs[866] := TInt16T(506);
  _static_L3_huffman_tabs[867] := TInt16T(414);
  _static_L3_huffman_tabs[868] := TInt16T(-1039);
  _static_L3_huffman_tabs[869] := TInt16T(1003);
  _static_L3_huffman_tabs[870] := TInt16T(958);
  _static_L3_huffman_tabs[871] := TInt16T(1017);
  _static_L3_huffman_tabs[872] := TInt16T(927);
  _static_L3_huffman_tabs[873] := TInt16T(942);
  _static_L3_huffman_tabs[874] := TInt16T(987);
  _static_L3_huffman_tabs[875] := TInt16T(957);
  _static_L3_huffman_tabs[876] := TInt16T(431);
  _static_L3_huffman_tabs[877] := TInt16T(476);
  _static_L3_huffman_tabs[878] := TInt16T(1272);
  _static_L3_huffman_tabs[879] := TInt16T(1167);
  _static_L3_huffman_tabs[880] := TInt16T(1228);
  _static_L3_huffman_tabs[881] := TInt16T(-1183);
  _static_L3_huffman_tabs[882] := TInt16T(1256);
  _static_L3_huffman_tabs[883] := TInt16T(-1199);
  _static_L3_huffman_tabs[884] := TInt16T(895);
  _static_L3_huffman_tabs[885] := TInt16T(895);
  _static_L3_huffman_tabs[886] := TInt16T(941);
  _static_L3_huffman_tabs[887] := TInt16T(941);
  _static_L3_huffman_tabs[888] := TInt16T(1242);
  _static_L3_huffman_tabs[889] := TInt16T(1227);
  _static_L3_huffman_tabs[890] := TInt16T(1212);
  _static_L3_huffman_tabs[891] := TInt16T(1135);
  _static_L3_huffman_tabs[892] := TInt16T(1014);
  _static_L3_huffman_tabs[893] := TInt16T(1014);
  _static_L3_huffman_tabs[894] := TInt16T(490);
  _static_L3_huffman_tabs[895] := TInt16T(489);
  _static_L3_huffman_tabs[896] := TInt16T(503);
  _static_L3_huffman_tabs[897] := TInt16T(487);
  _static_L3_huffman_tabs[898] := TInt16T(910);
  _static_L3_huffman_tabs[899] := TInt16T(1013);
  _static_L3_huffman_tabs[900] := TInt16T(985);
  _static_L3_huffman_tabs[901] := TInt16T(925);
  _static_L3_huffman_tabs[902] := TInt16T(863);
  _static_L3_huffman_tabs[903] := TInt16T(894);
  _static_L3_huffman_tabs[904] := TInt16T(970);
  _static_L3_huffman_tabs[905] := TInt16T(955);
  _static_L3_huffman_tabs[906] := TInt16T(1012);
  _static_L3_huffman_tabs[907] := TInt16T(847);
  _static_L3_huffman_tabs[908] := TInt16T(-1343);
  _static_L3_huffman_tabs[909] := TInt16T(831);
  _static_L3_huffman_tabs[910] := TInt16T(755);
  _static_L3_huffman_tabs[911] := TInt16T(755);
  _static_L3_huffman_tabs[912] := TInt16T(984);
  _static_L3_huffman_tabs[913] := TInt16T(909);
  _static_L3_huffman_tabs[914] := TInt16T(428);
  _static_L3_huffman_tabs[915] := TInt16T(366);
  _static_L3_huffman_tabs[916] := TInt16T(754);
  _static_L3_huffman_tabs[917] := TInt16T(559);
  _static_L3_huffman_tabs[918] := TInt16T(-1391);
  _static_L3_huffman_tabs[919] := TInt16T(752);
  _static_L3_huffman_tabs[920] := TInt16T(486);
  _static_L3_huffman_tabs[921] := TInt16T(457);
  _static_L3_huffman_tabs[922] := TInt16T(924);
  _static_L3_huffman_tabs[923] := TInt16T(997);
  _static_L3_huffman_tabs[924] := TInt16T(698);
  _static_L3_huffman_tabs[925] := TInt16T(698);
  _static_L3_huffman_tabs[926] := TInt16T(983);
  _static_L3_huffman_tabs[927] := TInt16T(893);
  _static_L3_huffman_tabs[928] := TInt16T(740);
  _static_L3_huffman_tabs[929] := TInt16T(740);
  _static_L3_huffman_tabs[930] := TInt16T(908);
  _static_L3_huffman_tabs[931] := TInt16T(877);
  _static_L3_huffman_tabs[932] := TInt16T(739);
  _static_L3_huffman_tabs[933] := TInt16T(739);
  _static_L3_huffman_tabs[934] := TInt16T(667);
  _static_L3_huffman_tabs[935] := TInt16T(667);
  _static_L3_huffman_tabs[936] := TInt16T(953);
  _static_L3_huffman_tabs[937] := TInt16T(938);
  _static_L3_huffman_tabs[938] := TInt16T(497);
  _static_L3_huffman_tabs[939] := TInt16T(287);
  _static_L3_huffman_tabs[940] := TInt16T(271);
  _static_L3_huffman_tabs[941] := TInt16T(271);
  _static_L3_huffman_tabs[942] := TInt16T(683);
  _static_L3_huffman_tabs[943] := TInt16T(606);
  _static_L3_huffman_tabs[944] := TInt16T(590);
  _static_L3_huffman_tabs[945] := TInt16T(712);
  _static_L3_huffman_tabs[946] := TInt16T(726);
  _static_L3_huffman_tabs[947] := TInt16T(574);
  _static_L3_huffman_tabs[948] := TInt16T(302);
  _static_L3_huffman_tabs[949] := TInt16T(302);
  _static_L3_huffman_tabs[950] := TInt16T(738);
  _static_L3_huffman_tabs[951] := TInt16T(736);
  _static_L3_huffman_tabs[952] := TInt16T(481);
  _static_L3_huffman_tabs[953] := TInt16T(286);
  _static_L3_huffman_tabs[954] := TInt16T(526);
  _static_L3_huffman_tabs[955] := TInt16T(725);
  _static_L3_huffman_tabs[956] := TInt16T(605);
  _static_L3_huffman_tabs[957] := TInt16T(711);
  _static_L3_huffman_tabs[958] := TInt16T(636);
  _static_L3_huffman_tabs[959] := TInt16T(724);
  _static_L3_huffman_tabs[960] := TInt16T(696);
  _static_L3_huffman_tabs[961] := TInt16T(651);
  _static_L3_huffman_tabs[962] := TInt16T(589);
  _static_L3_huffman_tabs[963] := TInt16T(681);
  _static_L3_huffman_tabs[964] := TInt16T(666);
  _static_L3_huffman_tabs[965] := TInt16T(710);
  _static_L3_huffman_tabs[966] := TInt16T(364);
  _static_L3_huffman_tabs[967] := TInt16T(467);
  _static_L3_huffman_tabs[968] := TInt16T(573);
  _static_L3_huffman_tabs[969] := TInt16T(695);
  _static_L3_huffman_tabs[970] := TInt16T(466);
  _static_L3_huffman_tabs[971] := TInt16T(466);
  _static_L3_huffman_tabs[972] := TInt16T(301);
  _static_L3_huffman_tabs[973] := TInt16T(465);
  _static_L3_huffman_tabs[974] := TInt16T(379);
  _static_L3_huffman_tabs[975] := TInt16T(379);
  _static_L3_huffman_tabs[976] := TInt16T(709);
  _static_L3_huffman_tabs[977] := TInt16T(604);
  _static_L3_huffman_tabs[978] := TInt16T(665);
  _static_L3_huffman_tabs[979] := TInt16T(679);
  _static_L3_huffman_tabs[980] := TInt16T(316);
  _static_L3_huffman_tabs[981] := TInt16T(316);
  _static_L3_huffman_tabs[982] := TInt16T(634);
  _static_L3_huffman_tabs[983] := TInt16T(633);
  _static_L3_huffman_tabs[984] := TInt16T(436);
  _static_L3_huffman_tabs[985] := TInt16T(436);
  _static_L3_huffman_tabs[986] := TInt16T(464);
  _static_L3_huffman_tabs[987] := TInt16T(269);
  _static_L3_huffman_tabs[988] := TInt16T(424);
  _static_L3_huffman_tabs[989] := TInt16T(394);
  _static_L3_huffman_tabs[990] := TInt16T(452);
  _static_L3_huffman_tabs[991] := TInt16T(332);
  _static_L3_huffman_tabs[992] := TInt16T(438);
  _static_L3_huffman_tabs[993] := TInt16T(363);
  _static_L3_huffman_tabs[994] := TInt16T(347);
  _static_L3_huffman_tabs[995] := TInt16T(408);
  _static_L3_huffman_tabs[996] := TInt16T(393);
  _static_L3_huffman_tabs[997] := TInt16T(448);
  _static_L3_huffman_tabs[998] := TInt16T(331);
  _static_L3_huffman_tabs[999] := TInt16T(422);
  _static_L3_huffman_tabs[1000] := TInt16T(362);
  _static_L3_huffman_tabs[1001] := TInt16T(407);
  _static_L3_huffman_tabs[1002] := TInt16T(392);
  _static_L3_huffman_tabs[1003] := TInt16T(421);
  _static_L3_huffman_tabs[1004] := TInt16T(346);
  _static_L3_huffman_tabs[1005] := TInt16T(406);
  _static_L3_huffman_tabs[1006] := TInt16T(391);
  _static_L3_huffman_tabs[1007] := TInt16T(376);
  _static_L3_huffman_tabs[1008] := TInt16T(375);
  _static_L3_huffman_tabs[1009] := TInt16T(359);
  _static_L3_huffman_tabs[1010] := TInt16T(1441);
  _static_L3_huffman_tabs[1011] := TInt16T(1306);
  _static_L3_huffman_tabs[1012] := TInt16T(-2367);
  _static_L3_huffman_tabs[1013] := TInt16T(1290);
  _static_L3_huffman_tabs[1014] := TInt16T(-2383);
  _static_L3_huffman_tabs[1015] := TInt16T(1337);
  _static_L3_huffman_tabs[1016] := TInt16T(-2399);
  _static_L3_huffman_tabs[1017] := TInt16T(-2415);
  _static_L3_huffman_tabs[1018] := TInt16T(1426);
  _static_L3_huffman_tabs[1019] := TInt16T(1321);
  _static_L3_huffman_tabs[1020] := TInt16T(-2431);
  _static_L3_huffman_tabs[1021] := TInt16T(1411);
  _static_L3_huffman_tabs[1022] := TInt16T(1336);
  _static_L3_huffman_tabs[1023] := TInt16T(-2447);
  _static_L3_huffman_tabs[1024] := TInt16T(-2463);
  _static_L3_huffman_tabs[1025] := TInt16T(-2479);
  _static_L3_huffman_tabs[1026] := TInt16T(1169);
  _static_L3_huffman_tabs[1027] := TInt16T(1169);
  _static_L3_huffman_tabs[1028] := TInt16T(1049);
  _static_L3_huffman_tabs[1029] := TInt16T(1049);
  _static_L3_huffman_tabs[1030] := TInt16T(1424);
  _static_L3_huffman_tabs[1031] := TInt16T(1289);
  _static_L3_huffman_tabs[1032] := TInt16T(1412);
  _static_L3_huffman_tabs[1033] := TInt16T(1352);
  _static_L3_huffman_tabs[1034] := TInt16T(1319);
  _static_L3_huffman_tabs[1035] := TInt16T(-2495);
  _static_L3_huffman_tabs[1036] := TInt16T(1154);
  _static_L3_huffman_tabs[1037] := TInt16T(1154);
  _static_L3_huffman_tabs[1038] := TInt16T(1064);
  _static_L3_huffman_tabs[1039] := TInt16T(1064);
  _static_L3_huffman_tabs[1040] := TInt16T(1153);
  _static_L3_huffman_tabs[1041] := TInt16T(1153);
  _static_L3_huffman_tabs[1042] := TInt16T(416);
  _static_L3_huffman_tabs[1043] := TInt16T(390);
  _static_L3_huffman_tabs[1044] := TInt16T(360);
  _static_L3_huffman_tabs[1045] := TInt16T(404);
  _static_L3_huffman_tabs[1046] := TInt16T(403);
  _static_L3_huffman_tabs[1047] := TInt16T(389);
  _static_L3_huffman_tabs[1048] := TInt16T(344);
  _static_L3_huffman_tabs[1049] := TInt16T(374);
  _static_L3_huffman_tabs[1050] := TInt16T(373);
  _static_L3_huffman_tabs[1051] := TInt16T(343);
  _static_L3_huffman_tabs[1052] := TInt16T(358);
  _static_L3_huffman_tabs[1053] := TInt16T(372);
  _static_L3_huffman_tabs[1054] := TInt16T(327);
  _static_L3_huffman_tabs[1055] := TInt16T(357);
  _static_L3_huffman_tabs[1056] := TInt16T(342);
  _static_L3_huffman_tabs[1057] := TInt16T(311);
  _static_L3_huffman_tabs[1058] := TInt16T(356);
  _static_L3_huffman_tabs[1059] := TInt16T(326);
  _static_L3_huffman_tabs[1060] := TInt16T(1395);
  _static_L3_huffman_tabs[1061] := TInt16T(1394);
  _static_L3_huffman_tabs[1062] := TInt16T(1137);
  _static_L3_huffman_tabs[1063] := TInt16T(1137);
  _static_L3_huffman_tabs[1064] := TInt16T(1047);
  _static_L3_huffman_tabs[1065] := TInt16T(1047);
  _static_L3_huffman_tabs[1066] := TInt16T(1365);
  _static_L3_huffman_tabs[1067] := TInt16T(1392);
  _static_L3_huffman_tabs[1068] := TInt16T(1287);
  _static_L3_huffman_tabs[1069] := TInt16T(1379);
  _static_L3_huffman_tabs[1070] := TInt16T(1334);
  _static_L3_huffman_tabs[1071] := TInt16T(1364);
  _static_L3_huffman_tabs[1072] := TInt16T(1349);
  _static_L3_huffman_tabs[1073] := TInt16T(1378);
  _static_L3_huffman_tabs[1074] := TInt16T(1318);
  _static_L3_huffman_tabs[1075] := TInt16T(1363);
  _static_L3_huffman_tabs[1076] := TInt16T(792);
  _static_L3_huffman_tabs[1077] := TInt16T(792);
  _static_L3_huffman_tabs[1078] := TInt16T(792);
  _static_L3_huffman_tabs[1079] := TInt16T(792);
  _static_L3_huffman_tabs[1080] := TInt16T(1152);
  _static_L3_huffman_tabs[1081] := TInt16T(1152);
  _static_L3_huffman_tabs[1082] := TInt16T(1032);
  _static_L3_huffman_tabs[1083] := TInt16T(1032);
  _static_L3_huffman_tabs[1084] := TInt16T(1121);
  _static_L3_huffman_tabs[1085] := TInt16T(1121);
  _static_L3_huffman_tabs[1086] := TInt16T(1046);
  _static_L3_huffman_tabs[1087] := TInt16T(1046);
  _static_L3_huffman_tabs[1088] := TInt16T(1120);
  _static_L3_huffman_tabs[1089] := TInt16T(1120);
  _static_L3_huffman_tabs[1090] := TInt16T(1030);
  _static_L3_huffman_tabs[1091] := TInt16T(1030);
  _static_L3_huffman_tabs[1092] := TInt16T(-2895);
  _static_L3_huffman_tabs[1093] := TInt16T(1106);
  _static_L3_huffman_tabs[1094] := TInt16T(1061);
  _static_L3_huffman_tabs[1095] := TInt16T(1104);
  _static_L3_huffman_tabs[1096] := TInt16T(849);
  _static_L3_huffman_tabs[1097] := TInt16T(849);
  _static_L3_huffman_tabs[1098] := TInt16T(789);
  _static_L3_huffman_tabs[1099] := TInt16T(789);
  _static_L3_huffman_tabs[1100] := TInt16T(1091);
  _static_L3_huffman_tabs[1101] := TInt16T(1076);
  _static_L3_huffman_tabs[1102] := TInt16T(1029);
  _static_L3_huffman_tabs[1103] := TInt16T(1090);
  _static_L3_huffman_tabs[1104] := TInt16T(1060);
  _static_L3_huffman_tabs[1105] := TInt16T(1075);
  _static_L3_huffman_tabs[1106] := TInt16T(833);
  _static_L3_huffman_tabs[1107] := TInt16T(833);
  _static_L3_huffman_tabs[1108] := TInt16T(309);
  _static_L3_huffman_tabs[1109] := TInt16T(324);
  _static_L3_huffman_tabs[1110] := TInt16T(532);
  _static_L3_huffman_tabs[1111] := TInt16T(532);
  _static_L3_huffman_tabs[1112] := TInt16T(832);
  _static_L3_huffman_tabs[1113] := TInt16T(772);
  _static_L3_huffman_tabs[1114] := TInt16T(818);
  _static_L3_huffman_tabs[1115] := TInt16T(803);
  _static_L3_huffman_tabs[1116] := TInt16T(561);
  _static_L3_huffman_tabs[1117] := TInt16T(561);
  _static_L3_huffman_tabs[1118] := TInt16T(531);
  _static_L3_huffman_tabs[1119] := TInt16T(560);
  _static_L3_huffman_tabs[1120] := TInt16T(515);
  _static_L3_huffman_tabs[1121] := TInt16T(546);
  _static_L3_huffman_tabs[1122] := TInt16T(289);
  _static_L3_huffman_tabs[1123] := TInt16T(274);
  _static_L3_huffman_tabs[1124] := TInt16T(288);
  _static_L3_huffman_tabs[1125] := TInt16T(258);
  _static_L3_huffman_tabs[1126] := TInt16T(-250);
  _static_L3_huffman_tabs[1127] := TInt16T(-1179);
  _static_L3_huffman_tabs[1128] := TInt16T(-1579);
  _static_L3_huffman_tabs[1129] := TInt16T(-1836);
  _static_L3_huffman_tabs[1130] := TInt16T(-1996);
  _static_L3_huffman_tabs[1131] := TInt16T(-2124);
  _static_L3_huffman_tabs[1132] := TInt16T(-2253);
  _static_L3_huffman_tabs[1133] := TInt16T(-2333);
  _static_L3_huffman_tabs[1134] := TInt16T(-2413);
  _static_L3_huffman_tabs[1135] := TInt16T(-2477);
  _static_L3_huffman_tabs[1136] := TInt16T(-2542);
  _static_L3_huffman_tabs[1137] := TInt16T(-2574);
  _static_L3_huffman_tabs[1138] := TInt16T(-2607);
  _static_L3_huffman_tabs[1139] := TInt16T(-2622);
  _static_L3_huffman_tabs[1140] := TInt16T(-2655);
  _static_L3_huffman_tabs[1141] := TInt16T(1314);
  _static_L3_huffman_tabs[1142] := TInt16T(1313);
  _static_L3_huffman_tabs[1143] := TInt16T(1298);
  _static_L3_huffman_tabs[1144] := TInt16T(1312);
  _static_L3_huffman_tabs[1145] := TInt16T(1282);
  _static_L3_huffman_tabs[1146] := TInt16T(785);
  _static_L3_huffman_tabs[1147] := TInt16T(785);
  _static_L3_huffman_tabs[1148] := TInt16T(785);
  _static_L3_huffman_tabs[1149] := TInt16T(785);
  _static_L3_huffman_tabs[1150] := TInt16T(1040);
  _static_L3_huffman_tabs[1151] := TInt16T(1040);
  _static_L3_huffman_tabs[1152] := TInt16T(1025);
  _static_L3_huffman_tabs[1153] := TInt16T(1025);
  _static_L3_huffman_tabs[1154] := TInt16T(768);
  _static_L3_huffman_tabs[1155] := TInt16T(768);
  _static_L3_huffman_tabs[1156] := TInt16T(768);
  _static_L3_huffman_tabs[1157] := TInt16T(768);
  _static_L3_huffman_tabs[1158] := TInt16T(-766);
  _static_L3_huffman_tabs[1159] := TInt16T(-798);
  _static_L3_huffman_tabs[1160] := TInt16T(-830);
  _static_L3_huffman_tabs[1161] := TInt16T(-862);
  _static_L3_huffman_tabs[1162] := TInt16T(-895);
  _static_L3_huffman_tabs[1163] := TInt16T(-911);
  _static_L3_huffman_tabs[1164] := TInt16T(-927);
  _static_L3_huffman_tabs[1165] := TInt16T(-943);
  _static_L3_huffman_tabs[1166] := TInt16T(-959);
  _static_L3_huffman_tabs[1167] := TInt16T(-975);
  _static_L3_huffman_tabs[1168] := TInt16T(-991);
  _static_L3_huffman_tabs[1169] := TInt16T(-1007);
  _static_L3_huffman_tabs[1170] := TInt16T(-1023);
  _static_L3_huffman_tabs[1171] := TInt16T(-1039);
  _static_L3_huffman_tabs[1172] := TInt16T(-1055);
  _static_L3_huffman_tabs[1173] := TInt16T(-1070);
  _static_L3_huffman_tabs[1174] := TInt16T(1724);
  _static_L3_huffman_tabs[1175] := TInt16T(1647);
  _static_L3_huffman_tabs[1176] := TInt16T(-1103);
  _static_L3_huffman_tabs[1177] := TInt16T(-1119);
  _static_L3_huffman_tabs[1178] := TInt16T(1631);
  _static_L3_huffman_tabs[1179] := TInt16T(1767);
  _static_L3_huffman_tabs[1180] := TInt16T(1662);
  _static_L3_huffman_tabs[1181] := TInt16T(1738);
  _static_L3_huffman_tabs[1182] := TInt16T(1708);
  _static_L3_huffman_tabs[1183] := TInt16T(1723);
  _static_L3_huffman_tabs[1184] := TInt16T(-1135);
  _static_L3_huffman_tabs[1185] := TInt16T(1780);
  _static_L3_huffman_tabs[1186] := TInt16T(1615);
  _static_L3_huffman_tabs[1187] := TInt16T(1779);
  _static_L3_huffman_tabs[1188] := TInt16T(1599);
  _static_L3_huffman_tabs[1189] := TInt16T(1677);
  _static_L3_huffman_tabs[1190] := TInt16T(1646);
  _static_L3_huffman_tabs[1191] := TInt16T(1778);
  _static_L3_huffman_tabs[1192] := TInt16T(1583);
  _static_L3_huffman_tabs[1193] := TInt16T(-1151);
  _static_L3_huffman_tabs[1194] := TInt16T(1777);
  _static_L3_huffman_tabs[1195] := TInt16T(1567);
  _static_L3_huffman_tabs[1196] := TInt16T(1737);
  _static_L3_huffman_tabs[1197] := TInt16T(1692);
  _static_L3_huffman_tabs[1198] := TInt16T(1765);
  _static_L3_huffman_tabs[1199] := TInt16T(1722);
  _static_L3_huffman_tabs[1200] := TInt16T(1707);
  _static_L3_huffman_tabs[1201] := TInt16T(1630);
  _static_L3_huffman_tabs[1202] := TInt16T(1751);
  _static_L3_huffman_tabs[1203] := TInt16T(1661);
  _static_L3_huffman_tabs[1204] := TInt16T(1764);
  _static_L3_huffman_tabs[1205] := TInt16T(1614);
  _static_L3_huffman_tabs[1206] := TInt16T(1736);
  _static_L3_huffman_tabs[1207] := TInt16T(1676);
  _static_L3_huffman_tabs[1208] := TInt16T(1763);
  _static_L3_huffman_tabs[1209] := TInt16T(1750);
  _static_L3_huffman_tabs[1210] := TInt16T(1645);
  _static_L3_huffman_tabs[1211] := TInt16T(1598);
  _static_L3_huffman_tabs[1212] := TInt16T(1721);
  _static_L3_huffman_tabs[1213] := TInt16T(1691);
  _static_L3_huffman_tabs[1214] := TInt16T(1762);
  _static_L3_huffman_tabs[1215] := TInt16T(1706);
  _static_L3_huffman_tabs[1216] := TInt16T(1582);
  _static_L3_huffman_tabs[1217] := TInt16T(1761);
  _static_L3_huffman_tabs[1218] := TInt16T(1566);
  _static_L3_huffman_tabs[1219] := TInt16T(-1167);
  _static_L3_huffman_tabs[1220] := TInt16T(1749);
  _static_L3_huffman_tabs[1221] := TInt16T(1629);
  _static_L3_huffman_tabs[1222] := TInt16T(767);
  _static_L3_huffman_tabs[1223] := TInt16T(766);
  _static_L3_huffman_tabs[1224] := TInt16T(751);
  _static_L3_huffman_tabs[1225] := TInt16T(765);
  _static_L3_huffman_tabs[1226] := TInt16T(494);
  _static_L3_huffman_tabs[1227] := TInt16T(494);
  _static_L3_huffman_tabs[1228] := TInt16T(735);
  _static_L3_huffman_tabs[1229] := TInt16T(764);
  _static_L3_huffman_tabs[1230] := TInt16T(719);
  _static_L3_huffman_tabs[1231] := TInt16T(749);
  _static_L3_huffman_tabs[1232] := TInt16T(734);
  _static_L3_huffman_tabs[1233] := TInt16T(763);
  _static_L3_huffman_tabs[1234] := TInt16T(447);
  _static_L3_huffman_tabs[1235] := TInt16T(447);
  _static_L3_huffman_tabs[1236] := TInt16T(748);
  _static_L3_huffman_tabs[1237] := TInt16T(718);
  _static_L3_huffman_tabs[1238] := TInt16T(477);
  _static_L3_huffman_tabs[1239] := TInt16T(506);
  _static_L3_huffman_tabs[1240] := TInt16T(431);
  _static_L3_huffman_tabs[1241] := TInt16T(491);
  _static_L3_huffman_tabs[1242] := TInt16T(446);
  _static_L3_huffman_tabs[1243] := TInt16T(476);
  _static_L3_huffman_tabs[1244] := TInt16T(461);
  _static_L3_huffman_tabs[1245] := TInt16T(505);
  _static_L3_huffman_tabs[1246] := TInt16T(415);
  _static_L3_huffman_tabs[1247] := TInt16T(430);
  _static_L3_huffman_tabs[1248] := TInt16T(475);
  _static_L3_huffman_tabs[1249] := TInt16T(445);
  _static_L3_huffman_tabs[1250] := TInt16T(504);
  _static_L3_huffman_tabs[1251] := TInt16T(399);
  _static_L3_huffman_tabs[1252] := TInt16T(460);
  _static_L3_huffman_tabs[1253] := TInt16T(489);
  _static_L3_huffman_tabs[1254] := TInt16T(414);
  _static_L3_huffman_tabs[1255] := TInt16T(503);
  _static_L3_huffman_tabs[1256] := TInt16T(383);
  _static_L3_huffman_tabs[1257] := TInt16T(474);
  _static_L3_huffman_tabs[1258] := TInt16T(429);
  _static_L3_huffman_tabs[1259] := TInt16T(459);
  _static_L3_huffman_tabs[1260] := TInt16T(502);
  _static_L3_huffman_tabs[1261] := TInt16T(502);
  _static_L3_huffman_tabs[1262] := TInt16T(746);
  _static_L3_huffman_tabs[1263] := TInt16T(752);
  _static_L3_huffman_tabs[1264] := TInt16T(488);
  _static_L3_huffman_tabs[1265] := TInt16T(398);
  _static_L3_huffman_tabs[1266] := TInt16T(501);
  _static_L3_huffman_tabs[1267] := TInt16T(473);
  _static_L3_huffman_tabs[1268] := TInt16T(413);
  _static_L3_huffman_tabs[1269] := TInt16T(472);
  _static_L3_huffman_tabs[1270] := TInt16T(486);
  _static_L3_huffman_tabs[1271] := TInt16T(271);
  _static_L3_huffman_tabs[1272] := TInt16T(480);
  _static_L3_huffman_tabs[1273] := TInt16T(270);
  _static_L3_huffman_tabs[1274] := TInt16T(-1439);
  _static_L3_huffman_tabs[1275] := TInt16T(-1455);
  _static_L3_huffman_tabs[1276] := TInt16T(1357);
  _static_L3_huffman_tabs[1277] := TInt16T(-1471);
  _static_L3_huffman_tabs[1278] := TInt16T(-1487);
  _static_L3_huffman_tabs[1279] := TInt16T(-1503);
  _static_L3_huffman_tabs[1280] := TInt16T(1341);
  _static_L3_huffman_tabs[1281] := TInt16T(1325);
  _static_L3_huffman_tabs[1282] := TInt16T(-1519);
  _static_L3_huffman_tabs[1283] := TInt16T(1489);
  _static_L3_huffman_tabs[1284] := TInt16T(1463);
  _static_L3_huffman_tabs[1285] := TInt16T(1403);
  _static_L3_huffman_tabs[1286] := TInt16T(1309);
  _static_L3_huffman_tabs[1287] := TInt16T(-1535);
  _static_L3_huffman_tabs[1288] := TInt16T(1372);
  _static_L3_huffman_tabs[1289] := TInt16T(1448);
  _static_L3_huffman_tabs[1290] := TInt16T(1418);
  _static_L3_huffman_tabs[1291] := TInt16T(1476);
  _static_L3_huffman_tabs[1292] := TInt16T(1356);
  _static_L3_huffman_tabs[1293] := TInt16T(1462);
  _static_L3_huffman_tabs[1294] := TInt16T(1387);
  _static_L3_huffman_tabs[1295] := TInt16T(-1551);
  _static_L3_huffman_tabs[1296] := TInt16T(1475);
  _static_L3_huffman_tabs[1297] := TInt16T(1340);
  _static_L3_huffman_tabs[1298] := TInt16T(1447);
  _static_L3_huffman_tabs[1299] := TInt16T(1402);
  _static_L3_huffman_tabs[1300] := TInt16T(1386);
  _static_L3_huffman_tabs[1301] := TInt16T(-1567);
  _static_L3_huffman_tabs[1302] := TInt16T(1068);
  _static_L3_huffman_tabs[1303] := TInt16T(1068);
  _static_L3_huffman_tabs[1304] := TInt16T(1474);
  _static_L3_huffman_tabs[1305] := TInt16T(1461);
  _static_L3_huffman_tabs[1306] := TInt16T(455);
  _static_L3_huffman_tabs[1307] := TInt16T(380);
  _static_L3_huffman_tabs[1308] := TInt16T(468);
  _static_L3_huffman_tabs[1309] := TInt16T(440);
  _static_L3_huffman_tabs[1310] := TInt16T(395);
  _static_L3_huffman_tabs[1311] := TInt16T(425);
  _static_L3_huffman_tabs[1312] := TInt16T(410);
  _static_L3_huffman_tabs[1313] := TInt16T(454);
  _static_L3_huffman_tabs[1314] := TInt16T(364);
  _static_L3_huffman_tabs[1315] := TInt16T(467);
  _static_L3_huffman_tabs[1316] := TInt16T(466);
  _static_L3_huffman_tabs[1317] := TInt16T(464);
  _static_L3_huffman_tabs[1318] := TInt16T(453);
  _static_L3_huffman_tabs[1319] := TInt16T(269);
  _static_L3_huffman_tabs[1320] := TInt16T(409);
  _static_L3_huffman_tabs[1321] := TInt16T(448);
  _static_L3_huffman_tabs[1322] := TInt16T(268);
  _static_L3_huffman_tabs[1323] := TInt16T(432);
  _static_L3_huffman_tabs[1324] := TInt16T(1371);
  _static_L3_huffman_tabs[1325] := TInt16T(1473);
  _static_L3_huffman_tabs[1326] := TInt16T(1432);
  _static_L3_huffman_tabs[1327] := TInt16T(1417);
  _static_L3_huffman_tabs[1328] := TInt16T(1308);
  _static_L3_huffman_tabs[1329] := TInt16T(1460);
  _static_L3_huffman_tabs[1330] := TInt16T(1355);
  _static_L3_huffman_tabs[1331] := TInt16T(1446);
  _static_L3_huffman_tabs[1332] := TInt16T(1459);
  _static_L3_huffman_tabs[1333] := TInt16T(1431);
  _static_L3_huffman_tabs[1334] := TInt16T(1083);
  _static_L3_huffman_tabs[1335] := TInt16T(1083);
  _static_L3_huffman_tabs[1336] := TInt16T(1401);
  _static_L3_huffman_tabs[1337] := TInt16T(1416);
  _static_L3_huffman_tabs[1338] := TInt16T(1458);
  _static_L3_huffman_tabs[1339] := TInt16T(1445);
  _static_L3_huffman_tabs[1340] := TInt16T(1067);
  _static_L3_huffman_tabs[1341] := TInt16T(1067);
  _static_L3_huffman_tabs[1342] := TInt16T(1370);
  _static_L3_huffman_tabs[1343] := TInt16T(1457);
  _static_L3_huffman_tabs[1344] := TInt16T(1051);
  _static_L3_huffman_tabs[1345] := TInt16T(1051);
  _static_L3_huffman_tabs[1346] := TInt16T(1291);
  _static_L3_huffman_tabs[1347] := TInt16T(1430);
  _static_L3_huffman_tabs[1348] := TInt16T(1385);
  _static_L3_huffman_tabs[1349] := TInt16T(1444);
  _static_L3_huffman_tabs[1350] := TInt16T(1354);
  _static_L3_huffman_tabs[1351] := TInt16T(1415);
  _static_L3_huffman_tabs[1352] := TInt16T(1400);
  _static_L3_huffman_tabs[1353] := TInt16T(1443);
  _static_L3_huffman_tabs[1354] := TInt16T(1082);
  _static_L3_huffman_tabs[1355] := TInt16T(1082);
  _static_L3_huffman_tabs[1356] := TInt16T(1173);
  _static_L3_huffman_tabs[1357] := TInt16T(1113);
  _static_L3_huffman_tabs[1358] := TInt16T(1186);
  _static_L3_huffman_tabs[1359] := TInt16T(1066);
  _static_L3_huffman_tabs[1360] := TInt16T(1185);
  _static_L3_huffman_tabs[1361] := TInt16T(1050);
  _static_L3_huffman_tabs[1362] := TInt16T(-1967);
  _static_L3_huffman_tabs[1363] := TInt16T(1158);
  _static_L3_huffman_tabs[1364] := TInt16T(1128);
  _static_L3_huffman_tabs[1365] := TInt16T(1172);
  _static_L3_huffman_tabs[1366] := TInt16T(1097);
  _static_L3_huffman_tabs[1367] := TInt16T(1171);
  _static_L3_huffman_tabs[1368] := TInt16T(1081);
  _static_L3_huffman_tabs[1369] := TInt16T(-1983);
  _static_L3_huffman_tabs[1370] := TInt16T(1157);
  _static_L3_huffman_tabs[1371] := TInt16T(1112);
  _static_L3_huffman_tabs[1372] := TInt16T(416);
  _static_L3_huffman_tabs[1373] := TInt16T(266);
  _static_L3_huffman_tabs[1374] := TInt16T(375);
  _static_L3_huffman_tabs[1375] := TInt16T(400);
  _static_L3_huffman_tabs[1376] := TInt16T(1170);
  _static_L3_huffman_tabs[1377] := TInt16T(1142);
  _static_L3_huffman_tabs[1378] := TInt16T(1127);
  _static_L3_huffman_tabs[1379] := TInt16T(1065);
  _static_L3_huffman_tabs[1380] := TInt16T(793);
  _static_L3_huffman_tabs[1381] := TInt16T(793);
  _static_L3_huffman_tabs[1382] := TInt16T(1169);
  _static_L3_huffman_tabs[1383] := TInt16T(1033);
  _static_L3_huffman_tabs[1384] := TInt16T(1156);
  _static_L3_huffman_tabs[1385] := TInt16T(1096);
  _static_L3_huffman_tabs[1386] := TInt16T(1141);
  _static_L3_huffman_tabs[1387] := TInt16T(1111);
  _static_L3_huffman_tabs[1388] := TInt16T(1155);
  _static_L3_huffman_tabs[1389] := TInt16T(1080);
  _static_L3_huffman_tabs[1390] := TInt16T(1126);
  _static_L3_huffman_tabs[1391] := TInt16T(1140);
  _static_L3_huffman_tabs[1392] := TInt16T(898);
  _static_L3_huffman_tabs[1393] := TInt16T(898);
  _static_L3_huffman_tabs[1394] := TInt16T(808);
  _static_L3_huffman_tabs[1395] := TInt16T(808);
  _static_L3_huffman_tabs[1396] := TInt16T(897);
  _static_L3_huffman_tabs[1397] := TInt16T(897);
  _static_L3_huffman_tabs[1398] := TInt16T(792);
  _static_L3_huffman_tabs[1399] := TInt16T(792);
  _static_L3_huffman_tabs[1400] := TInt16T(1095);
  _static_L3_huffman_tabs[1401] := TInt16T(1152);
  _static_L3_huffman_tabs[1402] := TInt16T(1032);
  _static_L3_huffman_tabs[1403] := TInt16T(1125);
  _static_L3_huffman_tabs[1404] := TInt16T(1110);
  _static_L3_huffman_tabs[1405] := TInt16T(1139);
  _static_L3_huffman_tabs[1406] := TInt16T(1079);
  _static_L3_huffman_tabs[1407] := TInt16T(1124);
  _static_L3_huffman_tabs[1408] := TInt16T(882);
  _static_L3_huffman_tabs[1409] := TInt16T(807);
  _static_L3_huffman_tabs[1410] := TInt16T(838);
  _static_L3_huffman_tabs[1411] := TInt16T(881);
  _static_L3_huffman_tabs[1412] := TInt16T(853);
  _static_L3_huffman_tabs[1413] := TInt16T(791);
  _static_L3_huffman_tabs[1414] := TInt16T(-2319);
  _static_L3_huffman_tabs[1415] := TInt16T(867);
  _static_L3_huffman_tabs[1416] := TInt16T(368);
  _static_L3_huffman_tabs[1417] := TInt16T(263);
  _static_L3_huffman_tabs[1418] := TInt16T(822);
  _static_L3_huffman_tabs[1419] := TInt16T(852);
  _static_L3_huffman_tabs[1420] := TInt16T(837);
  _static_L3_huffman_tabs[1421] := TInt16T(866);
  _static_L3_huffman_tabs[1422] := TInt16T(806);
  _static_L3_huffman_tabs[1423] := TInt16T(865);
  _static_L3_huffman_tabs[1424] := TInt16T(-2399);
  _static_L3_huffman_tabs[1425] := TInt16T(851);
  _static_L3_huffman_tabs[1426] := TInt16T(352);
  _static_L3_huffman_tabs[1427] := TInt16T(262);
  _static_L3_huffman_tabs[1428] := TInt16T(534);
  _static_L3_huffman_tabs[1429] := TInt16T(534);
  _static_L3_huffman_tabs[1430] := TInt16T(821);
  _static_L3_huffman_tabs[1431] := TInt16T(836);
  _static_L3_huffman_tabs[1432] := TInt16T(594);
  _static_L3_huffman_tabs[1433] := TInt16T(594);
  _static_L3_huffman_tabs[1434] := TInt16T(549);
  _static_L3_huffman_tabs[1435] := TInt16T(549);
  _static_L3_huffman_tabs[1436] := TInt16T(593);
  _static_L3_huffman_tabs[1437] := TInt16T(593);
  _static_L3_huffman_tabs[1438] := TInt16T(533);
  _static_L3_huffman_tabs[1439] := TInt16T(533);
  _static_L3_huffman_tabs[1440] := TInt16T(848);
  _static_L3_huffman_tabs[1441] := TInt16T(773);
  _static_L3_huffman_tabs[1442] := TInt16T(579);
  _static_L3_huffman_tabs[1443] := TInt16T(579);
  _static_L3_huffman_tabs[1444] := TInt16T(564);
  _static_L3_huffman_tabs[1445] := TInt16T(578);
  _static_L3_huffman_tabs[1446] := TInt16T(548);
  _static_L3_huffman_tabs[1447] := TInt16T(563);
  _static_L3_huffman_tabs[1448] := TInt16T(276);
  _static_L3_huffman_tabs[1449] := TInt16T(276);
  _static_L3_huffman_tabs[1450] := TInt16T(577);
  _static_L3_huffman_tabs[1451] := TInt16T(576);
  _static_L3_huffman_tabs[1452] := TInt16T(306);
  _static_L3_huffman_tabs[1453] := TInt16T(291);
  _static_L3_huffman_tabs[1454] := TInt16T(516);
  _static_L3_huffman_tabs[1455] := TInt16T(560);
  _static_L3_huffman_tabs[1456] := TInt16T(305);
  _static_L3_huffman_tabs[1457] := TInt16T(305);
  _static_L3_huffman_tabs[1458] := TInt16T(275);
  _static_L3_huffman_tabs[1459] := TInt16T(259);
  _static_L3_huffman_tabs[1460] := TInt16T(-251);
  _static_L3_huffman_tabs[1461] := TInt16T(-892);
  _static_L3_huffman_tabs[1462] := TInt16T(-2058);
  _static_L3_huffman_tabs[1463] := TInt16T(-2620);
  _static_L3_huffman_tabs[1464] := TInt16T(-2828);
  _static_L3_huffman_tabs[1465] := TInt16T(-2957);
  _static_L3_huffman_tabs[1466] := TInt16T(-3023);
  _static_L3_huffman_tabs[1467] := TInt16T(-3039);
  _static_L3_huffman_tabs[1468] := TInt16T(1041);
  _static_L3_huffman_tabs[1469] := TInt16T(1041);
  _static_L3_huffman_tabs[1470] := TInt16T(1040);
  _static_L3_huffman_tabs[1471] := TInt16T(1040);
  _static_L3_huffman_tabs[1472] := TInt16T(769);
  _static_L3_huffman_tabs[1473] := TInt16T(769);
  _static_L3_huffman_tabs[1474] := TInt16T(769);
  _static_L3_huffman_tabs[1475] := TInt16T(769);
  _static_L3_huffman_tabs[1476] := TInt16T(256);
  _static_L3_huffman_tabs[1477] := TInt16T(256);
  _static_L3_huffman_tabs[1478] := TInt16T(256);
  _static_L3_huffman_tabs[1479] := TInt16T(256);
  _static_L3_huffman_tabs[1480] := TInt16T(256);
  _static_L3_huffman_tabs[1481] := TInt16T(256);
  _static_L3_huffman_tabs[1482] := TInt16T(256);
  _static_L3_huffman_tabs[1483] := TInt16T(256);
  _static_L3_huffman_tabs[1484] := TInt16T(256);
  _static_L3_huffman_tabs[1485] := TInt16T(256);
  _static_L3_huffman_tabs[1486] := TInt16T(256);
  _static_L3_huffman_tabs[1487] := TInt16T(256);
  _static_L3_huffman_tabs[1488] := TInt16T(256);
  _static_L3_huffman_tabs[1489] := TInt16T(256);
  _static_L3_huffman_tabs[1490] := TInt16T(256);
  _static_L3_huffman_tabs[1491] := TInt16T(256);
  _static_L3_huffman_tabs[1492] := TInt16T(-511);
  _static_L3_huffman_tabs[1493] := TInt16T(-527);
  _static_L3_huffman_tabs[1494] := TInt16T(-543);
  _static_L3_huffman_tabs[1495] := TInt16T(-559);
  _static_L3_huffman_tabs[1496] := TInt16T(1530);
  _static_L3_huffman_tabs[1497] := TInt16T(-575);
  _static_L3_huffman_tabs[1498] := TInt16T(-591);
  _static_L3_huffman_tabs[1499] := TInt16T(1528);
  _static_L3_huffman_tabs[1500] := TInt16T(1527);
  _static_L3_huffman_tabs[1501] := TInt16T(1407);
  _static_L3_huffman_tabs[1502] := TInt16T(1526);
  _static_L3_huffman_tabs[1503] := TInt16T(1391);
  _static_L3_huffman_tabs[1504] := TInt16T(1023);
  _static_L3_huffman_tabs[1505] := TInt16T(1023);
  _static_L3_huffman_tabs[1506] := TInt16T(1023);
  _static_L3_huffman_tabs[1507] := TInt16T(1023);
  _static_L3_huffman_tabs[1508] := TInt16T(1525);
  _static_L3_huffman_tabs[1509] := TInt16T(1375);
  _static_L3_huffman_tabs[1510] := TInt16T(1268);
  _static_L3_huffman_tabs[1511] := TInt16T(1268);
  _static_L3_huffman_tabs[1512] := TInt16T(1103);
  _static_L3_huffman_tabs[1513] := TInt16T(1103);
  _static_L3_huffman_tabs[1514] := TInt16T(1087);
  _static_L3_huffman_tabs[1515] := TInt16T(1087);
  _static_L3_huffman_tabs[1516] := TInt16T(1039);
  _static_L3_huffman_tabs[1517] := TInt16T(1039);
  _static_L3_huffman_tabs[1518] := TInt16T(1523);
  _static_L3_huffman_tabs[1519] := TInt16T(-604);
  _static_L3_huffman_tabs[1520] := TInt16T(815);
  _static_L3_huffman_tabs[1521] := TInt16T(815);
  _static_L3_huffman_tabs[1522] := TInt16T(815);
  _static_L3_huffman_tabs[1523] := TInt16T(815);
  _static_L3_huffman_tabs[1524] := TInt16T(510);
  _static_L3_huffman_tabs[1525] := TInt16T(495);
  _static_L3_huffman_tabs[1526] := TInt16T(509);
  _static_L3_huffman_tabs[1527] := TInt16T(479);
  _static_L3_huffman_tabs[1528] := TInt16T(508);
  _static_L3_huffman_tabs[1529] := TInt16T(463);
  _static_L3_huffman_tabs[1530] := TInt16T(507);
  _static_L3_huffman_tabs[1531] := TInt16T(447);
  _static_L3_huffman_tabs[1532] := TInt16T(431);
  _static_L3_huffman_tabs[1533] := TInt16T(505);
  _static_L3_huffman_tabs[1534] := TInt16T(415);
  _static_L3_huffman_tabs[1535] := TInt16T(399);
  _static_L3_huffman_tabs[1536] := TInt16T(-734);
  _static_L3_huffman_tabs[1537] := TInt16T(-782);
  _static_L3_huffman_tabs[1538] := TInt16T(1262);
  _static_L3_huffman_tabs[1539] := TInt16T(-815);
  _static_L3_huffman_tabs[1540] := TInt16T(1259);
  _static_L3_huffman_tabs[1541] := TInt16T(1244);
  _static_L3_huffman_tabs[1542] := TInt16T(-831);
  _static_L3_huffman_tabs[1543] := TInt16T(1258);
  _static_L3_huffman_tabs[1544] := TInt16T(1228);
  _static_L3_huffman_tabs[1545] := TInt16T(-847);
  _static_L3_huffman_tabs[1546] := TInt16T(-863);
  _static_L3_huffman_tabs[1547] := TInt16T(1196);
  _static_L3_huffman_tabs[1548] := TInt16T(-879);
  _static_L3_huffman_tabs[1549] := TInt16T(1253);
  _static_L3_huffman_tabs[1550] := TInt16T(987);
  _static_L3_huffman_tabs[1551] := TInt16T(987);
  _static_L3_huffman_tabs[1552] := TInt16T(748);
  _static_L3_huffman_tabs[1553] := TInt16T(-767);
  _static_L3_huffman_tabs[1554] := TInt16T(493);
  _static_L3_huffman_tabs[1555] := TInt16T(493);
  _static_L3_huffman_tabs[1556] := TInt16T(462);
  _static_L3_huffman_tabs[1557] := TInt16T(477);
  _static_L3_huffman_tabs[1558] := TInt16T(414);
  _static_L3_huffman_tabs[1559] := TInt16T(414);
  _static_L3_huffman_tabs[1560] := TInt16T(686);
  _static_L3_huffman_tabs[1561] := TInt16T(669);
  _static_L3_huffman_tabs[1562] := TInt16T(478);
  _static_L3_huffman_tabs[1563] := TInt16T(446);
  _static_L3_huffman_tabs[1564] := TInt16T(461);
  _static_L3_huffman_tabs[1565] := TInt16T(445);
  _static_L3_huffman_tabs[1566] := TInt16T(474);
  _static_L3_huffman_tabs[1567] := TInt16T(429);
  _static_L3_huffman_tabs[1568] := TInt16T(487);
  _static_L3_huffman_tabs[1569] := TInt16T(458);
  _static_L3_huffman_tabs[1570] := TInt16T(412);
  _static_L3_huffman_tabs[1571] := TInt16T(471);
  _static_L3_huffman_tabs[1572] := TInt16T(1266);
  _static_L3_huffman_tabs[1573] := TInt16T(1264);
  _static_L3_huffman_tabs[1574] := TInt16T(1009);
  _static_L3_huffman_tabs[1575] := TInt16T(1009);
  _static_L3_huffman_tabs[1576] := TInt16T(799);
  _static_L3_huffman_tabs[1577] := TInt16T(799);
  _static_L3_huffman_tabs[1578] := TInt16T(-1019);
  _static_L3_huffman_tabs[1579] := TInt16T(-1276);
  _static_L3_huffman_tabs[1580] := TInt16T(-1452);
  _static_L3_huffman_tabs[1581] := TInt16T(-1581);
  _static_L3_huffman_tabs[1582] := TInt16T(-1677);
  _static_L3_huffman_tabs[1583] := TInt16T(-1757);
  _static_L3_huffman_tabs[1584] := TInt16T(-1821);
  _static_L3_huffman_tabs[1585] := TInt16T(-1886);
  _static_L3_huffman_tabs[1586] := TInt16T(-1933);
  _static_L3_huffman_tabs[1587] := TInt16T(-1997);
  _static_L3_huffman_tabs[1588] := TInt16T(1257);
  _static_L3_huffman_tabs[1589] := TInt16T(1257);
  _static_L3_huffman_tabs[1590] := TInt16T(1483);
  _static_L3_huffman_tabs[1591] := TInt16T(1468);
  _static_L3_huffman_tabs[1592] := TInt16T(1512);
  _static_L3_huffman_tabs[1593] := TInt16T(1422);
  _static_L3_huffman_tabs[1594] := TInt16T(1497);
  _static_L3_huffman_tabs[1595] := TInt16T(1406);
  _static_L3_huffman_tabs[1596] := TInt16T(1467);
  _static_L3_huffman_tabs[1597] := TInt16T(1496);
  _static_L3_huffman_tabs[1598] := TInt16T(1421);
  _static_L3_huffman_tabs[1599] := TInt16T(1510);
  _static_L3_huffman_tabs[1600] := TInt16T(1134);
  _static_L3_huffman_tabs[1601] := TInt16T(1134);
  _static_L3_huffman_tabs[1602] := TInt16T(1225);
  _static_L3_huffman_tabs[1603] := TInt16T(1225);
  _static_L3_huffman_tabs[1604] := TInt16T(1466);
  _static_L3_huffman_tabs[1605] := TInt16T(1451);
  _static_L3_huffman_tabs[1606] := TInt16T(1374);
  _static_L3_huffman_tabs[1607] := TInt16T(1405);
  _static_L3_huffman_tabs[1608] := TInt16T(1252);
  _static_L3_huffman_tabs[1609] := TInt16T(1252);
  _static_L3_huffman_tabs[1610] := TInt16T(1358);
  _static_L3_huffman_tabs[1611] := TInt16T(1480);
  _static_L3_huffman_tabs[1612] := TInt16T(1164);
  _static_L3_huffman_tabs[1613] := TInt16T(1164);
  _static_L3_huffman_tabs[1614] := TInt16T(1251);
  _static_L3_huffman_tabs[1615] := TInt16T(1251);
  _static_L3_huffman_tabs[1616] := TInt16T(1238);
  _static_L3_huffman_tabs[1617] := TInt16T(1238);
  _static_L3_huffman_tabs[1618] := TInt16T(1389);
  _static_L3_huffman_tabs[1619] := TInt16T(1465);
  _static_L3_huffman_tabs[1620] := TInt16T(-1407);
  _static_L3_huffman_tabs[1621] := TInt16T(1054);
  _static_L3_huffman_tabs[1622] := TInt16T(1101);
  _static_L3_huffman_tabs[1623] := TInt16T(-1423);
  _static_L3_huffman_tabs[1624] := TInt16T(1207);
  _static_L3_huffman_tabs[1625] := TInt16T(-1439);
  _static_L3_huffman_tabs[1626] := TInt16T(830);
  _static_L3_huffman_tabs[1627] := TInt16T(830);
  _static_L3_huffman_tabs[1628] := TInt16T(1248);
  _static_L3_huffman_tabs[1629] := TInt16T(1038);
  _static_L3_huffman_tabs[1630] := TInt16T(1237);
  _static_L3_huffman_tabs[1631] := TInt16T(1117);
  _static_L3_huffman_tabs[1632] := TInt16T(1223);
  _static_L3_huffman_tabs[1633] := TInt16T(1148);
  _static_L3_huffman_tabs[1634] := TInt16T(1236);
  _static_L3_huffman_tabs[1635] := TInt16T(1208);
  _static_L3_huffman_tabs[1636] := TInt16T(411);
  _static_L3_huffman_tabs[1637] := TInt16T(426);
  _static_L3_huffman_tabs[1638] := TInt16T(395);
  _static_L3_huffman_tabs[1639] := TInt16T(410);
  _static_L3_huffman_tabs[1640] := TInt16T(379);
  _static_L3_huffman_tabs[1641] := TInt16T(269);
  _static_L3_huffman_tabs[1642] := TInt16T(1193);
  _static_L3_huffman_tabs[1643] := TInt16T(1222);
  _static_L3_huffman_tabs[1644] := TInt16T(1132);
  _static_L3_huffman_tabs[1645] := TInt16T(1235);
  _static_L3_huffman_tabs[1646] := TInt16T(1221);
  _static_L3_huffman_tabs[1647] := TInt16T(1116);
  _static_L3_huffman_tabs[1648] := TInt16T(976);
  _static_L3_huffman_tabs[1649] := TInt16T(976);
  _static_L3_huffman_tabs[1650] := TInt16T(1192);
  _static_L3_huffman_tabs[1651] := TInt16T(1162);
  _static_L3_huffman_tabs[1652] := TInt16T(1177);
  _static_L3_huffman_tabs[1653] := TInt16T(1220);
  _static_L3_huffman_tabs[1654] := TInt16T(1131);
  _static_L3_huffman_tabs[1655] := TInt16T(1191);
  _static_L3_huffman_tabs[1656] := TInt16T(963);
  _static_L3_huffman_tabs[1657] := TInt16T(963);
  _static_L3_huffman_tabs[1658] := TInt16T(-1647);
  _static_L3_huffman_tabs[1659] := TInt16T(961);
  _static_L3_huffman_tabs[1660] := TInt16T(780);
  _static_L3_huffman_tabs[1661] := TInt16T(-1663);
  _static_L3_huffman_tabs[1662] := TInt16T(558);
  _static_L3_huffman_tabs[1663] := TInt16T(558);
  _static_L3_huffman_tabs[1664] := TInt16T(994);
  _static_L3_huffman_tabs[1665] := TInt16T(993);
  _static_L3_huffman_tabs[1666] := TInt16T(437);
  _static_L3_huffman_tabs[1667] := TInt16T(408);
  _static_L3_huffman_tabs[1668] := TInt16T(393);
  _static_L3_huffman_tabs[1669] := TInt16T(407);
  _static_L3_huffman_tabs[1670] := TInt16T(829);
  _static_L3_huffman_tabs[1671] := TInt16T(978);
  _static_L3_huffman_tabs[1672] := TInt16T(813);
  _static_L3_huffman_tabs[1673] := TInt16T(797);
  _static_L3_huffman_tabs[1674] := TInt16T(947);
  _static_L3_huffman_tabs[1675] := TInt16T(-1743);
  _static_L3_huffman_tabs[1676] := TInt16T(721);
  _static_L3_huffman_tabs[1677] := TInt16T(721);
  _static_L3_huffman_tabs[1678] := TInt16T(377);
  _static_L3_huffman_tabs[1679] := TInt16T(392);
  _static_L3_huffman_tabs[1680] := TInt16T(844);
  _static_L3_huffman_tabs[1681] := TInt16T(950);
  _static_L3_huffman_tabs[1682] := TInt16T(828);
  _static_L3_huffman_tabs[1683] := TInt16T(890);
  _static_L3_huffman_tabs[1684] := TInt16T(706);
  _static_L3_huffman_tabs[1685] := TInt16T(706);
  _static_L3_huffman_tabs[1686] := TInt16T(812);
  _static_L3_huffman_tabs[1687] := TInt16T(859);
  _static_L3_huffman_tabs[1688] := TInt16T(796);
  _static_L3_huffman_tabs[1689] := TInt16T(960);
  _static_L3_huffman_tabs[1690] := TInt16T(948);
  _static_L3_huffman_tabs[1691] := TInt16T(843);
  _static_L3_huffman_tabs[1692] := TInt16T(934);
  _static_L3_huffman_tabs[1693] := TInt16T(874);
  _static_L3_huffman_tabs[1694] := TInt16T(571);
  _static_L3_huffman_tabs[1695] := TInt16T(571);
  _static_L3_huffman_tabs[1696] := TInt16T(-1919);
  _static_L3_huffman_tabs[1697] := TInt16T(690);
  _static_L3_huffman_tabs[1698] := TInt16T(555);
  _static_L3_huffman_tabs[1699] := TInt16T(689);
  _static_L3_huffman_tabs[1700] := TInt16T(421);
  _static_L3_huffman_tabs[1701] := TInt16T(346);
  _static_L3_huffman_tabs[1702] := TInt16T(539);
  _static_L3_huffman_tabs[1703] := TInt16T(539);
  _static_L3_huffman_tabs[1704] := TInt16T(944);
  _static_L3_huffman_tabs[1705] := TInt16T(779);
  _static_L3_huffman_tabs[1706] := TInt16T(918);
  _static_L3_huffman_tabs[1707] := TInt16T(873);
  _static_L3_huffman_tabs[1708] := TInt16T(932);
  _static_L3_huffman_tabs[1709] := TInt16T(842);
  _static_L3_huffman_tabs[1710] := TInt16T(903);
  _static_L3_huffman_tabs[1711] := TInt16T(888);
  _static_L3_huffman_tabs[1712] := TInt16T(570);
  _static_L3_huffman_tabs[1713] := TInt16T(570);
  _static_L3_huffman_tabs[1714] := TInt16T(931);
  _static_L3_huffman_tabs[1715] := TInt16T(917);
  _static_L3_huffman_tabs[1716] := TInt16T(674);
  _static_L3_huffman_tabs[1717] := TInt16T(674);
  _static_L3_huffman_tabs[1718] := TInt16T(-2575);
  _static_L3_huffman_tabs[1719] := TInt16T(1562);
  _static_L3_huffman_tabs[1720] := TInt16T(-2591);
  _static_L3_huffman_tabs[1721] := TInt16T(1609);
  _static_L3_huffman_tabs[1722] := TInt16T(-2607);
  _static_L3_huffman_tabs[1723] := TInt16T(1654);
  _static_L3_huffman_tabs[1724] := TInt16T(1322);
  _static_L3_huffman_tabs[1725] := TInt16T(1322);
  _static_L3_huffman_tabs[1726] := TInt16T(1441);
  _static_L3_huffman_tabs[1727] := TInt16T(1441);
  _static_L3_huffman_tabs[1728] := TInt16T(1696);
  _static_L3_huffman_tabs[1729] := TInt16T(1546);
  _static_L3_huffman_tabs[1730] := TInt16T(1683);
  _static_L3_huffman_tabs[1731] := TInt16T(1593);
  _static_L3_huffman_tabs[1732] := TInt16T(1669);
  _static_L3_huffman_tabs[1733] := TInt16T(1624);
  _static_L3_huffman_tabs[1734] := TInt16T(1426);
  _static_L3_huffman_tabs[1735] := TInt16T(1426);
  _static_L3_huffman_tabs[1736] := TInt16T(1321);
  _static_L3_huffman_tabs[1737] := TInt16T(1321);
  _static_L3_huffman_tabs[1738] := TInt16T(1639);
  _static_L3_huffman_tabs[1739] := TInt16T(1680);
  _static_L3_huffman_tabs[1740] := TInt16T(1425);
  _static_L3_huffman_tabs[1741] := TInt16T(1425);
  _static_L3_huffman_tabs[1742] := TInt16T(1305);
  _static_L3_huffman_tabs[1743] := TInt16T(1305);
  _static_L3_huffman_tabs[1744] := TInt16T(1545);
  _static_L3_huffman_tabs[1745] := TInt16T(1668);
  _static_L3_huffman_tabs[1746] := TInt16T(1608);
  _static_L3_huffman_tabs[1747] := TInt16T(1623);
  _static_L3_huffman_tabs[1748] := TInt16T(1667);
  _static_L3_huffman_tabs[1749] := TInt16T(1592);
  _static_L3_huffman_tabs[1750] := TInt16T(1638);
  _static_L3_huffman_tabs[1751] := TInt16T(1666);
  _static_L3_huffman_tabs[1752] := TInt16T(1320);
  _static_L3_huffman_tabs[1753] := TInt16T(1320);
  _static_L3_huffman_tabs[1754] := TInt16T(1652);
  _static_L3_huffman_tabs[1755] := TInt16T(1607);
  _static_L3_huffman_tabs[1756] := TInt16T(1409);
  _static_L3_huffman_tabs[1757] := TInt16T(1409);
  _static_L3_huffman_tabs[1758] := TInt16T(1304);
  _static_L3_huffman_tabs[1759] := TInt16T(1304);
  _static_L3_huffman_tabs[1760] := TInt16T(1288);
  _static_L3_huffman_tabs[1761] := TInt16T(1288);
  _static_L3_huffman_tabs[1762] := TInt16T(1664);
  _static_L3_huffman_tabs[1763] := TInt16T(1637);
  _static_L3_huffman_tabs[1764] := TInt16T(1395);
  _static_L3_huffman_tabs[1765] := TInt16T(1395);
  _static_L3_huffman_tabs[1766] := TInt16T(1335);
  _static_L3_huffman_tabs[1767] := TInt16T(1335);
  _static_L3_huffman_tabs[1768] := TInt16T(1622);
  _static_L3_huffman_tabs[1769] := TInt16T(1636);
  _static_L3_huffman_tabs[1770] := TInt16T(1394);
  _static_L3_huffman_tabs[1771] := TInt16T(1394);
  _static_L3_huffman_tabs[1772] := TInt16T(1319);
  _static_L3_huffman_tabs[1773] := TInt16T(1319);
  _static_L3_huffman_tabs[1774] := TInt16T(1606);
  _static_L3_huffman_tabs[1775] := TInt16T(1621);
  _static_L3_huffman_tabs[1776] := TInt16T(1392);
  _static_L3_huffman_tabs[1777] := TInt16T(1392);
  _static_L3_huffman_tabs[1778] := TInt16T(1137);
  _static_L3_huffman_tabs[1779] := TInt16T(1137);
  _static_L3_huffman_tabs[1780] := TInt16T(1137);
  _static_L3_huffman_tabs[1781] := TInt16T(1137);
  _static_L3_huffman_tabs[1782] := TInt16T(345);
  _static_L3_huffman_tabs[1783] := TInt16T(390);
  _static_L3_huffman_tabs[1784] := TInt16T(360);
  _static_L3_huffman_tabs[1785] := TInt16T(375);
  _static_L3_huffman_tabs[1786] := TInt16T(404);
  _static_L3_huffman_tabs[1787] := TInt16T(373);
  _static_L3_huffman_tabs[1788] := TInt16T(1047);
  _static_L3_huffman_tabs[1789] := TInt16T(-2751);
  _static_L3_huffman_tabs[1790] := TInt16T(-2767);
  _static_L3_huffman_tabs[1791] := TInt16T(-2783);
  _static_L3_huffman_tabs[1792] := TInt16T(1062);
  _static_L3_huffman_tabs[1793] := TInt16T(1121);
  _static_L3_huffman_tabs[1794] := TInt16T(1046);
  _static_L3_huffman_tabs[1795] := TInt16T(-2799);
  _static_L3_huffman_tabs[1796] := TInt16T(1077);
  _static_L3_huffman_tabs[1797] := TInt16T(-2815);
  _static_L3_huffman_tabs[1798] := TInt16T(1106);
  _static_L3_huffman_tabs[1799] := TInt16T(1061);
  _static_L3_huffman_tabs[1800] := TInt16T(789);
  _static_L3_huffman_tabs[1801] := TInt16T(789);
  _static_L3_huffman_tabs[1802] := TInt16T(1105);
  _static_L3_huffman_tabs[1803] := TInt16T(1104);
  _static_L3_huffman_tabs[1804] := TInt16T(263);
  _static_L3_huffman_tabs[1805] := TInt16T(355);
  _static_L3_huffman_tabs[1806] := TInt16T(310);
  _static_L3_huffman_tabs[1807] := TInt16T(340);
  _static_L3_huffman_tabs[1808] := TInt16T(325);
  _static_L3_huffman_tabs[1809] := TInt16T(354);
  _static_L3_huffman_tabs[1810] := TInt16T(352);
  _static_L3_huffman_tabs[1811] := TInt16T(262);
  _static_L3_huffman_tabs[1812] := TInt16T(339);
  _static_L3_huffman_tabs[1813] := TInt16T(324);
  _static_L3_huffman_tabs[1814] := TInt16T(1091);
  _static_L3_huffman_tabs[1815] := TInt16T(1076);
  _static_L3_huffman_tabs[1816] := TInt16T(1029);
  _static_L3_huffman_tabs[1817] := TInt16T(1090);
  _static_L3_huffman_tabs[1818] := TInt16T(1060);
  _static_L3_huffman_tabs[1819] := TInt16T(1075);
  _static_L3_huffman_tabs[1820] := TInt16T(833);
  _static_L3_huffman_tabs[1821] := TInt16T(833);
  _static_L3_huffman_tabs[1822] := TInt16T(788);
  _static_L3_huffman_tabs[1823] := TInt16T(788);
  _static_L3_huffman_tabs[1824] := TInt16T(1088);
  _static_L3_huffman_tabs[1825] := TInt16T(1028);
  _static_L3_huffman_tabs[1826] := TInt16T(818);
  _static_L3_huffman_tabs[1827] := TInt16T(818);
  _static_L3_huffman_tabs[1828] := TInt16T(803);
  _static_L3_huffman_tabs[1829] := TInt16T(803);
  _static_L3_huffman_tabs[1830] := TInt16T(561);
  _static_L3_huffman_tabs[1831] := TInt16T(561);
  _static_L3_huffman_tabs[1832] := TInt16T(531);
  _static_L3_huffman_tabs[1833] := TInt16T(531);
  _static_L3_huffman_tabs[1834] := TInt16T(816);
  _static_L3_huffman_tabs[1835] := TInt16T(771);
  _static_L3_huffman_tabs[1836] := TInt16T(546);
  _static_L3_huffman_tabs[1837] := TInt16T(546);
  _static_L3_huffman_tabs[1838] := TInt16T(289);
  _static_L3_huffman_tabs[1839] := TInt16T(274);
  _static_L3_huffman_tabs[1840] := TInt16T(288);
  _static_L3_huffman_tabs[1841] := TInt16T(258);
  _static_L3_huffman_tabs[1842] := TInt16T(-253);
  _static_L3_huffman_tabs[1843] := TInt16T(-317);
  _static_L3_huffman_tabs[1844] := TInt16T(-381);
  _static_L3_huffman_tabs[1845] := TInt16T(-446);
  _static_L3_huffman_tabs[1846] := TInt16T(-478);
  _static_L3_huffman_tabs[1847] := TInt16T(-509);
  _static_L3_huffman_tabs[1848] := TInt16T(1279);
  _static_L3_huffman_tabs[1849] := TInt16T(1279);
  _static_L3_huffman_tabs[1850] := TInt16T(-811);
  _static_L3_huffman_tabs[1851] := TInt16T(-1179);
  _static_L3_huffman_tabs[1852] := TInt16T(-1451);
  _static_L3_huffman_tabs[1853] := TInt16T(-1756);
  _static_L3_huffman_tabs[1854] := TInt16T(-1900);
  _static_L3_huffman_tabs[1855] := TInt16T(-2028);
  _static_L3_huffman_tabs[1856] := TInt16T(-2189);
  _static_L3_huffman_tabs[1857] := TInt16T(-2253);
  _static_L3_huffman_tabs[1858] := TInt16T(-2333);
  _static_L3_huffman_tabs[1859] := TInt16T(-2414);
  _static_L3_huffman_tabs[1860] := TInt16T(-2445);
  _static_L3_huffman_tabs[1861] := TInt16T(-2511);
  _static_L3_huffman_tabs[1862] := TInt16T(-2526);
  _static_L3_huffman_tabs[1863] := TInt16T(1313);
  _static_L3_huffman_tabs[1864] := TInt16T(1298);
  _static_L3_huffman_tabs[1865] := TInt16T(-2559);
  _static_L3_huffman_tabs[1866] := TInt16T(1041);
  _static_L3_huffman_tabs[1867] := TInt16T(1041);
  _static_L3_huffman_tabs[1868] := TInt16T(1040);
  _static_L3_huffman_tabs[1869] := TInt16T(1040);
  _static_L3_huffman_tabs[1870] := TInt16T(1025);
  _static_L3_huffman_tabs[1871] := TInt16T(1025);
  _static_L3_huffman_tabs[1872] := TInt16T(1024);
  _static_L3_huffman_tabs[1873] := TInt16T(1024);
  _static_L3_huffman_tabs[1874] := TInt16T(1022);
  _static_L3_huffman_tabs[1875] := TInt16T(1007);
  _static_L3_huffman_tabs[1876] := TInt16T(1021);
  _static_L3_huffman_tabs[1877] := TInt16T(991);
  _static_L3_huffman_tabs[1878] := TInt16T(1020);
  _static_L3_huffman_tabs[1879] := TInt16T(975);
  _static_L3_huffman_tabs[1880] := TInt16T(1019);
  _static_L3_huffman_tabs[1881] := TInt16T(959);
  _static_L3_huffman_tabs[1882] := TInt16T(687);
  _static_L3_huffman_tabs[1883] := TInt16T(687);
  _static_L3_huffman_tabs[1884] := TInt16T(1018);
  _static_L3_huffman_tabs[1885] := TInt16T(1017);
  _static_L3_huffman_tabs[1886] := TInt16T(671);
  _static_L3_huffman_tabs[1887] := TInt16T(671);
  _static_L3_huffman_tabs[1888] := TInt16T(655);
  _static_L3_huffman_tabs[1889] := TInt16T(655);
  _static_L3_huffman_tabs[1890] := TInt16T(1016);
  _static_L3_huffman_tabs[1891] := TInt16T(1015);
  _static_L3_huffman_tabs[1892] := TInt16T(639);
  _static_L3_huffman_tabs[1893] := TInt16T(639);
  _static_L3_huffman_tabs[1894] := TInt16T(758);
  _static_L3_huffman_tabs[1895] := TInt16T(758);
  _static_L3_huffman_tabs[1896] := TInt16T(623);
  _static_L3_huffman_tabs[1897] := TInt16T(623);
  _static_L3_huffman_tabs[1898] := TInt16T(757);
  _static_L3_huffman_tabs[1899] := TInt16T(607);
  _static_L3_huffman_tabs[1900] := TInt16T(756);
  _static_L3_huffman_tabs[1901] := TInt16T(591);
  _static_L3_huffman_tabs[1902] := TInt16T(755);
  _static_L3_huffman_tabs[1903] := TInt16T(575);
  _static_L3_huffman_tabs[1904] := TInt16T(754);
  _static_L3_huffman_tabs[1905] := TInt16T(559);
  _static_L3_huffman_tabs[1906] := TInt16T(543);
  _static_L3_huffman_tabs[1907] := TInt16T(543);
  _static_L3_huffman_tabs[1908] := TInt16T(1009);
  _static_L3_huffman_tabs[1909] := TInt16T(783);
  _static_L3_huffman_tabs[1910] := TInt16T(-575);
  _static_L3_huffman_tabs[1911] := TInt16T(-621);
  _static_L3_huffman_tabs[1912] := TInt16T(-685);
  _static_L3_huffman_tabs[1913] := TInt16T(-749);
  _static_L3_huffman_tabs[1914] := TInt16T(496);
  _static_L3_huffman_tabs[1915] := TInt16T(-590);
  _static_L3_huffman_tabs[1916] := TInt16T(750);
  _static_L3_huffman_tabs[1917] := TInt16T(749);
  _static_L3_huffman_tabs[1918] := TInt16T(734);
  _static_L3_huffman_tabs[1919] := TInt16T(748);
  _static_L3_huffman_tabs[1920] := TInt16T(974);
  _static_L3_huffman_tabs[1921] := TInt16T(989);
  _static_L3_huffman_tabs[1922] := TInt16T(1003);
  _static_L3_huffman_tabs[1923] := TInt16T(958);
  _static_L3_huffman_tabs[1924] := TInt16T(988);
  _static_L3_huffman_tabs[1925] := TInt16T(973);
  _static_L3_huffman_tabs[1926] := TInt16T(1002);
  _static_L3_huffman_tabs[1927] := TInt16T(942);
  _static_L3_huffman_tabs[1928] := TInt16T(987);
  _static_L3_huffman_tabs[1929] := TInt16T(957);
  _static_L3_huffman_tabs[1930] := TInt16T(972);
  _static_L3_huffman_tabs[1931] := TInt16T(1001);
  _static_L3_huffman_tabs[1932] := TInt16T(926);
  _static_L3_huffman_tabs[1933] := TInt16T(986);
  _static_L3_huffman_tabs[1934] := TInt16T(941);
  _static_L3_huffman_tabs[1935] := TInt16T(971);
  _static_L3_huffman_tabs[1936] := TInt16T(956);
  _static_L3_huffman_tabs[1937] := TInt16T(1000);
  _static_L3_huffman_tabs[1938] := TInt16T(910);
  _static_L3_huffman_tabs[1939] := TInt16T(985);
  _static_L3_huffman_tabs[1940] := TInt16T(925);
  _static_L3_huffman_tabs[1941] := TInt16T(999);
  _static_L3_huffman_tabs[1942] := TInt16T(894);
  _static_L3_huffman_tabs[1943] := TInt16T(970);
  _static_L3_huffman_tabs[1944] := TInt16T(-1071);
  _static_L3_huffman_tabs[1945] := TInt16T(-1087);
  _static_L3_huffman_tabs[1946] := TInt16T(-1102);
  _static_L3_huffman_tabs[1947] := TInt16T(1390);
  _static_L3_huffman_tabs[1948] := TInt16T(-1135);
  _static_L3_huffman_tabs[1949] := TInt16T(1436);
  _static_L3_huffman_tabs[1950] := TInt16T(1509);
  _static_L3_huffman_tabs[1951] := TInt16T(1451);
  _static_L3_huffman_tabs[1952] := TInt16T(1374);
  _static_L3_huffman_tabs[1953] := TInt16T(-1151);
  _static_L3_huffman_tabs[1954] := TInt16T(1405);
  _static_L3_huffman_tabs[1955] := TInt16T(1358);
  _static_L3_huffman_tabs[1956] := TInt16T(1480);
  _static_L3_huffman_tabs[1957] := TInt16T(1420);
  _static_L3_huffman_tabs[1958] := TInt16T(-1167);
  _static_L3_huffman_tabs[1959] := TInt16T(1507);
  _static_L3_huffman_tabs[1960] := TInt16T(1494);
  _static_L3_huffman_tabs[1961] := TInt16T(1389);
  _static_L3_huffman_tabs[1962] := TInt16T(1342);
  _static_L3_huffman_tabs[1963] := TInt16T(1465);
  _static_L3_huffman_tabs[1964] := TInt16T(1435);
  _static_L3_huffman_tabs[1965] := TInt16T(1450);
  _static_L3_huffman_tabs[1966] := TInt16T(1326);
  _static_L3_huffman_tabs[1967] := TInt16T(1505);
  _static_L3_huffman_tabs[1968] := TInt16T(1310);
  _static_L3_huffman_tabs[1969] := TInt16T(1493);
  _static_L3_huffman_tabs[1970] := TInt16T(1373);
  _static_L3_huffman_tabs[1971] := TInt16T(1479);
  _static_L3_huffman_tabs[1972] := TInt16T(1404);
  _static_L3_huffman_tabs[1973] := TInt16T(1492);
  _static_L3_huffman_tabs[1974] := TInt16T(1464);
  _static_L3_huffman_tabs[1975] := TInt16T(1419);
  _static_L3_huffman_tabs[1976] := TInt16T(428);
  _static_L3_huffman_tabs[1977] := TInt16T(443);
  _static_L3_huffman_tabs[1978] := TInt16T(472);
  _static_L3_huffman_tabs[1979] := TInt16T(397);
  _static_L3_huffman_tabs[1980] := TInt16T(736);
  _static_L3_huffman_tabs[1981] := TInt16T(526);
  _static_L3_huffman_tabs[1982] := TInt16T(464);
  _static_L3_huffman_tabs[1983] := TInt16T(464);
  _static_L3_huffman_tabs[1984] := TInt16T(486);
  _static_L3_huffman_tabs[1985] := TInt16T(457);
  _static_L3_huffman_tabs[1986] := TInt16T(442);
  _static_L3_huffman_tabs[1987] := TInt16T(471);
  _static_L3_huffman_tabs[1988] := TInt16T(484);
  _static_L3_huffman_tabs[1989] := TInt16T(482);
  _static_L3_huffman_tabs[1990] := TInt16T(1357);
  _static_L3_huffman_tabs[1991] := TInt16T(1449);
  _static_L3_huffman_tabs[1992] := TInt16T(1434);
  _static_L3_huffman_tabs[1993] := TInt16T(1478);
  _static_L3_huffman_tabs[1994] := TInt16T(1388);
  _static_L3_huffman_tabs[1995] := TInt16T(1491);
  _static_L3_huffman_tabs[1996] := TInt16T(1341);
  _static_L3_huffman_tabs[1997] := TInt16T(1490);
  _static_L3_huffman_tabs[1998] := TInt16T(1325);
  _static_L3_huffman_tabs[1999] := TInt16T(1489);
  _static_L3_huffman_tabs[2000] := TInt16T(1463);
  _static_L3_huffman_tabs[2001] := TInt16T(1403);
  _static_L3_huffman_tabs[2002] := TInt16T(1309);
  _static_L3_huffman_tabs[2003] := TInt16T(1477);
  _static_L3_huffman_tabs[2004] := TInt16T(1372);
  _static_L3_huffman_tabs[2005] := TInt16T(1448);
  _static_L3_huffman_tabs[2006] := TInt16T(1418);
  _static_L3_huffman_tabs[2007] := TInt16T(1433);
  _static_L3_huffman_tabs[2008] := TInt16T(1476);
  _static_L3_huffman_tabs[2009] := TInt16T(1356);
  _static_L3_huffman_tabs[2010] := TInt16T(1462);
  _static_L3_huffman_tabs[2011] := TInt16T(1387);
  _static_L3_huffman_tabs[2012] := TInt16T(-1439);
  _static_L3_huffman_tabs[2013] := TInt16T(1475);
  _static_L3_huffman_tabs[2014] := TInt16T(1340);
  _static_L3_huffman_tabs[2015] := TInt16T(1447);
  _static_L3_huffman_tabs[2016] := TInt16T(1402);
  _static_L3_huffman_tabs[2017] := TInt16T(1474);
  _static_L3_huffman_tabs[2018] := TInt16T(1324);
  _static_L3_huffman_tabs[2019] := TInt16T(1461);
  _static_L3_huffman_tabs[2020] := TInt16T(1371);
  _static_L3_huffman_tabs[2021] := TInt16T(1473);
  _static_L3_huffman_tabs[2022] := TInt16T(269);
  _static_L3_huffman_tabs[2023] := TInt16T(448);
  _static_L3_huffman_tabs[2024] := TInt16T(1432);
  _static_L3_huffman_tabs[2025] := TInt16T(1417);
  _static_L3_huffman_tabs[2026] := TInt16T(1308);
  _static_L3_huffman_tabs[2027] := TInt16T(1460);
  _static_L3_huffman_tabs[2028] := TInt16T(-1711);
  _static_L3_huffman_tabs[2029] := TInt16T(1459);
  _static_L3_huffman_tabs[2030] := TInt16T(-1727);
  _static_L3_huffman_tabs[2031] := TInt16T(1441);
  _static_L3_huffman_tabs[2032] := TInt16T(1099);
  _static_L3_huffman_tabs[2033] := TInt16T(1099);
  _static_L3_huffman_tabs[2034] := TInt16T(1446);
  _static_L3_huffman_tabs[2035] := TInt16T(1386);
  _static_L3_huffman_tabs[2036] := TInt16T(1431);
  _static_L3_huffman_tabs[2037] := TInt16T(1401);
  _static_L3_huffman_tabs[2038] := TInt16T(-1743);
  _static_L3_huffman_tabs[2039] := TInt16T(1289);
  _static_L3_huffman_tabs[2040] := TInt16T(1083);
  _static_L3_huffman_tabs[2041] := TInt16T(1083);
  _static_L3_huffman_tabs[2042] := TInt16T(1160);
  _static_L3_huffman_tabs[2043] := TInt16T(1160);
  _static_L3_huffman_tabs[2044] := TInt16T(1458);
  _static_L3_huffman_tabs[2045] := TInt16T(1445);
  _static_L3_huffman_tabs[2046] := TInt16T(1067);
  _static_L3_huffman_tabs[2047] := TInt16T(1067);
  _static_L3_huffman_tabs[2048] := TInt16T(1370);
  _static_L3_huffman_tabs[2049] := TInt16T(1457);
  _static_L3_huffman_tabs[2050] := TInt16T(1307);
  _static_L3_huffman_tabs[2051] := TInt16T(1430);
  _static_L3_huffman_tabs[2052] := TInt16T(1129);
  _static_L3_huffman_tabs[2053] := TInt16T(1129);
  _static_L3_huffman_tabs[2054] := TInt16T(1098);
  _static_L3_huffman_tabs[2055] := TInt16T(1098);
  _static_L3_huffman_tabs[2056] := TInt16T(268);
  _static_L3_huffman_tabs[2057] := TInt16T(432);
  _static_L3_huffman_tabs[2058] := TInt16T(267);
  _static_L3_huffman_tabs[2059] := TInt16T(416);
  _static_L3_huffman_tabs[2060] := TInt16T(266);
  _static_L3_huffman_tabs[2061] := TInt16T(400);
  _static_L3_huffman_tabs[2062] := TInt16T(-1887);
  _static_L3_huffman_tabs[2063] := TInt16T(1144);
  _static_L3_huffman_tabs[2064] := TInt16T(1187);
  _static_L3_huffman_tabs[2065] := TInt16T(1082);
  _static_L3_huffman_tabs[2066] := TInt16T(1173);
  _static_L3_huffman_tabs[2067] := TInt16T(1113);
  _static_L3_huffman_tabs[2068] := TInt16T(1186);
  _static_L3_huffman_tabs[2069] := TInt16T(1066);
  _static_L3_huffman_tabs[2070] := TInt16T(1050);
  _static_L3_huffman_tabs[2071] := TInt16T(1158);
  _static_L3_huffman_tabs[2072] := TInt16T(1128);
  _static_L3_huffman_tabs[2073] := TInt16T(1143);
  _static_L3_huffman_tabs[2074] := TInt16T(1172);
  _static_L3_huffman_tabs[2075] := TInt16T(1097);
  _static_L3_huffman_tabs[2076] := TInt16T(1171);
  _static_L3_huffman_tabs[2077] := TInt16T(1081);
  _static_L3_huffman_tabs[2078] := TInt16T(420);
  _static_L3_huffman_tabs[2079] := TInt16T(391);
  _static_L3_huffman_tabs[2080] := TInt16T(1157);
  _static_L3_huffman_tabs[2081] := TInt16T(1112);
  _static_L3_huffman_tabs[2082] := TInt16T(1170);
  _static_L3_huffman_tabs[2083] := TInt16T(1142);
  _static_L3_huffman_tabs[2084] := TInt16T(1127);
  _static_L3_huffman_tabs[2085] := TInt16T(1065);
  _static_L3_huffman_tabs[2086] := TInt16T(1169);
  _static_L3_huffman_tabs[2087] := TInt16T(1049);
  _static_L3_huffman_tabs[2088] := TInt16T(1156);
  _static_L3_huffman_tabs[2089] := TInt16T(1096);
  _static_L3_huffman_tabs[2090] := TInt16T(1141);
  _static_L3_huffman_tabs[2091] := TInt16T(1111);
  _static_L3_huffman_tabs[2092] := TInt16T(1155);
  _static_L3_huffman_tabs[2093] := TInt16T(1080);
  _static_L3_huffman_tabs[2094] := TInt16T(1126);
  _static_L3_huffman_tabs[2095] := TInt16T(1154);
  _static_L3_huffman_tabs[2096] := TInt16T(1064);
  _static_L3_huffman_tabs[2097] := TInt16T(1153);
  _static_L3_huffman_tabs[2098] := TInt16T(1140);
  _static_L3_huffman_tabs[2099] := TInt16T(1095);
  _static_L3_huffman_tabs[2100] := TInt16T(1048);
  _static_L3_huffman_tabs[2101] := TInt16T(-2159);
  _static_L3_huffman_tabs[2102] := TInt16T(1125);
  _static_L3_huffman_tabs[2103] := TInt16T(1110);
  _static_L3_huffman_tabs[2104] := TInt16T(1137);
  _static_L3_huffman_tabs[2105] := TInt16T(-2175);
  _static_L3_huffman_tabs[2106] := TInt16T(823);
  _static_L3_huffman_tabs[2107] := TInt16T(823);
  _static_L3_huffman_tabs[2108] := TInt16T(1139);
  _static_L3_huffman_tabs[2109] := TInt16T(1138);
  _static_L3_huffman_tabs[2110] := TInt16T(807);
  _static_L3_huffman_tabs[2111] := TInt16T(807);
  _static_L3_huffman_tabs[2112] := TInt16T(384);
  _static_L3_huffman_tabs[2113] := TInt16T(264);
  _static_L3_huffman_tabs[2114] := TInt16T(368);
  _static_L3_huffman_tabs[2115] := TInt16T(263);
  _static_L3_huffman_tabs[2116] := TInt16T(868);
  _static_L3_huffman_tabs[2117] := TInt16T(838);
  _static_L3_huffman_tabs[2118] := TInt16T(853);
  _static_L3_huffman_tabs[2119] := TInt16T(791);
  _static_L3_huffman_tabs[2120] := TInt16T(867);
  _static_L3_huffman_tabs[2121] := TInt16T(822);
  _static_L3_huffman_tabs[2122] := TInt16T(852);
  _static_L3_huffman_tabs[2123] := TInt16T(837);
  _static_L3_huffman_tabs[2124] := TInt16T(866);
  _static_L3_huffman_tabs[2125] := TInt16T(806);
  _static_L3_huffman_tabs[2126] := TInt16T(865);
  _static_L3_huffman_tabs[2127] := TInt16T(790);
  _static_L3_huffman_tabs[2128] := TInt16T(-2319);
  _static_L3_huffman_tabs[2129] := TInt16T(851);
  _static_L3_huffman_tabs[2130] := TInt16T(821);
  _static_L3_huffman_tabs[2131] := TInt16T(836);
  _static_L3_huffman_tabs[2132] := TInt16T(352);
  _static_L3_huffman_tabs[2133] := TInt16T(262);
  _static_L3_huffman_tabs[2134] := TInt16T(850);
  _static_L3_huffman_tabs[2135] := TInt16T(805);
  _static_L3_huffman_tabs[2136] := TInt16T(849);
  _static_L3_huffman_tabs[2137] := TInt16T(-2399);
  _static_L3_huffman_tabs[2138] := TInt16T(533);
  _static_L3_huffman_tabs[2139] := TInt16T(533);
  _static_L3_huffman_tabs[2140] := TInt16T(835);
  _static_L3_huffman_tabs[2141] := TInt16T(820);
  _static_L3_huffman_tabs[2142] := TInt16T(336);
  _static_L3_huffman_tabs[2143] := TInt16T(261);
  _static_L3_huffman_tabs[2144] := TInt16T(578);
  _static_L3_huffman_tabs[2145] := TInt16T(548);
  _static_L3_huffman_tabs[2146] := TInt16T(563);
  _static_L3_huffman_tabs[2147] := TInt16T(577);
  _static_L3_huffman_tabs[2148] := TInt16T(532);
  _static_L3_huffman_tabs[2149] := TInt16T(532);
  _static_L3_huffman_tabs[2150] := TInt16T(832);
  _static_L3_huffman_tabs[2151] := TInt16T(772);
  _static_L3_huffman_tabs[2152] := TInt16T(562);
  _static_L3_huffman_tabs[2153] := TInt16T(562);
  _static_L3_huffman_tabs[2154] := TInt16T(547);
  _static_L3_huffman_tabs[2155] := TInt16T(547);
  _static_L3_huffman_tabs[2156] := TInt16T(305);
  _static_L3_huffman_tabs[2157] := TInt16T(275);
  _static_L3_huffman_tabs[2158] := TInt16T(560);
  _static_L3_huffman_tabs[2159] := TInt16T(515);
  _static_L3_huffman_tabs[2160] := TInt16T(290);
  _static_L3_huffman_tabs[2161] := TInt16T(290);
  _static_L3_huffman_tabs[2162] := TInt16T(288);
  _static_L3_huffman_tabs[2163] := TInt16T(258);
  FillChar(_static_L3_huffman_tab32, SizeOf(_static_L3_huffman_tab32), 0);
  _static_L3_huffman_tab32[0] := TUint8T(130);
  _static_L3_huffman_tab32[1] := TUint8T(162);
  _static_L3_huffman_tab32[2] := TUint8T(193);
  _static_L3_huffman_tab32[3] := TUint8T(209);
  _static_L3_huffman_tab32[4] := TUint8T(44);
  _static_L3_huffman_tab32[5] := TUint8T(28);
  _static_L3_huffman_tab32[6] := TUint8T(76);
  _static_L3_huffman_tab32[7] := TUint8T(140);
  _static_L3_huffman_tab32[8] := TUint8T(9);
  _static_L3_huffman_tab32[9] := TUint8T(9);
  _static_L3_huffman_tab32[10] := TUint8T(9);
  _static_L3_huffman_tab32[11] := TUint8T(9);
  _static_L3_huffman_tab32[12] := TUint8T(9);
  _static_L3_huffman_tab32[13] := TUint8T(9);
  _static_L3_huffman_tab32[14] := TUint8T(9);
  _static_L3_huffman_tab32[15] := TUint8T(9);
  _static_L3_huffman_tab32[16] := TUint8T(190);
  _static_L3_huffman_tab32[17] := TUint8T(254);
  _static_L3_huffman_tab32[18] := TUint8T(222);
  _static_L3_huffman_tab32[19] := TUint8T(238);
  _static_L3_huffman_tab32[20] := TUint8T(126);
  _static_L3_huffman_tab32[21] := TUint8T(94);
  _static_L3_huffman_tab32[22] := TUint8T(157);
  _static_L3_huffman_tab32[23] := TUint8T(157);
  _static_L3_huffman_tab32[24] := TUint8T(109);
  _static_L3_huffman_tab32[25] := TUint8T(61);
  _static_L3_huffman_tab32[26] := TUint8T(173);
  _static_L3_huffman_tab32[27] := TUint8T(205);
  FillChar(_static_L3_huffman_tab33, SizeOf(_static_L3_huffman_tab33), 0);
  _static_L3_huffman_tab33[0] := TUint8T(252);
  _static_L3_huffman_tab33[1] := TUint8T(236);
  _static_L3_huffman_tab33[2] := TUint8T(220);
  _static_L3_huffman_tab33[3] := TUint8T(204);
  _static_L3_huffman_tab33[4] := TUint8T(188);
  _static_L3_huffman_tab33[5] := TUint8T(172);
  _static_L3_huffman_tab33[6] := TUint8T(156);
  _static_L3_huffman_tab33[7] := TUint8T(140);
  _static_L3_huffman_tab33[8] := TUint8T(124);
  _static_L3_huffman_tab33[9] := TUint8T(108);
  _static_L3_huffman_tab33[10] := TUint8T(92);
  _static_L3_huffman_tab33[11] := TUint8T(76);
  _static_L3_huffman_tab33[12] := TUint8T(60);
  _static_L3_huffman_tab33[13] := TUint8T(44);
  _static_L3_huffman_tab33[14] := TUint8T(28);
  _static_L3_huffman_tab33[15] := TUint8T(12);
  FillChar(_static_L3_huffman_tabindex, SizeOf(_static_L3_huffman_tabindex), 0);
  _static_L3_huffman_tabindex[0] := TInt16T(0);
  _static_L3_huffman_tabindex[1] := TInt16T(32);
  _static_L3_huffman_tabindex[2] := TInt16T(64);
  _static_L3_huffman_tabindex[3] := TInt16T(98);
  _static_L3_huffman_tabindex[4] := TInt16T(0);
  _static_L3_huffman_tabindex[5] := TInt16T(132);
  _static_L3_huffman_tabindex[6] := TInt16T(180);
  _static_L3_huffman_tabindex[7] := TInt16T(218);
  _static_L3_huffman_tabindex[8] := TInt16T(292);
  _static_L3_huffman_tabindex[9] := TInt16T(364);
  _static_L3_huffman_tabindex[10] := TInt16T(426);
  _static_L3_huffman_tabindex[11] := TInt16T(538);
  _static_L3_huffman_tabindex[12] := TInt16T(648);
  _static_L3_huffman_tabindex[13] := TInt16T(746);
  _static_L3_huffman_tabindex[14] := TInt16T(0);
  _static_L3_huffman_tabindex[15] := TInt16T(1126);
  _static_L3_huffman_tabindex[16] := TInt16T(1460);
  _static_L3_huffman_tabindex[17] := TInt16T(1460);
  _static_L3_huffman_tabindex[18] := TInt16T(1460);
  _static_L3_huffman_tabindex[19] := TInt16T(1460);
  _static_L3_huffman_tabindex[20] := TInt16T(1460);
  _static_L3_huffman_tabindex[21] := TInt16T(1460);
  _static_L3_huffman_tabindex[22] := TInt16T(1460);
  _static_L3_huffman_tabindex[23] := TInt16T(1460);
  _static_L3_huffman_tabindex[24] := TInt16T(1842);
  _static_L3_huffman_tabindex[25] := TInt16T(1842);
  _static_L3_huffman_tabindex[26] := TInt16T(1842);
  _static_L3_huffman_tabindex[27] := TInt16T(1842);
  _static_L3_huffman_tabindex[28] := TInt16T(1842);
  _static_L3_huffman_tabindex[29] := TInt16T(1842);
  _static_L3_huffman_tabindex[30] := TInt16T(1842);
  _static_L3_huffman_tabindex[31] := TInt16T(1842);
  FillChar(_static_L3_huffman_g_linbits, SizeOf(_static_L3_huffman_g_linbits), 0);
  _static_L3_huffman_g_linbits[0] := TUint8T(0);
  _static_L3_huffman_g_linbits[1] := TUint8T(0);
  _static_L3_huffman_g_linbits[2] := TUint8T(0);
  _static_L3_huffman_g_linbits[3] := TUint8T(0);
  _static_L3_huffman_g_linbits[4] := TUint8T(0);
  _static_L3_huffman_g_linbits[5] := TUint8T(0);
  _static_L3_huffman_g_linbits[6] := TUint8T(0);
  _static_L3_huffman_g_linbits[7] := TUint8T(0);
  _static_L3_huffman_g_linbits[8] := TUint8T(0);
  _static_L3_huffman_g_linbits[9] := TUint8T(0);
  _static_L3_huffman_g_linbits[10] := TUint8T(0);
  _static_L3_huffman_g_linbits[11] := TUint8T(0);
  _static_L3_huffman_g_linbits[12] := TUint8T(0);
  _static_L3_huffman_g_linbits[13] := TUint8T(0);
  _static_L3_huffman_g_linbits[14] := TUint8T(0);
  _static_L3_huffman_g_linbits[15] := TUint8T(0);
  _static_L3_huffman_g_linbits[16] := TUint8T(1);
  _static_L3_huffman_g_linbits[17] := TUint8T(2);
  _static_L3_huffman_g_linbits[18] := TUint8T(3);
  _static_L3_huffman_g_linbits[19] := TUint8T(4);
  _static_L3_huffman_g_linbits[20] := TUint8T(6);
  _static_L3_huffman_g_linbits[21] := TUint8T(8);
  _static_L3_huffman_g_linbits[22] := TUint8T(10);
  _static_L3_huffman_g_linbits[23] := TUint8T(13);
  _static_L3_huffman_g_linbits[24] := TUint8T(4);
  _static_L3_huffman_g_linbits[25] := TUint8T(5);
  _static_L3_huffman_g_linbits[26] := TUint8T(6);
  _static_L3_huffman_g_linbits[27] := TUint8T(7);
  _static_L3_huffman_g_linbits[28] := TUint8T(8);
  _static_L3_huffman_g_linbits[29] := TUint8T(9);
  _static_L3_huffman_g_linbits[30] := TUint8T(11);
  _static_L3_huffman_g_linbits[31] := TUint8T(13);
  FillChar(_static_L3_stereo_process_g_pan, SizeOf(_static_L3_stereo_process_g_pan), 0);
  _static_L3_stereo_process_g_pan[0] := 0;
  _static_L3_stereo_process_g_pan[1] := 1;
  _static_L3_stereo_process_g_pan[2] := Single(0.21132487);
  _static_L3_stereo_process_g_pan[3] := Single(0.78867513);
  _static_L3_stereo_process_g_pan[4] := Single(0.36602540);
  _static_L3_stereo_process_g_pan[5] := Single(0.63397460);
  _static_L3_stereo_process_g_pan[6] := Single(0.5);
  _static_L3_stereo_process_g_pan[7] := Single(0.5);
  _static_L3_stereo_process_g_pan[8] := Single(0.63397460);
  _static_L3_stereo_process_g_pan[9] := Single(0.36602540);
  _static_L3_stereo_process_g_pan[10] := Single(0.78867513);
  _static_L3_stereo_process_g_pan[11] := Single(0.21132487);
  _static_L3_stereo_process_g_pan[12] := 1;
  _static_L3_stereo_process_g_pan[13] := 0;
  FillChar(_static_L3_antialias_g_aa, SizeOf(_static_L3_antialias_g_aa), 0);
  _static_L3_antialias_g_aa[0][0] := Single(0.85749293);
  _static_L3_antialias_g_aa[0][1] := Single(0.88174200);
  _static_L3_antialias_g_aa[0][2] := Single(0.94962865);
  _static_L3_antialias_g_aa[0][3] := Single(0.98331459);
  _static_L3_antialias_g_aa[0][4] := Single(0.99551782);
  _static_L3_antialias_g_aa[0][5] := Single(0.99916056);
  _static_L3_antialias_g_aa[0][6] := Single(0.99989920);
  _static_L3_antialias_g_aa[0][7] := Single(0.99999316);
  _static_L3_antialias_g_aa[1][0] := Single(0.51449576);
  _static_L3_antialias_g_aa[1][1] := Single(0.47173197);
  _static_L3_antialias_g_aa[1][2] := Single(0.31337745);
  _static_L3_antialias_g_aa[1][3] := Single(0.18191320);
  _static_L3_antialias_g_aa[1][4] := Single(0.09457419);
  _static_L3_antialias_g_aa[1][5] := Single(0.04096558);
  _static_L3_antialias_g_aa[1][6] := Single(0.01419856);
  _static_L3_antialias_g_aa[1][7] := Single(0.00369997);
  FillChar(_static_L3_imdct36_g_twid9, SizeOf(_static_L3_imdct36_g_twid9), 0);
  _static_L3_imdct36_g_twid9[0] := Single(0.73727734);
  _static_L3_imdct36_g_twid9[1] := Single(0.79335334);
  _static_L3_imdct36_g_twid9[2] := Single(0.84339145);
  _static_L3_imdct36_g_twid9[3] := Single(0.88701083);
  _static_L3_imdct36_g_twid9[4] := Single(0.92387953);
  _static_L3_imdct36_g_twid9[5] := Single(0.95371695);
  _static_L3_imdct36_g_twid9[6] := Single(0.97629601);
  _static_L3_imdct36_g_twid9[7] := Single(0.99144486);
  _static_L3_imdct36_g_twid9[8] := Single(0.99904822);
  _static_L3_imdct36_g_twid9[9] := Single(0.67559021);
  _static_L3_imdct36_g_twid9[10] := Single(0.60876143);
  _static_L3_imdct36_g_twid9[11] := Single(0.53729961);
  _static_L3_imdct36_g_twid9[12] := Single(0.46174861);
  _static_L3_imdct36_g_twid9[13] := Single(0.38268343);
  _static_L3_imdct36_g_twid9[14] := Single(0.30070580);
  _static_L3_imdct36_g_twid9[15] := Single(0.21643961);
  _static_L3_imdct36_g_twid9[16] := Single(0.13052619);
  _static_L3_imdct36_g_twid9[17] := Single(0.04361938);
  FillChar(_static_L3_imdct12_g_twid3, SizeOf(_static_L3_imdct12_g_twid3), 0);
  _static_L3_imdct12_g_twid3[0] := Single(0.79335334);
  _static_L3_imdct12_g_twid3[1] := Single(0.92387953);
  _static_L3_imdct12_g_twid3[2] := Single(0.99144486);
  _static_L3_imdct12_g_twid3[3] := Single(0.60876143);
  _static_L3_imdct12_g_twid3[4] := Single(0.38268343);
  _static_L3_imdct12_g_twid3[5] := Single(0.13052619);
  FillChar(_static_L3_imdct_gr_g_mdct_window, SizeOf(_static_L3_imdct_gr_g_mdct_window), 0);
  _static_L3_imdct_gr_g_mdct_window[0][0] := Single(0.99904822);
  _static_L3_imdct_gr_g_mdct_window[0][1] := Single(0.99144486);
  _static_L3_imdct_gr_g_mdct_window[0][2] := Single(0.97629601);
  _static_L3_imdct_gr_g_mdct_window[0][3] := Single(0.95371695);
  _static_L3_imdct_gr_g_mdct_window[0][4] := Single(0.92387953);
  _static_L3_imdct_gr_g_mdct_window[0][5] := Single(0.88701083);
  _static_L3_imdct_gr_g_mdct_window[0][6] := Single(0.84339145);
  _static_L3_imdct_gr_g_mdct_window[0][7] := Single(0.79335334);
  _static_L3_imdct_gr_g_mdct_window[0][8] := Single(0.73727734);
  _static_L3_imdct_gr_g_mdct_window[0][9] := Single(0.04361938);
  _static_L3_imdct_gr_g_mdct_window[0][10] := Single(0.13052619);
  _static_L3_imdct_gr_g_mdct_window[0][11] := Single(0.21643961);
  _static_L3_imdct_gr_g_mdct_window[0][12] := Single(0.30070580);
  _static_L3_imdct_gr_g_mdct_window[0][13] := Single(0.38268343);
  _static_L3_imdct_gr_g_mdct_window[0][14] := Single(0.46174861);
  _static_L3_imdct_gr_g_mdct_window[0][15] := Single(0.53729961);
  _static_L3_imdct_gr_g_mdct_window[0][16] := Single(0.60876143);
  _static_L3_imdct_gr_g_mdct_window[0][17] := Single(0.67559021);
  _static_L3_imdct_gr_g_mdct_window[1][0] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][1] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][2] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][3] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][4] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][5] := 1;
  _static_L3_imdct_gr_g_mdct_window[1][6] := Single(0.99144486);
  _static_L3_imdct_gr_g_mdct_window[1][7] := Single(0.92387953);
  _static_L3_imdct_gr_g_mdct_window[1][8] := Single(0.79335334);
  _static_L3_imdct_gr_g_mdct_window[1][9] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][10] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][11] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][12] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][13] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][14] := 0;
  _static_L3_imdct_gr_g_mdct_window[1][15] := Single(0.13052619);
  _static_L3_imdct_gr_g_mdct_window[1][16] := Single(0.38268343);
  _static_L3_imdct_gr_g_mdct_window[1][17] := Single(0.60876143);
  FillChar(_static_mp3d_DCT_II_g_sec, SizeOf(_static_mp3d_DCT_II_g_sec), 0);
  _static_mp3d_DCT_II_g_sec[0] := Single(10.19000816);
  _static_mp3d_DCT_II_g_sec[1] := Single(0.50060302);
  _static_mp3d_DCT_II_g_sec[2] := Single(0.50241929);
  _static_mp3d_DCT_II_g_sec[3] := Single(3.40760851);
  _static_mp3d_DCT_II_g_sec[4] := Single(0.50547093);
  _static_mp3d_DCT_II_g_sec[5] := Single(0.52249861);
  _static_mp3d_DCT_II_g_sec[6] := Single(2.05778098);
  _static_mp3d_DCT_II_g_sec[7] := Single(0.51544732);
  _static_mp3d_DCT_II_g_sec[8] := Single(0.56694406);
  _static_mp3d_DCT_II_g_sec[9] := Single(1.48416460);
  _static_mp3d_DCT_II_g_sec[10] := Single(0.53104258);
  _static_mp3d_DCT_II_g_sec[11] := Single(0.64682180);
  _static_mp3d_DCT_II_g_sec[12] := Single(1.16943991);
  _static_mp3d_DCT_II_g_sec[13] := Single(0.55310392);
  _static_mp3d_DCT_II_g_sec[14] := Single(0.78815460);
  _static_mp3d_DCT_II_g_sec[15] := Single(0.97256821);
  _static_mp3d_DCT_II_g_sec[16] := Single(0.58293498);
  _static_mp3d_DCT_II_g_sec[17] := Single(1.06067765);
  _static_mp3d_DCT_II_g_sec[18] := Single(0.83934963);
  _static_mp3d_DCT_II_g_sec[19] := Single(0.62250412);
  _static_mp3d_DCT_II_g_sec[20] := Single(1.72244716);
  _static_mp3d_DCT_II_g_sec[21] := Single(0.74453628);
  _static_mp3d_DCT_II_g_sec[22] := Single(0.67480832);
  _static_mp3d_DCT_II_g_sec[23] := Single(5.10114861);
  FillChar(_static_mp3d_synth_g_win, SizeOf(_static_mp3d_synth_g_win), 0);
  _static_mp3d_synth_g_win[0] := -1;
  _static_mp3d_synth_g_win[1] := 26;
  _static_mp3d_synth_g_win[2] := -31;
  _static_mp3d_synth_g_win[3] := 208;
  _static_mp3d_synth_g_win[4] := 218;
  _static_mp3d_synth_g_win[5] := 401;
  _static_mp3d_synth_g_win[6] := -519;
  _static_mp3d_synth_g_win[7] := 2063;
  _static_mp3d_synth_g_win[8] := 2000;
  _static_mp3d_synth_g_win[9] := 4788;
  _static_mp3d_synth_g_win[10] := -5517;
  _static_mp3d_synth_g_win[11] := 7134;
  _static_mp3d_synth_g_win[12] := 5959;
  _static_mp3d_synth_g_win[13] := 35640;
  _static_mp3d_synth_g_win[14] := -39336;
  _static_mp3d_synth_g_win[15] := 74992;
  _static_mp3d_synth_g_win[16] := -1;
  _static_mp3d_synth_g_win[17] := 24;
  _static_mp3d_synth_g_win[18] := -35;
  _static_mp3d_synth_g_win[19] := 202;
  _static_mp3d_synth_g_win[20] := 222;
  _static_mp3d_synth_g_win[21] := 347;
  _static_mp3d_synth_g_win[22] := -581;
  _static_mp3d_synth_g_win[23] := 2080;
  _static_mp3d_synth_g_win[24] := 1952;
  _static_mp3d_synth_g_win[25] := 4425;
  _static_mp3d_synth_g_win[26] := -5879;
  _static_mp3d_synth_g_win[27] := 7640;
  _static_mp3d_synth_g_win[28] := 5288;
  _static_mp3d_synth_g_win[29] := 33791;
  _static_mp3d_synth_g_win[30] := -41176;
  _static_mp3d_synth_g_win[31] := 74856;
  _static_mp3d_synth_g_win[32] := -1;
  _static_mp3d_synth_g_win[33] := 21;
  _static_mp3d_synth_g_win[34] := -38;
  _static_mp3d_synth_g_win[35] := 196;
  _static_mp3d_synth_g_win[36] := 225;
  _static_mp3d_synth_g_win[37] := 294;
  _static_mp3d_synth_g_win[38] := -645;
  _static_mp3d_synth_g_win[39] := 2087;
  _static_mp3d_synth_g_win[40] := 1893;
  _static_mp3d_synth_g_win[41] := 4063;
  _static_mp3d_synth_g_win[42] := -6237;
  _static_mp3d_synth_g_win[43] := 8092;
  _static_mp3d_synth_g_win[44] := 4561;
  _static_mp3d_synth_g_win[45] := 31947;
  _static_mp3d_synth_g_win[46] := -43006;
  _static_mp3d_synth_g_win[47] := 74630;
  _static_mp3d_synth_g_win[48] := -1;
  _static_mp3d_synth_g_win[49] := 19;
  _static_mp3d_synth_g_win[50] := -41;
  _static_mp3d_synth_g_win[51] := 190;
  _static_mp3d_synth_g_win[52] := 227;
  _static_mp3d_synth_g_win[53] := 244;
  _static_mp3d_synth_g_win[54] := -711;
  _static_mp3d_synth_g_win[55] := 2085;
  _static_mp3d_synth_g_win[56] := 1822;
  _static_mp3d_synth_g_win[57] := 3705;
  _static_mp3d_synth_g_win[58] := -6589;
  _static_mp3d_synth_g_win[59] := 8492;
  _static_mp3d_synth_g_win[60] := 3776;
  _static_mp3d_synth_g_win[61] := 30112;
  _static_mp3d_synth_g_win[62] := -44821;
  _static_mp3d_synth_g_win[63] := 74313;
  _static_mp3d_synth_g_win[64] := -1;
  _static_mp3d_synth_g_win[65] := 17;
  _static_mp3d_synth_g_win[66] := -45;
  _static_mp3d_synth_g_win[67] := 183;
  _static_mp3d_synth_g_win[68] := 228;
  _static_mp3d_synth_g_win[69] := 197;
  _static_mp3d_synth_g_win[70] := -779;
  _static_mp3d_synth_g_win[71] := 2075;
  _static_mp3d_synth_g_win[72] := 1739;
  _static_mp3d_synth_g_win[73] := 3351;
  _static_mp3d_synth_g_win[74] := -6935;
  _static_mp3d_synth_g_win[75] := 8840;
  _static_mp3d_synth_g_win[76] := 2935;
  _static_mp3d_synth_g_win[77] := 28289;
  _static_mp3d_synth_g_win[78] := -46617;
  _static_mp3d_synth_g_win[79] := 73908;
  _static_mp3d_synth_g_win[80] := -1;
  _static_mp3d_synth_g_win[81] := 16;
  _static_mp3d_synth_g_win[82] := -49;
  _static_mp3d_synth_g_win[83] := 176;
  _static_mp3d_synth_g_win[84] := 228;
  _static_mp3d_synth_g_win[85] := 153;
  _static_mp3d_synth_g_win[86] := -848;
  _static_mp3d_synth_g_win[87] := 2057;
  _static_mp3d_synth_g_win[88] := 1644;
  _static_mp3d_synth_g_win[89] := 3004;
  _static_mp3d_synth_g_win[90] := -7271;
  _static_mp3d_synth_g_win[91] := 9139;
  _static_mp3d_synth_g_win[92] := 2037;
  _static_mp3d_synth_g_win[93] := 26482;
  _static_mp3d_synth_g_win[94] := -48390;
  _static_mp3d_synth_g_win[95] := 73415;
  _static_mp3d_synth_g_win[96] := -2;
  _static_mp3d_synth_g_win[97] := 14;
  _static_mp3d_synth_g_win[98] := -53;
  _static_mp3d_synth_g_win[99] := 169;
  _static_mp3d_synth_g_win[100] := 227;
  _static_mp3d_synth_g_win[101] := 111;
  _static_mp3d_synth_g_win[102] := -919;
  _static_mp3d_synth_g_win[103] := 2032;
  _static_mp3d_synth_g_win[104] := 1535;
  _static_mp3d_synth_g_win[105] := 2663;
  _static_mp3d_synth_g_win[106] := -7597;
  _static_mp3d_synth_g_win[107] := 9389;
  _static_mp3d_synth_g_win[108] := 1082;
  _static_mp3d_synth_g_win[109] := 24694;
  _static_mp3d_synth_g_win[110] := -50137;
  _static_mp3d_synth_g_win[111] := 72835;
  _static_mp3d_synth_g_win[112] := -2;
  _static_mp3d_synth_g_win[113] := 13;
  _static_mp3d_synth_g_win[114] := -58;
  _static_mp3d_synth_g_win[115] := 161;
  _static_mp3d_synth_g_win[116] := 224;
  _static_mp3d_synth_g_win[117] := 72;
  _static_mp3d_synth_g_win[118] := -991;
  _static_mp3d_synth_g_win[119] := 2001;
  _static_mp3d_synth_g_win[120] := 1414;
  _static_mp3d_synth_g_win[121] := 2330;
  _static_mp3d_synth_g_win[122] := -7910;
  _static_mp3d_synth_g_win[123] := 9592;
  _static_mp3d_synth_g_win[124] := 70;
  _static_mp3d_synth_g_win[125] := 22929;
  _static_mp3d_synth_g_win[126] := -51853;
  _static_mp3d_synth_g_win[127] := 72169;
  _static_mp3d_synth_g_win[128] := -2;
  _static_mp3d_synth_g_win[129] := 11;
  _static_mp3d_synth_g_win[130] := -63;
  _static_mp3d_synth_g_win[131] := 154;
  _static_mp3d_synth_g_win[132] := 221;
  _static_mp3d_synth_g_win[133] := 36;
  _static_mp3d_synth_g_win[134] := -1064;
  _static_mp3d_synth_g_win[135] := 1962;
  _static_mp3d_synth_g_win[136] := 1280;
  _static_mp3d_synth_g_win[137] := 2006;
  _static_mp3d_synth_g_win[138] := -8209;
  _static_mp3d_synth_g_win[139] := 9750;
  _static_mp3d_synth_g_win[140] := -998;
  _static_mp3d_synth_g_win[141] := 21189;
  _static_mp3d_synth_g_win[142] := -53534;
  _static_mp3d_synth_g_win[143] := 71420;
  _static_mp3d_synth_g_win[144] := -2;
  _static_mp3d_synth_g_win[145] := 10;
  _static_mp3d_synth_g_win[146] := -68;
  _static_mp3d_synth_g_win[147] := 147;
  _static_mp3d_synth_g_win[148] := 215;
  _static_mp3d_synth_g_win[149] := 2;
  _static_mp3d_synth_g_win[150] := -1137;
  _static_mp3d_synth_g_win[151] := 1919;
  _static_mp3d_synth_g_win[152] := 1131;
  _static_mp3d_synth_g_win[153] := 1692;
  _static_mp3d_synth_g_win[154] := -8491;
  _static_mp3d_synth_g_win[155] := 9863;
  _static_mp3d_synth_g_win[156] := -2122;
  _static_mp3d_synth_g_win[157] := 19478;
  _static_mp3d_synth_g_win[158] := -55178;
  _static_mp3d_synth_g_win[159] := 70590;
  _static_mp3d_synth_g_win[160] := -3;
  _static_mp3d_synth_g_win[161] := 9;
  _static_mp3d_synth_g_win[162] := -73;
  _static_mp3d_synth_g_win[163] := 139;
  _static_mp3d_synth_g_win[164] := 208;
  _static_mp3d_synth_g_win[165] := -29;
  _static_mp3d_synth_g_win[166] := -1210;
  _static_mp3d_synth_g_win[167] := 1870;
  _static_mp3d_synth_g_win[168] := 970;
  _static_mp3d_synth_g_win[169] := 1388;
  _static_mp3d_synth_g_win[170] := -8755;
  _static_mp3d_synth_g_win[171] := 9935;
  _static_mp3d_synth_g_win[172] := -3300;
  _static_mp3d_synth_g_win[173] := 17799;
  _static_mp3d_synth_g_win[174] := -56778;
  _static_mp3d_synth_g_win[175] := 69679;
  _static_mp3d_synth_g_win[176] := -3;
  _static_mp3d_synth_g_win[177] := 8;
  _static_mp3d_synth_g_win[178] := -79;
  _static_mp3d_synth_g_win[179] := 132;
  _static_mp3d_synth_g_win[180] := 200;
  _static_mp3d_synth_g_win[181] := -57;
  _static_mp3d_synth_g_win[182] := -1283;
  _static_mp3d_synth_g_win[183] := 1817;
  _static_mp3d_synth_g_win[184] := 794;
  _static_mp3d_synth_g_win[185] := 1095;
  _static_mp3d_synth_g_win[186] := -8998;
  _static_mp3d_synth_g_win[187] := 9966;
  _static_mp3d_synth_g_win[188] := -4533;
  _static_mp3d_synth_g_win[189] := 16155;
  _static_mp3d_synth_g_win[190] := -58333;
  _static_mp3d_synth_g_win[191] := 68692;
  _static_mp3d_synth_g_win[192] := -4;
  _static_mp3d_synth_g_win[193] := 7;
  _static_mp3d_synth_g_win[194] := -85;
  _static_mp3d_synth_g_win[195] := 125;
  _static_mp3d_synth_g_win[196] := 189;
  _static_mp3d_synth_g_win[197] := -83;
  _static_mp3d_synth_g_win[198] := -1356;
  _static_mp3d_synth_g_win[199] := 1759;
  _static_mp3d_synth_g_win[200] := 605;
  _static_mp3d_synth_g_win[201] := 814;
  _static_mp3d_synth_g_win[202] := -9219;
  _static_mp3d_synth_g_win[203] := 9959;
  _static_mp3d_synth_g_win[204] := -5818;
  _static_mp3d_synth_g_win[205] := 14548;
  _static_mp3d_synth_g_win[206] := -59838;
  _static_mp3d_synth_g_win[207] := 67629;
  _static_mp3d_synth_g_win[208] := -4;
  _static_mp3d_synth_g_win[209] := 7;
  _static_mp3d_synth_g_win[210] := -91;
  _static_mp3d_synth_g_win[211] := 117;
  _static_mp3d_synth_g_win[212] := 177;
  _static_mp3d_synth_g_win[213] := -106;
  _static_mp3d_synth_g_win[214] := -1428;
  _static_mp3d_synth_g_win[215] := 1698;
  _static_mp3d_synth_g_win[216] := 402;
  _static_mp3d_synth_g_win[217] := 545;
  _static_mp3d_synth_g_win[218] := -9416;
  _static_mp3d_synth_g_win[219] := 9916;
  _static_mp3d_synth_g_win[220] := -7154;
  _static_mp3d_synth_g_win[221] := 12980;
  _static_mp3d_synth_g_win[222] := -61289;
  _static_mp3d_synth_g_win[223] := 66494;
  _static_mp3d_synth_g_win[224] := -5;
  _static_mp3d_synth_g_win[225] := 6;
  _static_mp3d_synth_g_win[226] := -97;
  _static_mp3d_synth_g_win[227] := 111;
  _static_mp3d_synth_g_win[228] := 163;
  _static_mp3d_synth_g_win[229] := -127;
  _static_mp3d_synth_g_win[230] := -1498;
  _static_mp3d_synth_g_win[231] := 1634;
  _static_mp3d_synth_g_win[232] := 185;
  _static_mp3d_synth_g_win[233] := 288;
  _static_mp3d_synth_g_win[234] := -9585;
  _static_mp3d_synth_g_win[235] := 9838;
  _static_mp3d_synth_g_win[236] := -8540;
  _static_mp3d_synth_g_win[237] := 11455;
  _static_mp3d_synth_g_win[238] := -62684;
  _static_mp3d_synth_g_win[239] := 65290;
end;

initialization
  { C 语义浮点环境：0/0 -> NaN 不陷阱（替代 c2p_cfloat，走 nextpas.core） }
  SetExceptionMask(GetExceptionMask + [exInvalidOp, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  __c2p_static_fill_mp3dec;
end.
