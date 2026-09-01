unit nextpas.core.tar.intf;
{**
 * @desc Tar builder 接口契约：ITarBuilder 链式构造器。
 * 遵循 base←intf←实现←门面 依赖方向，单建 intf.pas。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base;

type
  ITarBuilder = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111111111}']
    function Add(const AName: string; const AData: TBytes): ITarBuilder;
    function AddWithOptions(const AName: string; const AData: TBytes; const AOpts: TTarAddOptions): ITarBuilder;
    function AddDirectory(const AName: string): ITarBuilder;
    function AddDirectoryWithOptions(const AName: string; const AOpts: TTarAddOptions): ITarBuilder;
    function AddEntry(const AHdr: TTarHeader; const AData: TBytes): ITarBuilder;
    function Finish: TBytes;
  end;

implementation

end.
