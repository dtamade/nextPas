unit nextpas.core.webview.utils;

{** @desc webview L3 共享工具（非 base 纯类型）：容量/路径/哈希等实现职责下沉，
       base 仅保留纯数据类型与校验；本单元薄转发 L1 text.view Owner 单源（StripLeadingSlash/StripLeadingSlashView/ViewFromPChar），
       复用 bytes.ops SliceToStr/CStrLen 单源 + TrimLeftChar 单次扫描零拷贝 view，零重复 Delete 扫描，inline 薄转发零额外调用。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.window.base;

{ 资产路径归一：剥离前导 '/'，空串保持空（bridge TryResolve 与 gtk scheme 回调同源，零重复 Delete 扫描）。
  perf: inline thin-forward L1 text.view StripLeadingSlash 单源 + SliceToStr 单次 SetString+Move；CoW 快径零分配，trim 单 alloc+Move；零 Delete 扫描；薄转发 inline 零额外调用，loop 体在 Owner 侧非 inline 避膨胀 }
function NormalizeWebviewAssetPath(const APath: string): string; inline;
{ 零拷贝视图版：TStringView 输入→输出，无堆分配，供 scheme/bridge 热点复用 TStringView 零拷贝直通（L1 text.view 单源，零堆分配，PAnsiChar→view 无 AnsiPtrToStr 中间串）。
  perf: inline thin-forward L1 text.view StripLeadingSlashView/TrimLeftChar 单源零拷贝 view 零堆分配；inline 薄转发零额外调用，loop 体在 Owner 侧非 inline 避 I-Cache 膨胀（design-conventions §2） }
function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;
{ 窗口选项单源：TWebviewOptions→TWindowOptions 薄转发 window.base.WindowOptionsCreate 8字段 inline 零拷贝，家族内 gtk/fake 统一单源零重复，bytes.ops VecGrowCapacity 单源 }
function WebviewWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;

implementation

function NormalizeWebviewAssetPath(const APath: string): string; inline;
begin
  // thin-forward L1 text.view Owner 单源 StripLeadingSlash（复用 TrimLeftChar 单次扫描 + SliceToStr 单次 SetString+Move），零重复 Delete 扫描，inline 零额外调用，loop 体在 Owner 侧非 inline
  Result := StripLeadingSlash(APath);
end;

function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
begin
  // thin-forward L1 text.view Owner 单源 StripLeadingSlashView/TrimLeftChar 零拷贝 view 零堆分配，热点 scheme/bridge 直通 ViewFromPChar 零 AnsiPtrToStr 中间串；inline 零额外调用，loop 体在 Owner 侧非 inline
  Result := StripLeadingSlashView(AView);
end;

function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;
begin
  // thin-forward L1 text.view Owner 单源 ViewFromPChar inline 零拷贝 PAnsiChar→TStringView，复用 bytes.ops.CStrLen SIMD 单源（System.StrLen），nil→Empty，无 SetString+Move 中间串，inline 零额外调用
  Result := nextpas.core.text.view.ViewFromPChar(AP);
end;

function WebviewWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  // perf: single source inline zero-copy field copy via window.base.WindowOptionsCreate，家族 gtk/fake 统一单源零重复，高级感零样板
  Result := WindowOptionsCreate(AOptions.Title, AOptions.Width, AOptions.Height,
    AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight,
    AOptions.Resizable, AOptions.Maximized);
end;

end.
