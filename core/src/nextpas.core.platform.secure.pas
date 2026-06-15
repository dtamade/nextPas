unit nextpas.core.platform.secure;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.memory;

procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);
  deprecated 'Use platform_secure_zero_memory from nextpas.core.platform.memory';

implementation

procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);
begin
  platform_secure_zero_memory(Buffer, Size);
end;

end.
