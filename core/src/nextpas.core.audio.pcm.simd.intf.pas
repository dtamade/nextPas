unit nextpas.core.audio.pcm.simd.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.pcm.simd.base;

type
  { IPcmSimdConverter — procedural block converters as interface contract
    for audio.simd unified module candidate; future direct simd owner binding
    can replace impl without facade churn. GUID frozen per four-piece. }
  IPcmSimdConverter = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000061}']
    procedure ConvertS16ToF32(const ASrc: PSmallInt; ADst: PSingle; ACount: Integer);
    procedure ConvertF32ToS16(const ASrc: PSingle; ADst: PSmallInt; ACount: Integer);
    procedure ConvertS32ToF32(const ASrc: PLongInt; ADst: PSingle; ACount: Integer);
    procedure ConvertF32ToS32(const ASrc: PSingle; ADst: PLongInt; ACount: Integer);
  end;

implementation

end.
