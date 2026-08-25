{**
 * nextpas.core.diff.base - diff 家族基本类型与行切分工具
 *
 * 类型词汇表：TDiffLineAction 描述单行动作；TDiffEdit 是 Myers 输出的
 * 编辑脚本元素（索引 0-based）；TDiffHunk/TDiffHunkLine 是 unified 层的
 * 结构化 hunk。SplitLines/JoinLines 提供 \n、\r\n 与末行无换行的安全
 * 往返；空文本约定为 0 行。
 *}

unit nextpas.core.diff.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  { Action of a single line inside an edit script or a parsed hunk }
  TDiffLineAction = (daEqual, daDelete, daInsert);

  { One element of a Myers edit script; indexes are 0-based into the
    input arrays. daEqual fills both, daDelete only OldIndex,
    daInsert only NewIndex (the unused side is -1). }
  TDiffEdit = record
    Action: TDiffLineAction;
    OldIndex: Integer;
    NewIndex: Integer;
  end;

  TDiffEditArray = array of TDiffEdit;

  { One line inside a unified hunk }
  TDiffHunkLine = record
    Action: TDiffLineAction;
    OldIndex: Integer;
    NewIndex: Integer;
    Text: string;
  end;

  TDiffHunkLineArray = array of TDiffHunkLine;

  { A unified hunk; start numbers are 1-based as in the patch text,
    with the empty-side convention 0,0. Counts include context lines. }
  TDiffHunk = record
    OldStart: Integer;
    OldCount: Integer;
    NewStart: Integer;
    NewCount: Integer;
    Lines: TDiffHunkLineArray;
  end;

  TDiffHunkArray = array of TDiffHunk;

{ Split text into lines (without EOL). Handles "\n" and "\r\n"; a final
  line without EOL is still produced. Empty text yields zero lines. }
function DiffSplitLines(const AText: string): TStringArray;

{ Join lines appending LF after every line (POSIX text file convention).
  Zero lines yield the empty string. }
function DiffJoinLines(const ALines: TStringArray): string;

implementation

function DiffSplitLines(const AText: string): TStringArray;
var
  Count, Start, I: Integer;
begin
  Result := nil;
  Count := 0;
  if AText = '' then
    Exit;
  Start := 1;
  for I := 1 to Length(AText) do
    if AText[I] = #10 then
    begin
      SetLength(Result, Count + 1);
      // strip a preceding CR so both LF and CRLF input normalize
      if (I > Start) and (AText[I - 1] = #13) then
        Result[Count] := Copy(AText, Start, I - Start - 1)
      else
        Result[Count] := Copy(AText, Start, I - Start);
      Inc(Count);
      Start := I + 1;
    end;
  if Start <= Length(AText) then
  begin
    SetLength(Result, Count + 1);
    Result[Count] := Copy(AText, Start, Length(AText) - Start + 1);
  end;
end;

function DiffJoinLines(const ALines: TStringArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ALines) - 1 do
    Result := Result + ALines[I] + #10;
end;

end.
