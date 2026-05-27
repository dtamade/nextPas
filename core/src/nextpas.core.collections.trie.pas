unit nextpas.core.collections.trie;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.collections.trie - 字典树（前缀树）实现
 *
 * 高效的字符串前缀查询数据结构
 * 支持 O(m) 查找、插入、删除（m 为键长度）
 *}

interface

uses
  SysUtils,
  nextpas.core.collections.base,
  nextpas.core.collections.trie.intf;

type
  {**
   * TTrie<V>
   *
   * @desc 字典树实现，键为字符串，值为泛型类型 V
   *}
  generic TTrie<V> = class(TInterfacedObject, specialize ITrie<V>)
  public type
    TKeyArray = array of string;
  private type
    PNode = ^TNode;
    TNode = record
      Children: array[0..255] of PNode;
      HasValue: Boolean;
      Value: V;
    end;
  private
    FRoot: PNode;
    FCount: SizeUInt;

    function CreateNode: PNode;
    procedure FreeNode(aNode: PNode);
    procedure FreeNodeRecursive(aNode: PNode);
    function FindNode(const aKey: string): PNode;
    procedure CollectKeys(aNode: PNode; const aPrefix: string; var aKeys: TKeyArray; var aIndex: SizeUInt);
    function CountKeysInSubtree(aNode: PNode): SizeUInt;
    function HasChildren(aNode: PNode): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    {**
     * Put
     *
     * @desc 插入或更新键值对
     * @param aKey 键（字符串）
     * @param aValue 值
     * @return Boolean 如果是新键返回 True
     *}
    function Put(const aKey: string; const aValue: V): Boolean;

    {**
     * Get
     *
     * @desc 获取值
     * @param aKey 键
     * @param aValue 输出值
     * @return Boolean 如果键存在返回 True
     *}
    function Get(const aKey: string; out aValue: V): Boolean;

    {**
     * ContainsKey
     *
     * @desc 检查键是否存在
     * @param aKey 键
     * @return Boolean 如果存在返回 True
     *}
    function ContainsKey(const aKey: string): Boolean;

    {**
     * Remove
     *
     * @desc 移除键值对
     * @param aKey 键
     * @return Boolean 如果移除成功返回 True
     *}
    function Remove(const aKey: string): Boolean;

    {**
     * Clear
     *
     * @desc 清空所有元素
     *}
    procedure Clear;

    {**
     * HasPrefix
     *
     * @desc 检查是否存在以给定前缀开头的键
     * @param aPrefix 前缀
     * @return Boolean 如果存在匹配的键返回 True
     *}
    function HasPrefix(const aPrefix: string): Boolean;

    {**
     * KeysWithPrefix
     *
     * @desc 获取所有以给定前缀开头的键
     * @param aPrefix 前缀
     * @return TKeyArray 匹配的键数组
     *}
    function KeysWithPrefix(const aPrefix: string): TKeyArray;

    function GetCount: SizeUInt;
    function IsEmpty: Boolean;

    property Count: SizeUInt read GetCount;
  end;

implementation

{ TTrie<V> }

constructor TTrie.Create;
begin
  inherited Create;
  FRoot := CreateNode;
  FCount := 0;
end;

destructor TTrie.Destroy;
begin
  FreeNodeRecursive(FRoot);
  inherited Destroy;
end;

function TTrie.CreateNode: PNode;
var
  i: Integer;
begin
  New(Result);
  for i := 0 to 255 do
    Result^.Children[i] := nil;
  Result^.HasValue := False;
end;

procedure TTrie.FreeNode(aNode: PNode);
begin
  Dispose(aNode);
end;

procedure TTrie.FreeNodeRecursive(aNode: PNode);
var
  i: Integer;
begin
  if aNode = nil then Exit;

  for i := 0 to 255 do
    if aNode^.Children[i] <> nil then
      FreeNodeRecursive(aNode^.Children[i]);

  FreeNode(aNode);
end;

function TTrie.FindNode(const aKey: string): PNode;
var
  node: PNode;
  i: Integer;
  c: Byte;
begin
  node := FRoot;

  for i := 1 to Length(aKey) do
  begin
    c := Ord(aKey[i]);
    if node^.Children[c] = nil then
      Exit(nil);
    node := node^.Children[c];
  end;

  Result := node;
end;

function TTrie.HasChildren(aNode: PNode): Boolean;
var
  i: Integer;
begin
  for i := 0 to 255 do
    if aNode^.Children[i] <> nil then
      Exit(True);
  Result := False;
end;

procedure TTrie.CollectKeys(aNode: PNode; const aPrefix: string; var aKeys: TKeyArray; var aIndex: SizeUInt);
var
  i: Integer;
begin
  if aNode = nil then Exit;

  if aNode^.HasValue then
  begin
    if aIndex >= Length(aKeys) then
      SetLength(aKeys, Length(aKeys) + 16);
    aKeys[aIndex] := aPrefix;
    Inc(aIndex);
  end;

  for i := 0 to 255 do
    if aNode^.Children[i] <> nil then
      CollectKeys(aNode^.Children[i], aPrefix + Chr(i), aKeys, aIndex);
end;

function TTrie.CountKeysInSubtree(aNode: PNode): SizeUInt;
var
  i: Integer;
begin
  if aNode = nil then Exit(0);

  Result := 0;
  if aNode^.HasValue then
    Inc(Result);

  for i := 0 to 255 do
    if aNode^.Children[i] <> nil then
      Inc(Result, CountKeysInSubtree(aNode^.Children[i]));
end;

function TTrie.Put(const aKey: string; const aValue: V): Boolean;
var
  node: PNode;
  i: Integer;
  c: Byte;
begin
  node := FRoot;

  for i := 1 to Length(aKey) do
  begin
    c := Ord(aKey[i]);
    if node^.Children[c] = nil then
      node^.Children[c] := CreateNode;
    node := node^.Children[c];
  end;

  Result := not node^.HasValue;
  node^.HasValue := True;
  node^.Value := aValue;

  if Result then
    Inc(FCount);
end;

function TTrie.Get(const aKey: string; out aValue: V): Boolean;
var
  node: PNode;
begin
  node := FindNode(aKey);

  if (node <> nil) and node^.HasValue then
  begin
    aValue := node^.Value;
    Exit(True);
  end;

  Result := False;
end;

function TTrie.ContainsKey(const aKey: string): Boolean;
var
  node: PNode;
begin
  node := FindNode(aKey);
  Result := (node <> nil) and node^.HasValue;
end;

function TTrie.Remove(const aKey: string): Boolean;
var
  node: PNode;
begin
  node := FindNode(aKey);

  if (node = nil) or (not node^.HasValue) then
    Exit(False);

  node^.HasValue := False;
  Dec(FCount);
  Result := True;

  // Note: We don't prune empty nodes for simplicity
  // A more sophisticated implementation would clean up unused nodes
end;

procedure TTrie.Clear;
var
  i: Integer;
begin
  // Free all children of root
  for i := 0 to 255 do
  begin
    if FRoot^.Children[i] <> nil then
    begin
      FreeNodeRecursive(FRoot^.Children[i]);
      FRoot^.Children[i] := nil;
    end;
  end;

  FRoot^.HasValue := False;
  FCount := 0;
end;

function TTrie.HasPrefix(const aPrefix: string): Boolean;
var
  node: PNode;
begin
  if aPrefix = '' then
    Exit(FCount > 0);

  node := FindNode(aPrefix);
  if node = nil then
    Exit(False);

  // Check if this node has a value or has any children with values
  Result := node^.HasValue or HasChildren(node);
end;

function TTrie.KeysWithPrefix(const aPrefix: string): TKeyArray;
var
  node: PNode;
  idx: SizeUInt;
begin
  Result := nil;

  if aPrefix = '' then
    node := FRoot
  else
    node := FindNode(aPrefix);

  if node = nil then
    Exit;

  idx := 0;
  CollectKeys(node, aPrefix, Result, idx);
  SetLength(Result, idx);
end;

function TTrie.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TTrie.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

end.
