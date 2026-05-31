unit nextpas.core.crypto.hash;

{$mode objfpc}{$H+}
{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params
{$modeswitch advancedrecords}

{ 禁用64位常量范围检查警告 - SHA-512 K常量需要 }
{$WARN 4110 off}  // Range check error while evaluating constants
{ 禁用函数结果未初始化警告 - SetLength 已经初始化 TBytes }
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{ 禁用本地变量未使用警告 - 某些临时变量用于中间计算 }
{$NOTES OFF} // Suppress false-positive notes for vars passed to untyped params
{$WARN 5025 off}  // Local variable not used
{ 禁用不可达代码警告 - case 语句的 else 分支是防御性代码 }
{ 注意：此指令为文件级，因 FPC 6018 在函数级解析阶段才触发 }
{$WARN 6018 off}  // Unreachable code

{
  纯 Pascal 哈希算法实现

  支持的算法:
  - MD5 (128 bits) - 仅用于兼容性，不推荐用于安全场景
  - SHA-1 (160 bits) - 仅用于兼容性，不推荐用于安全场景
  - SHA-256 (256 bits) - 推荐
  - SHA-384 (384 bits) - 推荐
  - SHA-512 (512 bits) - 推荐

  参考标准:
  - RFC 1321 (MD5)
  - FIPS 180-4 (SHA-1, SHA-256, SHA-384, SHA-512)

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  SysUtils, Classes;

type
  // ========================================================================
  // 哈希算法类型
  // ========================================================================
  THashAlgorithm = (
    haMD5,
    haSHA1,
    haSHA256,
    haSHA384,
    haSHA512
  );

  // ========================================================================
  // 哈希上下文基类
  // ========================================================================
  THashContext = class
  public
    procedure Update(const AData: TBytes); overload; virtual; abstract;
    procedure Update(const AData: string); overload;
    procedure Update(AStream: TStream); overload;
    function Final: TBytes; virtual; abstract;
    procedure Reset; virtual; abstract;

    class function DigestSize: Integer; virtual; abstract;
    class function BlockSize: Integer; virtual; abstract;
    class function AlgorithmName: string; virtual; abstract;
  end;

  // ========================================================================
  // MD5 实现
  // ========================================================================
  TMD5Context = class(THashContext)
  private
    FState: array[0..3] of UInt32;
    FCount: array[0..1] of UInt32;
    FBuffer: array[0..63] of Byte;

    procedure Transform(const ABlock: array of Byte);
  public
    constructor Create;
    procedure Update(const AData: TBytes); override;
    function Final: TBytes; override;
    procedure Reset; override;

    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  // ========================================================================
  // SHA-1 实现
  // ========================================================================
  TSHA1Context = class(THashContext)
  private
    FState: array[0..4] of UInt32;
    FCount: UInt64;
    FBuffer: array[0..63] of Byte;
    FBufferIndex: Integer;

    procedure Transform(const ABlock: array of Byte);
  public
    constructor Create;
    procedure Update(const AData: TBytes); override;
    function Final: TBytes; override;
    procedure Reset; override;

    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  // ========================================================================
  // SHA-256 实现
  // ========================================================================
  TSHA256Context = class(THashContext)
  private
    FState: array[0..7] of UInt32;
    FCount: UInt64;
    FBuffer: array[0..63] of Byte;
    FBufferIndex: Integer;

    procedure Transform(const ABlock: array of Byte);
  public
    constructor Create;
    procedure Update(const AData: TBytes); override;
    function Final: TBytes; override;
    procedure Reset; override;

    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  // ========================================================================
  // SHA-512 实现 (SHA-384 基于此)
  // ========================================================================
  TSHA512Context = class(THashContext)
  private
    FState: array[0..7] of UInt64;
    FCount: array[0..1] of UInt64;
    FBuffer: array[0..127] of Byte;
    FBufferIndex: Integer;
    FIs384: Boolean;

    procedure Transform(const ABlock: array of Byte);
  public
    constructor Create; overload;
    constructor Create(AIs384: Boolean); overload;
    procedure Update(const AData: TBytes); override;
    function Final: TBytes; override;
    procedure Reset; override;

    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  // ========================================================================
  // SHA-384 实现 (继承自 SHA-512)
  // ========================================================================
  TSHA384Context = class(TSHA512Context)
  public
    constructor Create;

    class function DigestSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

// ========================================================================
// 便捷函数
// ========================================================================

// 一次性计算哈希
function MD5(const AData: TBytes): TBytes; overload;
function MD5(const AData: string): TBytes; overload;
function SHA1(const AData: TBytes): TBytes; overload;
function SHA1(const AData: string): TBytes; overload;
function SHA256(const AData: TBytes): TBytes; overload;
function SHA256(const AData: string): TBytes; overload;
function SHA384(const AData: TBytes): TBytes; overload;
function SHA384(const AData: string): TBytes; overload;
function SHA512(const AData: TBytes): TBytes; overload;
function SHA512(const AData: string): TBytes; overload;

// 哈希转十六进制字符串
function HashToHex(const AHash: TBytes): string;

// 创建哈希上下文
function CreateHashContext(AAlgorithm: THashAlgorithm): THashContext;

// 获取算法信息
function GetHashDigestSize(AAlgorithm: THashAlgorithm): Integer;
function GetHashBlockSize(AAlgorithm: THashAlgorithm): Integer;
function GetHashAlgorithmName(AAlgorithm: THashAlgorithm): string;

implementation

uses
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash.intf;

// ========================================================================
// THashContext 基类实现
// ========================================================================

procedure THashContext.Update(const AData: string);
begin
  Update(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

procedure THashContext.Update(AStream: TStream);
var
  Buffer: TBytes;
  BytesRead: Integer;
begin
  SetLength(Buffer, 8192);
  repeat
    BytesRead := AStream.Read(Buffer[0], 8192);
    if BytesRead > 0 then
      Update(Copy(Buffer, 0, BytesRead));
  until BytesRead = 0;
end;

// ========================================================================
// MD5 实现
// ========================================================================

const
  MD5_S: array[0..63] of Byte = (
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
  );

  MD5_K: array[0..63] of UInt32 = (
    $d76aa478, $e8c7b756, $242070db, $c1bdceee,
    $f57c0faf, $4787c62a, $a8304613, $fd469501,
    $698098d8, $8b44f7af, $ffff5bb1, $895cd7be,
    $6b901122, $fd987193, $a679438e, $49b40821,
    $f61e2562, $c040b340, $265e5a51, $e9b6c7aa,
    $d62f105d, $02441453, $d8a1e681, $e7d3fbc8,
    $21e1cde6, $c33707d6, $f4d50d87, $455a14ed,
    $a9e3e905, $fcefa3f8, $676f02d9, $8d2a4c8a,
    $fffa3942, $8771f681, $6d9d6122, $fde5380c,
    $a4beea44, $4bdecfa9, $f6bb4b60, $bebfbc70,
    $289b7ec6, $eaa127fa, $d4ef3085, $04881d05,
    $d9d4d039, $e6db99e5, $1fa27cf8, $c4ac5665,
    $f4292244, $432aff97, $ab9423a7, $fc93a039,
    $655b59c3, $8f0ccc92, $ffeff47d, $85845dd1,
    $6fa87e4f, $fe2ce6e0, $a3014314, $4e0811a1,
    $f7537e82, $bd3af235, $2ad7d2bb, $eb86d391
  );

function RotateLeft32(X: UInt32; N: Integer): UInt32; inline;
begin
  Result := (X shl N) or (X shr (32 - N));
end;

constructor TMD5Context.Create;
begin
  inherited Create;
  Reset;
end;

procedure TMD5Context.Reset;
begin
  FState[0] := $67452301;
  FState[1] := $efcdab89;
  FState[2] := $98badcfe;
  FState[3] := $10325476;
  FCount[0] := 0;
  FCount[1] := 0;
  FillChar(FBuffer[0], SizeOf(FBuffer), 0);
end;

procedure TMD5Context.Transform(const ABlock: array of Byte);
var
  A, B, C, D, F, G, Temp: UInt32;
  M: array[0..15] of UInt32;
  I: Integer;
begin
  // 将块转换为 16 个 32 位字 (小端)
  for I := 0 to 15 do
    M[I] := UInt32(ABlock[I * 4]) or
            (UInt32(ABlock[I * 4 + 1]) shl 8) or
            (UInt32(ABlock[I * 4 + 2]) shl 16) or
            (UInt32(ABlock[I * 4 + 3]) shl 24);

  A := FState[0];
  B := FState[1];
  C := FState[2];
  D := FState[3];

  for I := 0 to 63 do
  begin
    if I < 16 then
    begin
      F := (B and C) or ((not B) and D);
      G := I;
    end
    else if I < 32 then
    begin
      F := (D and B) or ((not D) and C);
      G := (5 * I + 1) mod 16;
    end
    else if I < 48 then
    begin
      F := B xor C xor D;
      G := (3 * I + 5) mod 16;
    end
    else
    begin
      F := C xor (B or (not D));
      G := (7 * I) mod 16;
    end;

    Temp := D;
    D := C;
    C := B;
    B := B + RotateLeft32(A + F + MD5_K[I] + M[G], MD5_S[I]);
    A := Temp;
  end;

  Inc(FState[0], A);
  Inc(FState[1], B);
  Inc(FState[2], C);
  Inc(FState[3], D);
end;

procedure TMD5Context.Update(const AData: TBytes);
var
  I, Index, PartLen: Integer;
  InputLen: UInt32;
begin
  InputLen := Length(AData);
  Index := (FCount[0] shr 3) and $3F;

  Inc(FCount[0], InputLen shl 3);
  if FCount[0] < (InputLen shl 3) then
    Inc(FCount[1]);
  Inc(FCount[1], InputLen shr 29);

  PartLen := 64 - Index;
  I := 0;

  if InputLen >= PartLen then
  begin
    Move(AData[0], FBuffer[Index], PartLen);
    Transform(FBuffer);

    I := PartLen;
    while I + 63 < InputLen do
    begin
      Transform(AData[I]);
      Inc(I, 64);
    end;
    Index := 0;
  end;

  if I < Integer(InputLen) then
    Move(AData[I], FBuffer[Index], InputLen - I);
end;

function TMD5Context.Final: TBytes;
var
  Bits: array[0..7] of Byte;
  Index, PadLen: Integer;
  Padding: TBytes;
  I: Integer;
begin
  // 保存位长度
  for I := 0 to 3 do
  begin
    Bits[I] := Byte(FCount[0] shr (I * 8));
    Bits[I + 4] := Byte(FCount[1] shr (I * 8));
  end;

  // 填充
  Index := (FCount[0] shr 3) and $3F;
  if Index < 56 then
    PadLen := 56 - Index
  else
    PadLen := 120 - Index;

  SetLength(Padding, PadLen);
  Padding[0] := $80;
  Update(Padding);

  // 添加长度
  SetLength(Padding, 8);
  Move(Bits[0], Padding[0], 8);
  Update(Padding);

  // 输出
  SetLength(Result, 16);
  for I := 0 to 3 do
  begin
    Result[I * 4] := Byte(FState[I]);
    Result[I * 4 + 1] := Byte(FState[I] shr 8);
    Result[I * 4 + 2] := Byte(FState[I] shr 16);
    Result[I * 4 + 3] := Byte(FState[I] shr 24);
  end;

  Reset;
end;

class function TMD5Context.DigestSize: Integer;
begin
  Result := 16;
end;

class function TMD5Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TMD5Context.AlgorithmName: string;
begin
  Result := 'MD5';
end;

// ========================================================================
// SHA-1 实现
// ========================================================================

constructor TSHA1Context.Create;
begin
  inherited Create;
  Reset;
end;

procedure TSHA1Context.Reset;
begin
  FState[0] := $67452301;
  FState[1] := $EFCDAB89;
  FState[2] := $98BADCFE;
  FState[3] := $10325476;
  FState[4] := $C3D2E1F0;
  FCount := 0;
  FBufferIndex := 0;
  FillChar(FBuffer[0], SizeOf(FBuffer), 0);
end;

procedure TSHA1Context.Transform(const ABlock: array of Byte);
var
  W: array[0..79] of UInt32;
  A, B, C, D, E, F, K, Temp: UInt32;
  I: Integer;
begin
  // 准备消息调度
  for I := 0 to 15 do
    W[I] := (UInt32(ABlock[I * 4]) shl 24) or
            (UInt32(ABlock[I * 4 + 1]) shl 16) or
            (UInt32(ABlock[I * 4 + 2]) shl 8) or
            UInt32(ABlock[I * 4 + 3]);

  for I := 16 to 79 do
    W[I] := RotateLeft32(W[I-3] xor W[I-8] xor W[I-14] xor W[I-16], 1);

  A := FState[0];
  B := FState[1];
  C := FState[2];
  D := FState[3];
  E := FState[4];

  for I := 0 to 79 do
  begin
    if I < 20 then
    begin
      F := (B and C) or ((not B) and D);
      K := $5A827999;
    end
    else if I < 40 then
    begin
      F := B xor C xor D;
      K := $6ED9EBA1;
    end
    else if I < 60 then
    begin
      F := (B and C) or (B and D) or (C and D);
      K := $8F1BBCDC;
    end
    else
    begin
      F := B xor C xor D;
      K := $CA62C1D6;
    end;

    Temp := RotateLeft32(A, 5) + F + E + K + W[I];
    E := D;
    D := C;
    C := RotateLeft32(B, 30);
    B := A;
    A := Temp;
  end;

  Inc(FState[0], A);
  Inc(FState[1], B);
  Inc(FState[2], C);
  Inc(FState[3], D);
  Inc(FState[4], E);
end;

procedure TSHA1Context.Update(const AData: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(AData) do
  begin
    FBuffer[FBufferIndex] := AData[I];
    Inc(FBufferIndex);
    Inc(FCount);

    if FBufferIndex = 64 then
    begin
      Transform(FBuffer);
      FBufferIndex := 0;
    end;
  end;
end;

function TSHA1Context.Final: TBytes;
var
  BitLen: UInt64;
  Padding: TBytes;
  PadLen: Integer;
  I: Integer;
begin
  BitLen := FCount * 8;

  // 填充
  if FBufferIndex < 56 then
    PadLen := 56 - FBufferIndex
  else
    PadLen := 120 - FBufferIndex;

  SetLength(Padding, PadLen + 8);
  FillChar(Padding[0], Length(Padding), 0);
  Padding[0] := $80;

  // 添加长度 (大端)
  Padding[PadLen] := Byte(BitLen shr 56);
  Padding[PadLen + 1] := Byte(BitLen shr 48);
  Padding[PadLen + 2] := Byte(BitLen shr 40);
  Padding[PadLen + 3] := Byte(BitLen shr 32);
  Padding[PadLen + 4] := Byte(BitLen shr 24);
  Padding[PadLen + 5] := Byte(BitLen shr 16);
  Padding[PadLen + 6] := Byte(BitLen shr 8);
  Padding[PadLen + 7] := Byte(BitLen);

  Update(Padding);

  // 输出 (大端)
  SetLength(Result, 20);
  for I := 0 to 4 do
  begin
    Result[I * 4] := Byte(FState[I] shr 24);
    Result[I * 4 + 1] := Byte(FState[I] shr 16);
    Result[I * 4 + 2] := Byte(FState[I] shr 8);
    Result[I * 4 + 3] := Byte(FState[I]);
  end;

  Reset;
end;

class function TSHA1Context.DigestSize: Integer;
begin
  Result := 20;
end;

class function TSHA1Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TSHA1Context.AlgorithmName: string;
begin
  Result := 'SHA-1';
end;

// ========================================================================
// SHA-256 实现
// ========================================================================

const
  SHA256_K: array[0..63] of UInt32 = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
    $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3,
    $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
    $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7,
    $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
    $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
    $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
    $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208,
    $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

function RotateRight32(X: UInt32; N: Integer): UInt32; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

constructor TSHA256Context.Create;
begin
  inherited Create;
  Reset;
end;

procedure TSHA256Context.Reset;
begin
  FState[0] := $6a09e667;
  FState[1] := $bb67ae85;
  FState[2] := $3c6ef372;
  FState[3] := $a54ff53a;
  FState[4] := $510e527f;
  FState[5] := $9b05688c;
  FState[6] := $1f83d9ab;
  FState[7] := $5be0cd19;
  FCount := 0;
  FBufferIndex := 0;
  FillChar(FBuffer[0], SizeOf(FBuffer), 0);
end;

procedure TSHA256Context.Transform(const ABlock: array of Byte);
var
  W: array[0..63] of UInt32;
  A, B, C, D, E, F, G, H: UInt32;
  S0, S1, Ch, Maj, Temp1, Temp2: UInt32;
  I: Integer;
begin
  // 准备消息调度
  for I := 0 to 15 do
    W[I] := (UInt32(ABlock[I * 4]) shl 24) or
            (UInt32(ABlock[I * 4 + 1]) shl 16) or
            (UInt32(ABlock[I * 4 + 2]) shl 8) or
            UInt32(ABlock[I * 4 + 3]);

  for I := 16 to 63 do
  begin
    S0 := RotateRight32(W[I-15], 7) xor RotateRight32(W[I-15], 18) xor (W[I-15] shr 3);
    S1 := RotateRight32(W[I-2], 17) xor RotateRight32(W[I-2], 19) xor (W[I-2] shr 10);
    W[I] := W[I-16] + S0 + W[I-7] + S1;
  end;

  A := FState[0];
  B := FState[1];
  C := FState[2];
  D := FState[3];
  E := FState[4];
  F := FState[5];
  G := FState[6];
  H := FState[7];

  for I := 0 to 63 do
  begin
    S1 := RotateRight32(E, 6) xor RotateRight32(E, 11) xor RotateRight32(E, 25);
    Ch := (E and F) xor ((not E) and G);
    Temp1 := H + S1 + Ch + SHA256_K[I] + W[I];
    S0 := RotateRight32(A, 2) xor RotateRight32(A, 13) xor RotateRight32(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    Temp2 := S0 + Maj;

    H := G;
    G := F;
    F := E;
    E := D + Temp1;
    D := C;
    C := B;
    B := A;
    A := Temp1 + Temp2;
  end;

  Inc(FState[0], A);
  Inc(FState[1], B);
  Inc(FState[2], C);
  Inc(FState[3], D);
  Inc(FState[4], E);
  Inc(FState[5], F);
  Inc(FState[6], G);
  Inc(FState[7], H);
end;

procedure TSHA256Context.Update(const AData: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(AData) do
  begin
    FBuffer[FBufferIndex] := AData[I];
    Inc(FBufferIndex);
    Inc(FCount);

    if FBufferIndex = 64 then
    begin
      Transform(FBuffer);
      FBufferIndex := 0;
    end;
  end;
end;

function TSHA256Context.Final: TBytes;
var
  BitLen: UInt64;
  Padding: TBytes;
  PadLen: Integer;
  I: Integer;
begin
  BitLen := FCount * 8;

  // 填充
  if FBufferIndex < 56 then
    PadLen := 56 - FBufferIndex
  else
    PadLen := 120 - FBufferIndex;

  SetLength(Padding, PadLen + 8);
  FillChar(Padding[0], Length(Padding), 0);
  Padding[0] := $80;

  // 添加长度 (大端)
  Padding[PadLen] := Byte(BitLen shr 56);
  Padding[PadLen + 1] := Byte(BitLen shr 48);
  Padding[PadLen + 2] := Byte(BitLen shr 40);
  Padding[PadLen + 3] := Byte(BitLen shr 32);
  Padding[PadLen + 4] := Byte(BitLen shr 24);
  Padding[PadLen + 5] := Byte(BitLen shr 16);
  Padding[PadLen + 6] := Byte(BitLen shr 8);
  Padding[PadLen + 7] := Byte(BitLen);

  Update(Padding);

  // 输出 (大端)
  SetLength(Result, 32);
  for I := 0 to 7 do
  begin
    Result[I * 4] := Byte(FState[I] shr 24);
    Result[I * 4 + 1] := Byte(FState[I] shr 16);
    Result[I * 4 + 2] := Byte(FState[I] shr 8);
    Result[I * 4 + 3] := Byte(FState[I]);
  end;

  Reset;
end;

class function TSHA256Context.DigestSize: Integer;
begin
  Result := 32;
end;

class function TSHA256Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TSHA256Context.AlgorithmName: string;
begin
  Result := 'SHA-256';
end;

// ========================================================================
// SHA-512 实现
// ========================================================================

const
  SHA512_K: array[0..79] of UInt64 = (
    $428a2f98d728ae22, $7137449123ef65cd, $b5c0fbcfec4d3b2f, $e9b5dba58189dbbc,
    $3956c25bf348b538, $59f111f1b605d019, $923f82a4af194f9b, $ab1c5ed5da6d8118,
    $d807aa98a3030242, $12835b0145706fbe, $243185be4ee4b28c, $550c7dc3d5ffb4e2,
    $72be5d74f27b896f, $80deb1fe3b1696b1, $9bdc06a725c71235, $c19bf174cf692694,
    $e49b69c19ef14ad2, $efbe4786384f25e3, $0fc19dc68b8cd5b5, $240ca1cc77ac9c65,
    $2de92c6f592b0275, $4a7484aa6ea6e483, $5cb0a9dcbd41fbd4, $76f988da831153b5,
    $983e5152ee66dfab, $a831c66d2db43210, $b00327c898fb213f, $bf597fc7beef0ee4,
    $c6e00bf33da88fc2, $d5a79147930aa725, $06ca6351e003826f, $142929670a0e6e70,
    $27b70a8546d22ffc, $2e1b21385c26c926, $4d2c6dfc5ac42aed, $53380d139d95b3df,
    $650a73548baf63de, $766a0abb3c77b2a8, $81c2c92e47edaee6, $92722c851482353b,
    $a2bfe8a14cf10364, $a81a664bbc423001, $c24b8b70d0f89791, $c76c51a30654be30,
    $d192e819d6ef5218, $d69906245565a910, $f40e35855771202a, $106aa07032bbd1b8,
    $19a4c116b8d2d0c8, $1e376c085141ab53, $2748774cdf8eeb99, $34b0bcb5e19b48a8,
    $391c0cb3c5c95a63, $4ed8aa4ae3418acb, $5b9cca4f7763e373, $682e6ff3d6b2b8a3,
    $748f82ee5defb2fc, $78a5636f43172f60, $84c87814a1f0ab72, $8cc702081a6439ec,
    $90befffa23631e28, $a4506cebde82bde9, $bef9a3f7b2c67915, $c67178f2e372532b,
    $ca273eceea26619c, $d186b8c721c0c207, $eada7dd6cde0eb1e, $f57d4f7fee6ed178,
    $06f067aa72176fba, $0a637dc5a2c898a6, $113f9804bef90dae, $1b710b35131c471b,
    $28db77f523047d84, $32caab7b40c72493, $3c9ebe0a15c9bebc, $431d67c49c100d4c,
    $4cc5d4becb3e42b6, $597f299cfc657e2a, $5fcb6fab3ad6faec, $6c44198c4a475817
  );

function RotateRight64(X: UInt64; N: Integer): UInt64; inline;
begin
  Result := (X shr N) or (X shl (64 - N));
end;

constructor TSHA512Context.Create;
begin
  Create(False);
end;

constructor TSHA512Context.Create(AIs384: Boolean);
begin
  inherited Create;
  FIs384 := AIs384;
  Reset;
end;

procedure TSHA512Context.Reset;
begin
  if FIs384 then
  begin
    // SHA-384 初始值
    FState[0] := $cbbb9d5dc1059ed8;
    FState[1] := $629a292a367cd507;
    FState[2] := $9159015a3070dd17;
    FState[3] := $152fecd8f70e5939;
    FState[4] := $67332667ffc00b31;
    FState[5] := $8eb44a8768581511;
    FState[6] := $db0c2e0d64f98fa7;
    FState[7] := $47b5481dbefa4fa4;
  end
  else
  begin
    // SHA-512 初始值
    FState[0] := $6a09e667f3bcc908;
    FState[1] := $bb67ae8584caa73b;
    FState[2] := $3c6ef372fe94f82b;
    FState[3] := $a54ff53a5f1d36f1;
    FState[4] := $510e527fade682d1;
    FState[5] := $9b05688c2b3e6c1f;
    FState[6] := $1f83d9abfb41bd6b;
    FState[7] := $5be0cd19137e2179;
  end;

  FCount[0] := 0;
  FCount[1] := 0;
  FBufferIndex := 0;
  FillChar(FBuffer[0], SizeOf(FBuffer), 0);
end;

procedure TSHA512Context.Transform(const ABlock: array of Byte);
var
  W: array[0..79] of UInt64;
  A, B, C, D, E, F, G, H: UInt64;
  S0, S1, Ch, Maj, Temp1, Temp2: UInt64;
  I: Integer;
begin
  // 准备消息调度
  for I := 0 to 15 do
    W[I] := (UInt64(ABlock[I * 8]) shl 56) or
            (UInt64(ABlock[I * 8 + 1]) shl 48) or
            (UInt64(ABlock[I * 8 + 2]) shl 40) or
            (UInt64(ABlock[I * 8 + 3]) shl 32) or
            (UInt64(ABlock[I * 8 + 4]) shl 24) or
            (UInt64(ABlock[I * 8 + 5]) shl 16) or
            (UInt64(ABlock[I * 8 + 6]) shl 8) or
            UInt64(ABlock[I * 8 + 7]);

  for I := 16 to 79 do
  begin
    S0 := RotateRight64(W[I-15], 1) xor RotateRight64(W[I-15], 8) xor (W[I-15] shr 7);
    S1 := RotateRight64(W[I-2], 19) xor RotateRight64(W[I-2], 61) xor (W[I-2] shr 6);
    W[I] := W[I-16] + S0 + W[I-7] + S1;
  end;

  A := FState[0];
  B := FState[1];
  C := FState[2];
  D := FState[3];
  E := FState[4];
  F := FState[5];
  G := FState[6];
  H := FState[7];

  for I := 0 to 79 do
  begin
    S1 := RotateRight64(E, 14) xor RotateRight64(E, 18) xor RotateRight64(E, 41);
    Ch := (E and F) xor ((not E) and G);
    Temp1 := H + S1 + Ch + SHA512_K[I] + W[I];
    S0 := RotateRight64(A, 28) xor RotateRight64(A, 34) xor RotateRight64(A, 39);
    Maj := (A and B) xor (A and C) xor (B and C);
    Temp2 := S0 + Maj;

    H := G;
    G := F;
    F := E;
    E := D + Temp1;
    D := C;
    C := B;
    B := A;
    A := Temp1 + Temp2;
  end;

  Inc(FState[0], A);
  Inc(FState[1], B);
  Inc(FState[2], C);
  Inc(FState[3], D);
  Inc(FState[4], E);
  Inc(FState[5], F);
  Inc(FState[6], G);
  Inc(FState[7], H);
end;

procedure TSHA512Context.Update(const AData: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(AData) do
  begin
    FBuffer[FBufferIndex] := AData[I];
    Inc(FBufferIndex);
    Inc(FCount[0]);
    if FCount[0] = 0 then
      Inc(FCount[1]);

    if FBufferIndex = 128 then
    begin
      Transform(FBuffer);
      FBufferIndex := 0;
    end;
  end;
end;

function TSHA512Context.Final: TBytes;
var
  BitLen: array[0..1] of UInt64;
  Padding: TBytes;
  PadLen: Integer;
  I: Integer;
  OutputLen: Integer;
begin
  // 计算位长度
  BitLen[1] := FCount[0] shl 3;
  BitLen[0] := (FCount[1] shl 3) or (FCount[0] shr 61);

  // 填充
  if FBufferIndex < 112 then
    PadLen := 112 - FBufferIndex
  else
    PadLen := 240 - FBufferIndex;

  SetLength(Padding, PadLen + 16);
  FillChar(Padding[0], Length(Padding), 0);
  Padding[0] := $80;

  // 添加长度 (大端, 128位)
  for I := 0 to 7 do
  begin
    Padding[PadLen + I] := Byte(BitLen[0] shr ((7 - I) * 8));
    Padding[PadLen + 8 + I] := Byte(BitLen[1] shr ((7 - I) * 8));
  end;

  Update(Padding);

  // 输出 (大端)
  if FIs384 then
    OutputLen := 48
  else
    OutputLen := 64;

  SetLength(Result, OutputLen);
  for I := 0 to (OutputLen div 8) - 1 do
  begin
    Result[I * 8] := Byte(FState[I] shr 56);
    Result[I * 8 + 1] := Byte(FState[I] shr 48);
    Result[I * 8 + 2] := Byte(FState[I] shr 40);
    Result[I * 8 + 3] := Byte(FState[I] shr 32);
    Result[I * 8 + 4] := Byte(FState[I] shr 24);
    Result[I * 8 + 5] := Byte(FState[I] shr 16);
    Result[I * 8 + 6] := Byte(FState[I] shr 8);
    Result[I * 8 + 7] := Byte(FState[I]);
  end;

  Reset;
end;

class function TSHA512Context.DigestSize: Integer;
begin
  Result := 64;
end;

class function TSHA512Context.BlockSize: Integer;
begin
  Result := 128;
end;

class function TSHA512Context.AlgorithmName: string;
begin
  Result := 'SHA-512';
end;

// ========================================================================
// SHA-384 实现
// ========================================================================

constructor TSHA384Context.Create;
begin
  inherited Create(True);
end;

class function TSHA384Context.DigestSize: Integer;
begin
  Result := 48;
end;

class function TSHA384Context.AlgorithmName: string;
begin
  Result := 'SHA-384';
end;

// ========================================================================
// 便捷函数实现
// ========================================================================

function MD5(const AData: TBytes): TBytes;
var
  Ctx: TMD5Context;
begin
  Ctx := TMD5Context.Create;
  try
    Ctx.Update(AData);
    Result := Ctx.Final;
  finally
    Ctx.Free;
  end;
end;

function MD5(const AData: string): TBytes;
begin
  Result := MD5(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

function SHA1(const AData: TBytes): TBytes;
var
  Ctx: TSHA1Context;
begin
  Ctx := TSHA1Context.Create;
  try
    Ctx.Update(AData);
    Result := Ctx.Final;
  finally
    Ctx.Free;
  end;
end;

function SHA1(const AData: string): TBytes;
begin
  Result := SHA1(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

function SHA256(const AData: TBytes): TBytes;
var
  LH: IHasher;
begin
  LH := nextpas.core.hash.sha256.NewSHA256;
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  Result := LH.SumBytes;
end;

function SHA256(const AData: string): TBytes;
begin
  Result := SHA256(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

function SHA384(const AData: TBytes): TBytes;
var
  Ctx: TSHA384Context;
begin
  Ctx := TSHA384Context.Create;
  try
    Ctx.Update(AData);
    Result := Ctx.Final;
  finally
    Ctx.Free;
  end;
end;

function SHA384(const AData: string): TBytes;
begin
  Result := SHA384(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

function SHA512(const AData: TBytes): TBytes;
var
  Ctx: TSHA512Context;
begin
  Ctx := TSHA512Context.Create;
  try
    Ctx.Update(AData);
    Result := Ctx.Final;
  finally
    Ctx.Free;
  end;
end;

function SHA512(const AData: string): TBytes;
begin
  Result := SHA512(TEncoding.UTF8.GetBytes(UnicodeString(AData)));
end;

function HashToHex(const AHash: TBytes): string;
const
  HEX: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  if Length(AHash) = 0 then begin Result := ''; Exit; end;
  SetLength(Result, Length(AHash) * 2);
  for I := 0 to High(AHash) do
  begin
    Result[I * 2 + 1] := HEX[AHash[I] shr 4];
    Result[I * 2 + 2] := HEX[AHash[I] and $0F];
  end;
end;

function CreateHashContext(AAlgorithm: THashAlgorithm): THashContext;
begin
  case AAlgorithm of
    haMD5:    Result := TMD5Context.Create;
    haSHA1:   Result := TSHA1Context.Create;
    haSHA256: Result := TSHA256Context.Create;
    haSHA384: Result := TSHA384Context.Create;
    haSHA512: Result := TSHA512Context.Create;
  else
    Result := nil;
  end;
end;

function GetHashDigestSize(AAlgorithm: THashAlgorithm): Integer;
begin
  case AAlgorithm of
    haMD5:    Result := 16;
    haSHA1:   Result := 20;
    haSHA256: Result := 32;
    haSHA384: Result := 48;
    haSHA512: Result := 64;
  else
    Result := 0;
  end;
end;

function GetHashBlockSize(AAlgorithm: THashAlgorithm): Integer;
begin
  case AAlgorithm of
    haMD5:    Result := 64;
    haSHA1:   Result := 64;
    haSHA256: Result := 64;
    haSHA384: Result := 128;
    haSHA512: Result := 128;
  else
    Result := 0;
  end;
end;

function GetHashAlgorithmName(AAlgorithm: THashAlgorithm): string;
begin
  case AAlgorithm of
    haMD5:    Result := 'MD5';
    haSHA1:   Result := 'SHA-1';
    haSHA256: Result := 'SHA-256';
    haSHA384: Result := 'SHA-384';
    haSHA512: Result := 'SHA-512';
  else
    Result := 'Unknown';
  end;
end;

end.
