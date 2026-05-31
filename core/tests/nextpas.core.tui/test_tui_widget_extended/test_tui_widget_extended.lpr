program test_tui_widget_extended;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.tree,
  nextpas.core.tui.widget.dialog,
  nextpas.core.tui.widget.menu,
  nextpas.core.testing;
var T: TTestRunner;

{ === TTree === }
procedure TestTreeRender;
var LTree: TTree; LState: TTreeState; LBuf: TBuffer; LLines: TBufferLines;
begin
  LTree := TTree.Create([
    TTreeNode.Make('Root').WithChildren([
      TTreeNode.Make('Child 1'),
      TTreeNode.Make('Child 2')
    ])
  ]);
  LState := TTreeState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 20, 5), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('Root', LLines[0]) > 0, 'root visible');
  finally LBuf.Free; end;
end;

{ === TDialog === }
procedure TestDialogRender;
var LD: TDialog; LBuf: TBuffer; LLines: TBufferLines;
begin
  LD := TDialog.Create('Confirm', 'Are you sure?');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    LD.Render(TRect.Make(0, 0, 30, 10), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('Confirm', LLines[0]) > 0, 'title visible');
  finally LBuf.Free; end;
end;

{ === TMenu === }
procedure TestMenuRender;
var LM: TMenu; LState: TMenuState; LBuf: TBuffer; LLines: TBufferLines;
begin
  LM := TMenu.Create([
    TMenuItem.Action('Open'),
    TMenuItem.Action('Save'),
    TMenuItem.Separator,
    TMenuItem.Action('Quit')
  ]);
  LState.Selected := 0;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 6));
  try
    LM.RenderStateful(TRect.Make(0, 0, 20, 6), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('Open', LLines[0]) > 0, 'Open visible');
    Check(Pos('Save', LLines[1]) > 0, 'Save visible');
    Check(Pos('Quit', LLines[3]) > 0, 'Quit visible');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.extended');
  T.Run('tree render', @TestTreeRender);
  T.Run('dialog render', @TestDialogRender);
  T.Run('menu render', @TestMenuRender);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
