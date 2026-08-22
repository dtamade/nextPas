{**
 * nextpas.core.platform.ctypes - 平台无关 C 类型别名单元
 *
 * 职责：以独立单元形式导出 nextpas.core.platform.ctypes.inc 中与
 * FPC ctypes 兼容的 C 类型命名（cint/cuint32/csize_t/...），供 FFI
 * 消费者替代 RTL ctypes 单元直接导入。
 *
 * 设计：
 *   类型别名本身平台无关；此前仅由 nextpas.core.platform.posix.base
 *   宿主导出，POSIX 专属依赖使跨平台消费者无法安全取用，故拆出本单元。
 *}
unit nextpas.core.platform.ctypes;

{$I nextpas.core.settings.inc}

interface

{$I nextpas.core.platform.ctypes.inc}

implementation

end.
