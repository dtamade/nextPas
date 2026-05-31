program Llvm_property;
type
  TBox = class
  private
    FWidth, FHeight: Integer;
  public
    constructor Create(W, H: Integer);
    function GetWidth: Integer;
    procedure SetWidth(V: Integer);
    function GetHeight: Integer;
    function Area: Integer;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight;
  end;

constructor TBox.Create(W, H: Integer);
begin
  FWidth := W;
  FHeight := H;
end;

function TBox.GetWidth: Integer;
begin
  GetWidth := FWidth;
end;

procedure TBox.SetWidth(V: Integer);
begin
  FWidth := V;
end;

function TBox.GetHeight: Integer;
begin
  GetHeight := FHeight;
end;

function TBox.Area: Integer;
begin
  Area := FWidth * FHeight;
end;

var
  B: TBox;
begin
  B := TBox.Create(3, 35);
  B.Width := 7;
  Halt(B.Width + B.Height);
end.
