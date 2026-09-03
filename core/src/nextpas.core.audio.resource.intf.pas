unit nextpas.core.audio.resource.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.resource.base;

type
  TAudioResourceState = nextpas.core.audio.resource.base.TAudioResourceState;
  TAudioResourceId = nextpas.core.audio.resource.base.TAudioResourceId;

  // Resource manager: async preload file → TAudioBuffer, Bank-friendly, thread-safe.
  // State machine: loading → ready | failed, explicit Release frees entry.
  IAudioResourceManager = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000054}']
    // Async load: deduplicates by path, returns existing Id if already loading/ready.
    // Non-blocking: caller polls GetState / TryGetBuffer.
    function AsyncLoad(const APath: string): TAudioResourceId;
    // Non-blocking query: zero alloc inside lock, copies buffer via refcounted share.
    function TryGetBuffer(AId: TAudioResourceId; out ABuffer: TAudioBuffer): Boolean;
    function TryGetTags(AId: TAudioResourceId; out ATags: TAudioTags): Boolean;
    function GetState(AId: TAudioResourceId): TAudioResourceState;
    function GetPath(AId: TAudioResourceId): string;
    function FindByPath(const APath: string): TAudioResourceId;
    function ResourceCount: Integer;
    function ProbeFile(const APath: string): TAudioProbeResult;
    procedure Release(AId: TAudioResourceId);
    procedure ReleaseAll;
  end;

implementation

end.
