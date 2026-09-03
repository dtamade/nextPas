unit nextpas.core.tar.capacity;
{** @desc Tar 容量与对齐专用内核：AlignUp4K 经 bytes.ops.AlignUp4K inline 零拷贝，阈值固化于 base，capacity→base 薄转发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base;

function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;

implementation

function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
begin
  // 单源 4K 对齐经 bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，无截断，32/64位安全（经 base 单源复用 bytes.ops，capacity→base 单向）
  Result := nextpas.core.tar.base.TarCapacityAlign4K(AValue);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // 薄转发 base 单源：预估+两零块 4K 对齐经 base.TarBuilderCapacityFor→bytes.ops.AlignUp4K inline 零拷贝，capacity→base 单向零漂移
  Result := nextpas.core.tar.base.TarBuilderCapacityFor(AEstimatedTotal);
end;

function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;
begin
  // 薄转发 base 单源：4K~1M clamp + AlignUp4K inline 零拷贝，capacity→base 单向
  Result := nextpas.core.tar.base.TarIOBufCapacityFor(ASize);
end;

end.
