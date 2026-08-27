unit nextpas.core.window.wasm.ffi;

{** @desc WASM canvas 后端的 ABI 声明层。
       只含浏览器/ Emscripten 环境的最小 canvas/Js 句柄类型与
       函数指针变量——无逻辑、无 external；绑定真相归 wasm.loader
       （经 nextpas.core.platform.dl 动态装载或 wasm import 映射）。

       覆盖 import 形态（wasm32-unknown-emscripten 典型导出）：
       env.emscripten_get_canvas_element_size
       env.emscripten_set_canvas_element_size
       env.emscripten_get_element_css_size
       env.emscripten_set_element_css_size
       env.emscripten_get_device_pixel_ratio

       调用约定统一 cdecl；本单元禁止 uses 家族其他单元（INV-3/5）。 *}

{$I nextpas.core.settings.inc}

interface

type
  { WASM 侧 canvas 句柄（DOM <canvas> element id 的不透明指针形态；
    实际为 Js 侧字符串指针或元素指针，Pascal 侧不解释内容） }
  TWasmCanvasHandle = type Pointer;

  { Emscripten 结果码（EMS_CRIPTEN_RESULT） }
  TEmscriptenResult = Int32;

const
  EMSCRIPTEN_RESULT_SUCCESS = 0;

var
  { ---- Emscripten canvas env imports（wasm.ffi 仅声明，不链接） ---- }
  emscripten_get_canvas_element_size: function(
    ATarget: PAnsiChar; AWidth, AHeight: PInt32): TEmscriptenResult; cdecl;
  emscripten_set_canvas_element_size: function(
    ATarget: PAnsiChar; AWidth, AHeight: Int32): TEmscriptenResult; cdecl;
  emscripten_get_element_css_size: function(
    ATarget: PAnsiChar; AWidth, AHeight: PDouble): TEmscriptenResult; cdecl;
  emscripten_set_element_css_size: function(
    ATarget: PAnsiChar; AWidth, AHeight: Double): TEmscriptenResult; cdecl;
  emscripten_get_device_pixel_ratio: function: Double; cdecl;

implementation

end.
