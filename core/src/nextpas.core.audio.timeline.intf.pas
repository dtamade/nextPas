unit nextpas.core.audio.timeline.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TTimelineClipId = Integer;
  TTimelineTrackId = Integer;

  TTimelineClip = record
    Id: TTimelineClipId;
    Buffer: TAudioBuffer; // sfF32, must match timeline format
    StartFrame: UInt64;
    Gain: Single;
    Pan: Single;
    Alive: Boolean;
  end;

  TTimelineTrack = record
    Id: TTimelineTrackId;
    Clips: array of TTimelineClip;
    Gain: Single;
    Pan: Single;
    Muted: Boolean;
    Solo: Boolean;
    Alive: Boolean;
  end;

  IAudioTimeline = interface(IRealtimeAudioSource)
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000060}']
    function GetFormat: TAudioFormat;
    function GetPosition: UInt64;
    function GetDuration: UInt64;
    function GetLoop: Boolean;
    procedure SetLoop(ALoop: Boolean);
    function AddTrack(AGain: Single = 1.0): TTimelineTrackId;
    function RemoveTrack(ATrack: TTimelineTrackId): Boolean;
    function SetTrackGain(ATrack: TTimelineTrackId; AGain: Single): Boolean;
    function SetTrackPan(ATrack: TTimelineTrackId; APan: Single): Boolean;
    function SetTrackMute(ATrack: TTimelineTrackId; AMuted: Boolean): Boolean;
    function SetTrackSolo(ATrack: TTimelineTrackId; ASolo: Boolean): Boolean;
    function AddClip(ATrack: TTimelineTrackId; const ABuffer: TAudioBuffer; AStartFrame: UInt64; AGain: Single = 1.0; APan: Single = 0): TTimelineClipId;
    function RemoveClip(ATrack: TTimelineTrackId; AClip: TTimelineClipId): Boolean;
    function TrackCount: Integer;
    function ClipCount(ATrack: TTimelineTrackId): Integer;
    procedure Clear;
    property Format: TAudioFormat read GetFormat;
    property Position: UInt64 read GetPosition;
    property Duration: UInt64 read GetDuration;
    property Loop: Boolean read GetLoop write SetLoop;
  end;

implementation

end.
