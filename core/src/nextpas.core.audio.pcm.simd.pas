unit nextpas.core.audio.pcm.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base;

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer);
procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);

implementation

uses
  nextpas.core.audio.pcm,
  nextpas.core.audio.simd;

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer);
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := PcmS16ToF32(ASrc[I]);
    ADst[I+1] := PcmS16ToF32(ASrc[I+1]);
    ADst[I+2] := PcmS16ToF32(ASrc[I+2]);
    ADst[I+3] := PcmS16ToF32(ASrc[I+3]);
    Inc(I, 4);
  end;
  while I < ACount do begin ADst[I] := PcmS16ToF32(ASrc[I]); Inc(I); end;
end;

procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := PcmF32ToS16(ASrc[I]);
    ADst[I+1] := PcmF32ToS16(ASrc[I+1]);
    ADst[I+2] := PcmF32ToS16(ASrc[I+2]);
    ADst[I+3] := PcmF32ToS16(ASrc[I+3]);
    Inc(I, 4);
  end;
  while I < ACount do begin ADst[I] := PcmF32ToS16(ASrc[I]); Inc(I); end;
end;

procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := PcmS32ToF32(ASrc[I]);
    ADst[I+1] := PcmS32ToF32(ASrc[I+1]);
    ADst[I+2] := PcmS32ToF32(ASrc[I+2]);
    ADst[I+3] := PcmS32ToF32(ASrc[I+3]);
    Inc(I, 4);
  end;
  while I < ACount do begin ADst[I] := PcmS32ToF32(ASrc[I]); Inc(I); end;
end;

procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);
var I, N4: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  N4 := ACount and not 3;
  I := 0;
  while I < N4 do
  begin
    ADst[I] := PcmF32ToS32(ASrc[I]);
    ADst[I+1] := PcmF32ToS32(ASrc[I+1]);
    ADst[I+2] := PcmF32ToS32(ASrc[I+2]);
    ADst[I+3] := PcmF32ToS32(ASrc[I+3]);
    Inc(I, 4);
  end;
  while I < ACount do begin ADst[I] := PcmF32ToS32(ASrc[I]); Inc(I); end;
end;

end.
