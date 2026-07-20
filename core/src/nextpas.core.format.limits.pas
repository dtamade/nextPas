unit nextpas.core.format.limits;
{**
 * @desc Shared limits for format modules (json/yaml/toml/csv/ini/xml bulk paths).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { Default max bytes for bulk Parse(IReader) / IoReadAll-then-parse entry points.
    CSV true streaming is not subject to this cap. }
  FORMAT_BULK_PARSE_MAX_BYTES = SizeUInt(64) * 1024 * 1024;

procedure RequireFormatBulkByteCount(const ACount: SizeUInt; const AContext: string);

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv;

procedure RequireFormatBulkByteCount(const ACount: SizeUInt; const AContext: string);
begin
  if ACount > FORMAT_BULK_PARSE_MAX_BYTES then
    raise EArgumentError.Create(AContext + ': input exceeds bulk parse limit of ' +
      IntToStr(Int64(FORMAT_BULK_PARSE_MAX_BYTES)) + ' bytes');
end;

end.
