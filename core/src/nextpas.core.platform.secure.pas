unit nextpas.core.platform.secure;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.memory;

{** @desc 安全清零内存区域（已废弃，请使用 platform_secure_zero_memory）
    @param Buffer 内存指针
    @param Size 字节数 *}
procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);
  deprecated 'Use platform_secure_zero_memory from nextpas.core.platform.memory';

implementation

procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);
begin
  platform_secure_zero_memory(Buffer, Size);
end;

end.
