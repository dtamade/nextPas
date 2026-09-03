unit nextpas.core.window.view.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowViewId = type UInt32;

const
  { 默认视图几何：语义化常量替代魔法数字 800/600，CONTRACT §3 单源；inline 零拷贝。
    单源：仅 WINDOW_VIEW_* 为真相，WINDOW_DEFAULT_* 归 window.base (1024/768)，禁别名污染。 }
  WINDOW_VIEW_DEFAULT_WIDTH = 800;
  WINDOW_VIEW_DEFAULT_HEIGHT = 600;

type
  TWindowViewOptions = record
    Id: TWindowViewId; // 视图标识，0 表示未分配
    Title: string;     // 视图标题
    Width: Integer;    // 宽度，默认 WINDOW_VIEW_DEFAULT_WIDTH (>=0)
    Height: Integer;   // 高度，默认 WINDOW_VIEW_DEFAULT_HEIGHT (>=0)
  end;

function DefaultWindowViewOptions: TWindowViewOptions; inline;

type
  EWindowViewError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowViewInvalidOptions = class(EWindowViewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowViewOptions: TWindowViewOptions; inline;
begin
  Result.Id := 0;
  Result.Title := '';
  Result.Width := WINDOW_VIEW_DEFAULT_WIDTH;
  Result.Height := WINDOW_VIEW_DEFAULT_HEIGHT;
end;

class function EWindowViewError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowViewInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
