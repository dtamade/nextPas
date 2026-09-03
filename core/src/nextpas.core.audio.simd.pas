unit nextpas.core.audio.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single source: SIMD dispatch Owner is nextpas.core.simd via nextpas.core.simd.cpuinfo
  (x86_64 SSE2 128-bit 4-wide + AVX2 256-bit 8-wide, aarch64 NEON baseline).
  nextpas.core.audio.simd is thin adapter over simd owner (AudioSimdCaps delegates to
  simd.cpuinfo.HasSSE2/HasAVX2/HasNEON, no parasitic CPUID); Simd* are single-source
  vector kernels. pcm.simd PcmConvertBlock* is thin inline forwarding single source
  via audio.simd → simd owner, no duplicate 4-way loop and no secondary caps dispatch;
  raw F32 block zero-copy single source via bytes.ops BytesCopy. }

type
  TSimdCaps = record
    HasSSE2: Boolean;
    HasAVX2: Boolean;
    HasNEON: Boolean;
  end;

function AudioSimdCaps: TSimdCaps; inline;
procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;
procedure SimdClampF32(AData: PSingle; ACount: Integer; ALo, AHi: Single);
procedure SimdConvertS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer);
procedure SimdConvertF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
procedure SimdConvertS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
procedure SimdConvertF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);
procedure SimdLerpF32(const AS0, AS1, AFrac, ADst: PSingle; ACount: Integer);
procedure SimdApplyGainRampF32(AData: PSingle; ACount: Integer; AStartGain, AEndGain: Single);

implementation

uses
  nextpas.core.simd.cpuinfo;

{$IFDEF CPUX86_64}
  {$ASMMODE INTEL}
{$ENDIF}

var
  GCaps: TSimdCaps;
  GInit: Boolean;

function AudioSimdCaps: TSimdCaps; inline;
begin
  // Owner delegation: single source via nextpas.core.simd.cpuinfo (no parasitic CPUID/XGETBV)
  // inline + cached, zero extra branch beyond GInit, reuses simd owner caps
  if not GInit then
  begin
    GCaps.HasSSE2 := nextpas.core.simd.cpuinfo.HasSSE2;
    GCaps.HasAVX2 := nextpas.core.simd.cpuinfo.HasAVX2;
    GCaps.HasNEON := nextpas.core.simd.cpuinfo.HasNEON;
    GInit := True;
  end;
  Result := GCaps;
end;

procedure SimdAddF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
var I, N4, N8: Integer;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    // AVX2 256-bit 8-wide single source Owner dispatch; zero-copy inline asm + vzeroupper
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [AGain]
      @Add8Loop:
        vmovups ymm0, yword ptr [rdx]
        vmovups ymm1, yword ptr [rcx]
        vmulps ymm1, ymm1, ymm2
        vaddps ymm0, ymm0, ymm1
        vmovups yword ptr [rdx], ymm0
        add rcx, 32
        add rdx, 32
        dec eax
        jnz @Add8Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin ADst[I] := ADst[I] + ASrc[I] * AGain; Inc(I); end;
    Exit;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        movss xmm2, dword ptr [AGain]
        shufps xmm2, xmm2, 0
      @Add4Loop:
        movups xmm0, dqword ptr [rdx]
        movups xmm1, dqword ptr [rcx]
        mulps xmm1, xmm2
        addps xmm0, xmm1
        movups dqword ptr [rdx], xmm0
        add rcx, 16
        add rdx, 16
        dec eax
        jnz @Add4Loop
      end;
    end;
    I := N4;
    while I < ACount do begin ADst[I] := ADst[I] + ASrc[I] * AGain; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := ADst[I] + ASrc[I] * AGain;
    ADst[I+1] := ADst[I+1] + ASrc[I+1] * AGain;
    ADst[I+2] := ADst[I+2] + ASrc[I+2] * AGain;
    ADst[I+3] := ADst[I+3] + ASrc[I+3] * AGain;
    Inc(I, 4);
  end;
  while I < ACount do
  begin
    ADst[I] := ADst[I] + ASrc[I] * AGain;
    Inc(I);
  end;
end;

procedure SimdMulF32(const ASrc: PSingle; ADst: PSingle; ACount: Integer; AGain: Single);
var I, N4, N8: Integer;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [AGain]
      @Mul8Loop:
        vmovups ymm1, yword ptr [rcx]
        vmulps ymm1, ymm1, ymm2
        vmovups yword ptr [rdx], ymm1
        add rcx, 32
        add rdx, 32
        dec eax
        jnz @Mul8Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin ADst[I] := ASrc[I] * AGain; Inc(I); end;
    Exit;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        movss xmm2, dword ptr [AGain]
        shufps xmm2, xmm2, 0
      @Mul4Loop:
        movups xmm1, dqword ptr [rcx]
        mulps xmm1, xmm2
        movups dqword ptr [rdx], xmm1
        add rcx, 16
        add rdx, 16
        dec eax
        jnz @Mul4Loop
      end;
    end;
    I := N4;
    while I < ACount do begin ADst[I] := ASrc[I] * AGain; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := ASrc[I] * AGain;
    ADst[I+1] := ASrc[I+1] * AGain;
    ADst[I+2] := ASrc[I+2] * AGain;
    ADst[I+3] := ASrc[I+3] * AGain;
    Inc(I, 4);
  end;
  while I < ACount do
  begin
    ADst[I] := ASrc[I] * AGain;
    Inc(I);
  end;
end;

function SimdPeakF32(const AData: PSingle; ACount: Integer): Single;
var I, N4, N8: Integer; V0, V1, V2, V3, M: Single;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps; LPeak: array[0..7] of Single; LAbsMask: array[0..3] of LongWord;
{$ENDIF}
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LAbsMask[0]:=$7fffffff; LAbsMask[1]:=$7fffffff; LAbsMask[2]:=$7fffffff; LAbsMask[3]:=$7fffffff;
      for I:=0 to 7 do LPeak[I]:=0;
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        lea rcx, qword ptr [LAbsMask]
        vmovups xmm4, dqword ptr [rcx]
        vinsertf128 ymm4, ymm4, xmm4, 1
        vxorps ymm5, ymm5, ymm5
      @Peak8Loop:
        vmovups ymm0, yword ptr [rdx]
        vandps ymm0, ymm0, ymm4
        vmaxps ymm5, ymm5, ymm0
        add rdx, 32
        dec eax
        jnz @Peak8Loop
        lea rcx, qword ptr [LPeak]
        vmovups yword ptr [rcx], ymm5
        vzeroupper
      end;
      M := LPeak[0];
      for I:=1 to 7 do if LPeak[I] > M then M := LPeak[I];
      I := N8;
      Result := M;
      while I < ACount do begin V0:=AData[I]; if V0<0 then V0:=-V0; if V0>Result then Result:=V0; Inc(I); end;
      Exit;
    end;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      LAbsMask[0]:=$7fffffff; LAbsMask[1]:=$7fffffff; LAbsMask[2]:=$7fffffff; LAbsMask[3]:=$7fffffff;
      for I:=0 to 3 do LPeak[I]:=0;
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        lea rcx, qword ptr [LAbsMask]
        movups xmm4, dqword ptr [rcx]
        xorps xmm5, xmm5
      @Peak4Loop:
        movups xmm0, dqword ptr [rdx]
        andps xmm0, xmm4
        maxps xmm5, xmm0
        add rdx, 16
        dec eax
        jnz @Peak4Loop
        lea rcx, qword ptr [LPeak]
        movups dqword ptr [rcx], xmm5
      end;
      M := LPeak[0];
      if LPeak[1] > M then M := LPeak[1];
      if LPeak[2] > M then M := LPeak[2];
      if LPeak[3] > M then M := LPeak[3];
      I := N4;
      Result := M;
      while I < ACount do begin V0:=AData[I]; if V0<0 then V0:=-V0; if V0>Result then Result:=V0; Inc(I); end;
      Exit;
    end;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  M := 0;
  I := 0;
  while I < N4 do
  begin
    V0 := AData[I]; if V0 < 0 then V0 := -V0; if V0 > M then M := V0;
    V1 := AData[I+1]; if V1 < 0 then V1 := -V1; if V1 > M then M := V1;
    V2 := AData[I+2]; if V2 < 0 then V2 := -V2; if V2 > M then M := V2;
    V3 := AData[I+3]; if V3 < 0 then V3 := -V3; if V3 > M then M := V3;
    Inc(I, 4);
  end;
  Result := M;
  while I < ACount do
  begin
    V0 := AData[I]; if V0 < 0 then V0 := -V0; if V0 > Result then Result := V0;
    Inc(I);
  end;
  if M > Result then Result := M;
end;

function SimdSumSquaresF32(const AData: PSingle; ACount: Integer): Double;
var I, N4, N8: Integer; S: Double;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps; LSum: array[0..7] of Single;
{$ENDIF}
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      for I:=0 to 7 do LSum[I]:=0;
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        vxorps ymm4, ymm4, ymm4
      @Sum8Loop:
        vmovups ymm0, yword ptr [rdx]
        vmulps ymm0, ymm0, ymm0
        vaddps ymm4, ymm4, ymm0
        add rdx, 32
        dec eax
        jnz @Sum8Loop
        lea rcx, qword ptr [LSum]
        vmovups yword ptr [rcx], ymm4
        vzeroupper
      end;
      S := LSum[0] + LSum[1] + LSum[2] + LSum[3] + LSum[4] + LSum[5] + LSum[6] + LSum[7];
      I := N8;
      while I < ACount do begin S := S + AData[I]*AData[I]; Inc(I); end;
      Result := S;
      Exit;
    end;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      for I:=0 to 3 do LSum[I]:=0;
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        xorps xmm4, xmm4
      @Sum4Loop:
        movups xmm0, dqword ptr [rdx]
        mulps xmm0, xmm0
        addps xmm4, xmm0
        add rdx, 16
        dec eax
        jnz @Sum4Loop
        lea rcx, qword ptr [LSum]
        movups dqword ptr [rcx], xmm4
      end;
      S := LSum[0] + LSum[1] + LSum[2] + LSum[3];
      I := N4;
      while I < ACount do begin S := S + AData[I]*AData[I]; Inc(I); end;
      Result := S;
      Exit;
    end;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  S := 0;
  I := 0;
  while I < N4 do
  begin
    S := S + AData[I]*AData[I] + AData[I+1]*AData[I+1] + AData[I+2]*AData[I+2] + AData[I+3]*AData[I+3];
    Inc(I, 4);
  end;
  Result := S;
  I := N4;
  while I < ACount do
  begin
    Result := Result + AData[I] * AData[I];
    Inc(I);
  end;
end;

procedure SimdClampF32(AData: PSingle; ACount: Integer; ALo, AHi: Single);
var I, N4, N8: Integer; V0, V1, V2, V3: Single;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps;
{$ENDIF}
begin
  if (AData = nil) or (ACount <= 0) then Exit;
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        vbroadcastss ymm2, dword ptr [ALo]
        vbroadcastss ymm3, dword ptr [AHi]
      @Clamp8Loop:
        vmovups ymm0, yword ptr [rdx]
        vmaxps ymm0, ymm0, ymm2
        vminps ymm0, ymm0, ymm3
        vmovups yword ptr [rdx], ymm0
        add rdx, 32
        dec eax
        jnz @Clamp8Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin V0:=AData[I]; if V0<ALo then V0:=ALo else if V0>AHi then V0:=AHi; AData[I]:=V0; Inc(I); end;
    Exit;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rdx, qword ptr [AData]
        movss xmm2, dword ptr [ALo]
        shufps xmm2, xmm2, 0
        movss xmm3, dword ptr [AHi]
        shufps xmm3, xmm3, 0
      @Clamp4Loop:
        movups xmm0, dqword ptr [rdx]
        maxps xmm0, xmm2
        minps xmm0, xmm3
        movups dqword ptr [rdx], xmm0
        add rdx, 16
        dec eax
        jnz @Clamp4Loop
      end;
    end;
    I := N4;
    while I < ACount do begin V0:=AData[I]; if V0<ALo then V0:=ALo else if V0>AHi then V0:=AHi; AData[I]:=V0; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    V0:=AData[I]; if V0<ALo then V0:=ALo else if V0>AHi then V0:=AHi; AData[I]:=V0;
    V1:=AData[I+1]; if V1<ALo then V1:=ALo else if V1>AHi then V1:=AHi; AData[I+1]:=V1;
    V2:=AData[I+2]; if V2<ALo then V2:=ALo else if V2>AHi then V2:=AHi; AData[I+2]:=V2;
    V3:=AData[I+3]; if V3<ALo then V3:=ALo else if V3>AHi then V3:=AHi; AData[I+3]:=V3;
    Inc(I,4);
  end;
  while I < ACount do
  begin V0:=AData[I]; if V0<ALo then V0:=ALo else if V0>AHi then V0:=AHi; AData[I]:=V0; Inc(I); end;
end;

procedure SimdConvertS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer);
var I, N4, N8: Integer;
{$IFDEF CPUX86_64}
var LCaps: TSimdCaps; LIter: Integer; LScale, LNegOne: Single; LNeg32768: LongInt;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source vector: AVX2 256-bit 8-wide single source Owner nextpas.core.simd, SSE2 4-wide fallback scalar
  // perf: inline caps delegate to simd.cpuinfo, zero-copy pointers, no alloc, vzeroupper
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      LScale := 1.0 / 32767.0;
      LNegOne := -1.0;
      LNeg32768 := -32768;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [LScale]
        vbroadcastss ymm3, dword ptr [LNegOne]
        vpbroadcastd ymm4, dword ptr [LNeg32768]
      @S16ToF328Loop:
        vmovdqu xmm0, dqword ptr [rcx]
        vpmovsxwd ymm0, xmm0
        vpcmpeqd ymm5, ymm0, ymm4
        vcvtdq2ps ymm0, ymm0
        vmulps ymm0, ymm0, ymm2
        vblendvps ymm0, ymm0, ymm3, ymm5
        vmovups yword ptr [rdx], ymm0
        add rcx, 16
        add rdx, 32
        dec eax
        jnz @S16ToF328Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin if ASrc[I] = -32768 then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 32767.0; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    if ASrc[I] = -32768 then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 32767.0;
    if ASrc[I+1] = -32768 then ADst[I+1] := -1.0 else ADst[I+1] := ASrc[I+1] / 32767.0;
    if ASrc[I+2] = -32768 then ADst[I+2] := -1.0 else ADst[I+2] := ASrc[I+2] / 32767.0;
    if ASrc[I+3] = -32768 then ADst[I+3] := -1.0 else ADst[I+3] := ASrc[I+3] / 32767.0;
    Inc(I, 4);
  end;
  while I < ACount do
  begin if ASrc[I] = -32768 then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 32767.0; Inc(I); end;
end;

procedure SimdConvertF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
var I, N4, N8: Integer; V: Single; LScaled: Integer;
{$IFDEF CPUX86_64}
var LCaps: TSimdCaps; LIter: Integer; LLo, LHi, LScale: Single; LNeg32768: LongInt;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source vector: AVX2 256-bit 8-wide Owner nextpas.core.simd, clamp+mul+cvt+pack
  // perf: inline caps via simd.cpuinfo, zero-copy, vzeroupper, single source 8-wide
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      LLo := -1.0; LHi := 1.0; LScale := 32767.0; LNeg32768 := -32768;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [LLo]
        vbroadcastss ymm3, dword ptr [LHi]
        vbroadcastss ymm4, dword ptr [LScale]
        vpbroadcastd ymm6, dword ptr [LNeg32768]
      @F32ToS168Loop:
        vmovups ymm0, yword ptr [rcx]
        vmaxps ymm0, ymm0, ymm2
        vminps ymm0, ymm0, ymm3
        vcmpps ymm5, ymm0, ymm2, 1
        vmulps ymm0, ymm0, ymm4
        vcvtps2dq ymm0, ymm0
        vpblendvb ymm0, ymm0, ymm6, ymm5
        vextractf128 xmm1, ymm0, 1
        vpackssdw xmm0, xmm0, xmm1
        vmovdqu dqword ptr [rdx], xmm0
        add rcx, 32
        add rdx, 16
        dec eax
        jnz @F32ToS168Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0; if V <= -1.0 then ADst[I] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I] := SmallInt(LScaled); end; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I] := SmallInt(LScaled); end;
    V := ASrc[I+1]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+1] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I+1] := SmallInt(LScaled); end;
    V := ASrc[I+2]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+2] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I+2] := SmallInt(LScaled); end;
    V := ASrc[I+3]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+3] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I+3] := SmallInt(LScaled); end;
    Inc(I, 4);
  end;
  while I < ACount do
  begin V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0; if V <= -1.0 then ADst[I] := -32768 else begin LScaled := Round(V * 32767.0); if LScaled < -32768 then LScaled := -32768 else if LScaled > 32767 then LScaled := 32767; ADst[I] := SmallInt(LScaled); end; Inc(I); end;
end;

procedure SimdConvertS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
var I, N4, N8: Integer;
{$IFDEF CPUX86_64}
var LCaps: TSimdCaps; LIter: Integer; LScale, LNegOne: Single; LNegMin: LongInt;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source vector: AVX2 256-bit 8-wide Owner nextpas.core.simd, scalar fallback
  // perf: inline caps via simd.cpuinfo, zero-copy, vzeroupper, single source 8-wide
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      LScale := 1.0 / 2147483647.0;
      LNegOne := -1.0;
      LNegMin := Low(LongInt);
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [LScale]
        vbroadcastss ymm3, dword ptr [LNegOne]
        vpbroadcastd ymm4, dword ptr [LNegMin]
      @S32ToF328Loop:
        vmovups ymm0, yword ptr [rcx]
        vpcmpeqd ymm5, ymm0, ymm4
        vcvtdq2ps ymm0, ymm0
        vmulps ymm0, ymm0, ymm2
        vblendvps ymm0, ymm0, ymm3, ymm5
        vmovups yword ptr [rdx], ymm0
        add rcx, 32
        add rdx, 32
        dec eax
        jnz @S32ToF328Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin if ASrc[I] = Low(LongInt) then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 2147483647.0; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    if ASrc[I] = Low(LongInt) then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 2147483647.0;
    if ASrc[I+1] = Low(LongInt) then ADst[I+1] := -1.0 else ADst[I+1] := ASrc[I+1] / 2147483647.0;
    if ASrc[I+2] = Low(LongInt) then ADst[I+2] := -1.0 else ADst[I+2] := ASrc[I+2] / 2147483647.0;
    if ASrc[I+3] = Low(LongInt) then ADst[I+3] := -1.0 else ADst[I+3] := ASrc[I+3] / 2147483647.0;
    Inc(I, 4);
  end;
  while I < ACount do
  begin if ASrc[I] = Low(LongInt) then ADst[I] := -1.0 else ADst[I] := ASrc[I] / 2147483647.0; Inc(I); end;
end;

procedure SimdConvertF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);
var I, N4, N8: Integer; V: Single; LScaled: Int64;
{$IFDEF CPUX86_64}
var LCaps: TSimdCaps; LIter: Integer; LLo, LHi, LScale: Single; LNegMin: LongInt;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source vector: AVX2 256-bit 8-wide Owner nextpas.core.simd, clamp+mul+cvt
  // perf: inline caps via simd.cpuinfo, zero-copy, vzeroupper, single source 8-wide
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      LLo := -1.0; LHi := 1.0; LScale := 2147483647.0; LNegMin := Low(LongInt);
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [ASrc]
        mov rdx, qword ptr [ADst]
        vbroadcastss ymm2, dword ptr [LLo]
        vbroadcastss ymm3, dword ptr [LHi]
        vbroadcastss ymm4, dword ptr [LScale]
        vpbroadcastd ymm6, dword ptr [LNegMin]
      @F32ToS328Loop:
        vmovups ymm0, yword ptr [rcx]
        vmaxps ymm0, ymm0, ymm2
        vminps ymm0, ymm0, ymm3
        vcmpps ymm5, ymm0, ymm2, 1
        vmulps ymm0, ymm0, ymm4
        vcvtps2dq ymm0, ymm0
        vpblendvb ymm0, ymm0, ymm6, ymm5
        vmovups yword ptr [rdx], ymm0
        add rcx, 32
        add rdx, 32
        dec eax
        jnz @F32ToS328Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0; if V <= -1.0 then ADst[I] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I] := LongInt(LScaled); end; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I] := LongInt(LScaled); end;
    V := ASrc[I+1]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+1] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I+1] := LongInt(LScaled); end;
    V := ASrc[I+2]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+2] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I+2] := LongInt(LScaled); end;
    V := ASrc[I+3]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0;
    if V <= -1.0 then ADst[I+3] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I+3] := LongInt(LScaled); end;
    Inc(I, 4);
  end;
  while I < ACount do
  begin V := ASrc[I]; if V < -1.0 then V := -1.0 else if V > 1.0 then V := 1.0; if V <= -1.0 then ADst[I] := Low(LongInt) else begin LScaled := Round(V * 2147483647.0); if LScaled < Low(LongInt) then LScaled := Low(LongInt) else if LScaled > High(LongInt) then LScaled := High(LongInt); ADst[I] := LongInt(LScaled); end; Inc(I); end;
end;

procedure SimdLerpF32(const AS0, AS1, AFrac, ADst: PSingle; ACount: Integer);
var I, N4, N8: Integer; V0: Single;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps; LOne: Single;
{$ENDIF}
begin
  if (AS0 = nil) or (AS1 = nil) or (AFrac = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // perf: inline caps via simd.cpuinfo, zero-copy PSingle windows, single source vector lerp per-element frac: dst = s0*(1-frac)+s1*frac; AVX2 8-wide + SSE2 4-wide + 4-unroll scalar; vzeroupper
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      LIter := N8 shr 3;
      LOne := 1.0;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [AS0]
        mov rdx, qword ptr [AS1]
        mov r8, qword ptr [AFrac]
        mov r9, qword ptr [ADst]
        vbroadcastss ymm3, dword ptr [LOne]
      @Lerp8Loop:
        vmovups ymm0, yword ptr [rcx]
        vmovups ymm1, yword ptr [rdx]
        vmovups ymm2, yword ptr [r8]
        vsubps ymm4, ymm3, ymm2
        vmulps ymm0, ymm0, ymm4
        vmulps ymm1, ymm1, ymm2
        vaddps ymm0, ymm0, ymm1
        vmovups yword ptr [r9], ymm0
        add rcx, 32
        add rdx, 32
        add r8, 32
        add r9, 32
        dec eax
        jnz @Lerp8Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin V0 := AFrac[I]; ADst[I] := AS0[I] * (1.0 - V0) + AS1[I] * V0; Inc(I); end;
    Exit;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      LIter := N4 shr 2;
      LOne := 1.0;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [AS0]
        mov rdx, qword ptr [AS1]
        mov r8, qword ptr [AFrac]
        mov r9, qword ptr [ADst]
        movss xmm3, dword ptr [LOne]
        shufps xmm3, xmm3, 0
      @Lerp4Loop:
        movups xmm0, dqword ptr [rcx]
        movups xmm1, dqword ptr [rdx]
        movups xmm2, dqword ptr [r8]
        movaps xmm4, xmm3
        subps xmm4, xmm2
        mulps xmm0, xmm4
        mulps xmm1, xmm2
        addps xmm0, xmm1
        movups dqword ptr [r9], xmm0
        add rcx, 16
        add rdx, 16
        add r8, 16
        add r9, 16
        dec eax
        jnz @Lerp4Loop
      end;
    end;
    I := N4;
    while I < ACount do begin V0 := AFrac[I]; ADst[I] := AS0[I] * (1.0 - V0) + AS1[I] * V0; Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    V0 := AFrac[I]; ADst[I] := AS0[I] * (1.0 - V0) + AS1[I] * V0;
    V0 := AFrac[I+1]; ADst[I+1] := AS0[I+1] * (1.0 - V0) + AS1[I+1] * V0;
    V0 := AFrac[I+2]; ADst[I+2] := AS0[I+2] * (1.0 - V0) + AS1[I+2] * V0;
    V0 := AFrac[I+3]; ADst[I+3] := AS0[I+3] * (1.0 - V0) + AS1[I+3] * V0;
    Inc(I, 4);
  end;
  while I < ACount do
  begin V0 := AFrac[I]; ADst[I] := AS0[I] * (1.0 - V0) + AS1[I] * V0; Inc(I); end;
end;

procedure SimdApplyGainRampF32(AData: PSingle; ACount: Integer; AStartGain, AEndGain: Single);
var I, N4, N8: Integer; LStep, LStep8: Single; LGains: array[0..7] of Single;
{$IFDEF CPUX86_64}
var LIter: Integer; LCaps: TSimdCaps;
{$ENDIF}
begin
  if (AData = nil) or (ACount <= 0) then Exit;
  if ACount = 1 then begin AData[0] := AData[0] * AStartGain; Exit; end;
  LStep := (AEndGain - AStartGain) / (ACount - 1);
  // perf: vector ramp via AVX2 8-wide / SSE2 4-wide single source, inline zero-copy PSingle, reuse SimdMul path, scalar tail
{$IFDEF CPUX86_64}
  LCaps := AudioSimdCaps;
  if LCaps.HasAVX2 then
  begin
    N8 := ACount and not 7;
    if N8 > 0 then
    begin
      for I := 0 to 7 do LGains[I] := AStartGain + I * LStep;
      LStep8 := LStep * 8;
      LIter := N8 shr 3;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [AData]
        lea rdx, qword ptr [LGains]
        vmovups ymm1, yword ptr [rdx]
        vbroadcastss ymm2, dword ptr [LStep8]
      @Ramp8Loop:
        vmovups ymm0, yword ptr [rcx]
        vmulps ymm0, ymm0, ymm1
        vmovups yword ptr [rcx], ymm0
        vaddps ymm1, ymm1, ymm2
        add rcx, 32
        dec eax
        jnz @Ramp8Loop
        vzeroupper
      end;
    end;
    I := N8;
    while I < ACount do begin AData[I] := AData[I] * (AStartGain + I * LStep); Inc(I); end;
    Exit;
  end;
  if LCaps.HasSSE2 then
  begin
    N4 := ACount and not 3;
    if N4 > 0 then
    begin
      for I := 0 to 3 do LGains[I] := AStartGain + I * LStep;
      LStep8 := LStep * 4;
      LIter := N4 shr 2;
      asm
        mov eax, dword ptr [LIter]
        mov rcx, qword ptr [AData]
        lea rdx, qword ptr [LGains]
        movups xmm1, dqword ptr [rdx]
        movss xmm2, dword ptr [LStep8]
        shufps xmm2, xmm2, 0
      @Ramp4Loop:
        movups xmm0, dqword ptr [rcx]
        mulps xmm0, xmm1
        movups dqword ptr [rcx], xmm0
        addps xmm1, xmm2
        add rcx, 16
        dec eax
        jnz @Ramp4Loop
      end;
    end;
    I := N4;
    while I < ACount do begin AData[I] := AData[I] * (AStartGain + I * LStep); Inc(I); end;
    Exit;
  end;
{$ENDIF}
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    AData[I] := AData[I] * (AStartGain + I * LStep);
    AData[I+1] := AData[I+1] * (AStartGain + (I+1) * LStep);
    AData[I+2] := AData[I+2] * (AStartGain + (I+2) * LStep);
    AData[I+3] := AData[I+3] * (AStartGain + (I+3) * LStep);
    Inc(I, 4);
  end;
  while I < ACount do begin AData[I] := AData[I] * (AStartGain + I * LStep); Inc(I); end;
end;

end.
