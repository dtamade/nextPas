program test_async_windows_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestAsyncFacadeReExportContract;
var
  LAsyncFacade: string;
begin
  LAsyncFacade := LoadSourceText('src/nextpas.core.async.pas');

  CheckContains(LAsyncFacade,
    'tasynccallback = nextpas.core.async.base.tasynccallback;',
    'async facade must re-export async callback type');
  CheckContains(LAsyncFacade,
    'tasynctimerhandle = nextpas.core.async.base.tasynctimerhandle;',
    'async facade must re-export async timer handle type');
  CheckContains(LAsyncFacade,
    'tasyncloop = nextpas.core.async.loop.tasyncloop;',
    'async facade must re-export async loop type');
  CheckContains(LAsyncFacade,
    'tiocompletion = nextpas.core.io.poller.tiocompletion;',
    'async facade must re-export file completion callback type');
end;

procedure TestAsyncWindowsCompileGateContract;
var
  LCompileGate: string;
begin
  LCompileGate := LoadSourceText(
    'tests/nextpas.core.async/test_async_windows_compile_gate/test_async_windows_compile_gate.lpr');

  CheckContains(LCompileGate,
    'source-contract and forced-compile only; not windows runtime evidence',
    'async Windows compile gate must declare its non-runtime truth layer');
  CheckContains(LCompileGate, 'nextpas.core.async',
    'async Windows compile gate must consume the async facade');
  CheckAbsent(LCompileGate, 'nextpas.core.async.loop',
    'async Windows compile gate must not bypass the async facade');
  CheckContains(LCompileGate, 'procedure noopiocompletion',
    'async Windows compile gate must force a concrete TIoCompletion callback');
  CheckContains(LCompileGate, 'procedure noopasynccallback',
    'async Windows compile gate must force a concrete TAsyncCallback');
  CheckContains(LCompileGate, 'lcompletion := @noopiocompletion;',
    'async Windows compile gate must bind the facade completion type');
  CheckContains(LCompileGate, 'lcallback := @noopasynccallback;',
    'async Windows compile gate must bind the facade async callback type');
  CheckContains(LCompileGate, 'lloop := tasyncloop.create(8);',
    'async Windows compile gate must create the loop through the facade type');
  CheckContains(LCompileGate, 'lloop.asyncread(0, nil, 0, 0, lcompletion, nil);',
    'async Windows compile gate must touch direct file AsyncRead');
  CheckContains(LCompileGate, 'lloop.asyncwrite(0, nil, 0, 0, lcompletion, nil);',
    'async Windows compile gate must touch direct file AsyncWrite');
  CheckContains(LCompileGate, 'lloop.asyncreadtimeout',
    'async Windows compile gate must touch file read timeout wrapper');
  CheckContains(LCompileGate, 'lloop.asyncwritetimeout',
    'async Windows compile gate must touch file write timeout wrapper');
  CheckContains(LCompileGate, 'lloop.asyncaccept',
    'async Windows compile gate must touch accept unsupported boundary');
  CheckContains(LCompileGate, 'lloop.asyncrecv',
    'async Windows compile gate must touch recv unsupported boundary');
  CheckContains(LCompileGate, 'lloop.asyncsend',
    'async Windows compile gate must touch send unsupported boundary');
  CheckContains(LCompileGate, 'lloop.poll;',
    'async Windows compile gate must touch async loop poll facade');
  CheckContains(LCompileGate, 'lloop.runonce;',
    'async Windows compile gate must touch async loop single-iteration runner');
  CheckContains(LCompileGate, 'lloop.close;',
    'async Windows compile gate must touch async loop close');
end;

begin
  T := TTestRunner.Create('nextpas.core.async.windows_contract');
  T.Run('async facade re-export contract', @TestAsyncFacadeReExportContract);
  T.Run('async Windows compile gate contract',
    @TestAsyncWindowsCompileGateContract);
  T.Summary;
end.
