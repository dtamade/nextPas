program test_tui_examples;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test;

var
  T: TTestSuite;

function ReadLowerSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolvePath(const APathFromTest: string; const APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function DemoSource(const ADemo: string): string;
begin
  Result := ReadLowerSourceFile(ResolvePath(
    '../../../examples/nextpas.core.tui/' + ADemo + '/' + ADemo + '.lpr',
    'core/examples/nextpas.core.tui/' + ADemo + '/' + ADemo + '.lpr'));
end;

procedure CheckTokenPresent(const ASource, AToken, ALabel: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0,
    ALabel + ' must contain token: ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, ALabel: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0,
    ALabel + ' must not contain token: ' + AToken);
end;

procedure CheckNoDirectTuiImplementationImports(const ASource, ALabel: string);
begin
  CheckTokenAbsent(ASource, 'nextpas.core.tui.base', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.color', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.style', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.cell', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.buffer', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.borders', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.layout', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.terminal', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.event', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.text', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.widget.', ALabel);
end;

procedure CheckAppFirstNoRawTerminal(const ASource, ALabel: string);
begin
  CheckTokenPresent(ASource, 'class(TScreen)', ALabel);
  CheckTokenPresent(ASource, 'TApp', ALabel);
  CheckTokenPresent(ASource, 'App.Screens.Push', ALabel);
  CheckTokenPresent(ASource, 'procedure Render', ALabel);
  CheckTokenAbsent(ASource, 'nextpas.core.tui.terminal', ALabel);
  CheckTokenAbsent(ASource, 'TTerminal', ALabel);
  CheckTokenAbsent(ASource, 'EnterTui', ALabel);
  CheckTokenAbsent(ASource, 'PollEvent', ALabel);
end;

procedure TestLayoutDemoTeachesAppFirstExtPath;
var
  LSource: string;
begin
  LSource := DemoSource('demo_layout');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_layout');
  CheckAppFirstNoRawTerminal(LSource, 'demo_layout');
  CheckTokenPresent(LSource, 'procedure HandleEvent', 'demo_layout');
end;

procedure TestWidgetsDemoTeachesAppFirstFullPath;
var
  LSource: string;
begin
  LSource := DemoSource('demo_widgets');
  CheckTokenPresent(LSource, 'nextpas.core.tui.full', 'demo_widgets');
  CheckTokenPresent(LSource, 'class(TScreen)', 'demo_widgets');
  CheckTokenPresent(LSource, 'TApp', 'demo_widgets');
  CheckTokenPresent(LSource, 'App.Screens.Push', 'demo_widgets');
  CheckTokenPresent(LSource, 'procedure Render', 'demo_widgets');
  CheckTokenPresent(LSource, 'procedure HandleEvent', 'demo_widgets');
  CheckTokenPresent(LSource, 'TGauge', 'demo_widgets');
  CheckNoDirectTuiImplementationImports(LSource, 'demo_widgets');
  CheckTokenAbsent(LSource, 'TTerminal', 'demo_widgets');
  CheckTokenAbsent(LSource, 'EnterTui', 'demo_widgets');
  CheckTokenAbsent(LSource, 'BeginFrame', 'demo_widgets');
  CheckTokenAbsent(LSource, 'EndFrame', 'demo_widgets');
  CheckTokenAbsent(LSource, 'PollEvent', 'demo_widgets');
  CheckTokenAbsent(LSource, 'repeat', 'demo_widgets');
end;

procedure TestFullRenderBenchmarkUsesFullFacade;
var
  LSource: string;
begin
  LSource := ReadLowerSourceFile(ResolvePath(
    '../../../benchmarks/nextpas.core.tui/bench_render/bench_render.lpr',
    'core/benchmarks/nextpas.core.tui/bench_render/bench_render.lpr'));
  CheckTokenPresent(LSource, 'nextpas.core.tui.full', 'bench_render');
  CheckTokenPresent(LSource, 'TGauge', 'bench_render');
  CheckNoDirectTuiImplementationImports(LSource, 'bench_render');
end;

procedure TestHelloDemoTeachesAppFirstExtPath;
var
  LSource: string;
begin
  LSource := DemoSource('demo_hello');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_hello');
  CheckAppFirstNoRawTerminal(LSource, 'demo_hello');
  CheckTokenPresent(LSource, 'procedure HandleEvent', 'demo_hello');
end;

procedure TestMultiScreenDemoTeachesSharedState;
var
  LSource: string;
begin
  LSource := DemoSource('demo_multi_screen');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_multi_screen');
  CheckAppFirstNoRawTerminal(LSource, 'demo_multi_screen');
  CheckTokenPresent(LSource, 'SharedStateObject', 'demo_multi_screen');
  CheckTokenPresent(LSource, 'GetShared', 'demo_multi_screen');
end;

procedure TestPanelLayoutDemoTeachesExtPanel;
var
  LSource: string;
begin
  LSource := DemoSource('demo_panel_layout');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_panel_layout');
  CheckAppFirstNoRawTerminal(LSource, 'demo_panel_layout');
  CheckTokenPresent(LSource, 'TPanel', 'demo_panel_layout');
end;

procedure TestTaskCompletionDemoTeachesTasks;
var
  LSource: string;
begin
  LSource := DemoSource('demo_task_completion');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_task_completion');
  CheckAppFirstNoRawTerminal(LSource, 'demo_task_completion');
  CheckTokenPresent(LSource, 'Tasks', 'demo_task_completion');
end;

procedure TestThemeFocusKeybindDemoTeachesKeybind;
var
  LSource: string;
begin
  LSource := DemoSource('demo_theme_focus_keybind');
  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_theme_focus_keybind');
  CheckAppFirstNoRawTerminal(LSource, 'demo_theme_focus_keybind');
  CheckTokenPresent(LSource, 'keybind', 'demo_theme_focus_keybind');
  CheckTokenPresent(LSource, 'TTheme', 'demo_theme_focus_keybind');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.examples');
  T.Test('layout demo teaches app-first ext path', @TestLayoutDemoTeachesAppFirstExtPath);
  T.Test('widgets demo teaches app-first full path', @TestWidgetsDemoTeachesAppFirstFullPath);
  T.Test('full render benchmark uses full facade', @TestFullRenderBenchmarkUsesFullFacade);
  T.Test('hello demo teaches app-first ext path', @TestHelloDemoTeachesAppFirstExtPath);
  T.Test('multi_screen demo teaches shared state', @TestMultiScreenDemoTeachesSharedState);
  T.Test('panel_layout demo teaches ext panel', @TestPanelLayoutDemoTeachesExtPanel);
  T.Test('task_completion demo teaches tasks', @TestTaskCompletionDemoTeachesTasks);
  T.Test('theme_focus_keybind demo teaches keybind', @TestThemeFocusKeybindDemoTeachesKeybind);
  if not T.Run then Halt(1);
end.
