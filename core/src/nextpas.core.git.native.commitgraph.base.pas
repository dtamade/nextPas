unit nextpas.core.git.native.commitgraph.base;

{$I nextpas.core.settings.inc}

{ commit-graph v1 共享基座: chunk 常量 + 对象条目 + 原始提交 + 块记录.
  依赖只向下 (git.native.base); reader/cache/writer/collect 均经此单源. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

const
  CGPH_MAGIC = $43475048;
  CGPH_VERSION: Byte = 1;
  CGPH_OID_VERSION: Byte = 1;

  CHUNK_OIDF = $4F494446;
  CHUNK_OIDL = $4F49444C;
  CHUNK_CDAT = $43444154;
  CHUNK_EDGE = $45444745;
  CHUNK_BIDX = $42494458;
  CHUNK_BDAT = $42444154;
  CHUNK_GDA2 = $47444132;
  CHUNK_GDO2 = $47444F32;

  MISSING_PARENT = $70000000;
  EDGE_LAST_MASK = $80000000;
  EDGE_INDEX_MASK = $7FFFFFFF;

type
  TGitOidArray = nextpas.core.git.native.base.TGitOidArray;

  TCommitGraphEntry = record
    Oid: TGitOid;
    TreeOid: TGitOid;
    CommitTime: Int64;
    Generation: Cardinal;
    Parents: TGitOidArray;
  end;

  TChunkRec = record
    Id: Cardinal;
    Off: SizeInt;
  end;

  TRawCommit = record
    Oid: TGitOid;
    TreeOid: TGitOid;
    CommitTime: Int64;
    Parents: TGitOidArray;
    Generation: Cardinal;
  end;
  TRawCommitArray = array of TRawCommit;

implementation

end.
