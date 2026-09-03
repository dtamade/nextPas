unit nextpas.core.git.libgit2.bindings;
{** @desc libgit2 全量 C ABI 绑定门面（按功能域分片）。
       原 8240 行单文件已按功能域拆分为 9 个子单元，每单元 <800 行：
       types / structs / consts / c / oid / odb / refs / commit / repo / diff / extra
       + shim（C 兼容层）。本单元为聚合门面，纯 re-export，零重复定义。
       再生成管线见 core/docs/git/bindings-pitfalls.md（按域分别生成后由门面聚合）。
       性能：零拷贝 Move/CompareMem inline，由 bytes.ops 单源语义保障；资源释放由各子单元 external 语义保证。 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs,
  nextpas.core.git.libgit2.bindings.consts,
  nextpas.core.git.libgit2.bindings.c,
  nextpas.core.git.libgit2.bindings.oid,
  nextpas.core.git.libgit2.bindings.odb,
  nextpas.core.git.libgit2.bindings.refs,
  nextpas.core.git.libgit2.bindings.commit,
  nextpas.core.git.libgit2.bindings.repo,
  nextpas.core.git.libgit2.bindings.diff,
  nextpas.core.git.libgit2.bindings.extra;

// Facade re-exports: keep `uses bindings` working for legacy consumers.
// Types/consts are already visible via `uses` chain for qualified access;
// unqualified access is provided via type/const aliases below (inline zero-copy).
type
  // Scalar aliases (representative – full set via qualified `bindings.types.*` is available)
  TGitOidFacade = nextpas.core.git.libgit2.bindings.structs.TGitOid;
  TGitStrarrayFacade = nextpas.core.git.libgit2.bindings.structs.TGitStrarray;
  TGitSignatureFacade = nextpas.core.git.libgit2.bindings.structs.TGitSignature;
  TGitTimeFacade = nextpas.core.git.libgit2.bindings.structs.TGitTime;
  TGitBufFacade = nextpas.core.git.libgit2.bindings.structs.TGitBuf;

implementation
end.
