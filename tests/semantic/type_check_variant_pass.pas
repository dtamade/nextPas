{$mode objfpc}{$H+}
program type_check_variant_pass;

{ 类型检查：变体记录 }

type
  TShapeKind = (skCircle, skRect);
  TShape = record
    case Kind: TShapeKind of
      skCircle: (Radius: Integer);
      skRect: (Width, Height: Integer);
  end;

var
  S: TShape;
begin
  S.Kind := skCircle;
  S.Radius := 5;
  if S.Radius <> 5 then Halt(1);

  S.Kind := skRect;
  S.Width := 10;
  S.Height := 20;
  if S.Width <> 10 then Halt(2);
  if S.Height <> 20 then Halt(3);
end.
