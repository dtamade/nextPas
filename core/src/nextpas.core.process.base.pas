unit nextpas.core.process.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base;

type
  TProcessResult = record
    ExitCode: Integer;
    StdOut: string;
    StdErr: string;
    Success: Boolean;
  end;

  TProcessOptions = record
    WorkDir: string;
    Env: TStringArray;
    MergeStdErr: Boolean;
  end;

const
  DEFAULT_PROCESS_OPTIONS: TProcessOptions = (
    WorkDir: '';
    Env: nil;
    MergeStdErr: False;
  );

implementation

end.
