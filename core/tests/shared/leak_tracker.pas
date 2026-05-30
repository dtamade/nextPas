unit leak_tracker;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

type
  TTracked = record
  private
    FId: Int32;
  public
    class var Alive: Int32;
    class var TotalInits: Int32;
    class var TotalFinals: Int32;

    class operator Initialize(var Self: TTracked);
    class operator Finalize(var Self: TTracked);
    class operator Copy(constref Src: TTracked; var Dst: TTracked);
  end;

  TLeakSnapshot = record
    Saved: Int32;
    procedure Take;
    procedure AssertZero(const AContext: string);
  end;

function MakeTracked(AId: Int32): TTracked;

implementation

uses
  SysUtils;

class operator TTracked.Initialize(var Self: TTracked);
begin
  Self.FId := 0;
  Inc(Alive);
  Inc(TotalInits);
end;

class operator TTracked.Finalize(var Self: TTracked);
begin
  Dec(Alive);
  Inc(TotalFinals);
end;

class operator TTracked.Copy(constref Src: TTracked; var Dst: TTracked);
begin
  Dst.FId := Src.FId;
  Inc(Alive);
  Inc(TotalInits);
end;

procedure TLeakSnapshot.Take;
begin
  Saved := TTracked.Alive;
end;

procedure TLeakSnapshot.AssertZero(const AContext: string);
var LDelta: Int32;
begin
  LDelta := TTracked.Alive - Saved;
  if LDelta <> 0 then
  begin
    WriteLn('LEAK in ', AContext, ': delta=', LDelta,
      ' (alive=', TTracked.Alive, ')');
    Halt(1);
  end;
end;

function MakeTracked(AId: Int32): TTracked;
begin
  Result.FId := AId;
end;

end.
