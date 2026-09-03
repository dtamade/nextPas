unit nextpas.core.audio.pcm.simd.base;

{$I nextpas.core.settings.inc}

interface

const
  CPcmSimdWidthSSE2 = 4; // SSE2 128-bit 4-wide
  CPcmSimdWidthAVX2 = 8; // AVX2 256-bit 8-wide
  CPcmS16ScaleF32: Single = 1.0 / 32767.0;
  CPcmS32ScaleF32: Single = 1.0 / 2147483647.0;
  CPcmS16NegClip = -32768;
  CPcmS32NegClip = Low(LongInt);
  CPcmSimdInlineNote = 'inline + zero-copy + single source bytes.ops';

type
  TPcmSimdCaps = record
    HasSSE2: Boolean;
    HasAVX2: Boolean;
    HasNEON: Boolean;
  end;

implementation

end.
