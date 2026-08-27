unit nextpas.core.zip.aes;
{**
 * @desc WinZip AES 加密条目（AE-1/AE-2）的加密原语与封框/解封实现。
 *       框架：salt + 2 字节口令校验值 + AES-CTR 密文 + 10 字节 HMAC-SHA1
 *       截断认证码；密钥经 PBKDF2-HMAC-SHA1（1000 轮）派生为
 *       encKey + authKey(20) + pwVerify(2)。计数器为小端 128 位、从 1 起。
 *
 *       写端只产出 AE-2（头部 CRC 置 0，完整性完全由认证码保证）；读端
 *       同时接受 AE-1（保留真实 CRC32，走常规校验）与 AE-2。遗留 ZipCrypto
 *       不在此单元职责内（读器按 ENotSupportedError 拒绝）。
 *
 *       错误模型：口令校验值或认证码不匹配统一 EParseError('zip aes:
 *       authentication failed')（不区分失败点，避免区分性 oracle）；
 *       帧截断/强度非法 → EParseError/EArgumentError；未配置口令 →
 *       EInvalidOperationError；盐取自安全随机，随机源故障原样传播。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.hash.intf,
  nextpas.core.io.intf,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.aesni;

const
  C_BLOCK = 16;  { AES 块宽 }

const
  { WinZip AES extra field 与 AE-1/AE-2 框架常量（APPNOTE 附录） }
  C_WINZIP_AES_EXTRA_ID     = $9901;
  C_WINZIP_AES_VERSION_1    = $0001; { AE-1：头部位保留真实 CRC32 }
  C_WINZIP_AES_VERSION_2    = $0002; { AE-2：头部 CRC 置 0 }
  C_WINZIP_AES_ITERATIONS   = 1000;  { PBKDF2-HMAC-SHA1 轮数（规范固定） }
  C_WINZIP_AES_AUTH_LEN     = 10;    { 认证码长度（HMAC-SHA1 截断） }
  C_WINZIP_AES_PWVERIFY_LEN = 2;     { 头部口令校验值宽度 }
  C_WINZIP_AES_EXTRA_BODY   = 7;     { extra 内容体宽：ver(2)+vendor(2)+strength(1)+method(2) }
  C_WINZIP_AES_VENDOR_LE    = $4541; { 厂商标识 'AE' 小端字 }

type
  { 派生密钥组：encKey 宽度随强度（16/24/32），authKey 固定 20，
    pwVerify 为存档头原样存储比对的 2 字节 }
  TWinZipAesKeys = record
    EncKey: TBytes;
    AuthKey: TBytes;
    PwVerify: TBytes;
  end;

{ 强度码 → 密钥字节数；非法码 raise EArgumentError }
function WinZipAesKeyBytes(AStrengthCode: Byte): Integer;

{ 强度码 → 盐字节数 = 密钥字节数一半；非法码 raise EArgumentError }
function WinZipAesSaltBytes(AStrengthCode: Byte): Integer;

{ 帧 = salt + 口令校验值 + 密文 + 认证码；返回除密文外的固定开销 }
function WinZipAesFrameOverhead(AStrengthCode: Byte): UInt64;

{ PBKDF2-HMAC-SHA1 派生三件套；非法强度码 raise EArgumentError }
function DeriveWinZipAesKeys(const APassword, ASalt: TBytes;
  AStrengthCode: Byte): TWinZipAesKeys;

{ 认证用增量 HMAC-SHA1（消息 = 口令校验值 || 密文，流式喂入） }
function NewWinZipAesAuth(const AAuthKey: TBytes): IHasher;

{ 常量时间字节序列比对；长度不同直接 False }
function WinZipAesEqualBytes(const AA, AB: TBytes): Boolean;

{ 构造 0x9901 extra 内容体（7 字节）：本单元固定产出 AE-2 版本 }
function BuildWinZipAesExtraBody(AStrengthCode: Byte;
  ARealMethod: Word): TBytes;

{ 写端封框：压缩后载荷 → salt+pwVerify+密文+认证码。盐取安全随机，
  随机源故障异常原样传播；空口令 raise EArgumentError }
function SealWinZipAesPayload(const APassword: TBytes; AStrengthCode: Byte;
  const ACompressed: TBytes): TBytes;

{ 读端一次性解封（提取路径）：校验口令校验值与认证码后输出解密出的
  压缩流。空口令 raise EInvalidOperationError }
function UnsealWinZipAesPayload(const APassword, APayload: TBytes;
  AStrengthCode: Byte; const AName: string): TBytes;

{ 流式解封装读端：从 AInner 顺序消费 salt/pwVerify/ACipherLen 字节密文/
  认证码。构造即派生密钥并强校验 pwVerify；密文透传时增量解密+认证；
  密文耗尽后的首次读取强制比对认证码，此后恒返 0 }
function NewWinZipAesReader(const AInner: IReader; const APassword: TBytes;
  AStrengthCode: Byte; ACipherLen: UInt64;
  const AName: string): IReader;

type
  { AES-CTR 变换器：小端 128 位计数器从 1 起，跨调用连续推进。
    x86_64 且 CPU 支持时走 AES-NI 硬件块加密（128/256 位密钥），
    其余（含 192 位密钥与非 x86_64 目标）走常数时间表驱动实现 }
  TWinZipAesCtr = class
  private
    FCtKey: TAESCt64Key;
    FCtr: array[0..C_BLOCK - 1] of Byte;      { 下一 keystream 块的计数值 }
    FKeystream: array[0..C_BLOCK - 1] of Byte;
    FPos: Integer;                            { FKeystream 已消耗偏移 }
    {$IFDEF CPUX86_64}
    FNiBits: Integer;                         { 16/128→AES-NI；0→ct64 }
    FNiKey128: TAESNIExpandedKey128;
    FNiKey256: TAESNIExpandedKey256;
    FNiIn: TAESNIBlock;
    FNiOut: TAESNIBlock;
    {$ENDIF}
    procedure RefreshKeystream;
    procedure NextCounter;
  public
    constructor Create(const AEncKey: TBytes);
    { 原地对 [ABuf, ABuf+ACount) 做 XOR keystream }
    procedure Transform(var ABuf; ACount: SizeUInt);
  end;

type
  { 增量封框器（写端流式路径）：Header 为 salt+pwVerify（须最先发出），
    Transform 对每段压缩输出原地"先加密后认证"（认证消息 = 密文，
    与一次性封框一致），Finish 产出 10 字节认证码（最后发出）。
    与 TWinZipAesReader 构成对称的流式封/解封对 }
  TWinZipAesSealer = class
  private
    FCipher: TWinZipAesCtr;
    FAuth: IHasher;
    FHeader: TBytes;             { salt || pwVerify }
    FClosed: Boolean;
  public
    constructor Create(const APassword: TBytes; AStrengthCode: Byte);
    destructor Destroy; override;
    function Header: TBytes;
    procedure Transform(var ABuf; ACount: SizeUInt);
    function Finish: TBytes;
  end;

{ 构造增量封框器；空口令 raise EArgumentError }
function NewWinZipAesSealer(const APassword: TBytes;
  AStrengthCode: Byte): TWinZipAesSealer;

implementation

uses
  nextpas.core.exception,
  nextpas.core.hash.base,
  nextpas.core.crypto.pbkdf2,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.random
  ;

type
  { 流式解封装读端（NewWinZipAesReader 返回体） }
  TWinZipAesReader = class(TInterfacedObject, IReader)
  private
    FInner: IReader;
    FName: string;
    FCipher: TWinZipAesCtr;      { 自有；析构释放 }
    FAuth: IHasher;
    FCipherRemaining: UInt64;    { 尚未透传的密文字节数 }
    FDone: Boolean;              { 认证码已强制校验，后续恒 EOF }
    function ReadExact(ADst: PByte; ACount: SizeUInt; const AWhat: string)
      : Boolean;
  public
    constructor Create(const AInner: IReader; const APassword: TBytes;
      AStrengthCode: Byte; ACipherLen: UInt64; const AName: string);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

{ ---- 强度换算 ---- }

function WinZipAesKeyBytes(AStrengthCode: Byte): Integer;
begin
  case AStrengthCode of
    1: Result := 16;   { AES-128 }
    2: Result := 24;   { AES-192 }
    3: Result := 32;   { AES-256 }
  else
    raise EArgumentError.Create(
      'zip aes: unsupported strength code ' + IntToStr(AStrengthCode));
  end;
end;

function WinZipAesSaltBytes(AStrengthCode: Byte): Integer;
begin
  Result := WinZipAesKeyBytes(AStrengthCode) div 2;
end;

function WinZipAesFrameOverhead(AStrengthCode: Byte): UInt64;
begin
  Result := UInt64(WinZipAesSaltBytes(AStrengthCode)) +
    C_WINZIP_AES_PWVERIFY_LEN + C_WINZIP_AES_AUTH_LEN;
end;

{ ---- 密钥派生与认证 ---- }

function DeriveWinZipAesKeys(const APassword, ASalt: TBytes;
  AStrengthCode: Byte): TWinZipAesKeys;
var
  LDk: TBytes;
  LKeyLen: Integer;
begin
  Result := Default(TWinZipAesKeys);
  LKeyLen := WinZipAesKeyBytes(AStrengthCode);
  LDk := PBKDF2_SHA1(APassword, ASalt, C_WINZIP_AES_ITERATIONS,
    LKeyLen + 20 + C_WINZIP_AES_PWVERIFY_LEN);
  Result.EncKey := Copy(LDk, 0, LKeyLen);
  Result.AuthKey := Copy(LDk, LKeyLen, 20);
  Result.PwVerify := Copy(LDk, LKeyLen + 20, C_WINZIP_AES_PWVERIFY_LEN);
end;

function NewWinZipAesAuth(const AAuthKey: TBytes): IHasher;
begin
  if Length(AAuthKey) = 0 then
    raise EArgumentError.Create('zip aes: empty auth key');
  Result := NewHMAC(haSHA1, AAuthKey[0], SizeUInt(Length(AAuthKey)));
end;

function WinZipAesEqualBytes(const AA, AB: TBytes): Boolean;
begin
  if Length(AA) <> Length(AB) then
    Exit(False);
  if Length(AA) = 0 then
    Exit(True);
  Result := TConstantTime.CompareBuffer(@AA[0], @AB[0],
    SizeUInt(Length(AA))) <> 0;
end;

{ ---- extra field 内容体 ---- }

function BuildWinZipAesExtraBody(AStrengthCode: Byte;
  ARealMethod: Word): TBytes;
begin
  Result := nil;
  SetLength(Result, C_WINZIP_AES_EXTRA_BODY);
  Result[0] := Byte(C_WINZIP_AES_VERSION_2);   { version lo：本单元固定 AE-2 }
  Result[1] := 0;                              { version hi }
  Result[2] := Ord('A');                       { vendor 'AE' }
  Result[3] := Ord('E');
  Result[4] := AStrengthCode;
  Result[5] := Byte(ARealMethod and $FF);
  Result[6] := Byte(ARealMethod shr 8);
end;

{ ---- AES-CTR 变换器 ---- }

constructor TWinZipAesCtr.Create(const AEncKey: TBytes);
begin
  inherited Create;
  if Length(AEncKey) = 0 then
    raise EArgumentError.Create('zip aes: empty encryption key');
  FillChar(FCtr, C_BLOCK, 0);
  FCtr[0] := 1;                  { 规范：小端 128 位计数器从 1 开始 }
  FPos := 0;
  {$IFDEF CPUX86_64}
  FNiBits := 0;
  if IsAESNIAvailable then
    case Length(AEncKey) of
      16:
        begin
          Move(AEncKey[0], FNiIn, 16);
          AESNIExpandKey128(FNiIn, FNiKey128);
          FNiBits := 16;
        end;
      32:
        begin
          AESNIExpandKey256(AEncKey, FNiKey256);
          FNiBits := 32;
        end;
    end;
  if FNiBits = 0 then
  {$ENDIF}
    AESCt64KeyExpand(AEncKey, FCtKey);
end;

procedure TWinZipAesCtr.RefreshKeystream;
begin
  {$IFDEF CPUX86_64}
  case FNiBits of
    16:
      begin
        Move(FCtr, FNiIn, C_BLOCK);
        AESNIEncryptBlock128(FNiIn, FNiOut, FNiKey128);
        Move(FNiOut, FKeystream, C_BLOCK);
      end;
    32:
      begin
        Move(FCtr, FNiIn, C_BLOCK);
        AESNIEncryptBlock256(FNiIn, FNiOut, FNiKey256);
        Move(FNiOut, FKeystream, C_BLOCK);
      end;
  end;
  if FNiBits <> 0 then
    Exit;
  {$ENDIF}
  AESCt64EncryptBlock(@FCtr, @FKeystream, FCtKey);
end;

procedure TWinZipAesCtr.NextCounter;
var
  LI: Integer;
begin
  for LI := 0 to C_BLOCK - 1 do
  begin
    Inc(FCtr[LI]);
    if FCtr[LI] <> 0 then
      Break;                     { 无进位即止（小端全宽递增） }
  end;
end;

procedure TWinZipAesCtr.Transform(var ABuf; ACount: SizeUInt);
var
  LP: PByte;
  LChunk, LI: Integer;
begin
  LP := @ABuf;
  while ACount > 0 do
  begin
    if FPos = 0 then
      RefreshKeystream;
    LChunk := C_BLOCK - FPos;
    if SizeUInt(LChunk) > ACount then
      LChunk := Integer(ACount);
    for LI := 0 to LChunk - 1 do
      (LP + LI)^ := (LP + LI)^ xor FKeystream[FPos + LI];
    Inc(FPos, LChunk);
    Inc(LP, LChunk);
    Dec(ACount, SizeUInt(LChunk));
    if FPos = C_BLOCK then
    begin
      NextCounter;
      FPos := 0;
    end;
  end;
end;

{ ---- 写端封框 / 读端一次性解封 ---- }

function SealWinZipAesPayload(const APassword: TBytes; AStrengthCode: Byte;
  const ACompressed: TBytes): TBytes;
var
  LSaltLen, LBodyLen, LTotal: Integer;
  LSalt: TBytes;
  LKeys: TWinZipAesKeys;
  LCipher: TWinZipAesCtr;
  LAuth: IHasher;
  LDigest: TBytes;
begin
  Result := nil;
  if Length(APassword) = 0 then
    raise EArgumentError.Create('zip aes: seal requires a non-empty password');
  LSaltLen := WinZipAesSaltBytes(AStrengthCode);
  LSalt := GenerateSecureRandomBytes(LSaltLen);
  LKeys := DeriveWinZipAesKeys(APassword, LSalt, AStrengthCode);

  LBodyLen := Length(ACompressed);
  LTotal := LSaltLen + C_WINZIP_AES_PWVERIFY_LEN + LBodyLen +
    C_WINZIP_AES_AUTH_LEN;
  SetLength(Result, LTotal);
  if LSaltLen > 0 then
    Move(LSalt[0], Result[0], SizeUInt(LSaltLen));
  Move(LKeys.PwVerify[0], Result[LSaltLen], C_WINZIP_AES_PWVERIFY_LEN);
  if LBodyLen > 0 then
    Move(ACompressed[0], Result[LSaltLen + C_WINZIP_AES_PWVERIFY_LEN],
      SizeUInt(LBodyLen));

  LCipher := TWinZipAesCtr.Create(LKeys.EncKey);
  try
    if LBodyLen > 0 then
      LCipher.Transform(Result[LSaltLen + C_WINZIP_AES_PWVERIFY_LEN],
        SizeUInt(LBodyLen));
  finally
    LCipher.Free;
  end;

  { 认证消息 = 口令校验值 || 密文 }
  LAuth := NewWinZipAesAuth(LKeys.AuthKey);
  LAuth.Write(LKeys.PwVerify[0], C_WINZIP_AES_PWVERIFY_LEN);
  if LBodyLen > 0 then
    LAuth.Write(Result[LSaltLen + C_WINZIP_AES_PWVERIFY_LEN],
      SizeUInt(LBodyLen));
  LDigest := LAuth.SumBytes;
  Move(LDigest[0],
    Result[LSaltLen + C_WINZIP_AES_PWVERIFY_LEN + LBodyLen],
    C_WINZIP_AES_AUTH_LEN);
end;

function UnsealWinZipAesPayload(const APassword, APayload: TBytes;
  AStrengthCode: Byte; const AName: string): TBytes;
var
  LSaltLen, LBodyOfs, LBodyLen: Integer;
  LSalt, LStoredPwv, LDigest: TBytes;
  LKeys: TWinZipAesKeys;
  LCipher: TWinZipAesCtr;
  LAuth: IHasher;
begin
  Result := nil;
  if Length(APassword) = 0 then
    raise EInvalidOperationError.Create(
      'zip aes: no password configured for encrypted entry: ' + AName);
  LSaltLen := WinZipAesSaltBytes(AStrengthCode);
  if Length(APayload) < LSaltLen + C_WINZIP_AES_PWVERIFY_LEN +
    C_WINZIP_AES_AUTH_LEN then
    raise EParseError.Create('zip aes: encrypted payload truncated: ' +
      AName);

  LSalt := Copy(APayload, 0, LSaltLen);
  LStoredPwv := Copy(APayload, LSaltLen, C_WINZIP_AES_PWVERIFY_LEN);
  LKeys := DeriveWinZipAesKeys(APassword, LSalt, AStrengthCode);
  { 校验值与认证码失败统一报错，避免可区分的失败点 oracle }
  if not WinZipAesEqualBytes(LStoredPwv, LKeys.PwVerify) then
    raise EParseError.Create('zip aes: authentication failed: ' + AName);

  LBodyOfs := LSaltLen + C_WINZIP_AES_PWVERIFY_LEN;
  LBodyLen := Length(APayload) - LBodyOfs - C_WINZIP_AES_AUTH_LEN;
  Result := Copy(APayload, LBodyOfs, LBodyLen);

  { 认证消息 = 口令校验值 || 密文：先强校验认证码再解密 }
  LAuth := NewWinZipAesAuth(LKeys.AuthKey);
  LAuth.Write(LKeys.PwVerify[0], C_WINZIP_AES_PWVERIFY_LEN);
  if LBodyLen > 0 then
    LAuth.Write(APayload[LBodyOfs], SizeUInt(LBodyLen));
  LDigest := LAuth.SumBytes;
  if not WinZipAesEqualBytes(Copy(LDigest, 0, C_WINZIP_AES_AUTH_LEN),
    Copy(APayload, Length(APayload) - C_WINZIP_AES_AUTH_LEN,
    C_WINZIP_AES_AUTH_LEN)) then
    raise EParseError.Create('zip aes: authentication failed: ' + AName);

  LCipher := TWinZipAesCtr.Create(LKeys.EncKey);
  try
    if LBodyLen > 0 then
      LCipher.Transform(Result[0], SizeUInt(LBodyLen));
  finally
    LCipher.Free;
  end;
end;

{ ---- 流式解封装读端 ---- }

constructor TWinZipAesReader.Create(const AInner: IReader;
  const APassword: TBytes; AStrengthCode: Byte; ACipherLen: UInt64;
  const AName: string);
var
  LSaltLen: Integer;
  LSalt, LHead: TBytes;
  LKeys: TWinZipAesKeys;
begin
  inherited Create;
  if Length(APassword) = 0 then
    raise EInvalidOperationError.Create(
      'zip aes: no password configured for encrypted entry: ' + AName);
  FInner := AInner;
  FName := AName;
  FCipherRemaining := ACipherLen;
  FDone := False;

  LSaltLen := WinZipAesSaltBytes(AStrengthCode);
  SetLength(LSalt, LSaltLen);
  if LSaltLen > 0 then
    if not ReadExact(@LSalt[0], SizeUInt(LSaltLen), 'salt') then
      raise EParseError.Create('zip aes: encrypted payload truncated: ' +
        AName);
  SetLength(LHead, C_WINZIP_AES_PWVERIFY_LEN);
  if not ReadExact(@LHead[0], C_WINZIP_AES_PWVERIFY_LEN, 'password verify')
  then
    raise EParseError.Create('zip aes: encrypted payload truncated: ' +
      AName);

  LKeys := DeriveWinZipAesKeys(APassword, LSalt, AStrengthCode);
  if not WinZipAesEqualBytes(LHead, LKeys.PwVerify) then
    raise EParseError.Create('zip aes: authentication failed: ' + AName);

  FCipher := TWinZipAesCtr.Create(LKeys.EncKey);
  FAuth := NewWinZipAesAuth(LKeys.AuthKey);
  FAuth.Write(LKeys.PwVerify[0], C_WINZIP_AES_PWVERIFY_LEN);
end;

destructor TWinZipAesReader.Destroy;
begin
  FCipher.Free;
  inherited;
end;

function TWinZipAesReader.ReadExact(ADst: PByte; ACount: SizeUInt;
  const AWhat: string): Boolean;
var
  LGot, LOff: SizeUInt;
begin
  LOff := 0;
  while LOff < ACount do
  begin
    LGot := FInner.Read((ADst + LOff)^, ACount - LOff);
    if LGot = 0 then
      Exit(False);
    Inc(LOff, LGot);
  end;
  Result := True;
end;

function TWinZipAesReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LN: SizeUInt;
  LTail, LDigest: TBytes;
begin
  if FDone or (ACount = 0) then
    Exit(0);

  if FCipherRemaining > 0 then
  begin
    LN := ACount;
    if UInt64(LN) > FCipherRemaining then
      LN := SizeUInt(FCipherRemaining);
    if not ReadExact(@ABuf, LN, 'ciphertext') then
      raise EParseError.Create('zip aes: encrypted payload truncated: ' +
        FName);
    { 认证消息 = 密文：先喂认证再原地解密 }
    FAuth.Write(ABuf, LN);
    FCipher.Transform(ABuf, LN);
    Dec(FCipherRemaining, LN);
    Exit(LN);
  end;

  { 密文耗尽：读取并强制比对认证码，此后恒 EOF }
  SetLength(LTail, C_WINZIP_AES_AUTH_LEN);
  if not ReadExact(@LTail[0], C_WINZIP_AES_AUTH_LEN, 'auth code') then
    raise EParseError.Create('zip aes: encrypted payload truncated: ' +
      FName);
  LDigest := FAuth.SumBytes;
  if not WinZipAesEqualBytes(LTail,
    Copy(LDigest, 0, C_WINZIP_AES_AUTH_LEN)) then
    raise EParseError.Create('zip aes: authentication failed: ' + FName);
  FDone := True;
  Result := 0;
end;

function NewWinZipAesReader(const AInner: IReader; const APassword: TBytes;
  AStrengthCode: Byte; ACipherLen: UInt64;
  const AName: string): IReader;
begin
  Result := TWinZipAesReader.Create(AInner, APassword, AStrengthCode,
    ACipherLen, AName);
end;

{ ---- 增量封框器 ---- }

constructor TWinZipAesSealer.Create(const APassword: TBytes;
  AStrengthCode: Byte);
var
  LSaltLen: Integer;
  LSalt: TBytes;
  LKeys: TWinZipAesKeys;
begin
  inherited Create;
  if Length(APassword) = 0 then
    raise EArgumentError.Create('zip aes: seal requires a non-empty password');
  LSaltLen := WinZipAesSaltBytes(AStrengthCode);
  LSalt := GenerateSecureRandomBytes(LSaltLen);
  LKeys := DeriveWinZipAesKeys(APassword, LSalt, AStrengthCode);

  SetLength(FHeader, LSaltLen + C_WINZIP_AES_PWVERIFY_LEN);
  if LSaltLen > 0 then
    Move(LSalt[0], FHeader[0], SizeUInt(LSaltLen));
  Move(LKeys.PwVerify[0], FHeader[LSaltLen], C_WINZIP_AES_PWVERIFY_LEN);

  FCipher := TWinZipAesCtr.Create(LKeys.EncKey);
  FAuth := NewWinZipAesAuth(LKeys.AuthKey);
  FAuth.Write(LKeys.PwVerify[0], C_WINZIP_AES_PWVERIFY_LEN);
  FClosed := False;
end;

destructor TWinZipAesSealer.Destroy;
begin
  FCipher.Free;
  inherited;
end;

function TWinZipAesSealer.Header: TBytes;
begin
  Result := Copy(FHeader);
end;

procedure TWinZipAesSealer.Transform(var ABuf; ACount: SizeUInt);
begin
  if FClosed then
    raise EInvalidOperationError.Create('zip aes: sealer already finished');
  if ACount = 0 then
    Exit;
  { 认证消息 = 密文（与一次性封框一致）：原地加密后再喂认证 }
  FCipher.Transform(ABuf, ACount);
  FAuth.Write(ABuf, ACount);
end;

function TWinZipAesSealer.Finish: TBytes;
var
  LDigest: TBytes;
begin
  if FClosed then
    raise EInvalidOperationError.Create('zip aes: sealer already finished');
  FClosed := True;
  LDigest := FAuth.SumBytes;
  Result := Copy(LDigest, 0, C_WINZIP_AES_AUTH_LEN);
end;

function NewWinZipAesSealer(const APassword: TBytes;
  AStrengthCode: Byte): TWinZipAesSealer;
begin
  Result := TWinZipAesSealer.Create(APassword, AStrengthCode);
end;

end.
