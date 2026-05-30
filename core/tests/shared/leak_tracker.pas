unit leak_tracker;

{$mode objfpc}{$H+}

interface

type
  ITracked = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetId: Int32;
  end;

  TLeakSnapshot = Int32;

var
  GTrackedAlive: Int32;

function MakeTracked(AId: Int32): ITracked;
function SnapTake: TLeakSnapshot; inline;
procedure SnapAssert(const ASnap: TLeakSnapshot; const AContext: string);

implementation

uses
  SysUtils;

type
  TTrackedImpl = class(TInterfacedObject, ITracked)
  private
    FId: Int32;
  public
    constructor Create(AId: Int32);
    destructor Destroy; override;
    function GetId: Int32;
  end;

constructor TTrackedImpl.Create(AId: Int32);
begin
  inherited Create;
  FId := AId;
  InterlockedIncrement(GTrackedAlive);
end;

destructor TTrackedImpl.Destroy;
begin
  InterlockedDecrement(GTrackedAlive);
  inherited Destroy;
end;

function TTrackedImpl.GetId: Int32;
begin
  Result := FId;
end;

function MakeTracked(AId: Int32): ITracked;
begin
  Result := TTrackedImpl.Create(AId);
end;

function SnapTake: TLeakSnapshot;
begin
  Result := GTrackedAlive;
end;

procedure SnapAssert(const ASnap: TLeakSnapshot; const AContext: string);
var LDelta: Int32;
begin
  LDelta := GTrackedAlive - ASnap;
  if LDelta <> 0 then
  begin
    WriteLn('LEAK in ', AContext, ': delta=', LDelta,
      ' (alive=', GTrackedAlive, ')');
    Halt(1);
  end;
end;

end.
