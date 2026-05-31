program InaccessibleMember;
type
  TFoo = class
  private
    FSecret: Integer;
  public
    constructor Create;
  end;
constructor TFoo.Create; begin FSecret := 42; end;
var F: TFoo;
begin
  F := TFoo.Create;
  F.FSecret := 10;
end.
