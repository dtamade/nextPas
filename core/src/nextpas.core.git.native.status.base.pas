unit nextpas.core.git.native.status.base;

{$I nextpas.core.settings.inc}

{ status 基础域: 状态码/条目纯数据类型与模式类常量.
  依赖只向下 (git.base owner). }

interface

uses
  nextpas.core.git.base;

{ ── Status.Base: 纯数据类型, owner L2 git.base ── }
type
  // single source via base — eliminates L2:base vs native dual track, reuse bytes.ops inline zero-copy
  TGitStatusCode = nextpas.core.git.base.TGitStatusCode;

const
  // re-export base vocab for qualified native.status.gsc* consumers (staging facade) — inline zero-copy, no alloc
  gscUnmodified  = nextpas.core.git.base.gscUnmodified;
  gscAdded       = nextpas.core.git.base.gscAdded;
  gscModified    = nextpas.core.git.base.gscModified;
  gscDeleted     = nextpas.core.git.base.gscDeleted;
  gscTypeChanged = nextpas.core.git.base.gscTypeChanged;
  gscUnmerged    = nextpas.core.git.base.gscUnmerged;
  gscUntracked   = nextpas.core.git.base.gscUntracked;
  gscRenamed     = nextpas.core.git.base.gscRenamed;
  gscCopied      = nextpas.core.git.base.gscCopied;

type
  TGitNativeStatusEntry = record
    Path: string;
    OldPath: string;
    Similarity: Byte;
    HeadCode: TGitStatusCode;
    WorkCode: TGitStatusCode;
  end;
  TGitNativeStatusArray = array of TGitNativeStatusEntry;

const
  CModeDir = $4000;
  CModeRegular = $81A4;
  CModeExec = $81ED;
  CModeSymlink = $A000;
  CModeGitlink = $E000;
  CMaxFlattenDepth = 32;

implementation

end.
