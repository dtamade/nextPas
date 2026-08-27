unit nextpas.core.respack.base;

{** @desc respack 线格式 v1 基座：常量、record、LE 编解码、路径语法、FNV-1a、错误。
  权威格式定义见 core/docs/respack/FORMAT.md；实现与文档冲突时先修文档。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { 线格式常量（FORMAT.md） }
  RESPACK_MAGIC: array[0..3] of AnsiChar = ('N', 'P', 'R', 'S');
  RESPACK_VERSION              = 1;
  RESPACK_HEADER_SIZE          = 40;
  RESPACK_ENTRY_SIZE           = 40;
  RESPACK_DATA_ALIGN           = 16;
  RESPACK_DIGEST_SIZE          = 32;

  { header flags；bit0/bit1 已定义，bit2 起保留（reader 拒绝置位） }
  RESPACK_FLAG_HASHED   = $00000001;  { 全部条目 hash 有效（汇总提示） }
  RESPACK_FLAG_DIGESTED = $00000002;  { digest 区存在 }
  RESPACK_FLAG_KNOWN    = RESPACK_FLAG_HASHED or RESPACK_FLAG_DIGESTED;

  { entry flags }
  RESPACK_EFLAG_HASHED = $0001;      { 本条目 hash 有效（权威判定） }
  RESPACK_EFLAG_KNOWN  = RESPACK_EFLAG_HASHED;

  { codecId 登记表（FORMAT.md）；未知值 reader 整包拒绝 }
  RESPACK_CODEC_STORE = 0;

  { writer 输入上限（CONTRACT INV-R10）：超出显式 raise，绝不静默产出坏包 }
  RESPACK_MAX_INPUT_BYTES = SizeUInt(512) * 1024 * 1024;

type
  { host-order API record；线上布局一律经 LE helper 编解码（BE 平台安全） }
  TResPackHeader = record
    Version: UInt32;
    Flags: UInt32;
    EntryCount: UInt32;
    IndexOffset: UInt64;
    DigestOffset: UInt64;  { 0 = 无 digest 区 }
    BlobTotal: UInt64;
  end;

  TResPackEntry = record
    PathOffset: UInt32;    { 相对 string table 基址 }
    PathLen: Word;
    Flags: Word;
    DataOffset: UInt64;    { blob 内绝对偏移 }
    Size: UInt64;
    ModTime: Int64;        { Unix 秒；0 = 未知 }
    Hash: UInt32;          { FNV-1a 32；Flags 含 HASHED 时有效 }
    CodecId: Byte;
  end;

  TResPackDigest = array[0..RESPACK_DIGEST_SIZE - 1] of Byte;

  { writer 输入条目：内容由调用方持有，Build 过程内只读 }
  TResPackInputEntry = record
    Path: string;          { 必须通过 ResPackValidPath；'.' 根不是文件路径 }
    Data: PByte;
    DataSize: SizeUInt;
    ModTime: Int64;
  end;

  TResPackInputArray = array of TResPackInputEntry;

  TResPackDigestFunc = reference to procedure(const AData: PByte;
    const ASize: SizeUInt; const ADigestOut: PByte);

  TResPackBuildOptions = record
    Deduplicate: Boolean;         { fnv 候选 + 字节回验后复用槽位 }
    Hashes: Boolean;              { 计算并写入条目 FNV-1a }
    DigestFunc: TResPackDigestFunc; { nil = 无 digest 区 }
    MaxTotalInputBytes: SizeUInt; { 输入总量上限；超限 EResPackTooLarge }
  end;

  { Build 产物：Owned=True 时 Data 为堆缓冲，须 ResPackFreeBlob 归还 }
  TResPackBlob = record
    Data: PByte;
    Size: SizeUInt;
    Owned: Boolean;
  end;

  { 错误层级：全部挂在 exception 根上，不触碰 SysUtils }
  EResPackError = class(Exception);
  EResPackCorrupted = class(EResPackError)
  public
    constructor CreateStep(const AStep: Integer; const ADetail: string);
  end;
  EResPackDuplicatePath = class(EResPackError);
  EResPackInvalidPath = class(EResPackError);
  EResPackNotFound = class(EResPackError);
  EResPackTooLarge = class(EResPackError);
  EResPackDirSourceFailed = class(EResPackError);

{ LE 编解码（host-endian 无关） }
function RdU16LE(AData: PByte): Word; inline;
function RdU32LE(AData: PByte): UInt32; inline;
function RdU64LE(AData: PByte): UInt64; inline;
procedure WrU16LE(AData: PByte; const AValue: Word); inline;
procedure WrU32LE(AData: PByte; const AValue: UInt32); inline;
procedure WrU64LE(AData: PByte; const AValue: UInt64); inline;

{ FNV-1a 32（内联实现决策见 README 设计决策记录） }
function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32;

{ Go io/fs.ValidPath 语义（FORMAT.md 路径规范）：UTF-8、unrooted、'/'
  分隔、段非空非'.'非'..'、反斜杠为普通字符；特例 '.' 表根。
  文件条目场景 AFileEntry=True 时拒绝根。 }
function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean;

{ 默认构建选项 }
function ResPackDefaultOptions: TResPackBuildOptions; inline;

procedure ResPackFreeBlob(var ABlob: TResPackBlob);

implementation

function RdU16LE(AData: PByte): Word;
begin
  Result := Word(AData[0]) or (Word(AData[1]) shl 8);
end;

function RdU32LE(AData: PByte): UInt32;
begin
  Result := UInt32(AData[0]) or (UInt32(AData[1]) shl 8)
    or (UInt32(AData[2]) shl 16) or (UInt32(AData[3]) shl 24);
end;

function RdU64LE(AData: PByte): UInt64;
begin
  Result := UInt64(RdU32LE(AData)) or (UInt64(RdU32LE(AData + 4)) shl 32);
end;

procedure WrU16LE(AData: PByte; const AValue: Word);
begin
  AData[0] := Byte(AValue);
  AData[1] := Byte(AValue shr 8);
end;

procedure WrU32LE(AData: PByte; const AValue: UInt32);
begin
  AData[0] := Byte(AValue);
  AData[1] := Byte(AValue shr 8);
  AData[2] := Byte(AValue shr 16);
  AData[3] := Byte(AValue shr 24);
end;

procedure WrU64LE(AData: PByte; const AValue: UInt64);
begin
  WrU32LE(AData, UInt32(AValue));
  WrU32LE(AData + 4, UInt32(AValue shr 32));
end;

function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32;
const
  PRIME: UInt32 = 16777619;
var
  I: SizeUInt;
  H: UInt32;
begin
  H := $811C9DC5;
  if ASize = 0 then
    Exit(H);   { 空内容：FNV 偏移基值；同时规避 SizeUInt 下界回绕 }
  for I := 0 to ASize - 1 do
  begin
    H := (H xor UInt32(AData[I])) * PRIME;
  end;
  Result := H;
end;

function ResPackUtf8Valid(const S: string): Boolean;
var
  I, N: Integer;
  B, Cont: Byte;
  Need: Integer;
begin
  { 轻量 UTF-8 结构校验（Go utf8.ValidString 对等语义） }
  Result := False;
  N := Length(S);
  if N = 0 then
    Exit(True);
  I := 1;
  while I <= N do
  begin
    B := Byte(S[I]);
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end
    else if (B and $E0) = $C0 then
    begin
      Need := 1;
      if (B and $1E) = 0 then Exit(False);  { 过长编码 C0/C1 }
    end
    else if (B and $F0) = $E0 then
      Need := 2
    else if (B and $F8) = $F0 then
    begin
      Need := 3;
      if B > $F4 then Exit(False);          { > U+10FFFF 首字节 }
    end
    else
      Exit(False);
    if I + Need > N then
      Exit(False);
    for Cont := 1 to Need do
    begin
      if (Byte(S[I + Cont]) and $C0) <> $80 then
        Exit(False);
    end;
    { 排除代理区与过长编码边界值 }
    if (Need = 2) and (B = $E0) and (Byte(S[I + 1]) < $A0) then
      Exit(False);
    if (Need = 3) and ((B = $F0) and (Byte(S[I + 1]) < $90)) then
      Exit(False);
    if (Need = 3) and (B = $F4) and (Byte(S[I + 1]) >= $90) then
      Exit(False);
    Inc(I, Need + 1);
  end;
  Result := True;
end;

function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean;
var
  Start, I, N, SegLen: Integer;
begin
  Result := False;
  if not ResPackUtf8Valid(APath) then
    Exit;
  if APath = '.' then
    Exit(not AFileEntry);   { '.' 仅表根；文件条目非法 }
  if Length(APath) = 0 then
    Exit;
  if (APath[1] = '/') or (APath[Length(APath)] = '/') then
    Exit;
  N := Length(APath);
  Start := 1;
  for I := 1 to N + 1 do
  begin
    if (I > N) or (APath[I] = '/') then
    begin
      SegLen := I - Start;
      if SegLen = 0 then
        Exit; { empty segment: 'a//b' }
      if SegLen = 1 then
      begin
        if APath[Start] = '.' then
          Exit; { single dot segment }
      end
      else if SegLen = 2 then
      begin
        if (APath[Start] = '.') and (APath[Start + 1] = '.') then
          Exit; { parent segment }
      end;
      Start := I + 1;
    end;
  end;
  Result := True;
end;

function ResPackDefaultOptions: TResPackBuildOptions;
begin
  Result.Deduplicate := False;
  Result.Hashes := True;
  Result.DigestFunc := nil;
  Result.MaxTotalInputBytes := RESPACK_MAX_INPUT_BYTES;
end;

procedure ResPackFreeBlob(var ABlob: TResPackBlob);
begin
  if ABlob.Owned and (ABlob.Data <> nil) then
    FreeMem(ABlob.Data);
  ABlob.Data := nil;
  ABlob.Size := 0;
  ABlob.Owned := False;
end;

{ 十进制整数转字符串（局部实现，避免引入 SysUtils/text 依赖） }
function ResPackUIntToStr(AValue: UInt32): string;
var
  Tmp: array[0..15] of AnsiChar;
  I, J: Integer;
begin
  if AValue = 0 then
    Exit('0');
  I := High(Tmp);
  while AValue > 0 do
  begin
    Tmp[I] := AnsiChar(Ord('0') + (AValue mod 10));
    Dec(I);
    AValue := AValue div 10;
  end;
  SetLength(Result, High(Tmp) - I);
  for J := 1 to High(Tmp) - I do
    Result[J] := Char(Tmp[I + J]);
end;

constructor EResPackCorrupted.CreateStep(const AStep: Integer; const ADetail: string);
begin
  inherited Create('respack: validation step '
    + ResPackUIntToStr(UInt32(AStep)) + ' failed: ' + ADetail);
end;

end.
