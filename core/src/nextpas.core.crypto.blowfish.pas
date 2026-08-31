unit nextpas.core.crypto.blowfish;

{** nextpas.core.crypto - Blowfish 分组密码（bcrypt_pbkdf 底座）。
 *
 * 语义对齐 OpenBSD lib/libc/crypt/blowfish.c（bcrypt 所用变体）：
 *   InitState     加载 pi 常数表（常量程序化提取自权威源码，见 .inc）
 *   Stream2Word   字节流按循环取 4 字节组大端字
 *   Expand0State  标准链式重键（P/S 全部由密文回填）
 *   ExpandState   data 流 XOR 进 P 后，key 流逐对 XOR 贯穿全部回填
 *   EncryptBlock  标准 16 轮 Feistel（P[0..17] 依序消费）
 * 全部字序大端；供 nextpas.core.crypto.bcrypt_pbkdf 使用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base;

type
  TBlowfishState = record
    P: array[0..17] of UInt32;
    S: array[0..3] of array[0..255] of UInt32;
  end;

{ 从 pi 常数表初始化 }
procedure BlowfishInitState(out AState: TBlowfishState);

{ 数据流循环取 4 字节为大端字（ACur 为游标，跨调用保持推进）}
function BlowfishStream2Word(const AData: TBytes; ADataLen: Integer;
  var ACur: Integer): UInt32;

{ 单块加密（XL/XR 为两个 32 位半块）}
procedure BlowfishEncryptBlock(var AState: TBlowfishState;
  var AXl, AXr: UInt32);

{ 链式重键（OpenBSD Blowfish_expand0state）：key XOR 进 P，
  P 与 S 全部由连续加密的密文回填 }
procedure BlowfishExpand0State(var AState: TBlowfishState;
  const AKey: TBytes);

{ 双流重键（OpenBSD Blowfish_expandstate）：data XOR 进 P 后，
  key 流逐对 XOR 贯穿 P/S 的整轮回填 }
procedure BlowfishExpandState(var AState: TBlowfishState;
  const AData, AKey: TBytes);

implementation

{$I nextpas.core.crypto.blowfish.consts.inc}

procedure BlowfishInitState(out AState: TBlowfishState);
var
  I: Integer;
begin
  for I := 0 to 17 do
    AState.P[I] := BF_P_INIT[I];
  for I := 0 to 255 do
  begin
    AState.S[0][I] := BF_S0_INIT[I];
    AState.S[1][I] := BF_S1_INIT[I];
    AState.S[2][I] := BF_S2_INIT[I];
    AState.S[3][I] := BF_S3_INIT[I];
  end;
end;

function BlowfishStream2Word(const AData: TBytes; ADataLen: Integer;
  var ACur: Integer): UInt32;
var
  I, J: Integer;
begin
  Result := 0;
  J := ACur;
  for I := 0 to 3 do
  begin
    if J >= ADataLen then
      J := 0;
    Result := (Result shl 8) or AData[J];
    Inc(J);
  end;
  ACur := J;
end;

function BlfF(const AState: TBlowfishState; AX: UInt32): UInt32;
begin
  Result := ((AState.S[0][AX shr 24] + AState.S[1][(AX shr 16) and $FF])
    xor AState.S[2][(AX shr 8) and $FF]) + AState.S[3][AX and $FF];
end;

procedure BlowfishEncryptBlock(var AState: TBlowfishState;
  var AXl, AXr: UInt32);
var
  I: Integer;
  LTmp: UInt32;
begin
  { 教科书规范形：16 轮 Feistel + 末轮撤销交换，白化为 XR^P[16]、XL^P[17]
    （展开式变体曾因白化归属错位产生错误密文，勿再"优化"）}
  for I := 0 to 15 do
  begin
    AXl := AXl xor AState.P[I];
    AXr := AXr xor BlfF(AState, AXl);
    LTmp := AXl;
    AXl := AXr;
    AXr := LTmp;
  end;
  LTmp := AXl;
  AXl := AXr;
  AXr := LTmp;
  AXr := AXr xor AState.P[16];
  AXl := AXl xor AState.P[17];
end;

procedure BlowfishExpand0State(var AState: TBlowfishState;
  const AKey: TBytes);
var
  I, J, K, LLen: Integer;
  LXl, LXr: UInt32;
begin
  LLen := Length(AKey);
  J := 0;
  for I := 0 to 17 do
    AState.P[I] := AState.P[I] xor BlowfishStream2Word(AKey, LLen, J);

  LXl := 0;
  LXr := 0;
  I := 0;
  while I < 18 do
  begin
    BlowfishEncryptBlock(AState, LXl, LXr);
    AState.P[I] := LXl;
    AState.P[I + 1] := LXr;
    Inc(I, 2);
  end;

  for I := 0 to 3 do
  begin
    K := 0;
    while K < 256 do
    begin
      BlowfishEncryptBlock(AState, LXl, LXr);
      AState.S[I][K] := LXl;
      AState.S[I][K + 1] := LXr;
      Inc(K, 2);
    end;
  end;
end;

{ 双流重键（OpenBSD Blowfish_expandstate）。注意其反直觉的流归属：
  初始阶段 XOR 进 P 的是 *key* 流；链式回填期间逐对 XOR 的是 *data* 流。
  （两者写反时核心块测仍全绿，只在 bcrypt 黄金向量上暴露）}
procedure BlowfishExpandState(var AState: TBlowfishState;
  const AData, AKey: TBytes);
var
  I, J, K, LDataLen, LKeyLen: Integer;
  LXl, LXr: UInt32;
begin
  LDataLen := Length(AData);
  LKeyLen := Length(AKey);

  J := 0;
  for I := 0 to 17 do
    AState.P[I] := AState.P[I] xor BlowfishStream2Word(AKey, LKeyLen, J);

  J := 0;
  LXl := 0;
  LXr := 0;
  I := 0;
  while I < 18 do
  begin
    LXl := LXl xor BlowfishStream2Word(AData, LDataLen, J);
    LXr := LXr xor BlowfishStream2Word(AData, LDataLen, J);
    BlowfishEncryptBlock(AState, LXl, LXr);
    AState.P[I] := LXl;
    AState.P[I + 1] := LXr;
    Inc(I, 2);
  end;

  for I := 0 to 3 do
  begin
    K := 0;
    while K < 256 do
    begin
      LXl := LXl xor BlowfishStream2Word(AData, LDataLen, J);
      LXr := LXr xor BlowfishStream2Word(AData, LDataLen, J);
      BlowfishEncryptBlock(AState, LXl, LXr);
      AState.S[I][K] := LXl;
      AState.S[I][K + 1] := LXr;
      Inc(K, 2);
    end;
  end;
end;

end.
