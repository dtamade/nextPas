unit nextpas.core.db.trace.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.trace.base,
  nextpas.core.db.intf;

type
  IDbTraceSummary = interface
    ['{C7A4D2E8-51B9-4F63-9E0A-88D3B21F70C3}']
    function MaxLen: Integer;
  end;

function DbTraceHasListener(const AListener: IDbTraceListener): Boolean; inline;
function DbTraceSummaryMax: Integer; inline;

implementation

function DbTraceHasListener(const AListener: IDbTraceListener): Boolean; inline;
begin
  { perf: inline nil check, zero-cost fast path when no listener }
  Result := AListener <> nil;
end;

function DbTraceSummaryMax: Integer; inline;
begin
  Result := DB_TRACE_SQL_SUMMARY_MAX;
end;

end.
