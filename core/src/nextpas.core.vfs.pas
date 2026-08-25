unit nextpas.core.vfs;

{** @desc 门面：纯 re-export + inline 转发，不含逻辑（design-conventions §2）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.intf,
  nextpas.core.vfs.memtree,
  nextpas.core.vfs.util;

type
  TEntryInfo = nextpas.core.vfs.base.TEntryInfo;
  TEntryArray = nextpas.core.vfs.base.TEntryArray;
  TStatInfo = nextpas.core.vfs.base.TStatInfo;
  IVfs = nextpas.core.vfs.intf.IVfs;
  TVfsMemEntry = nextpas.core.vfs.memtree.TVfsMemEntry;
  TVfsTreeBuilder = nextpas.core.vfs.memtree.TVfsTreeBuilder;
  TVfsVisitProc = nextpas.core.vfs.util.TVfsVisitProc;

  EVfsError = nextpas.core.vfs.errors.EVfsError;
  EVfsNotFound = nextpas.core.vfs.errors.EVfsNotFound;
  EVfsNotADirectory = nextpas.core.vfs.errors.EVfsNotADirectory;
  EVfsIsADirectory = nextpas.core.vfs.errors.EVfsIsADirectory;
  EVfsInvalidPath = nextpas.core.vfs.errors.EVfsInvalidPath;
  EVfsClosed = nextpas.core.vfs.errors.EVfsClosed;

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs; inline;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function VfsIsRoot(const APath: string): Boolean; inline;

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo; inline;
function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray; inline;
function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes; inline;
function VfsReadAllText(const AFs: IVfs; const APath: string): string; inline;
procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc); inline;

implementation

function CreateMemTreeVfs(AItems: array of TVfsMemEntry): IVfs;
begin
  Result := nextpas.core.vfs.memtree.CreateMemTreeVfs(AItems);
end;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
begin
  Result := nextpas.core.vfs.base.VfsValidPath(APath, AAllowRoot);
end;

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := nextpas.core.vfs.base.VfsIsRoot(APath);
end;

function VfsStat(const AFs: IVfs; const APath: string): TStatInfo;
begin
  Result := nextpas.core.vfs.util.VfsStat(AFs, APath);
end;

function VfsList(const AFs: IVfs; const ADirPath: string): TEntryArray;
begin
  Result := nextpas.core.vfs.util.VfsList(AFs, ADirPath);
end;

function VfsReadAllBytes(const AFs: IVfs; const APath: string): TBytes;
begin
  Result := nextpas.core.vfs.util.VfsReadAllBytes(AFs, APath);
end;

function VfsReadAllText(const AFs: IVfs; const APath: string): string;
begin
  Result := nextpas.core.vfs.util.VfsReadAllText(AFs, APath);
end;

procedure VfsWalk(const AFs: IVfs; const ARoot: string;
  const AVisit: TVfsVisitProc);
begin
  nextpas.core.vfs.util.VfsWalk(AFs, ARoot, AVisit);
end;

end.
