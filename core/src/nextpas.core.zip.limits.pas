unit nextpas.core.zip.limits;

{**
 * @desc ZIP 炸弹与头部硬上限纯常量 - 单源收敛。
 *
 * 集中管理 ZIP 读端的解压上限，reader / sequential / facade / test 共享同一
 * 常量源，避免两处硬编码漂移。纯常量单元，不依赖 intf 的接口声明。
 * 零拷贝：仅常量，无分配；稳定性：常量经 checked 语义使用。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { 单条目解压默认上限：1 GiB，防 zip bomb }
  C_ZIP_DEFAULT_MAX_OUTPUT = SizeUInt(1) shl 30;
  { 描述符扫描缓冲默认上限：512 MiB，防无签名描述符全缓冲 bomb }
  C_ZIP_DEFAULT_MAX_DESCRIPTOR = SizeUInt(512) * 1024 * 1024;

implementation

end.
