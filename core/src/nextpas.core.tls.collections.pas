{**
 * Unit: nextpas.core.tls.collections
 * Purpose: 可替换的集合接口 - 为 fafafa.core 集成预留
 *
 * 设计目标:
 * - 定义简单的 Map 接口，方便后续替换为 fafafa.core 的 HashMap
 * - 当前提供基于动态数组的简单实现
 * - 接口设计兼容 fafafa.core 的集合框架
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2025-12-27
 *}

unit nextpas.core.tls.collections;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface


type
  {**
   * 通用键值对
   *}
  generic TKeyValuePair<TKey, TValue> = record
    Key: TKey;
    Value: TValue;
  end;

  {**
   * IMap 接口 - 键值映射的抽象接口
   *
   * 设计说明:
   * - 当前由 TSimpleMap 实现（O(n) 查找）
   * - 后续可替换为 fafafa.core 的 THashMap（O(1) 查找）
   * - 接口保持稳定，实现可替换
   *}
  generic IMap<TKey, TValue> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    {** 添加或更新键值对 *}
    procedure Put(const AKey: TKey; const AValue: TValue);

    {** 获取值，不存在返回默认值 *}
    function Get(const AKey: TKey; const ADefault: TValue): TValue;

    {** 尝试获取值 *}
    function TryGet(const AKey: TKey; out AValue: TValue): Boolean;

    {** 检查键是否存在 *}
    function Contains(const AKey: TKey): Boolean;

    {** 删除键值对 *}
    function Remove(const AKey: TKey): Boolean;

    {** 清空所有键值对 *}
    procedure Clear;

    {** 获取元素数量 *}
    function Count: Integer;

    {** 获取所有键 *}
    function Keys: specialize TArray<TKey>;

    {** 获取所有值 *}
    function Values: specialize TArray<TValue>;
  end;

  {**
   * IStringMap 接口 - 字符串键的特化版本
   *
   * 用于常见的字符串到对象的映射场景
   *}
  generic IStringMap<TValue> = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']

    procedure Put(const AKey: string; const AValue: TValue);
    function Get(const AKey: string; const ADefault: TValue): TValue;
    function TryGet(const AKey: string; out AValue: TValue): Boolean;
    function Contains(const AKey: string): Boolean;
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: TStringArray;
    function Values: specialize TArray<TValue>;
  end;

  {**
   * IIntegerMap 接口 - 整数键的特化版本
   *
   * 用于枚举类型或整数 ID 到对象的映射
   *}
  generic IIntegerMap<TValue> = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']

    procedure Put(AKey: Integer; const AValue: TValue);
    function Get(AKey: Integer; const ADefault: TValue): TValue;
    function TryGet(AKey: Integer; out AValue: TValue): Boolean;
    function Contains(AKey: Integer): Boolean;
    function Remove(AKey: Integer): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: specialize TArray<Integer>;
    function Values: specialize TArray<TValue>;
  end;

  {**
   * TSimpleStringMap - 基于动态数组的简单字符串映射实现
   *
   * 特点:
   * - O(n) 查找复杂度
   * - 内存占用小
   * - 适合小规模数据（< 100 项）
   *
   * 后续可替换为 fafafa.core 的 THashMap 获得 O(1) 性能
   *}
  generic TSimpleStringMap<TValue> = class(TInterfacedObject, specialize IStringMap<TValue>)
  private type
    TEntry = record
      Key: string;
      Value: TValue;
      Used: Boolean;
    end;
  private
    FEntries: array of TEntry;
    FCount: Integer;

    function FindIndex(const AKey: string): Integer;
  public
    constructor Create(AInitialCapacity: Integer = 16);
    destructor Destroy; override;

    procedure Put(const AKey: string; const AValue: TValue);
    function Get(const AKey: string; const ADefault: TValue): TValue;
    function TryGet(const AKey: string; out AValue: TValue): Boolean;
    function Contains(const AKey: string): Boolean;
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: TStringArray;
    function Values: specialize TArray<TValue>;
  end;

  {**
   * TSimpleIntegerMap - 基于动态数组的简单整数映射实现
   *
   * 适用于枚举类型键（如 TSSLLibraryType）
   *}
  generic TSimpleIntegerMap<TValue> = class(TInterfacedObject, specialize IIntegerMap<TValue>)
  private type
    TEntry = record
      Key: Integer;
      Value: TValue;
      Used: Boolean;
    end;
  private
    FEntries: array of TEntry;
    FCount: Integer;

    function FindIndex(AKey: Integer): Integer;
  public
    constructor Create(AInitialCapacity: Integer = 16);
    destructor Destroy; override;

    procedure Put(AKey: Integer; const AValue: TValue);
    function Get(AKey: Integer; const ADefault: TValue): TValue;
    function TryGet(AKey: Integer; out AValue: TValue): Boolean;
    function Contains(AKey: Integer): Boolean;
    function Remove(AKey: Integer): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: specialize TArray<Integer>;
    function Values: specialize TArray<TValue>;
  end;

  {**
   * TMapFactory - Map 工厂类
   *
   * 提供统一的 Map 创建入口，方便后续切换实现
   *
   * 使用示例:
   *   LMap := TMapFactory.CreateStringMap<TMyValue>;
   *
   * 后续集成 fafafa.core 时，只需修改此工厂的实现
   *}
  TMapFactory = class
  public
    {** 创建字符串键映射 *}
    generic class function CreateStringMap<TValue>: specialize IStringMap<TValue>; static;

    {** 创建整数键映射 *}
    generic class function CreateIntegerMap<TValue>: specialize IIntegerMap<TValue>; static;
  end;

implementation

{ TSimpleStringMap }

constructor TSimpleStringMap.Create(AInitialCapacity: Integer);
begin
  inherited Create;
  SetLength(FEntries, AInitialCapacity);
  FCount := 0;
end;

destructor TSimpleStringMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TSimpleStringMap.FindIndex(const AKey: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used and (FEntries[I].Key = AKey) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TSimpleStringMap.Put(const AKey: string; const AValue: TValue);
var
  LIndex, I: Integer;
begin
  LIndex := FindIndex(AKey);

  if LIndex >= 0 then
  begin
    // 更新现有项
    FEntries[LIndex].Value := AValue;
  end
  else
  begin
    // 查找空槽位
    LIndex := -1;
    for I := 0 to High(FEntries) do
    begin
      if not FEntries[I].Used then
      begin
        LIndex := I;
        Break;
      end;
    end;

    // 需要扩容
    if LIndex < 0 then
    begin
      LIndex := Length(FEntries);
      SetLength(FEntries, Length(FEntries) * 2);
    end;

    FEntries[LIndex].Key := AKey;
    FEntries[LIndex].Value := AValue;
    FEntries[LIndex].Used := True;
    Inc(FCount);
  end;
end;

function TSimpleStringMap.Get(const AKey: string; const ADefault: TValue): TValue;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  if LIndex >= 0 then
    Result := FEntries[LIndex].Value
  else
    Result := ADefault;
end;

function TSimpleStringMap.TryGet(const AKey: string; out AValue: TValue): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  Result := LIndex >= 0;
  if Result then
    AValue := FEntries[LIndex].Value;
end;

function TSimpleStringMap.Contains(const AKey: string): Boolean;
begin
  Result := FindIndex(AKey) >= 0;
end;

function TSimpleStringMap.Remove(const AKey: string): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  Result := LIndex >= 0;
  if Result then
  begin
    FEntries[LIndex].Key := '';
    FEntries[LIndex].Used := False;
    Dec(FCount);
  end;
end;

procedure TSimpleStringMap.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
  begin
    FEntries[I].Key := '';
    FEntries[I].Used := False;
  end;
  FCount := 0;
end;

function TSimpleStringMap.Count: Integer;
begin
  Result := FCount;
end;

function TSimpleStringMap.Keys: TStringArray;
var
  I, J: Integer;
begin
  Result := nil;
  SetLength(Result, FCount);
  J := 0;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used then
    begin
      Result[J] := FEntries[I].Key;
      Inc(J);
    end;
  end;
end;

function TSimpleStringMap.Values: specialize TArray<TValue>;
var
  I, J: Integer;
begin
  Result := nil;
  SetLength(Result, FCount);
  J := 0;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used then
    begin
      Result[J] := FEntries[I].Value;
      Inc(J);
    end;
  end;
end;

{ TSimpleIntegerMap }

constructor TSimpleIntegerMap.Create(AInitialCapacity: Integer);
begin
  inherited Create;
  SetLength(FEntries, AInitialCapacity);
  FCount := 0;
end;

destructor TSimpleIntegerMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TSimpleIntegerMap.FindIndex(AKey: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used and (FEntries[I].Key = AKey) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TSimpleIntegerMap.Put(AKey: Integer; const AValue: TValue);
var
  LIndex, I: Integer;
begin
  LIndex := FindIndex(AKey);

  if LIndex >= 0 then
  begin
    FEntries[LIndex].Value := AValue;
  end
  else
  begin
    LIndex := -1;
    for I := 0 to High(FEntries) do
    begin
      if not FEntries[I].Used then
      begin
        LIndex := I;
        Break;
      end;
    end;

    if LIndex < 0 then
    begin
      LIndex := Length(FEntries);
      SetLength(FEntries, Length(FEntries) * 2);
    end;

    FEntries[LIndex].Key := AKey;
    FEntries[LIndex].Value := AValue;
    FEntries[LIndex].Used := True;
    Inc(FCount);
  end;
end;

function TSimpleIntegerMap.Get(AKey: Integer; const ADefault: TValue): TValue;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  if LIndex >= 0 then
    Result := FEntries[LIndex].Value
  else
    Result := ADefault;
end;

function TSimpleIntegerMap.TryGet(AKey: Integer; out AValue: TValue): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  Result := LIndex >= 0;
  if Result then
    AValue := FEntries[LIndex].Value;
end;

function TSimpleIntegerMap.Contains(AKey: Integer): Boolean;
begin
  Result := FindIndex(AKey) >= 0;
end;

function TSimpleIntegerMap.Remove(AKey: Integer): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindIndex(AKey);
  Result := LIndex >= 0;
  if Result then
  begin
    FEntries[LIndex].Used := False;
    Dec(FCount);
  end;
end;

procedure TSimpleIntegerMap.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    FEntries[I].Used := False;
  FCount := 0;
end;

function TSimpleIntegerMap.Count: Integer;
begin
  Result := FCount;
end;

function TSimpleIntegerMap.Keys: specialize TArray<Integer>;
var
  I, J: Integer;
begin
  Result := nil;
  SetLength(Result, FCount);
  J := 0;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used then
    begin
      Result[J] := FEntries[I].Key;
      Inc(J);
    end;
  end;
end;

function TSimpleIntegerMap.Values: specialize TArray<TValue>;
var
  I, J: Integer;
begin
  Result := nil;
  SetLength(Result, FCount);
  J := 0;
  for I := 0 to High(FEntries) do
  begin
    if FEntries[I].Used then
    begin
      Result[J] := FEntries[I].Value;
      Inc(J);
    end;
  end;
end;

{ TMapFactory }

generic class function TMapFactory.CreateStringMap<TValue>: specialize IStringMap<TValue>;
begin
  // 当前使用简单实现
  // 后续集成 fafafa.core 时，可替换为:
  // Result := specialize THashMap<string, TValue>.Create;
  Result := specialize TSimpleStringMap<TValue>.Create;
end;

generic class function TMapFactory.CreateIntegerMap<TValue>: specialize IIntegerMap<TValue>;
begin
  // 当前使用简单实现
  // 后续集成 fafafa.core 时，可替换为:
  // Result := specialize THashMap<Integer, TValue>.Create;
  Result := specialize TSimpleIntegerMap<TValue>.Create;
end;

end.
