unit nextpas.core.tar.intf;
{**
 * @desc Tar builder 接口契约：ITarBuilder 链式构造器。
 * 遵循 base←intf←实现←门面 依赖方向，单建 intf.pas。
 * @note 精简（2026-09-02）：链式单口 ITarBuilder 直达流式 AddEntryFromReader，
 *  消除 ITarStreamBuilder+AsStreamBuilder+TarBuilderAddFromReader 四入口与
 *  QueryInterface 仪式分发，调用 TarBuilder.Add(...).AddEntryFromReader(...).Finish
 *  一链直达；L2→L1 单向依赖 nextpas.core.io.intf(IReader)，复用 bytes.ops 单源
 *  CopyMemory/Move inline 零拷贝、64K pooled FIOBuf 于 Finish 即释 + try..finally
 *  必释资源不丢，性能/稳定性证据见 builder/writer。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

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
