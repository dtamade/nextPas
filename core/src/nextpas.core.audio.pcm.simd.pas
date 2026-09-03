unit nextpas.core.audio.pcm.simd;

{$I nextpas.core.settings.inc}

{ Facade — pure re-export, zero logic; base←intf←impl←facade four-piece.
  Owner single source is nextpas.core.simd via audio.simd; pcm.simd is thin
  inline forwarding to Owner, no duplicate unroll, no secondary caps,
  inline + zero-copy, bytes.ops single source for raw F32. Ready to extract
  to nextpas.core.audio.simd unified module (phase s10-5). }

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.pcm.simd.base,
  nextpas.core.audio.pcm.simd.intf,
  nextpas.core.audio.pcm.simd.impl;

type
  TPcmSimdCaps = nextpas.core.audio.pcm.simd.base.TPcmSimdCaps;
  IPcmSimdConverter = nextpas.core.audio.pcm.simd.intf.IPcmSimdConverter;

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer); inline;
procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer); inline;
procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer); inline;
procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer); inline;

implementation

procedure PcmConvertBlockS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer); inline;
begin
  nextpas.core.audio.pcm.simd.impl.PcmConvertBlockS16ToF32(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer); inline;
begin
  nextpas.core.audio.pcm.simd.impl.PcmConvertBlockF32ToS16(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer); inline;
begin
  nextpas.core.audio.pcm.simd.impl.PcmConvertBlockS32ToF32(ASrc, ADst, ACount);
end;

procedure PcmConvertBlockF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer); inline;
begin
  nextpas.core.audio.pcm.simd.impl.PcmConvertBlockF32ToS32(ASrc, ADst, ACount);
end;

end.
