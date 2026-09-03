unit nextpas.core.tar.log;
{**
 * @desc Tar 日志文案单源：Warn 可观测文案集中收敛，沉自 base 类型层
 *  解耦行为层职责（base 纯类型/常量，log 单源行为文案），防硬编码分散。
 *  供 reader (global pax) / writer+builder (destroy without Finish) 单源复用，
 *  不引入 FPC RTL，零依赖同模块除 base 常量语义，L2 单点。
 *}

{$I nextpas.core.settings.inc}

interface

const
  { 全局 pax 可观测 Warn 文案单源（reader 日志复用，防硬编码分散） }
  C_TAR_WARN_GLOBAL_PAX_AUTO_CLEAR = 'tar: global pax auto-cleared after single use (no guard held; hold AcquireGlobalPaxGuard IInterface to persist across Next/image, or call ClearGlobalPax explicitly)';
  C_TAR_WARN_GLOBAL_PAX_REJECTED_PREFIX = 'tar: global pax rejected unsafe name: ';
  C_TAR_WARN_GLOBAL_PAX_REJECTED_SUFFIX = ' (filtered, not persisted)';
  { 析构可观测 Warn 文案单源（writer/builder 双处析构收敛，防硬编码分立） }
  C_TAR_WARN_WRITER_DESTROYED_WITHOUT_FINISH = 'tar: writer destroyed without Finish (missing two zero blocks, data truncated; call Finish explicitly)';
  C_TAR_WARN_BUILDER_DESTROYED_WITHOUT_FINISH = 'tar: builder destroyed without Finish (missing two zero blocks, data truncated)';

implementation

end.
