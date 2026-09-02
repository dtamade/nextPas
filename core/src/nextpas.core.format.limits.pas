unit nextpas.core.format.limits;
{**
 * @desc Shared limits for format modules (json/yaml/toml/csv/ini/xml bulk paths).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

const
  { Default max bytes for bulk Parse(IReader) / IoReadAll-then-parse entry points.
    CSV true streaming is not subject to this cap. Single source canonical via bytes.ops BYTES_BULK_PARSE_MAX_BYTES (L1 owner, no L2→L2, bytes.ops single source, inline zero-copy, L0-L3 kept). }
  FORMAT_BULK_PARSE_MAX_BYTES = BYTES_BULK_PARSE_MAX_BYTES;

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
