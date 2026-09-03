unit nextpas.core.audio.playlist.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.playlist.base;

type
  TPlaylistItem = nextpas.core.audio.playlist.base.TPlaylistItem;
  TPlaylistState = nextpas.core.audio.playlist.base.TPlaylistState;

  IAudioPlaylist = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000080}']
    function GetCount: Integer;
    function GetState: TPlaylistState;
    procedure Add(const ABuffer: TAudioBuffer; AGain: Single; ACrossfadeMs: Integer);
    procedure Clear;
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure Next;
    function CurrentIndex: Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

implementation

end.
