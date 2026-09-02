unit nextpas.core.tar.capacity;
{**
 * @desc Tar 容量与对齐专用内核：4K 对齐与阈值分叉集中收敛，L2 单源。
 * 依赖 nextpas.core.base + nextpas.core.tar.base（阈值常量与 AlignUp4K 单源于 base 经 nextpas.core.bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，base 纯度：capacity→base 单向，base 零依赖同模块文件守四件套，无常量薄别名双路径）+ 无 FPC RTL 直引。
 * 阈值分叉由代码层固化：builder floor 4K（小包友好，修复原 64K 对 512B 128倍过度预分配，内存驻留降低）/ IOBuf 4K~1M clamp，高水位池化零漂移，单源于 base 常量。
 * 仅供 builder/writer/fs 受信 implementation uses 单源复用（函数经 base 薄转发 inline 零拷贝单源，base 已纯化零依赖 capacity，门面经 nextpas.core.tar.base 常量/函数单源 re-export，经 bytes.ops 单源）。
 *}

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
