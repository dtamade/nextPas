unit nextpas.core.sevenz.filters;

{**
 * nextpas.core.sevenz.filters - 过滤器注册表与统一分发
 *
 * 将 TSevenZFilter 枚举、MethodId、Props 生成、BCJ/Delta 互逆转换收敛为
 * 单一表驱动入口，供 writer（编码，起点 0）与 coders（解码，按 Props 还原）
 * 共享，避免两处 case 散落与 MethodId 漂移。高阶复用、零额外开销。
 *}

{$I nextpas.core.settings.inc}
{$PUSH}{$WARN 5024 OFF}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.intf,
  nextpas.core.sevenz.base;

function SevenZFilterMethodId(AFilter: TSevenZFilter): UInt64;
function SevenZFilterDefaultProps(AFilter: TSevenZFilter): TBytes;
procedure SevenZFilterConvert(var AData: TBytes; AFilter: TSevenZFilter;
  const AProps: TBytes; AEncode: Boolean);

function SevenZDeltaDecode(const AProps: TBytes; const AInput: TBytes;
  AOutSize: UInt64): TBytes;
function SevenZDeltaEncode(const AProps: TBytes; const AInput: TBytes): TBytes;

procedure SevenZDeltaEncodeInPlace(var AData: TBytes; const AProps: TBytes);
procedure SevenZDeltaDecodeInPlace(var AData: TBytes; const AProps: TBytes);

function SevenZFilterFromMethodId(AMethodId: UInt64; out AFilter: TSevenZFilter): Boolean;
function SevenZIsSupportedMethod(AMethodId: UInt64): Boolean;

implementation

uses
  nextpas.core.sevenz.bcj.x86,
  nextpas.core.sevenz.bcj.arm,
  nextpas.core.sevenz.bcj.arm64,
  nextpas.core.sevenz.bcj.ppc,
  nextpas.core.sevenz.bcj.ia64,
  nextpas.core.sevenz.bcj.sparc,
  nextpas.core.sevenz.bcj.armt,
  nextpas.core.sevenz.bcj.riscv;

function BcjStartOffset(const AProps: TBytes; const ATag: string): UInt32;
begin
  if Length(AProps) = 0 then Exit(0);
  if Length(AProps) < 4 then
    raise ESevenZError.Create('bcj ' + ATag + ' props shorter than 4 bytes');
  Result := UInt32(AProps[0]) or (UInt32(AProps[1]) shl 8) or
    (UInt32(AProps[2]) shl 16) or (UInt32(AProps[3]) shl 24);
end;

function SevenZFilterMethodId(AFilter: TSevenZFilter): UInt64;
begin
  case AFilter of
    szfBcjX86:  Result := SEVENZ_METHOD_BCJ_X86;
    szfBcjArm:  Result := SEVENZ_METHOD_BCJ_ARM;
    szfBcjArm64:Result := SEVENZ_METHOD_BCJ_ARM64;
    szfBcjPpc:  Result := SEVENZ_METHOD_BCJ_PPC;
    szfBcjIa64: Result := SEVENZ_METHOD_BCJ_IA64;
    szfBcjSparc:Result := SEVENZ_METHOD_BCJ_SPARC;
    szfBcjArmt: Result := SEVENZ_METHOD_BCJ_ARMT;
    szfBcjRiscv:Result := SEVENZ_METHOD_BCJ_RISCV;
    szfDelta:  Result := SEVENZ_METHOD_DELTA;
  end;
end;

function SevenZFilterFromMethodId(AMethodId: UInt64; out AFilter: TSevenZFilter): Boolean;
begin
  case AMethodId of
    SEVENZ_METHOD_BCJ_X86:  AFilter := szfBcjX86;
    SEVENZ_METHOD_BCJ_ARM:  AFilter := szfBcjArm;
    SEVENZ_METHOD_BCJ_ARM64:AFilter := szfBcjArm64;
    SEVENZ_METHOD_BCJ_PPC:  AFilter := szfBcjPpc;
    SEVENZ_METHOD_BCJ_IA64: AFilter := szfBcjIa64;
    SEVENZ_METHOD_BCJ_SPARC:AFilter := szfBcjSparc;
    SEVENZ_METHOD_BCJ_ARMT: AFilter := szfBcjArmt;
    SEVENZ_METHOD_BCJ_RISCV:AFilter := szfBcjRiscv;
    SEVENZ_METHOD_DELTA:   AFilter := szfDelta;
  else
    Exit(False);
  end;
  Result := True;
end;

function SevenZIsSupportedMethod(AMethodId: UInt64): Boolean;
begin
  case AMethodId of
    SEVENZ_METHOD_COPY,
    SEVENZ_METHOD_LZMA1,
    SEVENZ_METHOD_LZMA2,
    SEVENZ_METHOD_DELTA,
    SEVENZ_METHOD_BCJ_X86,
    SEVENZ_METHOD_BCJ_ARM,
    SEVENZ_METHOD_BCJ_ARM64,
    SEVENZ_METHOD_BCJ_PPC,
    SEVENZ_METHOD_BCJ_IA64,
    SEVENZ_METHOD_BCJ_SPARC,
    SEVENZ_METHOD_BCJ_ARMT,
    SEVENZ_METHOD_BCJ_RISCV,
    SEVENZ_METHOD_BCJ2,
    SEVENZ_METHOD_AES256_CRC,
    SEVENZ_METHOD_DEFLATE,
    SEVENZ_METHOD_BZIP2: Result := True;
  else
    Result := False;
  end;
end;

function SevenZFilterDefaultProps(AFilter: TSevenZFilter): TBytes;
begin
  if AFilter = szfDelta then
    Result := TBytes.Create(Byte(0)) // dist=1
  else
    Result := nil;
end;

{ Delta 单一 helper：栈历史 + 零堆分配，in-place/out-of-place 复用，单源于 bytes.ops 零拷贝哲学 }
function DeltaDist(const AProps: TBytes): SizeInt; inline;
begin
  if Length(AProps) < 1 then
    raise ESevenZError.Create('delta props missing');
  Result := SizeInt(AProps[0]) + 1;
end;

procedure DeltaApply(const ASrc: PByte; ADst: PByte; ALen: SizeUInt;
  LDist: SizeInt; AEncode: Boolean);
var
  LHist: array[0..255] of Byte;
  LI: SizeUInt;
  LSlot: SizeInt;
  LOrig: Byte;
begin
  if ALen = 0 then Exit;
  { perf: stack LHist avoids SetLength heap alloc per hot call; single FillChar over LDist (≤256), inline }
  FillChar(LHist[0], LDist, 0);
  if AEncode then
  begin
    for LI := 0 to ALen - 1 do
    begin
      LSlot := SizeInt(LI mod SizeUInt(LDist));
      LOrig := ASrc[LI];
      {$PUSH}{$Q-}{$R-}
      ADst[LI] := Byte(LOrig - LHist[LSlot]);
      {$POP}
      LHist[LSlot] := LOrig;
    end;
  end
  else
  begin
    for LI := 0 to ALen - 1 do
    begin
      LSlot := SizeInt(LI mod SizeUInt(LDist));
      {$PUSH}{$Q-}{$R-}
      ADst[LI] := Byte(ASrc[LI] + LHist[LSlot]);
      {$POP}
      LHist[LSlot] := ADst[LI];
    end;
  end;
end;

function SevenZDeltaDecode(const AProps: TBytes; const AInput: TBytes;
  AOutSize: UInt64): TBytes;
var
  LDist: SizeInt;
begin
  Result := nil;
  LDist := DeltaDist(AProps);
  if SizeUInt(Length(AInput)) < AOutSize then
    raise ESevenZError.Create('delta input shorter than declared output');
  SetLength(Result, AOutSize);
  if AOutSize = 0 then Exit;
  DeltaApply(@AInput[0], @Result[0], SizeUInt(AOutSize), LDist, False);
end;

function SevenZDeltaEncode(const AProps: TBytes; const AInput: TBytes): TBytes;
var
  LDist: SizeInt;
begin
  Result := nil;
  LDist := DeltaDist(AProps);
  SetLength(Result, Length(AInput));
  if Length(AInput) = 0 then Exit;
  DeltaApply(@AInput[0], @Result[0], SizeUInt(Length(AInput)), LDist, True);
end;

procedure SevenZDeltaEncodeInPlace(var AData: TBytes; const AProps: TBytes);
var
  LDist: SizeInt;
begin
  if Length(AData) = 0 then Exit;
  LDist := DeltaDist(AProps);
  DeltaApply(@AData[0], @AData[0], SizeUInt(Length(AData)), LDist, True);
end;

procedure SevenZDeltaDecodeInPlace(var AData: TBytes; const AProps: TBytes);
begin
  if Length(AData) = 0 then Exit;
  DeltaApply(@AData[0], @AData[0], SizeUInt(Length(AData)), DeltaDist(AProps), False);
end;

procedure SevenZFilterConvert(var AData: TBytes; AFilter: TSevenZFilter;
  const AProps: TBytes; AEncode: Boolean);
var
  LDeltaIn: TBytes;
begin
  case AFilter of
    szfBcjX86:
      SevenZBcjX86Convert(AData, BcjStartOffset(AProps, 'x86'), AEncode);
    szfBcjArm:
      SevenZBcjArmConvert(AData, BcjStartOffset(AProps, 'arm'), AEncode);
    szfBcjArm64:
      SevenZBcjArm64Convert(AData, BcjStartOffset(AProps, 'arm64'), AEncode);
    szfBcjPpc:
      SevenZBcjPpcConvert(AData, BcjStartOffset(AProps, 'ppc'), AEncode);
    szfBcjIa64:
      SevenZBcjIa64Convert(AData, BcjStartOffset(AProps, 'ia64'), AEncode);
    szfBcjSparc:
      SevenZBcjSparcConvert(AData, BcjStartOffset(AProps, 'sparc'), AEncode);
    szfBcjArmt:
      SevenZBcjArmtConvert(AData, BcjStartOffset(AProps, 'armt'), AEncode);
    szfBcjRiscv:
      SevenZBcjRiscvConvert(AData, BcjStartOffset(AProps, 'riscv'), AEncode);
    szfDelta:
      begin
        if AEncode then
        begin
          if Length(AProps) = 0 then
            LDeltaIn := SevenZFilterDefaultProps(szfDelta)
          else
            LDeltaIn := AProps;
          SevenZDeltaEncodeInPlace(AData, LDeltaIn);
        end
        else
        begin
          SevenZDeltaDecodeInPlace(AData, AProps);
        end;
      end;
  end;
end;
{$POP}
end.
