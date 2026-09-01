unit nextpas.core.sevenz.base;

{**
 * nextpas.core.sevenz.base - 7z 归档容器基本类型
 *
 * 拥有 7z 格式的公共词汇表：容器常量、coder method ID、header 属性 ID、
 * 条目信息 record、模块异常、UTF-16LE 名称转换和 FILETIME 时间换算。
 * 不含任何解析/压缩逻辑；实现子模块从这里取类型。炸弹与头部硬上限
 * 亦归入本单元单源，limits 单元薄封装 re-export，避免四件套外碎片化。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

const
  { 签名头：6 字节魔数 + 版本 + StartHeaderCRC + 定位三元组，共 32 字节 }
  C_SEVENZ_MAGIC_0 = $37;
  C_SEVENZ_MAGIC_1 = $7A;
  C_SEVENZ_MAGIC_2 = $BC;
  C_SEVENZ_MAGIC_3 = $AF;
  C_SEVENZ_MAGIC_4 = $27;
  C_SEVENZ_MAGIC_5 = $1C;
  C_SEVENZ_VERSION_MAJOR = $00;
  C_SEVENZ_VERSION_MINOR = $04;
  C_SEVENZ_SIG_HEADER_SIZE = 32;

  { coder method ID（7z 规范编号） }
  SEVENZ_METHOD_COPY    = UInt64($0000000000);
  SEVENZ_METHOD_DELTA   = UInt64($0000000003);
  SEVENZ_METHOD_LZMA1   = UInt64($0000030101);
  SEVENZ_METHOD_BCJ_X86 = UInt64($0003030103);
  SEVENZ_METHOD_BCJ_PPC = UInt64($0003030205);
  SEVENZ_METHOD_BCJ_IA64 = UInt64($0003030401);
  SEVENZ_METHOD_BCJ_ARM = UInt64($0003030501);
  SEVENZ_METHOD_BCJ_ARMT = UInt64($0003030701);
  SEVENZ_METHOD_BCJ_SPARC = UInt64($0003030805);
  SEVENZ_METHOD_BCJ_ARM64 = UInt64($0003030A01);
  SEVENZ_METHOD_BCJ_RISCV = UInt64($0003030B01);
  SEVENZ_METHOD_BCJ2    = UInt64($000303011B);
  SEVENZ_METHOD_AES256_CRC = UInt64($0006F10701);
  SEVENZ_METHOD_DEFLATE = UInt64($00040108);
  SEVENZ_METHOD_BZIP2   = UInt64($00040202);
  SEVENZ_METHOD_PPMD    = UInt64($00030401);
  SEVENZ_METHOD_LZMA2   = UInt64($21);

  { header 属性 ID（7z 规范 kXxx 编号） }
  SZ_ID_END               = $00;
  SZ_ID_HEADER            = $01;
  SZ_ID_ARCHIVE_PROPS     = $02;
  SZ_ID_ADD_STREAMS_INFO  = $03;
  SZ_ID_MAIN_STREAMS      = $04;
  SZ_ID_FILES_INFO        = $05;
  SZ_ID_PACK_INFO         = $06;
  SZ_ID_UNPACK_INFO       = $07;
  SZ_ID_SUBSTREAMS_INFO   = $08;
  SZ_ID_SIZE              = $09;
  SZ_ID_CRC               = $0A;
  SZ_ID_FOLDER            = $0B;
  SZ_ID_CODERS_UNPACK_SZ  = $0C;
  SZ_ID_NUM_UNPACK_STREAM = $0D;
  SZ_ID_EMPTY_STREAM      = $0E;
  SZ_ID_EMPTY_FILE        = $0F;
  SZ_ID_ANTI              = $10;
  SZ_ID_NAME              = $11;
  SZ_ID_CTIME             = $12;
  SZ_ID_ATIME             = $13;
  SZ_ID_MTIME             = $14;
  SZ_ID_WIN_ATTRIBUTES    = $15;
  SZ_ID_ENCODED_HEADER    = $17;
  SZ_ID_START_POS         = $18;
  SZ_ID_DUMMY             = $19;

  { 文件属性位（Windows FILE_ATTRIBUTE_* 子集，跨平台语义保留原值） }
  SEVENZ_ATTR_DIRECTORY = $00000010;

  { Windows FILETIME 纪元偏移：1601-01-01 与 Unix 纪元的秒差 }
  C_FILETIME_EPOCH_DELTA_SEC = 11644473600;
  C_FILETIME_TICKS_PER_SEC   = 10000000;

  { 7z 炸弹与头部硬上限——单源表，limits 单元 re-export，保持 base 职责聚合；
    与 reader/writer/header 共享，避免魔法数漂移 }
  SEVENZ_DEFAULT_MAX_OUTPUT = UInt64(8) * 1024 * 1024 * 1024;
  SEVENZ_MAX_HEADER_SIZE = UInt64(64) * 1024 * 1024;
  SEVENZ_MAX_PACK_SIZE = UInt64(64) * 1024 * 1024;
  SEVENZ_MAX_FILE_COUNT = 1000000;
  SEVENZ_MAX_NAME_BYTES = 64 * 1024;
  SEVENZ_EXTRACT_WINDOW = 256 * 1024;
  SEVENZ_WRITER_CHUNK   = 64 * 1024;
  SEVENZ_MAX_PACK_STREAMS = 1000000;
  SEVENZ_MAX_FOLDERS      = 1000000;
  SEVENZ_MAX_CODER_PROPS  = 1 * 1024 * 1024;
  SEVENZ_MAX_UNPACK_SIZE  = SEVENZ_DEFAULT_MAX_OUTPUT;
  SEVENZ_MAX_CRC_COUNT    = SEVENZ_MAX_FILE_COUNT;
  { folder 解码缓存字节上限：2-entry MRU 总量受限，极端 solid 2×大 folder 防翻倍；单 folder 超阈值不入缓存 }
  SEVENZ_CACHE_MAX_BYTES = UInt64(64) * 1024 * 1024;

type
  {** @desc 归档内条目类别 *}
  TSevenZEntryKind = (sekFile, sekDirectory);

  {** @desc 归档条目元数据（List/Find 返回的只读快照） *}
  TSevenZEntryInfo = record
    Name: string;
    Kind: TSevenZEntryKind;
    Size: Int64;
    HasMTime: Boolean;
    MTimeUnixSec: Int64;
    Attributes: UInt32;
    HasAttributes: Boolean;
    HasCrc: Boolean;
    Crc32: UInt32;
  end;

  {** @desc 7z 容器统一错误：格式损坏、不支持特性、校验不符 *}
  ESevenZError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  {** @desc 输入超出显式解压上限（反归档炸弹边界） *}
  ESevenZLimitError = class(ESevenZError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

{ UTF-16LE 字节序列转 UTF-8 string（7z 条目名编码）；非法序列以 U+FFFD 替换 }
function SevenZUtf16LeToUtf8(const ABytes: TBytes): string;

{ UTF-8 string 转 UTF-16LE 字节序列（写端条目名编码）；非法字节以 U+FFFD 替换 }
function SevenZUtf8ToUtf16Le(const S: string): TBytes;

{ 方法 ID 诊断名（未知返回 12位 hex） }
function SevenZMethodName(AMethodId: UInt64): string;

{ Unix 秒 ↔ Windows FILETIME（100ns tick）换算 }
function SevenZUnixToFILETIME(AUnixSec: Int64): UInt64;
function SevenZFILETIMEToUnix(ATicks: UInt64): Int64;

implementation

class function ESevenZError.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;

class function ESevenZLimitError.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;

type
  TSevenZUtf8State = record
    Buf: string;
    Pos: SizeInt;
  end;

  { 单标量解码结果：UTF 转换两遍扫描共用，保证计数与写出口径一致 }
  TSevenZUtf8Unit = record
    Len: SizeInt;    { 消耗的字节数；整段判废时消耗完整序列 }
    Units: SizeInt;  { 输出 UTF-16 单元数：1 或 2（增补平面代理对） }
    Code: UInt32;    { 码点；非法序列为 $FFFD }
  end;

procedure SevenZUtf8Emit(var AState: TSevenZUtf8State; ACh: UInt32);
begin
  if ACh < $80 then
  begin
    AState.Buf[AState.Pos] := Chr(ACh);
    Inc(AState.Pos);
  end
  else if ACh < $800 then
  begin
    AState.Buf[AState.Pos] := Chr($C0 or (ACh shr 6));
    AState.Buf[AState.Pos + 1] := Chr($80 or (ACh and $3F));
    Inc(AState.Pos, 2);
  end
  else if ACh < $10000 then
  begin
    AState.Buf[AState.Pos] := Chr($E0 or (ACh shr 12));
    AState.Buf[AState.Pos + 1] := Chr($80 or ((ACh shr 6) and $3F));
    AState.Buf[AState.Pos + 2] := Chr($80 or (ACh and $3F));
    Inc(AState.Pos, 3);
  end
  else
  begin
    AState.Buf[AState.Pos] := Chr($F0 or (ACh shr 18));
    AState.Buf[AState.Pos + 1] := Chr($80 or ((ACh shr 12) and $3F));
    AState.Buf[AState.Pos + 2] := Chr($80 or ((ACh shr 6) and $3F));
    AState.Buf[AState.Pos + 3] := Chr($80 or (ACh and $3F));
    Inc(AState.Pos, 4);
  end;
end;

procedure SevenZUtf8Ensure(var AState: TSevenZUtf8State; ANeed: SizeInt);
begin
  while (AState.Pos - 1) + ANeed > Length(AState.Buf) do
    SetLength(AState.Buf, Length(AState.Buf) * 2 + 4);
end;

function SevenZUtf16LeToUtf8(const ABytes: TBytes): string;
var
  LI: SizeInt;
  LCode: UInt32;
  LPendingSurrogate: UInt32;
  LState: TSevenZUtf8State;
begin
  Result := '';
  if Length(ABytes) = 0 then
    Exit('');
  LState.Pos := 1;
  SetLength(LState.Buf, Length(ABytes) * 2 + 8);
  LPendingSurrogate := 0;
  LI := 0;
  while LI < Length(ABytes) do
  begin
    if Length(ABytes) - LI < 2 then
    begin
      SevenZUtf8Ensure(LState, 3);
      SevenZUtf8Emit(LState, $FFFD);
      Break;
    end;
    {$PUSH}{$Q-}{$R-}
    LCode := UInt32(ABytes[LI]) or (UInt32(ABytes[LI + 1]) shl 8);
    {$POP}
    Inc(LI, 2);
    if (LCode >= $D800) and (LCode <= $DBFF) then
    begin
      if LPendingSurrogate <> 0 then
      begin
        SevenZUtf8Ensure(LState, 3);
        SevenZUtf8Emit(LState, $FFFD);
      end;
      LPendingSurrogate := LCode;
      Continue;
    end;
    if (LCode >= $DC00) and (LCode <= $DFFF) then
    begin
      if LPendingSurrogate <> 0 then
      begin
        LCode := $10000 + ((LPendingSurrogate - $D800) shl 10) + (LCode - $DC00);
        LPendingSurrogate := 0;
      end
      else
        LCode := $FFFD;
    end
    else if LPendingSurrogate <> 0 then
    begin
      SevenZUtf8Ensure(LState, 3);
      SevenZUtf8Emit(LState, $FFFD);
      LPendingSurrogate := 0;
    end;
    if (LCode >= $D800) and (LCode <= $DFFF) then
      LCode := $FFFD;
    SevenZUtf8Ensure(LState, 4);
    SevenZUtf8Emit(LState, LCode);
  end;
  if LPendingSurrogate <> 0 then
  begin
    SevenZUtf8Ensure(LState, 3);
    SevenZUtf8Emit(LState, $FFFD);
  end;
  SetLength(LState.Buf, LState.Pos - 1);
  Result := LState.Buf;
end;

function SevenZUtf8DecodeAt(const S: string; AIdx: SizeInt): TSevenZUtf8Unit;
var
  LCode: UInt32;
  LDecoded: UInt32;
  LOctets: SizeInt;
  LI: SizeInt;
  LValid: Boolean;
begin
  LCode := UInt32(Ord(S[AIdx]));
  if LCode < $80 then
  begin
    Result.Len := 1;
    Result.Units := 1;
    Result.Code := LCode;
    Exit;
  end;
  { C0/C1 为过度精简首字节，F5..FF 从未定义 }
  if LCode < $C2 then
    LOctets := -1
  else if LCode < $E0 then
    LOctets := 2
  else if LCode < $F0 then
    LOctets := 3
  else if LCode <= $F4 then
    LOctets := 4
  else
    LOctets := -1;
  if LOctets < 0 then
  begin
    Result.Len := 1;
    Result.Units := 1;
    Result.Code := $FFFD;
    Exit;
  end;
  if AIdx + LOctets - 1 > Length(S) then
  begin
    Result.Len := Length(S) - AIdx + 1;  { 尾部截断：吞掉剩余全部 }
    Result.Units := 1;
    Result.Code := $FFFD;
    Exit;
  end;
  for LI := 1 to LOctets - 1 do
    if (UInt32(Ord(S[AIdx + LI])) and $C0) <> $80 then
    begin
      Result.Len := LOctets;             { 续字节非法：整段判废 }
      Result.Units := 1;
      Result.Code := $FFFD;
      Exit;
    end;
  {$PUSH}{$Q-}{$R-}
  case LOctets of
    2:
      LDecoded := ((LCode and $1F) shl 6) or
        (UInt32(Ord(S[AIdx + 1])) and $3F);
    3:
      LDecoded := ((LCode and $0F) shl 12) or
        ((UInt32(Ord(S[AIdx + 1])) and $3F) shl 6) or
        (UInt32(Ord(S[AIdx + 2])) and $3F);
    else
      LDecoded := ((LCode and $07) shl 18) or
        ((UInt32(Ord(S[AIdx + 1])) and $3F) shl 12) or
        ((UInt32(Ord(S[AIdx + 2])) and $3F) shl 6) or
        (UInt32(Ord(S[AIdx + 3])) and $3F);
  end;
  {$POP}
  LValid := True;
  case LOctets of
    2:
      if LDecoded < $80 then
        LValid := False;
    3:
      if (LDecoded < $800) or ((LDecoded >= $D800) and (LDecoded <= $DFFF))
      then
        LValid := False;                 { 过度精简或代理区码点 }
    4:
      if (LDecoded < $10000) or (LDecoded > $10FFFF) then
        LValid := False;
  end;
  if not LValid then
  begin
    Result.Len := LOctets;
    Result.Units := 1;
    Result.Code := $FFFD;
    Exit;
  end;
  Result.Len := LOctets;
  if LDecoded >= $10000 then
    Result.Units := 2
  else
    Result.Units := 1;
  Result.Code := LDecoded;
end;

function SevenZUtf8ToUtf16Le(const S: string): TBytes;
var
  LI: SizeInt;
  LOutPos: SizeInt;
  LU: TSevenZUtf8Unit;

  procedure PushUnit(AUnit: UInt32);
  begin
    {$PUSH}{$Q-}{$R-}
    Result[LOutPos] := Byte(AUnit and $FF);
    Result[LOutPos + 1] := Byte((AUnit shr 8) and $FF);
    {$POP}
    Inc(LOutPos, 2);
  end;

begin
  Result := nil;
  { 两遍扫描共用 SevenZUtf8DecodeAt：计数与写出口径恒一致，
    增补平面按代理对计两个单元 }
  LOutPos := 0;
  LI := 1;
  while LI <= Length(S) do
  begin
    LU := SevenZUtf8DecodeAt(S, LI);
    Inc(LI, LU.Len);
    Inc(LOutPos, LU.Units * 2);
  end;
  SetLength(Result, LOutPos);
  LOutPos := 0;
  LI := 1;
  while LI <= Length(S) do
  begin
    LU := SevenZUtf8DecodeAt(S, LI);
    Inc(LI, LU.Len);
    if LU.Code >= $10000 then
    begin
      PushUnit($D800 or ((LU.Code - $10000) shr 10));
      PushUnit($DC00 or ((LU.Code - $10000) and $3FF));
    end
    else
      PushUnit(LU.Code);
  end;
end;

function SevenZUnixToFILETIME(AUnixSec: Int64): UInt64;
var
  LEpochSecs: Int64;
begin
  LEpochSecs := AUnixSec + C_FILETIME_EPOCH_DELTA_SEC;
  if LEpochSecs < 0 then
    LEpochSecs := 0;
  Result := UInt64(LEpochSecs) * C_FILETIME_TICKS_PER_SEC;
end;

function SevenZFILETIMEToUnix(ATicks: UInt64): Int64;
begin
  if ATicks < UInt64(C_FILETIME_EPOCH_DELTA_SEC) * C_FILETIME_TICKS_PER_SEC then
    Exit(-C_FILETIME_EPOCH_DELTA_SEC);
  Result := Int64(ATicks div C_FILETIME_TICKS_PER_SEC) - C_FILETIME_EPOCH_DELTA_SEC;
end;

function SevenZMethodName(AMethodId: UInt64): string;
var
  LHex: string;
  LI: Integer;
  LV: QWord;
const
  HD: array[0..15] of Char = '0123456789ABCDEF';
begin
  case AMethodId of
    SEVENZ_METHOD_COPY:    Exit('Copy');
    SEVENZ_METHOD_DELTA:   Exit('Delta');
    SEVENZ_METHOD_LZMA1:   Exit('LZMA');
    SEVENZ_METHOD_LZMA2:   Exit('LZMA2');
    SEVENZ_METHOD_BCJ_X86: Exit('BCJ_X86');
    SEVENZ_METHOD_BCJ_PPC: Exit('BCJ_PPC');
    SEVENZ_METHOD_BCJ_IA64:Exit('BCJ_IA64');
    SEVENZ_METHOD_BCJ_ARM: Exit('BCJ_ARM');
    SEVENZ_METHOD_BCJ_ARMT:Exit('BCJ_ARMT');
    SEVENZ_METHOD_BCJ_SPARC:Exit('BCJ_SPARC');
    SEVENZ_METHOD_BCJ_ARM64:Exit('BCJ_ARM64');
    SEVENZ_METHOD_BCJ_RISCV:Exit('BCJ_RISCV');
    SEVENZ_METHOD_BCJ2:    Exit('BCJ2');
    SEVENZ_METHOD_AES256_CRC: Exit('AES256');
    SEVENZ_METHOD_DEFLATE: Exit('Deflate');
    SEVENZ_METHOD_BZIP2:   Exit('BZip2');
    SEVENZ_METHOD_PPMD:    Exit('PPMD');
  end;
  SetLength(LHex, 12);
  LV := QWord(AMethodId);
  for LI := 11 downto 0 do
  begin
    LHex[LI + 1] := HD[LV and $F];
    LV := LV shr 4;
  end;
  Result := 'Unknown_' + LHex;
end;

end.
