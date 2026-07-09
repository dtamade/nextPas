unit nextpas.core.platform.unix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.unix.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{** @desc 获取 errno 指针（通用 Unix 版本） *}
function __errno_location: PInt32; cdecl; external 'c' name '__errno_location';

{** @desc 设置信号处理动作（通用 Unix 版本）
    @param ASignal 信号编号
    @param ANewAction 新动作
    @param AOldAction 输出旧动作
    @return 0 成功 *}
function sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformUnixSigAction;
  AOldAction: PPlatformUnixSigAction): Int32; cdecl; external 'c' name 'sigaction';

{** @desc 设置信号掩码（通用 Unix 版本）
    @param AHow 操作类型
    @param ANewSet 新掩码
    @param AOldSet 输出旧掩码
    @return 0 成功 *}
function sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformUnixSignalSet;
  AOldSet: PPlatformUnixSignalSet): Int32; cdecl; external 'c' name 'sigprocmask';

{** @desc 设置条件变量时钟属性
    @param attr 条件变量属性
    @param clk_id 时钟 ID
    @return 0 成功 *}
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

{** @desc 打开动态链接库
    @param Name 库名称
    @param Flags 打开标志
    @return 库句柄，nil 失败 *}
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
{** @desc 获取动态链接库符号
    @param Lib 库句柄
    @param Name 符号名称
    @return 符号地址，nil 失败 *}
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
{** @desc 关闭动态链接库
    @param Lib 库句柄
    @return 0 成功 *}
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
{** @desc 获取动态链接错误消息
    @return 错误消息字符串 *}
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

implementation

end.
