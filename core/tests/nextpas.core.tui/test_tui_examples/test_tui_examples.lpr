program test_tui_examples;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

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

procedure TestLayoutDemoTeachesAppFirstExtPath;
var
  LSource: string;
begin
  LSource := ReadLowerSourceFile(ResolvePath(
    '../../../examples/nextpas.core.tui/demo_layout/demo_layout.lpr',
    'core/examples/nextpas.core.tui/demo_layout/demo_layout.lpr'));

  CheckTokenPresent(LSource, 'nextpas.core.tui.ext', 'demo_layout');
  CheckTokenPresent(LSource, 'class(TScreen)', 'demo_layout');
  CheckTokenPresent(LSource, 'TApp', 'demo_layout');
  CheckTokenPresent(LSource, 'App.Screens.Push', 'demo_layout');
  CheckTokenPresent(LSource, 'procedure Render', 'demo_layout');
  CheckTokenPresent(LSource, 'procedure HandleEvent', 'demo_layout');

  CheckTokenAbsent(LSource, 'nextpas.core.tui.terminal', 'demo_layout');
  CheckTokenAbsent(LSource, 'TTerminal', 'demo_layout');
  CheckTokenAbsent(LSource, 'EnterTui', 'demo_layout');
  CheckTokenAbsent(LSource, 'PollEvent', 'demo_layout');
end;

procedure TestWidgetsDemoTeachesAppFirstFullPath;
var
  LSource: string;
begin
  LSource := ReadLowerSourceFile(ResolvePath(
    '../../../examples/nextpas.core.tui/demo_widgets/demo_widgets.lpr',
    'core/examples/nextpas.core.tui/demo_widgets/demo_widgets.lpr'));

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

begin
  T := TTestRunner.Create('nextpas.core.tui.examples');
  T.Run('layout demo teaches app-first ext path', @TestLayoutDemoTeachesAppFirstExtPath);
  T.Run('widgets demo teaches app-first full path', @TestWidgetsDemoTeachesAppFirstFullPath);
  T.Run('full render benchmark uses full facade', @TestFullRenderBenchmarkUsesFullFacade);
  T.Summary;
end.
