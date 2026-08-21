program test_tui_widget_markdown;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.markdown,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestMdLineKindEnum;
begin
  Check(Ord(mlNormal) = 0, 'mlNormal should be 0');
  Check(Ord(mlH1) = 1, 'mlH1 should be 1');
  Check(Ord(mlH2) = 2, 'mlH2 should be 2');
  Check(Ord(mlH3) = 3, 'mlH3 should be 3');
  Check(Ord(mlBullet) = 4, 'mlBullet should be 4');
  Check(Ord(mlNumbered) = 5, 'mlNumbered should be 5');
  Check(Ord(mlCode) = 6, 'mlCode should be 6');
  Check(Ord(mlCodeBlock) = 7, 'mlCodeBlock should be 7');
  Check(Ord(mlHRule) = 8, 'mlHRule should be 8');
end;

procedure TestMdLineRecord;
var
  LLine: TMdLine;
begin
  LLine.Kind := mlH1;
  LLine.Text := '# Title';
  LLine.Indent := 0;
  Check(LLine.Kind = mlH1, 'Kind should be mlH1');
  Check(LLine.Text = '# Title', 'Text should be # Title');
  Check(LLine.Indent = 0, 'Indent should be 0');
end;

procedure TestMdThemeDefault;
var
  LTheme: TMdTheme;
begin
  LTheme := TMdTheme.Default;
  Check(LTheme.H1.Fg.Kind <> ckUnset, 'H1 theme should have style');
  Check(LTheme.H2.Fg.Kind <> ckUnset, 'H2 theme should have style');
  Check(LTheme.H3.Fg.Kind <> ckUnset, 'H3 theme should have style');
  Check(LTheme.Code.Fg.Kind <> ckUnset, 'Code theme should have style');
  Check(LTheme.Bullet.Fg.Kind <> ckUnset, 'Bullet theme should have style');
  Check(LTheme.HRule.Fg.Kind <> ckUnset, 'HRule theme should have style');
end;

procedure TestParseMarkdownLinesEmpty;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('');
  Check(Length(LLines) = 1, 'Empty source should produce 1 empty line');
  Check(LLines[0].Kind = mlNormal, 'Empty line should be mlNormal');
  Check(LLines[0].Text = '', 'Empty line text should be empty');
end;

procedure TestParseMarkdownLinesNormal;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('Hello World');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlNormal, 'Should be mlNormal');
  Check(LLines[0].Text = 'Hello World', 'Text should be Hello World');
end;

procedure TestParseMarkdownLinesH1;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('# Title');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlH1, 'Should be mlH1');
  Check(LLines[0].Text = 'Title', 'Text should be Title');
end;

procedure TestParseMarkdownLinesH2;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('## Subtitle');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlH2, 'Should be mlH2');
  Check(LLines[0].Text = 'Subtitle', 'Text should be Subtitle');
end;

procedure TestParseMarkdownLinesH3;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('### Section');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlH3, 'Should be mlH3');
  Check(LLines[0].Text = 'Section', 'Text should be Section');
end;

procedure TestParseMarkdownLinesBullet;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('- Item 1' + LineEnding + '- Item 2');
  Check(Length(LLines) = 2, 'Should produce 2 lines');
  Check(LLines[0].Kind = mlBullet, 'First line should be mlBullet');
  Check(LLines[1].Kind = mlBullet, 'Second line should be mlBullet');
  Check(LLines[0].Text = 'Item 1', 'First item text should be Item 1');
  Check(LLines[1].Text = 'Item 2', 'Second item text should be Item 2');
end;

procedure TestParseMarkdownLinesNumbered;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('1. First' + LineEnding + '2. Second');
  Check(Length(LLines) = 2, 'Should produce 2 lines');
  Check(LLines[0].Kind = mlNumbered, 'First line should be mlNumbered');
  Check(LLines[1].Kind = mlNumbered, 'Second line should be mlNumbered');
end;

procedure TestParseMarkdownLinesCode;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('`code`');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlNormal, 'Inline code should be mlNormal');
  Check(Pos('`', LLines[0].Text) > 0, 'Text should contain backticks');
end;

procedure TestParseMarkdownLinesCodeBlock;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('```pascal' + LineEnding + 'begin' + LineEnding + 'end.' + LineEnding + '```');
  Check(Length(LLines) > 0, 'Should produce lines');
  Check(LLines[0].Kind = mlCodeBlock, 'First line should be mlCodeBlock');
end;

procedure TestParseMarkdownLinesHRule;
var
  LLines: TMdLineArray;
begin
  LLines := ParseMarkdownLines('---');
  Check(Length(LLines) = 1, 'Should produce 1 line');
  Check(LLines[0].Kind = mlHRule, 'Should be mlHRule');
end;

procedure TestParseMarkdownLinesMultiple;
var
  LLines: TMdLineArray;
  LSource: AnsiString;
begin
  LSource := '# Title' + LineEnding +
             'Hello World' + LineEnding +
             '- Item 1' + LineEnding +
             '- Item 2' + LineEnding +
             '---';
  LLines := ParseMarkdownLines(LSource);
  Check(Length(LLines) = 5, 'Should produce 5 lines');
  Check(LLines[0].Kind = mlH1, 'First line should be mlH1');
  Check(LLines[1].Kind = mlNormal, 'Second line should be mlNormal');
  Check(LLines[2].Kind = mlBullet, 'Third line should be mlBullet');
  Check(LLines[3].Kind = mlBullet, 'Fourth line should be mlBullet');
  Check(LLines[4].Kind = mlHRule, 'Fifth line should be mlHRule');
end;

procedure TestMarkdownNew;
var
  LMarkdown: IMarkdown;
begin
  LMarkdown := TMarkdown.New('# Hello');
  Check(LMarkdown <> nil, 'New markdown should not be nil');
end;

procedure TestMarkdownWithTheme;
var
  LMarkdown: IMarkdown;
  LTheme: TMdTheme;
begin
  LMarkdown := TMarkdown.New('# Hello');
  LTheme := TMdTheme.Default;
  LMarkdown := LMarkdown.WithTheme(LTheme);
  Check(LMarkdown <> nil, 'WithTheme should return markdown');
end;

procedure TestMarkdownWithBlock;
var
  LMarkdown: IMarkdown;
  LBlock: IBlock;
begin
  LMarkdown := TMarkdown.New('# Hello');
  LBlock := TBlock.New;
  LMarkdown := LMarkdown.WithBlock(LBlock);
  Check(LMarkdown <> nil, 'WithBlock should return markdown');
end;

procedure TestMarkdownRender;
var
  LMarkdown: IMarkdown;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LMarkdown := TMarkdown.New('# Hello World');
  LArea := TRect.Make(0, 0, 20, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LMarkdown.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestMarkdownBuilderChaining;
var
  LMarkdown: IMarkdown;
  LTheme: TMdTheme;
  LBlock: IBlock;
begin
  LMarkdown := TMarkdown.New('# Hello');
  LTheme := TMdTheme.Default;
  LBlock := TBlock.New;
  LMarkdown := LMarkdown
    .WithTheme(LTheme)
    .WithBlock(LBlock);
  Check(LMarkdown <> nil, 'Builder chaining should work');
end;

{ PH33 P3：数据更新面——SetSource 原地替换源文本（渲染时重解析） }
procedure TestMarkdownSetSource;
var
  LMarkdown: IMarkdown;
  LBuffer: TBuffer;
  LAll: AnsiString;
  I: Integer;
begin
  LMarkdown := TMarkdown.New('old-line');
  LMarkdown.SetSource('fresh token xyz');
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 5));
  try
    LMarkdown.Render(TRect.Make(0, 0, 40, 5), LBuffer);
    LAll := '';
    for I := 0 to 4 do LAll := LAll + LBuffer.RowAsString(I);
    Check(Pos('fresh token xyz', LAll) > 0, 'new source rendered');
    Check(Pos('old-line', LAll) = 0, 'old source gone');
  finally
    LBuffer.Free;
  end;
end;

procedure TestMarkdownWithSourceChaining;
var LMarkdown: IMarkdown;
begin
  LMarkdown := TMarkdown.New('a').WithSource('b').WithTheme(TMdTheme.Default);
  Check(LMarkdown <> nil, 'WithSource chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.markdown');
  T.Test('TMdLineKind enum', @TestMdLineKindEnum);
  T.Test('TMdLine record', @TestMdLineRecord);
  T.Test('TMdTheme.Default', @TestMdThemeDefault);
  T.Test('ParseMarkdownLines empty', @TestParseMarkdownLinesEmpty);
  T.Test('ParseMarkdownLines normal', @TestParseMarkdownLinesNormal);
  T.Test('ParseMarkdownLines H1', @TestParseMarkdownLinesH1);
  T.Test('ParseMarkdownLines H2', @TestParseMarkdownLinesH2);
  T.Test('ParseMarkdownLines H3', @TestParseMarkdownLinesH3);
  T.Test('ParseMarkdownLines bullet', @TestParseMarkdownLinesBullet);
  T.Test('ParseMarkdownLines numbered', @TestParseMarkdownLinesNumbered);
  T.Test('ParseMarkdownLines code', @TestParseMarkdownLinesCode);
  T.Test('ParseMarkdownLines code block', @TestParseMarkdownLinesCodeBlock);
  T.Test('ParseMarkdownLines hrule', @TestParseMarkdownLinesHRule);
  T.Test('ParseMarkdownLines multiple', @TestParseMarkdownLinesMultiple);
  T.Test('TMarkdown.New', @TestMarkdownNew);
  T.Test('TMarkdown.WithTheme', @TestMarkdownWithTheme);
  T.Test('TMarkdown.WithBlock', @TestMarkdownWithBlock);
  T.Test('TMarkdown.Render', @TestMarkdownRender);
  T.Test('TMarkdown builder chaining', @TestMarkdownBuilderChaining);
  T.Test('SetSource in-place update (PH33 P3)', @TestMarkdownSetSource);
  T.Test('WithSource chaining (PH33 P3)', @TestMarkdownWithSourceChaining);
  if not T.Run then Halt(1);
end.
