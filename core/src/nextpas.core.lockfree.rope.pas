unit nextpas.core.lockfree.rope;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TRopeResult = (rpOk, rpNotFound, rpClosed, rpOutOfBounds);

  PRopeNode = ^TRopeNode;
  TRopeNode = record
    Left, Right: PRopeNode;
    Weight: Int32;
    Text: AnsiString;
  end;

  {** @desc Rope（大字符串数据结构）
    @details 二叉树结构，O(log n) 拼接/切片/插入/删除。
      适用场景：文本编辑器、大字符串处理、协同编辑。
  }
  TRope = class
  private
    FRoot: PRopeNode;
    FLength: Int64;
    FClosed: Int32;
    function NodeLength(ANode: PRopeNode): Int32;
    function BuildNode(const AText: AnsiString): PRopeNode;
    procedure FreeNode(ANode: PRopeNode);
    function ConcatNodes(ALeft, ARight: PRopeNode): PRopeNode;
    procedure CollectText(ANode: PRopeNode; var AResult: AnsiString);
    function SplitNode(ANode: PRopeNode; APos: Int32;
      out ALeft, ARight: PRopeNode): TRopeResult;
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(APosition: Int32; const AText: AnsiString): TRopeResult;
    function Delete(APosition, ACount: Int32): TRopeResult;
    function Substring(APosition, ACount: Int32; out AResult: AnsiString): TRopeResult;
    function CharAt(APosition: Int32; out AChar: AnsiChar): TRopeResult;
    function GetLength: Int64;
    function ToString: AnsiString;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.atomic;

function TRope.NodeLength(ANode: PRopeNode): Int32;
begin
  if ANode = nil then
    Exit(0);
  if ANode^.Left = nil then
    Exit(System.Length(ANode^.Text));
  Result := ANode^.Weight + NodeLength(ANode^.Right);
end;

function TRope.BuildNode(const AText: AnsiString): PRopeNode;
begin
  New(Result);
  Result^.Left := nil;
  Result^.Right := nil;
  Result^.Weight := System.Length(AText);
  Result^.Text := AText;
end;

procedure TRope.FreeNode(ANode: PRopeNode);
begin
  if ANode = nil then
    Exit;
  FreeNode(ANode^.Left);
  FreeNode(ANode^.Right);
  ANode^.Text := '';
  Dispose(ANode);
end;

function TRope.ConcatNodes(ALeft, ARight: PRopeNode): PRopeNode;
begin
  if ALeft = nil then
    Exit(ARight);
  if ARight = nil then
    Exit(ALeft);
  New(Result);
  Result^.Left := ALeft;
  Result^.Right := ARight;
  Result^.Weight := NodeLength(ALeft);
  Result^.Text := '';
end;

procedure TRope.CollectText(ANode: PRopeNode; var AResult: AnsiString);
begin
  if ANode = nil then
    Exit;
  if ANode^.Left = nil then
    AResult := AResult + ANode^.Text
  else
  begin
    CollectText(ANode^.Left, AResult);
    CollectText(ANode^.Right, AResult);
  end;
end;

function TRope.SplitNode(ANode: PRopeNode; APos: Int32;
  out ALeft, ARight: PRopeNode): TRopeResult;
var
  LLen: Int32;
begin
  if ANode = nil then
  begin
    ALeft := nil;
    ARight := nil;
    Exit(rpOk);
  end;
  if ANode^.Left = nil then
  begin
    LLen := System.Length(ANode^.Text);
    if APos > LLen then
    begin
      ALeft := ANode;
      ARight := nil;
      Exit(rpOk);
    end;
    if APos = 0 then
    begin
      ALeft := nil;
      ARight := ANode;
      Exit(rpOk);
    end;
    ALeft := BuildNode(Copy(ANode^.Text, 1, APos));
    ARight := BuildNode(Copy(ANode^.Text, APos + 1, LLen - APos));
    Dispose(ANode);
    Exit(rpOk);
  end;
  if APos <= ANode^.Weight then
  begin
    SplitNode(ANode^.Left, APos, ALeft, ARight);
    ARight := ConcatNodes(ARight, ANode^.Right);
    ANode^.Left := nil;
    ANode^.Right := nil;
    Dispose(ANode);
  end
  else
  begin
    SplitNode(ANode^.Right, APos - ANode^.Weight, ALeft, ARight);
    ALeft := ConcatNodes(ANode^.Left, ALeft);
    ANode^.Left := nil;
    ANode^.Right := nil;
    Dispose(ANode);
  end;
  Result := rpOk;
end;

constructor TRope.Create;
begin
  inherited Create;
  FRoot := nil;
  FLength := 0;
  FClosed := 0;
end;

destructor TRope.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TRope.Insert(APosition: Int32; const AText: AnsiString): TRopeResult;
var
  LLeft, LRight, LNew: PRopeNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rpClosed);
  if APosition < 0 then
    Exit(rpOutOfBounds);
  if APosition > FLength then
    APosition := FLength;
  if System.Length(AText) = 0 then
    Exit(rpOk);
  LNew := BuildNode(AText);
  if FRoot = nil then
  begin
    FRoot := LNew;
    FLength := System.Length(AText);
    Exit(rpOk);
  end;
  SplitNode(FRoot, APosition, LLeft, LRight);
  FRoot := ConcatNodes(ConcatNodes(LLeft, LNew), LRight);
  FLength := FLength + System.Length(AText);
  Result := rpOk;
end;

function TRope.Delete(APosition, ACount: Int32): TRopeResult;
var
  LLeft, LMid, LRight, LTemp: PRopeNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rpClosed);
  if (APosition < 0) or (ACount <= 0) then
    Exit(rpOutOfBounds);
  if APosition >= FLength then
    Exit(rpOutOfBounds);
  if APosition + ACount > FLength then
    ACount := FLength - APosition;
  SplitNode(FRoot, APosition, LLeft, LTemp);
  SplitNode(LTemp, ACount, LMid, LRight);
  FreeNode(LMid);
  FRoot := ConcatNodes(LLeft, LRight);
  FLength := FLength - ACount;
  Result := rpOk;
end;

function TRope.Substring(APosition, ACount: Int32; out AResult: AnsiString): TRopeResult;
var
  LLeft, LMid, LRight, LTemp: PRopeNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rpClosed);
  if (APosition < 0) or (ACount <= 0) then
    Exit(rpOutOfBounds);
  if APosition >= FLength then
    Exit(rpOutOfBounds);
  if APosition + ACount > FLength then
    ACount := FLength - APosition;
  AResult := '';
  SplitNode(FRoot, APosition, LLeft, LTemp);
  SplitNode(LTemp, ACount, LMid, LRight);
  CollectText(LMid, AResult);
  FRoot := ConcatNodes(ConcatNodes(LLeft, LMid), LRight);
  Result := rpOk;
end;

function CharAtNode(ANode: PRopeNode; APosition: Int32): AnsiChar;
begin
  if ANode = nil then
    Exit(#0);
  if ANode^.Left = nil then
    Result := ANode^.Text[APosition + 1]
  else if APosition < ANode^.Weight then
    Result := CharAtNode(ANode^.Left, APosition)
  else
    Result := CharAtNode(ANode^.Right, APosition - ANode^.Weight);
end;

function TRope.CharAt(APosition: Int32; out AChar: AnsiChar): TRopeResult;
begin
  if (APosition < 0) or (APosition >= FLength) then
    Exit(rpOutOfBounds);
  AChar := CharAtNode(FRoot, APosition);
  Result := rpOk;
end;

function TRope.GetLength: Int64;
begin
  Result := FLength;
end;

function TRope.ToString: AnsiString;
begin
  Result := '';
  CollectText(FRoot, Result);
end;

procedure TRope.Clear;
begin
  FreeNode(FRoot);
  FRoot := nil;
  FLength := 0;
end;

procedure TRope.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TRope.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
