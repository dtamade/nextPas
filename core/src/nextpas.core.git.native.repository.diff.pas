unit nextpas.core.git.native.repository.diff;

{$I nextpas.core.settings.inc}

{ repository.diff 薄门面: 六入口 inline 转发至按域分片实现.
  - read: 工作区/对象内容行化 + 修订树解析.
  - hunks: Myers 行 opcodes + 合并 hunk 构建.
  - query: 修订间/工作树 diff + 补丁文本.
  - mutate: 补丁应用 + 路径检出.
  存量调用方零改动, 新代码可直引分片. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.base,
  nextpas.core.git.native.repository.diff.query,
  nextpas.core.git.native.repository.diff.mutate;

{ Diff subdomain: pure helpers + repository diff operations.
  Single-source via bytes.ops (SpanEqual), inline zero-copy for IsBinaryBytes/PathIncluded,
  TBytes->string via bytes.ops.BytesToString single source, no SysUtils. }

function RepositoryDiffEx(const AGitDir, AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff; inline;
function RepositoryDiff(const AGitDir, AOldRef, ANewRef: string): TGitDiff; inline;
function RepositoryDiffWorkingTreeEx(const AGitDir, AWorkTree, ARef: string; const AOptions: TGitDiffOptions): TGitDiff; inline;
function RepositoryDiffWorkingTree(const AGitDir, AWorkTree, ARef: string): TGitDiff; inline;
function RepositoryWorkdirPatchText(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string; inline;
procedure RepositoryApplyPatch(const AGitDir, AWorkTree, APatchText: string); inline;
procedure RepositoryCheckoutPaths(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray); inline;

implementation

function RepositoryDiffEx(const AGitDir, AOldRef, ANewRef: string; const AOptions: TGitDiffOptions): TGitDiff; inline;
begin
  Result := nextpas.core.git.native.repository.diff.query.RepositoryDiffEx(AGitDir, AOldRef, ANewRef, AOptions);
end;

function RepositoryDiff(const AGitDir, AOldRef, ANewRef: string): TGitDiff; inline;
begin
  Result := nextpas.core.git.native.repository.diff.query.RepositoryDiffEx(AGitDir, AOldRef, ANewRef, DefaultGitDiffOptions);
end;

function RepositoryDiffWorkingTreeEx(const AGitDir, AWorkTree, ARef: string; const AOptions: TGitDiffOptions): TGitDiff; inline;
begin
  Result := nextpas.core.git.native.repository.diff.query.RepositoryDiffWorkingTreeEx(AGitDir, AWorkTree, ARef, AOptions);
end;

function RepositoryDiffWorkingTree(const AGitDir, AWorkTree, ARef: string): TGitDiff; inline;
begin
  Result := nextpas.core.git.native.repository.diff.query.RepositoryDiffWorkingTreeEx(AGitDir, AWorkTree, ARef, DefaultGitDiffOptions);
end;

function RepositoryWorkdirPatchText(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray; AShowBinary: Boolean): string; inline;
begin
  Result := nextpas.core.git.native.repository.diff.query.RepositoryWorkdirPatchText(AGitDir, AWorkTree, ARevspec, APaths, AShowBinary);
end;

procedure RepositoryApplyPatch(const AGitDir, AWorkTree, APatchText: string); inline;
begin
  nextpas.core.git.native.repository.diff.mutate.RepositoryApplyPatch(AGitDir, AWorkTree, APatchText);
end;

procedure RepositoryCheckoutPaths(const AGitDir, AWorkTree, ARevspec: string; const APaths: TStringArray); inline;
begin
  nextpas.core.git.native.repository.diff.mutate.RepositoryCheckoutPaths(AGitDir, AWorkTree, ARevspec, APaths);
end;

end.
