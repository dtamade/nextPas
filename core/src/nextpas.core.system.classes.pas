unit nextpas.core.system.classes;
{**
 * @desc Minimal Classes compatibility facade.
 *   Re-exports nextpas.core.io types — no direct FPC RTL dependency.
 *   Modules that need FPC TStream bridging should use
 *   nextpas.core.io.stream_adapter directly.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf;

type
  TSeekOrigin = nextpas.core.io.base.TSeekOrigin;
  IStream = nextpas.core.io.intf.IStream;
  IReader = nextpas.core.io.intf.IReader;
  IWriter = nextpas.core.io.intf.IWriter;

implementation

end.
