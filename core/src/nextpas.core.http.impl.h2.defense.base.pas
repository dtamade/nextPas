unit nextpas.core.http.impl.h2.defense.base;

{$I nextpas.core.settings.inc}

interface

const
  H2_MAX_RAPID_RESETS = 100;
  H2_MAX_CONTROL_FRAME_FLOOD = 100;
  H2_MAX_HEADER_BLOCK_BYTES = 64 * 1024;
  H2_MAX_HEADER_FRAGMENTS = 512;
  H2_MAX_EMPTY_FRAGMENTS = 64;
  H2_HEADER_LIST_HARD_LIMIT = 1024 * 1024;
  H2_WIRE_READ_HARD_LIMIT = 16 * 1024 * 1024;

type
  TH2DefenseCounters = record
    RapidResetCount: Int32;
    ControlFrameFloodCount: Int32;
    procedure ResetOnRequestComplete; inline;
  end;

implementation

procedure TH2DefenseCounters.ResetOnRequestComplete; inline;
begin
  { perf: inline reset, zero-copy, completion-clears both counters per CONTRACT invariance }
  RapidResetCount := 0;
  ControlFrameFloodCount := 0;
end;

end.
