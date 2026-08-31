unit nextpas.core.audio.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

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
{$ENDIF}
begin
  if not GInit then
  begin
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False;
{$IFDEF CPUX86_64}
    LHasSSE2 := False; LHasAVX2 := False;
    asm
      mov eax, 1
      cpuid
      mov LEAX, eax
      mov LEBX, ebx
      mov LECX, ecx
      mov LEDX, edx
    end;
    LHasSSE2 := (LEDX and (1 shl 26)) <> 0;
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
    GCaps.HasSSE2 := LHasSSE2;
    GCaps.HasAVX2 := LHasAVX2 and LHasSSE2;
    if not GCaps.HasSSE2 then GCaps.HasSSE2 := True; // x86_64 baseline, honesty fallback
{$ELSE}
{$IFDEF CPUAARCH64}
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := True; // aarch64 baseline NEON
{$ELSEIF defined(CPUARM)}
    GCaps.HasSSE2 := False;
    GCaps.HasAVX2 := False;
    GCaps.HasNEON := False; // arm32 NEON optional, conservative
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
var I, N4: Integer;
{$IFDEF CPUX86_64}
var LIter: Integer;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
{$IFDEF CPUX86_64}
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
{$ENDIF}
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
var I, N4: Integer;
{$IFDEF CPUX86_64}
var LIter: Integer;
{$ENDIF}
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
{$IFDEF CPUX86_64}
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
{$ENDIF}
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
var I, N4: Integer; V0, V1, V2, V3, M: Single;
{$IFDEF CPUX86_64}
var LIter: Integer; LPeak: array[0..3] of Single; LAbsMask: array[0..3] of LongWord;
{$ENDIF}
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
{$IFDEF CPUX86_64}
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
{$ENDIF}
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
var I, N4: Integer; S: Double;
{$IFDEF CPUX86_64}
var LIter: Integer; LSum: array[0..3] of Single;
{$ENDIF}
begin
  Result := 0;
  if (AData = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
{$IFDEF CPUX86_64}
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
{$ENDIF}
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
var I, N4: Integer; V0, V1, V2, V3: Single;
{$IFDEF CPUX86_64}
var LIter: Integer;
{$ENDIF}
begin
  if (AData = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
{$IFDEF CPUX86_64}
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
{$ENDIF}
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

end.
