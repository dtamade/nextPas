unit nextpas.core.diff;
{**
 * @desc diff 门面：Myers 行级编辑脚本 + unified patch 编解码。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.diff.base,
  nextpas.core.diff.myers,
  nextpas.core.diff.unified;

type
  TDiffLineAction = nextpas.core.diff.base.TDiffLineAction;
  TDiffEdit = nextpas.core.diff.base.TDiffEdit;
  TDiffEditArray = nextpas.core.diff.base.TDiffEditArray;
  TDiffHunkLine = nextpas.core.diff.base.TDiffHunkLine;
  TDiffHunkLineArray = nextpas.core.diff.base.TDiffHunkLineArray;
  TDiffHunk = nextpas.core.diff.base.TDiffHunk;
  TDiffHunkArray = nextpas.core.diff.base.TDiffHunkArray;

function DiffLines(const AOld, ANew: TStringArray): TDiffEditArray; inline;
function BuildHunks(const AEdits: TDiffEditArray;
  const AOld, ANew: TStringArray; AContext: Integer): TDiffHunkArray; inline;
function EmitUnifiedHunks(const AHunks: TDiffHunkArray): string; inline;
function EmitUnified(const AOld, ANew: TStringArray;
  AContext: Integer = 3): string; inline;
function ParseUnified(const AText: string): TDiffHunkArray; inline;
function DiffSplitLines(const AText: string): TStringArray; inline;
function DiffJoinLines(const ALines: TStringArray): string; inline;

implementation

function DiffLines(const AOld, ANew: TStringArray): TDiffEditArray;
begin
  Result := nextpas.core.diff.myers.DiffLines(AOld, ANew);
end;

function BuildHunks(const AEdits: TDiffEditArray;
  const AOld, ANew: TStringArray; AContext: Integer): TDiffHunkArray;
begin
  Result := nextpas.core.diff.unified.BuildHunks(AEdits, AOld, ANew, AContext);
end;

function EmitUnifiedHunks(const AHunks: TDiffHunkArray): string;
begin
  Result := nextpas.core.diff.unified.EmitUnifiedHunks(AHunks);
end;

function EmitUnified(const AOld, ANew: TStringArray;
  AContext: Integer = 3): string;
begin
  Result := nextpas.core.diff.unified.EmitUnified(AOld, ANew, AContext);
end;

function ParseUnified(const AText: string): TDiffHunkArray;
begin
  Result := nextpas.core.diff.unified.ParseUnified(AText);
end;

function DiffSplitLines(const AText: string): TStringArray;
begin
  Result := nextpas.core.diff.base.DiffSplitLines(AText);
end;

function DiffJoinLines(const ALines: TStringArray): string;
begin
  Result := nextpas.core.diff.base.DiffJoinLines(ALines);
end;

end.
