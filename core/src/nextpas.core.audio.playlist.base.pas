unit nextpas.core.audio.playlist.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base;

type
  TPlaylistState = (psStopped, psPlaying, psPaused);

  TPlaylistItem = record
    Buffer: TAudioBuffer;
    Gain: Single;
    CrossfadeMs: Integer;
  end;

const
  CAudioPlaylistDefaultGain = 1.0;
  CAudioPlaylistDefaultCrossfadeMs = 0;

implementation

end.
