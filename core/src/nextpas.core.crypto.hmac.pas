unit nextpas.core.crypto.hmac;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}

{ nextpas.core.crypto.hmac — HMAC 实现 (RFC 2104)

  基于 nextpas.core.hash.IHasher 接口。
  Sum 语义：不改变内部状态（可多次调用，继续 Write 后再 Sum 得到不同结果）。
  NewHMAC(工厂, key) 允许嵌套 HMAC（底层 IHasher 可以是另一个 HMAC）。
}

interface

uses
  nextpas.core.base,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash;

type
  THasherFactory = reference to function: IHasher;

function NewHMAC(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt): IHasher; overload;
function NewHMAC(AFactory: THasherFactory; const AKey; AKeyLen: SizeUInt): IHasher; overload;

function HmacSHA256(const AKey, AData: TBytes): TSHA256Digest;
function HmacSHA384(const AKey, AData: TBytes): TSHA384Digest;
function HmacSHA512(const AKey, AData: TBytes): TSHA512Digest;

{ TBytes 返回版本（兼容旧消费者，后续逐步淘汰） }
function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
function HMAC_SHA1(const AKey, AData: TBytes): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.bytes.ops;

type
  THMACHasher = class(TInterfacedObject, IHasher)
  private
    FAlgo: THashAlgorithm;
    FFactory: THasherFactory;
    FInner: IHasher;
    FBlockSize: SizeUInt;
    FDigestSize: SizeUInt;
    FOPad: array[0..127] of Byte;
    function MakeInner: IHasher;
    procedure InitKey(const AKey; AKeyLen: SizeUInt);
  public
    constructor Create(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt); overload;
    constructor Create(AFactory: THasherFactory; const AKey; AKeyLen: SizeUInt); overload;
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
    function Clone: IHasher;
  end;

function THMACHasher.MakeInner: IHasher;
begin
  if Assigned(FFactory) then
    Result := FFactory()
  else
    Result := nextpas.core.hash.NewHasher(FAlgo);
end;

procedure THMACHasher.InitKey(const AKey; AKeyLen: SizeUInt);
var
  LKeyBlock: array[0..127] of Byte;
  LIPad: array[0..127] of Byte;
  LTmpHash: IHasher;
  LDigest: array[0..63] of Byte;
  I: SizeUInt;
begin
  inherited Create;
  if FBlockSize > SizeOf(LKeyBlock) then
    raise EArgumentError.Create('NewHMAC: block size exceeds 128');
  FillChar(LKeyBlock[0], SizeOf(LKeyBlock), 0);
  // 显式契约：AKeyLen=0 时不解引用 AKey。空 key 允许传任意地址（如 TBytes 变量本身）
  // 作为 untyped const，仅当 AKeyLen>0 才 Move/Write；底层 IHasher.Write(…,0) 亦保证不解引用
  // （HashRequireBuffer 仅在 ACount>0 时校验 @ABuf，与 Deflate 同理），故 NewHMAC(…,AKey,0) 安全。
  if AKeyLen > FBlockSize then
  begin
    LTmpHash := MakeInner;
    LTmpHash.Write(AKey, AKeyLen);
    LTmpHash.Sum(LDigest[0], FDigestSize);
    BytesCopy(@LKeyBlock[0], @LDigest[0], FDigestSize); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, SIMD single-source convergence)
    FillChar(LDigest[0], SizeOf(LDigest), 0);
  end
  else if AKeyLen > 0 then
    BytesCopy(@LKeyBlock[0], @AKey, AKeyLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy); AKeyLen=0 分支不触碰 AKey
  for I := 0 to FBlockSize - 1 do
  begin
    LIPad[I] := LKeyBlock[I] xor $36;
    FOPad[I] := LKeyBlock[I] xor $5C;
  end;
  FInner := MakeInner;
  FInner.Write(LIPad[0], FBlockSize);
  FillChar(LKeyBlock[0], SizeOf(LKeyBlock), 0);
  FillChar(LIPad[0], SizeOf(LIPad), 0);
end;

constructor THMACHasher.Create(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt);
begin
  FAlgo := AAlgo;
  FFactory := nil;
  FBlockSize := GetBlockSize(AAlgo);
  FDigestSize := GetDigestSize(AAlgo);
  InitKey(AKey, AKeyLen);
end;

constructor THMACHasher.Create(AFactory: THasherFactory; const AKey; AKeyLen: SizeUInt);
var
  LProbe: IHasher;
begin
  FAlgo := haSHA256;
  FFactory := AFactory;
  LProbe := AFactory();
  FBlockSize := LProbe.BlockSize;
  FDigestSize := LProbe.DigestSize;
  InitKey(AKey, AKeyLen);
end;

destructor THMACHasher.Destroy;
begin
  FillChar(FOPad[0], SizeOf(FOPad), 0);
  FInner := nil;
  inherited Destroy;
end;

function THMACHasher.Clone: IHasher;
var
  LClone: THMACHasher;
begin
  if Assigned(FFactory) then
    LClone := THMACHasher.Create(FFactory, FOPad[0], 0)
  else
    LClone := THMACHasher.Create(FAlgo, FOPad[0], 0);
  BytesCopy(@LClone.FOPad[0], @FOPad[0], SizeUInt(SizeOf(FOPad))); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
  LClone.FBlockSize := FBlockSize;
  LClone.FDigestSize := FDigestSize;
  LClone.FFactory := FFactory;
  LClone.FInner := FInner.Clone;
  Result := LClone;
end;

function THMACHasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

procedure THMACHasher.Sum(out ADst; const ASize: SizeUInt);
var
  LInnerDigest: array[0..63] of Byte;
  LOuter: IHasher;
begin
  FInner.Sum(LInnerDigest[0], FDigestSize);

  LOuter := MakeInner;
  LOuter.Write(FOPad[0], FBlockSize);
  LOuter.Write(LInnerDigest[0], FDigestSize);
  LOuter.Sum(ADst, ASize);

  FillChar(LInnerDigest[0], SizeOf(LInnerDigest), 0);
end;

function THMACHasher.SumBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, FDigestSize);
  Sum(Result[0], FDigestSize);
end;

procedure THMACHasher.Reset;
var
  LIPad: array[0..127] of Byte;
  I: SizeUInt;
begin
  for I := 0 to FBlockSize - 1 do
    LIPad[I] := FOPad[I] xor $5C xor $36;
  FInner.Reset;
  FInner.Write(LIPad[0], FBlockSize);
  FillChar(LIPad[0], SizeOf(LIPad), 0);
end;

function THMACHasher.DigestSize: SizeUInt;
begin
  Result := FDigestSize;
end;

function THMACHasher.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function NewHMAC(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt): IHasher;
begin
  Result := THMACHasher.Create(AAlgo, AKey, AKeyLen);
end;

function NewHMAC(AFactory: THasherFactory; const AKey; AKeyLen: SizeUInt): IHasher;
begin
  Result := THMACHasher.Create(AFactory, AKey, AKeyLen);
end;

function HmacSHA256(const AKey, AData: TBytes): TSHA256Digest;
var LH: IHasher;
begin
  // 空 key 显式契约：AKeyLen=0 时不解引用 AKey。else 分支传 AKey 变量本身作 untyped const
  // 仅为满足语法（空 TBytes 无 AKey[0]），因长度为 0，InitKey/底层 Write 均不读内存故安全。
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA256, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA256, AKey, 0); // AKeyLen=0 => 不解引用，显式标注隐式契约
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA256_DIGEST_SIZE);
end;

function HmacSHA384(const AKey, AData: TBytes): TSHA384Digest;
var LH: IHasher;
begin
  // 空 key 显式契约同 HmacSHA256：AKeyLen=0 时不解引用，else 传 AKey 本身安全。
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA384, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA384, AKey, 0); // AKeyLen=0 => 不解引用，显式标注隐式契约
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA384_DIGEST_SIZE);
end;

function HmacSHA512(const AKey, AData: TBytes): TSHA512Digest;
var LH: IHasher;
begin
  // 空 key 显式契约同 HmacSHA256：AKeyLen=0 时不解引用，else 传 AKey 本身安全。
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA512, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA512, AKey, 0); // AKeyLen=0 => 不解引用，显式标注隐式契约
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA512_DIGEST_SIZE);
end;

function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
var LD: TSHA256Digest;
begin
  LD := HmacSHA256(AKey, AData);
  Result := nil;
  SetLength(Result, SHA256_DIGEST_SIZE);
  BytesCopy(@Result[0], @LD[0], SHA256_DIGEST_SIZE); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
end;

function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
var LD: TSHA384Digest;
begin
  LD := HmacSHA384(AKey, AData);
  Result := nil;
  SetLength(Result, SHA384_DIGEST_SIZE);
  BytesCopy(@Result[0], @LD[0], SHA384_DIGEST_SIZE); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy)
end;

function HMAC_SHA1(const AKey, AData: TBytes): TBytes;
var LH: IHasher;
begin
  // 空 key 显式契约同 HmacSHA256：AKeyLen=0 时不解引用，else 传 AKey 本身安全。
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA1, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA1, AKey, 0); // AKeyLen=0 => 不解引用，显式标注隐式契约
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  Result := nil;
  SetLength(Result, SHA1_DIGEST_SIZE);
  LH.Sum(Result[0], SHA1_DIGEST_SIZE);
end;

end.
