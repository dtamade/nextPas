unit nextpas.core.git.native.index.base;

{$I nextpas.core.settings.inc}

{ index 基础域: 条目/文件纯数据类型与格式常量.
  依赖只向下 (L0-L1 owner + cachetree 类型). }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.cachetree;

{ Read/write support for the .git/index binary format (DIRC). Parsing
  covers versions 2, 3 and 4 including v4 prefix-compressed paths; the
  TREE cache-tree extension is parsed into the record, unknown uppercase
  extensions are skipped, mandatory lowercase extensions such as
  split-index "link" are refused because ignoring them would silently
  return wrong entries, and the trailing SHA-1 checksum is verified.
  Serialization re-emits a parsed TREE cache verbatim when present and
  stays extension-less otherwise (extensions are optional caches git
  rebuilds on demand). }

type
  TGitIndexEntry = record
    { stat data as stored by git — truncated to 32 bits per format }
    CTimeSec: Cardinal;
    CTimeNSec: Cardinal;
    MTimeSec: Cardinal;
    MTimeNSec: Cardinal;
    Dev: Cardinal;
    Ino: Cardinal;
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    Size: Cardinal;
    Oid: TGitOid;
    Stage: Byte;
    AssumeValid: Boolean;
    SkipWorktree: Boolean;
    IntentToAdd: Boolean;
    Path: string;
  end;

  TGitIndexFile = record
    Version: Cardinal;
    Entries: array of TGitIndexEntry;
    { parsed TREE extension payload; HasCacheTree=False means absent }
    CacheTree: TGitCacheTree;
    HasCacheTree: Boolean;
  end;
  TGitIndexEntryArray = array of TGitIndexEntry;

const
  CFixedV2 = 62;   // stat block (40) + oid (20) + flags (2)
  CFixedExt = 64;  // + extended flags word (v3/v4)
  CTrailerLen = GitOidRawLen;
  CModeTree = $4000;

implementation

end.
