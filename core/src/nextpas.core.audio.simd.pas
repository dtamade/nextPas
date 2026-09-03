unit nextpas.core.audio.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single source: audio SIMD dispatch Owner is nextpas.core.audio.simd via AudioSimdCaps
  (x86_64 SSE2 128-bit 4-wide + AVX2 256-bit 8-wide, aarch64 NEON baseline).
  pcm.simd PcmConvertBlock* is thin inline forwarding single source to SimdConvert*,
  no duplicate 4-way loop and no secondary caps dispatch; raw F32 block
  zero-copy single source via nextpas.core.base.utils CopyMem → bytes.ops. }

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

implementation

{$IFDEF CPUX86_64}
  {$ASMMODE INTEL}
{$ENDIF}

var
  GCaps: TSimdCaps;
  GInit: Boolean;

function AudioSimdCaps: TSimdCaps;
{$IFDEF CPUX86_64}
var LHasSSE2, LHasAVX2: LongBool;
    LEAX, LEBX, LECX, LEDX: LongWord;
    LMaxLeaf: LongWord;
    LLeaf1ECX: LongWord;
    LXCR0Lo, LXCR0Hi: LongWord;
{$ENDIF}
begin
  if not GInit then
  begin
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False;
{$IFDEF CPUX86_64}
    LHasSSE2 := False; LHasAVX2 := False;
    LMaxLeaf := 0; LLeaf1ECX := 0; LXCR0Lo := 0; LXCR0Hi := 0;
    asm
      xor eax, eax
      cpuid
      mov LEAX, eax
      mov LEBX, ebx
      mov LECX, ecx
      mov LEDX, edx
    end;
    LMaxLeaf := LEAX;
    asm
      mov eax, 1
      cpuid
      mov LEAX, eax
      mov LEBX, ebx
      mov LECX, ecx
      mov LEDX, edx
    end;
    LHasSSE2 := (LEDX and (1 shl 26)) <> 0;
    LLeaf1ECX := LECX;
    if LMaxLeaf >= 7 then
    begin
      asm
        mov eax, 7
        xor ecx, ecx
        cpuid
        mov LEAX, eax
        mov LEBX, ebx
        mov LECX, ecx
        mov LEDX, edx
      end;
      LHasAVX2 := (LEBX and (1 shl 5)) <> 0;
      if LHasAVX2 and ((LLeaf1ECX and (1 shl 27)) <> 0) then
      begin
        asm
          xor ecx, ecx
          XGETBV
          mov LXCR0Lo, eax
          mov LXCR0Hi, edx
        end;
        if (LXCR0Lo and 6) <> 6 then
          LHasAVX2 := False;
      end else if LHasAVX2 then
        LHasAVX2 := False;
    end else
      LHasAVX2 := False;
    GCaps.HasSSE2 := LHasSSE2;
    GCaps.HasAVX2 := LHasAVX2;
{$ELSE}
{$IFDEF CPUAARCH64}
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := True;
{$ELSEIF defined(CPUARM)}
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False;
{$ELSE}
    GCaps.HasSSE2 := True;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False;
{$ENDIF}
{$ENDIF}
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
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source scalar 4-way unrolled; vector widening deferred to Owner nextpas.core.simd
  // thin reuse via bytes.ops single source is not needed for per-sample scale, but pcm.simd forwards here
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
var I, N4: Integer; V: Single; LScaled: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source scalar 4-way; vector dispatch owned by nextpas.core.simd when widened
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
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source scalar 4-way; Owner nextpas.core.simd will widen to AVX2/NEON when needed
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
var I, N4: Integer; V: Single; LScaled: Int64;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // single source scalar 4-way; Owner nextpas.core.simd widening point
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

end.
