unit nextpas.core.vfs.errors;

{** @desc vfs 异常层级：EVfsError(Op/Path) 及子类（Go PathError 对等物）。
  四件套归位：intf 子层（base ← intf(errors) ← 实现 ← 门面），
  与 vfs.intf 同层，不单独构成 base 层；错误分类见 CONTRACT INV-V4/V5。
  全部挂 nextpas.core.exception.Exception 根，不触碰 SysUtils。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  EVfsError = class(Exception)
  private
    FOp: string;
    FPath: string;
  public
    constructor CreateCtx(const AOp, APath, AMsg: string);
    property Op: string read FOp;
    property Path: string read FPath;
  end;

  EVfsNotFound = class(EVfsError);
  EVfsNotADirectory = class(EVfsError);
  EVfsIsADirectory = class(EVfsError);
  EVfsInvalidPath = class(EVfsError);
  EVfsClosed = class(EVfsError);

implementation

constructor EVfsError.CreateCtx(const AOp, APath, AMsg: string);
begin
  inherited Create(AMsg + ' (op=' + AOp + ', path=' + APath + ')');
  FOp := AOp;
  FPath := APath;
end;

end.
