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
function IsPowerOfTwo(N: Integer): Boolean;

implementation

function IsPowerOfTwo(N: Integer): Boolean;
begin
  Result := (N > 0) and ((N and (N - 1)) = 0);
end;

function WindowHann(N, I: Integer): Single; inline;
var
  LAng: Double;
begin
  if N <= 1 then
    Exit(1.0);
  if (I < 0) or (I >= N) then
    Exit(0.0);
  LAng := 2.0 * Pi * I / (N - 1);
  Result := Single(0.5 * (1.0 - Cos(LAng)));
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
  if N <= 1 then
    Exit;
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
      TmpRe := ARe[I];
      ARe[I] := ARe[J];
      ARe[J] := TmpRe;
      TmpIm := AIm[I];
      AIm[I] := AIm[J];
      AIm[J] := TmpIm;
    end;
  end;
  Len := 2;
  while Len <= N do
  begin
    Ang := 2.0 * Pi / Len;
    WLenRe := Cos(Ang);
    WLenIm := Sin(Ang);
    Half := Len shr 1;
    I := 0;
    while I < N do
    begin
      WRe := 1.0;
      WIm := 0.0;
      for K := 0 to Half - 1 do
      begin
        J := I + K;
        URe := ARe[J];
        UIm := AIm[J];
        VRe := ARe[J + Half] * WRe - AIm[J + Half] * WIm;
        VIm := ARe[J + Half] * WIm + AIm[J + Half] * WRe;
        ARe[J] := URe + VRe;
        AIm[J] := UIm + VIm;
        ARe[J + Half] := URe - VRe;
        AIm[J + Half] := UIm - VIm;
        TmpRe := WRe * WLenRe - WIm * WLenIm;
        TmpIm := WRe * WLenIm + WIm * WLenRe;
        WRe := TmpRe;
        WIm := TmpIm;
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
  if N = 0 then
    Exit;
  for I := 0 to N - 1 do
    AIm[I] := -AIm[I];
  FFT(ARe, AIm);
  for I := 0 to N - 1 do
    AIm[I] := -AIm[I];
  InvN := 1.0 / N;
  for I := 0 to N - 1 do
  begin
    ARe[I] := ARe[I] * InvN;
    AIm[I] := AIm[I] * InvN;
  end;
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
  for I := 0 to N - 1 do
  begin
    AOutRe[I] := AIn[I];
    AOutIm[I] := 0.0;
  end;
  if N > 0 then
    FFT(AOutRe, AOutIm);
end;

procedure FFTReal(const AIn: array of Single; out AOutRe, AOutIm: TSingleArray); overload;
var
  N, I: Integer;
begin
  N := Length(AIn);
  if not IsPowerOfTwo(N) then
    raise EInvalidArgument.Create('FFTReal: n must be power of two');
  SetLength(AOutRe, N);
  SetLength(AOutIm, N);
  for I := 0 to N - 1 do
  begin
    AOutRe[I] := AIn[I];
    AOutIm[I] := 0.0;
  end;
  if N > 0 then
    FFT(AOutRe, AOutIm);
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
  SetLength(LRe, N);
  SetLength(LIm, N);
  for I := 0 to N - 1 do
  begin
    LRe[I] := ARe[I];
    LIm[I] := AIm[I];
  end;
  if N > 0 then
    IFFT(LRe, LIm);
  for I := 0 to N - 1 do
    AOut[I] := LRe[I];
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
  SetLength(LRe, N);
  SetLength(LIm, N);
  for I := 0 to N - 1 do
  begin
    LRe[I] := ARe[I];
    LIm[I] := AIm[I];
  end;
  if N > 0 then
    IFFT(LRe, LIm);
  SetLength(AOut, N);
  for I := 0 to N - 1 do
    AOut[I] := LRe[I];
end;

end.
