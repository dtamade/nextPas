unit nextpas.core.xml.dom;
{**
 * @desc XML DOM 树构建器，基于 TXmlReader 解析构建节点树。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.xml.base,
  nextpas.core.xml.reader;

type
  TXmlNode = class;
  TXmlNodeArray = array of TXmlNode;

  TXmlNodeKind = (xnkElement, xnkText, xnkCData, xnkComment, xnkPI, xnkDocument);

  TXmlNode = class
  private
    FKind: TXmlNodeKind;
    FName: TXmlName;
    FValue: string;
    FAttributes: TXmlAttributeArray;
    FChildren: TXmlNodeArray;
    FChildCount: Integer;
    FParent: TXmlNode;
    procedure Grow;
  public
    constructor Create(AKind: TXmlNodeKind);
    destructor Destroy; override;
    procedure AddChild(ANode: TXmlNode);
    function FindChild(const AName: string): TXmlNode;
    function FindChildren(const AName: string): TXmlNodeArray;
    function GetAttr(const AName: string; const ADefault: string = ''): string;
    function Text: string;
    function ChildCount: Integer;
    property Kind: TXmlNodeKind read FKind;
    property Name: TXmlName read FName write FName;
    property Value: string read FValue write FValue;
    property Attributes: TXmlAttributeArray read FAttributes write FAttributes;
    property Children: TXmlNodeArray read FChildren;
    property Parent: TXmlNode read FParent;
  end;

  TXmlDocument = class(TXmlNode)
  private
    FRoot: TXmlNode;
  public
    class function Parse(const AInput: string): TXmlDocument; static;
    destructor Destroy; override;
    function Root: TXmlNode;
    function SelectPath(const APath: string): TXmlNodeArray;
  end;

implementation

{ TXmlNode }

constructor TXmlNode.Create(AKind: TXmlNodeKind);
begin
  inherited Create;
  FKind := AKind;
  FName.Prefix := '';
  FName.Local := '';
  FValue := '';
  FChildCount := 0;
  FParent := nil;
  SetLength(FChildren, 0);
  SetLength(FAttributes, 0);
end;

destructor TXmlNode.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to FChildCount - 1 do
    FChildren[LI].Free;
  inherited;
end;

procedure TXmlNode.Grow;
begin
  if FChildCount >= Length(FChildren) then
  begin
    if Length(FChildren) = 0 then
      SetLength(FChildren, 8)
    else
      SetLength(FChildren, Length(FChildren) * 2);
  end;
end;

procedure TXmlNode.AddChild(ANode: TXmlNode);
begin
  Grow;
  FChildren[FChildCount] := ANode;
  ANode.FParent := Self;
  Inc(FChildCount);
end;

function TXmlNode.FindChild(const AName: string): TXmlNode;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 0 to FChildCount - 1 do
    if (FChildren[LI].FKind = xnkElement) and (FChildren[LI].FName.Local = AName) then
    begin
      Result := FChildren[LI];
      Exit;
    end;
end;

function TXmlNode.FindChildren(const AName: string): TXmlNodeArray;
var
  LI, LCount: Integer;
begin
  LCount := 0;
  SetLength(Result, FChildCount);
  for LI := 0 to FChildCount - 1 do
    if (FChildren[LI].FKind = xnkElement) and (FChildren[LI].FName.Local = AName) then
    begin
      Result[LCount] := FChildren[LI];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function TXmlNode.GetAttr(const AName: string; const ADefault: string): string;
var
  LI: Integer;
begin
  for LI := 0 to High(FAttributes) do
    if FAttributes[LI].Name.Local = AName then
    begin
      Result := FAttributes[LI].Value;
      Exit;
    end;
  Result := ADefault;
end;

function TXmlNode.Text: string;
var
  LI: Integer;
begin
  Result := '';
  if (FKind = xnkText) or (FKind = xnkCData) then
  begin
    Result := FValue;
    Exit;
  end;
  for LI := 0 to FChildCount - 1 do
    if (FChildren[LI].FKind = xnkText) or (FChildren[LI].FKind = xnkCData) then
      Result := Result + FChildren[LI].FValue
    else if FChildren[LI].FKind = xnkElement then
      Result := Result + FChildren[LI].Text;
end;

function TXmlNode.ChildCount: Integer;
begin
  Result := FChildCount;
end;

{ TXmlDocument }

class function TXmlDocument.Parse(const AInput: string): TXmlDocument;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LDoc: TXmlDocument;
  LCurrent: TXmlNode;
  LChild: TXmlNode;
  LI: Integer;
  LRootCount: Integer;
begin
  LDoc := TXmlDocument.Create(xnkDocument);
  LCurrent := LDoc;
  LRootCount := 0;
  LReader := TXmlReader.Create(AInput);
  try
    while LReader.Next(LTok) do
    begin
      case LTok.Kind of
        xtkStartElement:
        begin
          { HIGH 5 fix: detect multiple root elements }
          if LCurrent = LDoc then
          begin
            Inc(LRootCount);
            if LRootCount > 1 then
            begin
              LDoc.Free;
              raise EXmlError.Create('Multiple root elements', LReader.Position);
            end;
          end;
          LChild := TXmlNode.Create(xnkElement);
          LChild.FName := LTok.Name;
          LChild.FAttributes := LTok.Attributes;
          LCurrent.AddChild(LChild);
          LCurrent := LChild;
        end;
        xtkEndElement:
        begin
          if LCurrent.FParent <> nil then
            LCurrent := LCurrent.FParent;
        end;
        xtkEmptyElement:
        begin
          { HIGH 5 fix: detect multiple root elements }
          if LCurrent = LDoc then
          begin
            Inc(LRootCount);
            if LRootCount > 1 then
            begin
              LDoc.Free;
              raise EXmlError.Create('Multiple root elements', LReader.Position);
            end;
          end;
          LChild := TXmlNode.Create(xnkElement);
          LChild.FName := LTok.Name;
          LChild.FAttributes := LTok.Attributes;
          LCurrent.AddChild(LChild);
        end;
        xtkText:
        begin
          LChild := TXmlNode.Create(xnkText);
          LChild.FValue := LTok.Value;
          LCurrent.AddChild(LChild);
        end;
        xtkCData:
        begin
          LChild := TXmlNode.Create(xnkCData);
          LChild.FValue := LTok.Value;
          LCurrent.AddChild(LChild);
        end;
        xtkComment:
        begin
          LChild := TXmlNode.Create(xnkComment);
          LChild.FValue := LTok.Value;
          LCurrent.AddChild(LChild);
        end;
        xtkProcessingInstr:
        begin
          LChild := TXmlNode.Create(xnkPI);
          LChild.FName := LTok.Name;
          LChild.FValue := LTok.Value;
          LCurrent.AddChild(LChild);
        end;
      end; { case }
    end;
    if LReader.HasError then
    begin
      LDoc.Free;
      raise EXmlError.Create(LReader.GetError, LReader.Position);
    end;
  finally
    LReader.Free;
  end;
  { Find root element }
  LDoc.FRoot := nil;
  if LDoc.FChildCount > 0 then
  begin
    LChild := nil;
    for LI := 0 to LDoc.FChildCount - 1 do
      if LDoc.FChildren[LI].FKind = xnkElement then
      begin
        LChild := LDoc.FChildren[LI];
        Break;
      end;
    LDoc.FRoot := LChild;
  end;
  Result := LDoc;
end;

destructor TXmlDocument.Destroy;
begin
  inherited;
end;

function TXmlDocument.Root: TXmlNode;
begin
  Result := FRoot;
end;

function TXmlDocument.SelectPath(const APath: string): TXmlNodeArray;
var
  LParts: array of string;
  LPartCount: Integer;
  LI, LJ, LStart: Integer;
  LCurrent: TXmlNodeArray;
  LNext: TXmlNodeArray;
  LNextCount: Integer;
  LNode: TXmlNode;
begin
  { Split path by '/' }
  LPartCount := 0;
  SetLength(LParts, 16);
  LStart := 1;
  if (Length(APath) > 0) and (APath[1] = '/') then
    LStart := 2;
  LI := LStart;
  while LI <= Length(APath) do
  begin
    if APath[LI] = '/' then
    begin
      if LI > LStart then
      begin
        if LPartCount >= Length(LParts) then
          SetLength(LParts, Length(LParts) * 2);
        LParts[LPartCount] := Copy(APath, LStart, LI - LStart);
        Inc(LPartCount);
      end;
      LStart := LI + 1;
    end;
    Inc(LI);
  end;
  if LStart <= Length(APath) then
  begin
    if LPartCount >= Length(LParts) then
      SetLength(LParts, Length(LParts) * 2);
    LParts[LPartCount] := Copy(APath, LStart, Length(APath) - LStart + 1);
    Inc(LPartCount);
  end;

  if LPartCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  { Start from root }
  if FRoot = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  { First part must match root }
  if FRoot.FName.Local <> LParts[0] then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LCurrent, 1);
  LCurrent[0] := FRoot;

  { Navigate remaining parts }
  for LI := 1 to LPartCount - 1 do
  begin
    LNextCount := 0;
    SetLength(LNext, Length(LCurrent) * 4);
    for LJ := 0 to High(LCurrent) do
    begin
      LNode := LCurrent[LJ];
      for LStart := 0 to LNode.FChildCount - 1 do
        if (LNode.FChildren[LStart].FKind = xnkElement) and
           (LNode.FChildren[LStart].FName.Local = LParts[LI]) then
        begin
          if LNextCount >= Length(LNext) then
            SetLength(LNext, Length(LNext) * 2);
          LNext[LNextCount] := LNode.FChildren[LStart];
          Inc(LNextCount);
        end;
    end;
    SetLength(LNext, LNextCount);
    LCurrent := LNext;
    if Length(LCurrent) = 0 then Break;
  end;

  Result := LCurrent;
end;

end.
