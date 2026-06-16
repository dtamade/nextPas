unit nextpas.core.tui.error;

{**
 * @desc TUI 模块异常层次。
 *
 * 基类 ETui 继承框架根异常 ENextPasError，便于消费方在 TUI 事件循环入口统一
 * 捕获 TUI 级失败而无需引入 terminal/widget 运行时单元。子类按场景细分，
 * 错误信息应带上下文，让消费方不读源码即可定位。
 *
 * @note 热路径绝不靠异常控制流——越界等情形走返回 nil / 边界检查，
 *       异常仅用于意外情况（违反不变量、资源失败、编程错误）。
 *}

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.exception;

type
  { TUI 模块异常基类 }
  ETui = class(ENextPasError);

  { 缓冲区错误：越界、resize 失败、尺寸不一致 }
  ETuiBuffer = class(ETui);

  { 布局错误：非法约束、求解失败 }
  ETuiLayout = class(ETui);

  { 后端错误：写失败、终端 I/O 错误、帧生命周期违规 }
  ETuiBackend = class(ETui);

  { 输入解析错误（通常非致命，记录后继续） }
  ETuiInput = class(ETui);

implementation

end.
