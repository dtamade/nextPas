unit nextpas.core.tar.intf;
{**
 * @desc Tar builder 接口契约：ITarBuilder 链式构造器。
 * 遵循 base←intf←实现←门面 依赖方向，单建 intf.pas。
 * @note 例外备案（CONTRACT §4 源契约显式备案例外）：intf 层额外依赖 L1 nextpas.core.io.intf(IReader)
 *  偏离 design-conventions base←intf 纯数据依赖，仅为 AddEntryFromReader 流式零拷贝必需；
 *  L2→L1 单向合规，复用 bytes.ops 单源 CopyMemory/Move inline 零拷贝、64K pooled FIOBuf
 *  于 Finish 即释 + try..finally 必释资源不丢，性能/稳定性证据见 builder/writer；禁止扩散至其他 intf 依赖。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf, // 例外：L1 IReader 仅为 AddEntryFromReader 流式零拷贝必需，已在 CONTRACT §4 备案（base←intf 例外，禁止扩散）
  nextpas.core.tar.base;

type
  ITarBuilder = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111111111}']
    function Add(const AName: string; const AData: TBytes): ITarBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder;
    function AddDirectory(const AName: string): ITarBuilder;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder;
    function AddEntryFromReader(const AHdr: TTarHeader; const AReader: IReader): ITarBuilder;
    function Finish: TBytes;
  end;

implementation

end.
