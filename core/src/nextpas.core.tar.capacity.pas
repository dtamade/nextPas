unit nextpas.core.tar.capacity;
{**
 * @desc Tar 容量与对齐专用内核：4K 对齐与阈值分叉集中收敛，L2 单源。
 * 依赖 nextpas.core.base + nextpas.core.bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝单源，无 FPC RTL 直引。
 * 阈值分叉由代码层固化：builder floor 4K（小包友好，修复原 64K 对 512B 128倍过度预分配，内存驻留降低）/ IOBuf 4K~1M clamp，高水位池化零漂移。
 * 被 nextpas.core.tar.base 薄转发，门面经 nextpas.core.tar re-export。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

const
  C_TAR_CAP_ALIGN = 4096;
  C_TAR_BUILDER_INITIAL_CAPACITY = 4096; // 4K floor，单条目 512B 仅 8倍，按需 4K 对齐零拷贝，修复 64K 128倍驻留
  C_TAR_IOBUF_INIT = 4096;
  C_TAR_IOBUF_MAX = 1048576; // 1M clamp，单分发 high-water，消除 1M 拆 16次 WriteChecked 抖动

function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;

implementation

function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
begin
  // 单源 4K 对齐经 bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，无截断，32/64位安全
  Result := AlignUp4K(AValue);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // 单源容量策略：预估+两零块 1024，floor 4K，4K 对齐经 TarCapacityAlign4K→bytes.ops.AlignUp4K inline 零拷贝（阈值分叉已固化于 capacity 常量）
  if AEstimatedTotal = 0 then
    Exit(C_TAR_BUILDER_INITIAL_CAPACITY);
  if AEstimatedTotal > High(SizeUInt) - 2 * 512 then
    Exit(High(SizeUInt));
  Result := AEstimatedTotal + 2 * 512;
  if Result < C_TAR_BUILDER_INITIAL_CAPACITY then
    Result := C_TAR_BUILDER_INITIAL_CAPACITY;
  Result := TarCapacityAlign4K(Result);
end;

function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;
begin
  // 单源 I/O 缓冲策略：4K~1M clamp + AlignUp4K inline 零拷贝，高水位 1M 单分发，消除 1M 拆 16次抖动
  if ASize <= Int64(C_TAR_IOBUF_INIT) then
    Exit(C_TAR_IOBUF_INIT);
  if ASize <= Int64(C_TAR_IOBUF_MAX) then
    Exit(TarCapacityAlign4K(SizeUInt(ASize)));
  Result := C_TAR_IOBUF_MAX;
end;

end.
