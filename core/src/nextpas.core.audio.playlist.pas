unit nextpas.core.audio.playlist;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.playlist.base,
  nextpas.core.audio.playlist.intf,
  nextpas.core.audio.playlist.impl;

type
  TPlaylistItem = nextpas.core.audio.playlist.base.TPlaylistItem;
  TPlaylistState = nextpas.core.audio.playlist.base.TPlaylistState;
  IAudioPlaylist = nextpas.core.audio.playlist.intf.IAudioPlaylist;

const
  PLAYLIST_GUID = '{F1A2B3C4-D5E6-7890-ABCD-A00000000080}';
  psStopped = nextpas.core.audio.playlist.base.psStopped;
  psPlaying = nextpas.core.audio.playlist.base.psPlaying;
  psPaused = nextpas.core.audio.playlist.base.psPaused;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist; inline;

implementation

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist; inline;
begin
  Result := nextpas.core.audio.playlist.impl.CreateAudioPlaylist(AFormat);
end;

end.
