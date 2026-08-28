unit nextpas.core.audio.studio.project;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.studio.intf;

type
  TStudioProject = class(TInterfacedObject, IStudioProject)
  private
    FName: string;
    FBpm: Double;
    FFormat: TAudioFormat;
    function GetName: string;
    procedure SetName(const AName: string);
    function GetBpm: Double;
    procedure SetBpm(ABpm: Double);
  public
    constructor Create(const AName: string; ABpm: Double; const AFormat: TAudioFormat);
  end;

function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject;

implementation

constructor TStudioProject.Create(const AName: string; ABpm: Double; const AFormat: TAudioFormat);
begin
  inherited Create;
  FName := AName;
  if ABpm <= 0 then FBpm := 120 else FBpm := ABpm;
  FFormat := AFormat;
end;

function TStudioProject.GetName: string; begin Result := FName; end;
procedure TStudioProject.SetName(const AName: string); begin FName := AName; end;
function TStudioProject.GetBpm: Double; begin Result := FBpm; end;
procedure TStudioProject.SetBpm(ABpm: Double); begin if ABpm > 0 then FBpm := ABpm; end;

function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject;
begin
  Result := TStudioProject.Create(AName, ABpm, AFormat);
end;

end.
