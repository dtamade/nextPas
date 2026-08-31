program demo_pure;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.fs,
  nextpas.core.git.factory,
  nextpas.core.git.intf;

function BytesOfString(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

var
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LTmp: string;
  LStatuses: TStringArray;
  LHead: IGitReference;
  I: Integer;
begin
  LTmp := PathJoin([GetTempDir, 'nextpas_demo_pure_' + IntToStr(GetProcessID)]);
  RemoveAll(LTmp);
  MkdirAll(LTmp);
  try
    LMgr := NewGitManager(gbNative);
    LMgr.Initialize;
    LRepo := LMgr.InitRepository(LTmp, False);
    WriteLn('init: ', LTmp);
    WriteLn('IsRepository: ', LMgr.IsRepository(LTmp));

    WriteFile(PathJoin([LTmp, 'README.md']), BytesOfString('# Demo Pure' + LineEnding + 'hello pure backend' + LineEnding), PermDefault);
    WriteLn('wrote README.md');

    LStatuses := LRepo.Status;
    WriteLn('Status count: ', Length(LStatuses));
    for I := 0 to High(LStatuses) do
      WriteLn('  ', LStatuses[I]);

    // detailed flags
    WriteLn('StatusEntries:');
    // show entry flags via base
    try
      LHead := LRepo.Head;
      WriteLn('Head.ShortName: ', LHead.ShortName);
      WriteLn('Head.Target: ', LHead.TargetOIDString);
    except
      on E: Exception do
        WriteLn('Head not ready (empty repo, no commit yet): ', E.Message, ' ShortName fallback: ', LRepo.CurrentBranch);
    end;

  finally
    RemoveAll(LTmp);
    WriteLn('cleaned: ', LTmp);
  end;
end.
