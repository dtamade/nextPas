{**
 * nextpas.core.canvas.base - 画布 L1 值类型底座（零堆，零 L2 依赖）
 * 仅含跨层复用的枚举/常量，保持 L1 graphics.base 零依赖，intf 复用。
 *}
unit nextpas.core.canvas.base;

{$mode objfpc}{$H+}

interface

type
  TFilterQuality = (fqNearest, fqLinear, fqCubic);

implementation

end.
