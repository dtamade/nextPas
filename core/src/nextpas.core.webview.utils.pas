unit nextpas.core.webview.utils;

{** @desc webview L3 共享工具：资产路径归一与窗口选项单源转发。
       thin-forward 至 L1 text.view / L2 window.base 单源，inline 零拷贝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.window.base;

{ 资产路径归一：剥离前导 '/'，空串保持空（String 版 SliceToStr 单次拷贝，CoW 快径零分配） }
function NormalizeWebviewAssetPath(const APath: string): string; inline;
{ 零拷贝视图版：TStringView 零堆分配直通 }
function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
{ PAnsiChar → TStringView 零拷贝（bytes.ops.CStrLen 单源） }
function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;
{ 窗口选项单源：TWebviewOptions → TWindowOptions 8字段 inline 零拷贝 }
function WebviewWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;

implementation

function NormalizeWebviewAssetPath(const APath: string): string; inline;
begin
  Result := StripLeadingSlash(APath);
end;

function NormalizeWebviewAssetView(const AView: TStringView): TStringView; inline;
begin
  Result := StripLeadingSlashView(AView);
end;

function ViewFromPChar(const AP: PAnsiChar): TStringView; inline;
begin
  Result := nextpas.core.text.view.ViewFromPChar(AP);
end;

function WebviewWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  Result := WindowOptionsCreate(AOptions.Title, AOptions.Width, AOptions.Height,
    AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight,
    AOptions.Resizable, AOptions.Maximized);
end;

end.
