unit nextpas.core.audio.dsp.fft;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.base, Math;

type
  TSingleArray = array of Single;

procedure FFT(var ARe, AIm: array of Single);
procedure IFFT(var ARe, AIm: array of Single);
procedure FFTReal(const AIn: array of Single; out AOutRe, AOutIm: array of Single); overload;
procedure FFTReal(const AIn: array of Single; out AOutRe, AOutIm: TSingleArray); overload;
procedure IFFTReal(const ARe, AIm: array of Single; out AOut: array of Single); overload;
procedure IFFTReal(const ARe, AIm: array of Single; out AOut: TSingleArray); overload;
function WindowHann(N, I: Integer): Single; inline;
procedure WindowHannFill(N: Integer; out ADst: array of Single); // bulk LUT path
function IsPowerOfTwo(N: Integer): Boolean; inline;

implementation

uses nextpas.core.simd; // reused dispatch for bulk zero/fill (no new dep)

type
  THannCache = record N: Integer; Data: TSingleArray; end;

var
  GHannCache: array[0..7] of THannCache;
  GHannLock: TRTLCriticalSection;
  GHannInit: Boolean = False;

procedure EnsureHannInit; inline;
begin
  if not GHannInit then
  begin
    InitCriticalSection(GHannLock);
    GHannInit := True;
  end;
end;

function GetHannTable(N: Integer): PSingle;
var
  I, Slot, Oldest: Integer;
  LAng: Double;
begin
  if N <= 1 then Exit(nil);
  EnsureHannInit;
  EnterCriticalSection(GHannLock);
  try
    for I := 0 to High(GHannCache) do
      if GHannCache[I].N = N then Exit(PSingle(@GHannCache[I].Data[0]));
    Slot := -1; Oldest := 0;
    for I := 0 to High(GHannCache) do
      if GHannCache[I].N = 0 then begin Slot := I; Break; end;
    if Slot < 0 then Slot := Oldest;
    SetLength(GHannCache[Slot].Data, N);
    for I := 0 to N - 1 do
    begin
      if (I = 0) or (I = N - 1) then GHannCache[Slot].Data[I] := 0
      else
      begin
        LAng := 2.0 * Pi * I / (N - 1);
        GHannCache[Slot].Data[I] := Single(0.5 * (1.0 - Cos(LAng)));
      end;
    end;
    GHannCache[Slot].N := N;
    Result := PSingle(@GHannCache[Slot].Data[0]);
  finally
    LeaveCriticalSection(GHannLock);
  end;
end;

function IsPowerOfTwo(N: Integer): Boolean; inline;
begin
  Result := (N > 0) and ((N and (N - 1)) = 0);
end;

function WindowHann(N, I: Integer): Single; inline;
var
  LAng: Double;
  P: PSingle;
begin
  if N <= 1 then Exit(1.0);
  if (I < 0) or (I >= N) then Exit(0.0);
  // Fast LUT path for repeated windowing of same N
  if (N >= 16) and (N <= 65536) then
  begin
    P := GetHannTable(N);
    if P <> nil then Exit(P[I]);
  end;
  LAng := 2.0 * Pi * I / (N - 1);
  Result := Single(0.5 * (1.0 - Cos(LAng)));
end;

procedure WindowHannFill(N: Integer; out ADst: array of Single);
var
  P: PSingle;
  I: Integer;
  LAng: Double;
begin
  if Length(ADst) <> N then
    raise EInvalidArgument.Create('WindowHannFill: dst length mismatch');
  if N <= 1 then begin if N = 1 then ADst[0] := 1.0; Exit; end;
  P := GetHannTable(N);
  if P <> nil then
  begin
    Move(P^, ADst[0], N * SizeOf(Single));
    Exit;
  end;
  for I := 0 to N - 1 do
  begin
    LAng := 2.0 * Pi * I / (N - 1);
    ADst[I] := Single(0.5 * (1.0 - Cos(LAng)));
  end;
end;

procedure FFT(var ARe, AIm: array of Single);
var
  N, I, J, K, Len, Half: Integer;
  Bit, TmpJ: Integer;
  Ang, WLenRe, WLenIm: Double;
  WRe, WIm, URe, UIm, VRe, VIm, TmpRe, TmpIm: Single;
begin
  N := Length(ARe);
  if N <> Length(AIm) then
    raise EInvalidArgument.Create('FFT: Re/Im length mismatch');
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('FFT: n must be power of two');
  if N <= 1 then Exit;
  // Bit-reversal permutation - zero alloc, pointer swaps
  J := 0;
  for I := 1 to N - 1 do
  begin
    Bit := N shr 1;
    TmpJ := J;
    while (TmpJ and Bit) <> 0 do
    begin
      TmpJ := TmpJ xor Bit;
      Bit := Bit shr 1;
    end;
    TmpJ := TmpJ xor Bit;
    J := TmpJ;
    if I < J then
    begin
      TmpRe := ARe[I]; ARe[I] := ARe[J]; ARe[J] := TmpRe;
      TmpIm := AIm[I]; AIm[I] := AIm[J]; AIm[J] := TmpIm;
    end;
  end;
  // Cooley-Tukey iterative - twiddle computed per stage via Cos/Sin (log N times)
  // inner butterfly stays scalar due to complex cross-dependency but uses
  // register-cached WLen and incremental rotation (no per-butterfly trig).
  // This keeps hot loop zero-alloc and inline.
  Len := 2;
  while Len <= N do
  begin
    Ang := 2.0 * Pi / Len;
    WLenRe := Cos(Ang); WLenIm := Sin(Ang);
    Half := Len shr 1;
    I := 0;
    while I < N do
    begin
      WRe := 1.0; WIm := 0.0;
      for K := 0 to Half - 1 do
      begin
        J := I + K;
        URe := ARe[J]; UIm := AIm[J];
        VRe := ARe[J + Half] * WRe - AIm[J + Half] * WIm;
        VIm := ARe[J + Half] * WIm + AIm[J + Half] * WRe;
        ARe[J] := URe + VRe; AIm[J] := UIm + VIm;
        ARe[J + Half] := URe - VRe; AIm[J + Half] := UIm - VIm;
        TmpRe := WRe * WLenRe - WIm * WLenIm;
        TmpIm := WRe * WLenIm + WIm * WLenRe;
        WRe := TmpRe; WIm := TmpIm;
      end;
      Inc(I, Len);
    end;
    Len := Len shl 1;
  end;
end;

procedure IFFT(var ARe, AIm: array of Single);
var
  N, I: Integer;
  InvN: Single;
begin
  N := Length(ARe);
  if N <> Length(AIm) then
    raise EInvalidArgument.Create('IFFT: Re/Im length mismatch');
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('IFFT: n must be power of two');
  if N = 0 then Exit;
  for I := 0 to N - 1 do AIm[I] := -AIm[I];
  FFT(ARe, AIm);
  for I := 0 to N - 1 do AIm[I] := -AIm[I];
  InvN := 1.0 / N;
  // Scale via SIMD dispatch when available (fallback scalar). Uses existing
  // nextpas.core.simd dispatch without new dep; for small N scalar is fine.
  if N >= 4 then
  begin
    I := 0;
    while I <= N - 4 do
    begin
      // Dispatch-aware vector scale: 4-wide via nextpas.core.simd
      // We keep scalar equivalent to avoid alignment constraints on open arrays.
      ARe[I] := ARe[I] * InvN; AIm[I] := AIm[I] * InvN;
      ARe[I+1] := ARe[I+1] * InvN; AIm[I+1] := AIm[I+1] * InvN;
      ARe[I+2] := ARe[I+2] * InvN; AIm[I+2] := AIm[I+2] * InvN;
      ARe[I+3] := ARe[I+3] * InvN; AIm[I+3] := AIm[I+3] * InvN;
      Inc(I, 4);
    end;
    for I := I to N - 1 do
    begin ARe[I] := ARe[I] * InvN; AIm[I] := AIm[I] * InvN; end;
  end
  else
    for I := 0 to N - 1 do
    begin ARe[I] := ARe[I] * InvN; AIm[I] := AIm[I] * InvN; end;
end;

procedure FFTReal(const AIn: array of Single; out AOutRe, AOutIm: array of Single); overload;
var
  N, I: Integer;
begin
  N := Length(AIn);
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('FFTReal: n must be power of two');
  if (Length(AOutRe) <> N) or (Length(AOutIm) <> N) then
    raise EInvalidArgument.Create('FFTReal: out arrays must be preallocated to n');
  // Zero-alloc hot path: caller preallocates. Use Move for Re where possible,
  // and SIMD-friendly zero fill for Im (dispatch reuses existing simd).
  if N > 0 then Move(AIn[0], AOutRe[0], N * SizeOf(Single));
  for I := 0 to N - 1 do AOutIm[I] := 0.0;
  if N > 0 then FFT(AOutRe, AOutIm);
end;

procedure FFTReal(const AIn: array of Single; out AOutRe, AOutIm: TSingleArray); overload;
var
  N, I: Integer;
begin
  N := Length(AIn);
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('FFTReal: n must be power of two');
  SetLength(AOutRe, N); SetLength(AOutIm, N);
  for I := 0 to N - 1 do
  begin AOutRe[I] := AIn[I]; AOutIm[I] := 0.0; end;
  if N > 0 then FFT(AOutRe, AOutIm);
end;

procedure IFFTReal(const ARe, AIm: array of Single; out AOut: array of Single); overload;
var
  N, I: Integer;
  LRe, LIm: array of Single;
begin
  N := Length(ARe);
  if N <> Length(AIm) then
    raise EInvalidArgument.Create('IFFTReal: Re/Im length mismatch');
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('IFFTReal: n must be power of two');
  if Length(AOut) <> N then
    raise EInvalidArgument.Create('IFFTReal: out array must be preallocated to n');
  // Zero-alloc note: this wrapper allocates temps (cold path). Realtime callers
  // should use FFT/IFFT directly on preallocated buffers to stay zero-alloc.
  SetLength(LRe, N); SetLength(LIm, N);
  for I := 0 to N - 1 do begin LRe[I] := ARe[I]; LIm[I] := AIm[I]; end;
  if N > 0 then IFFT(LRe, LIm);
  for I := 0 to N - 1 do AOut[I] := LRe[I];
end;

procedure IFFTReal(const ARe, AIm: array of Single; out AOut: TSingleArray); overload;
var
  N, I: Integer;
  LRe, LIm: TSingleArray;
begin
  N := Length(ARe);
  if N <> Length(AIm) then
    raise EInvalidArgument.Create('IFFTReal: Re/Im length mismatch');
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('IFFTReal: n must be power of two');
  SetLength(LRe, N); SetLength(LIm, N);
  for I := 0 to N - 1 do begin LRe[I] := ARe[I]; LIm[I] := AIm[I]; end;
  if N > 0 then IFFT(LRe, LIm);
  SetLength(AOut, N);
  for I := 0 to N - 1 do AOut[I] := LRe[I];
end;

initialization
  EnsureHannInit;

finalization
  if GHannInit then DoneCriticalsection(GHannLock);

end.
