{**
 * nextpas.core.gpu.canvas - GPU 画布门面（纯 re-export，零逻辑）
 * L3 薄桥门面：base←intf←impl←facade，inline 零拷贝转发，零 FFI 硬链接。
 * 消费方 uses 此门面即可；实现由 gpu.canvas.impl 承载，打包状态内聚于
 * TAtlas 实例（无全局游标），由调用方同步；对齐复用 mem.base 16px=64B。
 *}
unit nextpas.core.gpu.canvas;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.gpu.canvas.base,
  nextpas.core.gpu.canvas.intf,
  nextpas.core.gpu.canvas.impl,
  nextpas.core.graphics.base,
  nextpas.core.canvas.intf,
  nextpas.core.image.base;

type
  TAtlas = nextpas.core.gpu.canvas.base.TAtlas;
  TAtlasRegion = nextpas.core.gpu.canvas.base.TAtlasRegion;
  IGpuBatch = nextpas.core.gpu.canvas.intf.IGpuBatch;

function ScaleFactorForWindow(ADisplayScale: Single): Single; inline;
function AtlasAlloc(var AAtlas: TAtlas; AWidth, AHeight: Integer; AScale: Single): TAtlasRegion; inline;
function CreateGpuBatch(APageW, APageH: Integer): IGpuBatch; inline;

implementation

function ScaleFactorForWindow(ADisplayScale: Single): Single; inline;
begin
  Result := nextpas.core.gpu.canvas.impl.ScaleFactorForWindow(ADisplayScale);
end;

function AtlasAlloc(var AAtlas: TAtlas; AWidth, AHeight: Integer; AScale: Single): TAtlasRegion; inline;
begin
  Result := nextpas.core.gpu.canvas.impl.AtlasAlloc(AAtlas, AWidth, AHeight, AScale);
end;

function CreateGpuBatch(APageW, APageH: Integer): IGpuBatch; inline;
begin
  Result := nextpas.core.gpu.canvas.impl.CreateGpuBatch(APageW, APageH);
end;

end.
