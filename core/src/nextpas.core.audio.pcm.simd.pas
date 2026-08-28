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
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := PcmS16ToF32(ASrc[I]);
end;

procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := PcmF32ToS16(ASrc[I]);
end;

procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := PcmS32ToF32(ASrc[I]);
end;

procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);
var I: Integer;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := PcmF32ToS32(ASrc[I]);
end;

end.
