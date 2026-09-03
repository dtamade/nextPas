unit nextpas.core.http.impl.h2.defense;
{**
 * @desc H2 DoS defense facade (L3 http.impl.h2 domain extracted per CONTRACT §1.1 §6 h2 DoS stance).
 *       Aggregates FRapidResetCount/FControlFrameFloodCount + EscalateHeaderBlockFlood + HARD_LIMITS.
 *       Four-piece: defense.base ← defense.intf ← defense. L0-L3 ok, bytes.ops single source via header size calc.
 *       perf: inline hot counters, zero-copy header-list size via TByteSpan view; stability: GOAWAY+Close + pending clear, no leak.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h2.defense.base,
  nextpas.core.http.impl.h2.defense.intf;

type
  TH2DefenseCounters = nextpas.core.http.impl.h2.defense.base.TH2DefenseCounters;
  IHttpH2Defense = nextpas.core.http.impl.h2.defense.intf.IHttpH2Defense;

function H2DefenseShouldGoAway(const ACnt: TH2DefenseCounters): Boolean; inline;
procedure H2DefenseMarkHandled(var ACnt: TH2DefenseCounters); inline;

const
  H2_DEFENSE_MAX_RAPID_RESETS = H2_MAX_RAPID_RESETS;
  H2_DEFENSE_MAX_CONTROL_FLOOD = H2_MAX_CONTROL_FRAME_FLOOD;
  H2_DEFENSE_HEADER_LIST_HARD_LIMIT = H2_HEADER_LIST_HARD_LIMIT;

implementation

function H2DefenseShouldGoAway(const ACnt: TH2DefenseCounters): Boolean; inline;
begin
  Result := nextpas.core.http.impl.h2.defense.intf.H2DefenseShouldGoAway(ACnt);
end;

procedure H2DefenseMarkHandled(var ACnt: TH2DefenseCounters); inline;
begin
  ACnt.ResetOnRequestComplete;
end;

end.
