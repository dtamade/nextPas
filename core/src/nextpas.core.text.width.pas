unit nextpas.core.text.width;

{**
 * @desc 终端显示宽度计算（East Asian Width + grapheme cluster）。
 *
 * 依据 Unicode Standard Annex #11 (East Asian Width) 与组合标记
 * (General Category Mn/Me) 的代表性区间，计算单个码点在等宽终端中占用的
 * 列数：
 *
 *   - 控制字符（C0/C1）           -> 0
 *   - 组合标记 / 零宽字符         -> 0
 *   - East Asian Wide / Fullwidth -> 2
 *   - 其余                        -> 1
 *
 * CodepointWidth 只做单码点宽度；StringDisplayWidth 在非 ASCII 路径通过
 * GraphemeNext 按 grapheme cluster 计宽，确保 ZWJ emoji、keycap、变体选择符
 * 和组合标记等多码点簇按终端单个字形推进。组合标记表覆盖常用脚本
 *（拉丁/西里尔/希伯来/阿拉伯/天城文/孟加拉/泰/老挝/谚文连接等）的代表性
 * 区间，非完整 Unicode Mn/Me 全集。
 *
 * @note 热路径：StringDisplayWidth 对纯 ASCII 输入走 SIMD/标量快路径，
 *       按 CodepointWidth 的控制字符契约计宽；含多字节序列时回退到
 *       grapheme cluster 解码。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.width.codepoint;

{**
 * @desc 返回单个 Unicode 码点的终端列宽。
 * 委托给 nextpas.core.text.width.codepoint。
 *}
function CodepointWidth(const ACodePoint: UInt32): Byte; inline;

{**
 * @desc 计算 UTF-8 字节序列的总显示宽度。
 * @params
 *   AData  UTF-8 字节起始指针
 *   ALen   字节长度
 * @return 总列宽（非 ASCII 路径按 grapheme cluster 计宽）
 * @note 纯 ASCII 输入走 SIMD 快路径；非法字节按宽度 1 计。
 *}
function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;

{**
 * @desc 计算 AnsiString（UTF-8）的总显示宽度。便利重载。
 *}
function StringDisplayWidth(const AStr: AnsiString): SizeUInt; overload; inline;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.grapheme,
  nextpas.core.simd.cpuinfo;

{$ifdef CPUX86_64}
var
  GHasAVX2: Boolean;
{$endif}

function GraphemeWidthFrom(const AData: PByte; const ALen, AStart: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LGR: TGraphemeResult;
begin
  Result := 0;
  LPos := AStart;
  while LPos < ALen do
  begin
    LGR := GraphemeNext(@AData[LPos], ALen - LPos);
    Inc(Result, LGR.Width);
    Inc(LPos, LGR.ByteLen);
  end;
end;

function GraphemeFallbackStart(AAsciiPrefixLen: SizeUInt): SizeUInt; inline;
begin
  if AAsciiPrefixLen = 0 then
    Result := 0
  else
    Result := AAsciiPrefixLen - 1;
end;

function IsAsciiControl(const AByte: Byte): Boolean; inline;
begin
  Result := (AByte < 32) or (AByte = $7F);
end;

function AsciiDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
begin
  if ALen = 0 then
    Exit(0);
  if AData = nil then
    Exit(0);

  Result := ALen;
  for LPos := 0 to ALen - 1 do
    if IsAsciiControl(AData[LPos]) then
      Dec(Result);
end;

function CodepointWidth(const ACodePoint: UInt32): Byte;
begin
  Result := nextpas.core.text.width.codepoint.CodepointWidth(ACodePoint);
end;

function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  {$ifdef CPUX86_64}
  LMask: UInt32;
  LP: PByte;
  {$endif}
begin
  if ALen = 0 then
    Exit(0);
  if AData = nil then
    Exit(0);

  {$ifdef CPUX86_64}
  LPos := 0;

  if (ALen >= 128) and GHasAVX2 then
  begin
    while LPos + 32 <= ALen do
    begin
      LP := @AData[LPos];
      {$asmmode intel}
      asm
        mov rax, [LP]
        vmovdqu ymm0, [rax]
        vpmovmskb eax, ymm0
        mov [LMask], eax
      end;
      {$asmmode default}
      if LMask = 0 then
        Inc(LPos, 32)
      else
        Break;
    end;
    asm vzeroupper end;
  end;

  { SSE2 路径：处理 AVX2 剩余或无 AVX2 时的主循环 }
  while LPos + 16 <= ALen do
  begin
    LP := @AData[LPos];
    {$asmmode intel}
    asm
      mov rax, [LP]
      movdqu xmm0, [rax]
      pmovmskb eax, xmm0
      mov [LMask], eax
    end;
    {$asmmode default}
    if LMask = 0 then
      Inc(LPos, 16)
    else
      Break;
  end;

  { 标量扫描尾部 }
  while (LPos < ALen) and (AData[LPos] < $80) do
    Inc(LPos);
  if LPos = ALen then
    Exit(AsciiDisplayWidth(AData, ALen));

  LPos := GraphemeFallbackStart(LPos);
  Result := AsciiDisplayWidth(AData, LPos) + GraphemeWidthFrom(AData, ALen, LPos);
  {$else}
  { 非 x86_64 标量路径 }
  LPos := 0;
  while (LPos < ALen) and (AData[LPos] < $80) do
    Inc(LPos);
  if LPos = ALen then
    Exit(AsciiDisplayWidth(AData, ALen));

  LPos := GraphemeFallbackStart(LPos);
  Result := AsciiDisplayWidth(AData, LPos) + GraphemeWidthFrom(AData, ALen, LPos);
  {$endif}
end;

function StringDisplayWidth(const AStr: AnsiString): SizeUInt;
begin
  if Length(AStr) = 0 then
    Exit(0);
  Result := StringDisplayWidth(@AStr[1], Length(AStr));
end;

{$ifdef CPUX86_64}
initialization
  GHasAVX2 := HasAVX2;
{$endif}

end.
