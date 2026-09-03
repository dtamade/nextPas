unit nextpas.core.audio.pcm.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base;

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer); inline;
procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer); inline;
procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer); inline;
procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer); inline;

implementation

uses
  nextpas.core.audio.simd;

// Single source Owner is nextpas.core.audio.simd dispatch via AudioSimdCaps/ SimdConvert*.
// pcm.simd is thin inline forwarding single source, no duplicate 4-way unroll,
// no secondary caps dispatch, zero extra branch. Raw F32 block copy stays single
// source via nextpas.core.base.utils CopyMem → bytes.ops (see audio.pcm).

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer); inline;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  // thin inline forward single source to Owner simd; inline + no extra caps branch
  SimdConvertS16ToF32(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer); inline;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  SimdConvertF32ToS16(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer); inline;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  SimdConvertS32ToF32(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer); inline;
begin
  if (ASrc = nil) or (ADst = nil) or (ACount <= 0) then Exit;
  SimdConvertF32ToS32(ASrc, ADst, ACount);
end;

end.
