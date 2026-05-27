unit nextpas.core.collections.tree_set;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  TypInfo,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.rbset,
  nextpas.core.mem.allocator;

type
  // TreeSet 实现 - 封装 TRBTreeSet
  generic TTreeSet<T> = class(TInterfacedObject, specialize ITreeSet<T>)
  private
    type
      TRBTreeSet = specialize TRBTreeSet<T>;
    var
      FImpl: TRBTreeSet;
  public
    constructor Create; overload;
    constructor Create(aAllocator: IAllocator); overload;
    destructor Destroy; override;

    // ITreeSet<T> specific methods
    function Add(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;

    // Set operations
    function Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;

    // IGenericCollection<T> interface methods (delegated to FImpl)
    function GetElementTypeInfo: PTypeInfo;
    function GetEnumerator: specialize TIter<T>;
    function Iter: specialize TIter<T>;
    function GetElementSize: SizeUInt;
    function GetIsManagedType: Boolean;
    function GetElementManager: specialize TElementManager<T>;
    procedure LoadFrom(const aSrc: array of T); overload;
    procedure Append(const aSrc: array of T); overload;
    function ToArray: specialize TGenericArray<T>;
    function ForEach(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function ForEach(aForEach: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ForEach(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}
    function Contains(const aElement: T): Boolean; overload;
    function Contains(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Contains(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}
    function CountOf(const aElement: T): SizeUInt; overload;
    function CountOf(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}
    function CountIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIF(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}
    procedure Fill(const aElement: T);
    procedure Zero();
    procedure Replace(const aElement, aNewElement: T);
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}
    procedure Reverse;

    // ICollection methods (delegated to FImpl)
    function PtrIter: TPtrIter;
    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    procedure Clear;
    function GetAllocator: IAllocator;
    procedure SetData(aData: Pointer);
    function GetData: Pointer;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
    function Clone: TCollection;
    function IsCompatible(aDst: TCollection): Boolean;
    procedure LoadFrom(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure LoadFromUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure Append(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure LoadFrom(const aSrc: TCollection); overload;
    procedure LoadFromUnChecked(const aSrc: TCollection); overload;
    procedure SaveTo(aDst: TCollection); overload;
    procedure SaveToUnChecked(aDst: TCollection);
    procedure Append(const aSrc: TCollection); overload;
    procedure AppendUnChecked(const aSrc: TCollection); overload;
    procedure AppendTo(const aDst: TCollection); overload;
    procedure AppendToUnChecked(const aDst: TCollection); overload;
  end;

implementation

{ TTreeSet<T> }

constructor TTreeSet.Create;
begin
  inherited Create;
  FImpl := TRBTreeSet.Create;
end;

constructor TTreeSet.Create(aAllocator: IAllocator);
begin
  inherited Create;
  FImpl := TRBTreeSet.Create(aAllocator);
end;

destructor TTreeSet.Destroy;
begin
  FImpl.Free;
  inherited Destroy;
end;

function TTreeSet.Add(const AValue: T): Boolean;
begin
  Result := FImpl.Insert(AValue);
end;

function TTreeSet.Remove(const AValue: T): Boolean;
begin
  Result := FImpl.Delete(AValue);
end;

// IGenericCollection<T> interface delegation

function TTreeSet.GetElementTypeInfo: PTypeInfo;
begin
  Result := FImpl.GetElementTypeInfo;
end;

function TTreeSet.GetEnumerator: specialize TIter<T>;
begin
  Result := FImpl.GetEnumerator;
end;

function TTreeSet.Iter: specialize TIter<T>;
begin
  Result := FImpl.Iter;
end;

function TTreeSet.GetElementSize: SizeUInt;
begin
  Result := FImpl.GetElementSize;
end;

function TTreeSet.GetIsManagedType: Boolean;
begin
  Result := FImpl.GetIsManagedType;
end;

function TTreeSet.GetElementManager: specialize TElementManager<T>;
begin
  Result := FImpl.GetElementManager;
end;

procedure TTreeSet.LoadFrom(const aSrc: array of T);
begin
  FImpl.LoadFrom(aSrc);
end;

procedure TTreeSet.Append(const aSrc: array of T);
begin
  FImpl.Append(aSrc);
end;

function TTreeSet.ToArray: specialize TGenericArray<T>;
begin
  Result := FImpl.ToArray;
end;

function TTreeSet.ForEach(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  Result := FImpl.ForEach(aPredicate, aData);
end;

function TTreeSet.ForEach(aForEach: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  Result := FImpl.ForEach(aForEach, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TTreeSet.ForEach(aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  Result := FImpl.ForEach(aPredicate);
end;
{$ENDIF}

function TTreeSet.Contains(const aElement: T): Boolean;
begin
  Result := FImpl.ContainsKey(aElement);
end;

function TTreeSet.Contains(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  Result := FImpl.Contains(aElement, aEquals, aData);
end;

function TTreeSet.Contains(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  Result := FImpl.Contains(aElement, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TTreeSet.Contains(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  Result := FImpl.Contains(aElement, aEquals);
end;
{$ENDIF}

function TTreeSet.CountOf(const aElement: T): SizeUInt;
begin
  Result := FImpl.CountOf(aElement);
end;

function TTreeSet.CountOf(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FImpl.CountOf(aElement, aEquals, aData);
end;

function TTreeSet.CountOf(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FImpl.CountOf(aElement, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TTreeSet.CountOf(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  Result := FImpl.CountOf(aElement, aEquals);
end;
{$ENDIF}

function TTreeSet.CountIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FImpl.CountIF(aPredicate, aData);
end;

function TTreeSet.CountIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FImpl.CountIF(aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TTreeSet.CountIF(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  Result := FImpl.CountIF(aPredicate);
end;
{$ENDIF}

procedure TTreeSet.Fill(const aElement: T);
begin
  FImpl.Fill(aElement);
end;

procedure TTreeSet.Zero();
begin
  FImpl.Zero();
end;

procedure TTreeSet.Replace(const aElement, aNewElement: T);
begin
  FImpl.Replace(aElement, aNewElement);
end;

procedure TTreeSet.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  FImpl.Replace(aElement, aNewElement, aEquals, aData);
end;

procedure TTreeSet.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  FImpl.Replace(aElement, aNewElement, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TTreeSet.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsRefFunc<T>);
begin
  FImpl.Replace(aElement, aNewElement, aEquals);
end;
{$ENDIF}

procedure TTreeSet.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  FImpl.ReplaceIf(aNewElement, aPredicate, aData);
end;

procedure TTreeSet.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  FImpl.ReplaceIf(aNewElement, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TTreeSet.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateRefFunc<T>);
begin
  FImpl.ReplaceIf(aNewElement, aPredicate);
end;
{$ENDIF}

procedure TTreeSet.Reverse;
begin
  FImpl.Reverse;
end;

// ICollection methods

function TTreeSet.PtrIter: TPtrIter;
begin
  Result := FImpl.PtrIter;
end;

function TTreeSet.GetCount: SizeUInt;
begin
  Result := FImpl.GetCount;
end;

function TTreeSet.IsEmpty: Boolean;
begin
  Result := FImpl.IsEmpty;
end;

procedure TTreeSet.Clear;
begin
  FImpl.Clear;
end;

function TTreeSet.GetAllocator: IAllocator;
begin
  Result := FImpl.GetAllocator;
end;

procedure TTreeSet.SetData(aData: Pointer);
begin
  FImpl.SetData(aData);
end;

function TTreeSet.GetData: Pointer;
begin
  Result := FImpl.GetData;
end;

procedure TTreeSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
begin
  FImpl.SerializeToArrayBuffer(aDst, aCount);
end;

function TTreeSet.Clone: TCollection;
begin
  Result := FImpl.Clone;
end;

function TTreeSet.IsCompatible(aDst: TCollection): Boolean;
begin
  Result := FImpl.IsCompatible(aDst);
end;

procedure TTreeSet.LoadFrom(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FImpl.LoadFrom(aSrc, aElementCount);
end;

procedure TTreeSet.LoadFromUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FImpl.LoadFromUnChecked(aSrc, aElementCount);
end;

procedure TTreeSet.Append(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FImpl.Append(aSrc, aElementCount);
end;

procedure TTreeSet.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FImpl.AppendUnChecked(aSrc, aElementCount);
end;

procedure TTreeSet.LoadFrom(const aSrc: TCollection);
begin
  FImpl.LoadFrom(aSrc);
end;

procedure TTreeSet.LoadFromUnChecked(const aSrc: TCollection);
begin
  FImpl.LoadFromUnChecked(aSrc);
end;

procedure TTreeSet.SaveTo(aDst: TCollection);
begin
  FImpl.SaveTo(aDst);
end;

procedure TTreeSet.SaveToUnChecked(aDst: TCollection);
begin
  FImpl.SaveToUnChecked(aDst);
end;

procedure TTreeSet.Append(const aSrc: TCollection);
begin
  FImpl.Append(aSrc);
end;

procedure TTreeSet.AppendUnChecked(const aSrc: TCollection);
begin
  FImpl.AppendUnChecked(aSrc);
end;

procedure TTreeSet.AppendTo(const aDst: TCollection);
begin
  FImpl.AppendTo(aDst);
end;

procedure TTreeSet.AppendToUnChecked(const aDst: TCollection);
begin
  FImpl.AppendToUnChecked(aDst);
end;

// Set operations

function TTreeSet.Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  ResultSet: specialize TTreeSet<T>;
  Element: T;
begin
  ResultSet := specialize TTreeSet<T>.Create;

  // Add all elements from current set
  for Element in Self do
    ResultSet.Add(Element);

  // Add all elements from other set
  for Element in Other do
    ResultSet.Add(Element);

  Result := ResultSet;
end;

function TTreeSet.Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  ResultSet: specialize TTreeSet<T>;
  Element: T;
begin
  ResultSet := specialize TTreeSet<T>.Create;

  // Add only elements that exist in both sets
  for Element in Self do
    if Other.Contains(Element) then
      ResultSet.Add(Element);

  Result := ResultSet;
end;

function TTreeSet.Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
var
  ResultSet: specialize TTreeSet<T>;
  Element: T;
begin
  ResultSet := specialize TTreeSet<T>.Create;

  // Add only elements that exist in Self but not in Other
  for Element in Self do
    if not Other.Contains(Element) then
      ResultSet.Add(Element);

  Result := ResultSet;
end;

end.
