unit nextpas.core.collections.builder;

{**
 * nextpas.core.collections.builder - 集合容器 Builder 模式
 *
 * @desc
 *   提供流式 API 来配置和创建集合容器实例。
 *   遵循 Rust/Java Builder 模式设计。
 *
 * @features
 *   - TVecBuilder<T>: Vec 向量构建器
 *   - THashMapBuilder<K,V>: HashMap 构建器
 *
 * @usage
 *   var Vec := specialize TVecBuilder<Integer>.WithElement(1).AndWithElement(2).AndBuild;
 *   var Map := specialize THashMapBuilder<String, Integer>
 *       .WithEntry('key', 100).Build;
 *
 * @author fafafaStudio
 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.collections.vec,
  nextpas.core.collections.hashmap;

type

  {**
   * TVecBuilder<T> - Vec 向量构建器
   *
   * @desc
   *   流式 API 用于配置和创建 IVec<T> 实例。
   *   支持预设容量和添加初始元素。
   *
 * @usage
 *   var Vec := specialize TVecBuilder<Integer>
 *       .WithCapacity(100)
 *       .AndWithElement(1).AndWithElement(2).AndWithElement(3)
 *       .AndBuild;
   *}
  generic TVecBuilder<T> = record
  private
    type
      TVecType = specialize TVec<T>;
      IVecType = specialize IVec<T>;
      TSelf = specialize TVecBuilder<T>;
  private
    FVec: TVecType;
    FCapacity: SizeUInt;
    FInitialized: Boolean;

    procedure EnsureInitialized;
  public
    {**
     * WithCapacity - 预设向量容量
     *
     * @param ACapacity 预设容量
     * @return Self 支持链式调用
     *}
    class function WithCapacity(ACapacity: SizeUInt): TSelf; static;

    {**
     * WithElement - 添加一个元素
     *
     * @param AElement 要添加的元素
     * @return Self 支持链式调用
     *}
    class function WithElement(const AElement: T): TSelf; static;

    {**
     * Build - 创建向量实例
     *
     * @return IVec<T> 向量接口
     *}
    class function Build: IVecType; static;

    // 实例方法版本（用于链式调用）
    function AndWithCapacity(ACapacity: SizeUInt): TSelf;
    function AndWithElement(const AElement: T): TSelf;
    function AndBuild: IVecType;
  end;

  {**
   * THashMapBuilder<K,V> - HashMap 构建器
   *
   * @desc
   *   流式 API 用于配置和创建 IHashMap<K,V> 实例。
   *   支持预设容量和添加初始键值对。
   *
   * @usage
   *   var Map := specialize THashMapBuilder<String, Integer>
   *       .WithCapacity(100)
   *       .WithEntry('key1', 100)
   *       .WithEntry('key2', 200)
   *       .Build;
   *}
  generic THashMapBuilder<K, V> = record
  private
    type
      TMapType = specialize THashMap<K, V>;
      IMapType = specialize IHashMap<K, V>;
      TSelf = specialize THashMapBuilder<K, V>;
  private
    FMap: TMapType;
    FCapacity: SizeUInt;
    FInitialized: Boolean;

    procedure EnsureInitialized;
  public
    {**
     * WithCapacity - 预设哈希表容量
     *
     * @param ACapacity 预设容量
     * @return Self 支持链式调用
     *}
    class function WithCapacity(ACapacity: SizeUInt): TSelf; static;

    {**
     * WithEntry - 添加一个键值对
     *
     * @param AKey 键
     * @param AValue 值
     * @return Self 支持链式调用
     *}
    class function WithEntry(const AKey: K; const AValue: V): TSelf; static;

    {**
     * Build - 创建哈希表实例
     *
     * @return IHashMap<K,V> 哈希表接口
     *}
    class function Build: IMapType; static;

    // 实例方法版本（用于链式调用）
    function AndWithCapacity(ACapacity: SizeUInt): TSelf;
    function AndWithEntry(const AKey: K; const AValue: V): TSelf;
    function AndBuild: IMapType;
  end;

implementation

{ TVecBuilder<T> }

procedure TVecBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    if FCapacity > 0 then
      FVec := TVecType.Create(FCapacity)
    else
      FVec := TVecType.Create;
    FInitialized := True;
  end;
end;

class function TVecBuilder.WithCapacity(ACapacity: SizeUInt): TSelf;
begin
  Result := Default(TSelf);
  Result.FCapacity := ACapacity;
  Result.FInitialized := False;
end;

class function TVecBuilder.WithElement(const AElement: T): TSelf;
begin
  Result := Default(TSelf);
  Result.FCapacity := 0;
  Result.FInitialized := False;
  Result.EnsureInitialized;
  Result.FVec.Push(AElement);
end;

class function TVecBuilder.Build: IVecType;
var
  Builder: TSelf;
begin
  Builder := Default(TSelf);
  Builder.EnsureInitialized;
  Result := Builder.FVec;
end;

function TVecBuilder.AndWithCapacity(ACapacity: SizeUInt): TSelf;
begin
  Result := Self;
  if not FInitialized then
    Result.FCapacity := ACapacity
  else
    Result.FVec.EnsureCapacity(ACapacity);
end;

function TVecBuilder.AndWithElement(const AElement: T): TSelf;
begin
  Result := Self;
  Result.EnsureInitialized;
  Result.FVec.Push(AElement);
end;

function TVecBuilder.AndBuild: IVecType;
begin
  EnsureInitialized;
  Result := FVec;
end;

{ THashMapBuilder<K,V> }

procedure THashMapBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    if FCapacity > 0 then
      FMap := TMapType.Create(FCapacity)
    else
      FMap := TMapType.Create;
    FInitialized := True;
  end;
end;

class function THashMapBuilder.WithCapacity(ACapacity: SizeUInt): TSelf;
begin
  Result := Default(TSelf);
  Result.FCapacity := ACapacity;
  Result.FInitialized := False;
end;

class function THashMapBuilder.WithEntry(const AKey: K; const AValue: V): TSelf;
begin
  Result := Default(TSelf);
  Result.FCapacity := 0;
  Result.FInitialized := False;
  Result.EnsureInitialized;
  Result.FMap.Add(AKey, AValue);
end;

class function THashMapBuilder.Build: IMapType;
var
  Builder: TSelf;
begin
  Builder := Default(TSelf);
  Builder.EnsureInitialized;
  Result := Builder.FMap;
end;

function THashMapBuilder.AndWithCapacity(ACapacity: SizeUInt): TSelf;
begin
  Result := Self;
  if not FInitialized then
    Result.FCapacity := ACapacity
  else
    Result.FMap.Reserve(ACapacity);
end;

function THashMapBuilder.AndWithEntry(const AKey: K; const AValue: V): TSelf;
begin
  Result := Self;
  Result.EnsureInitialized;
  Result.FMap.Add(AKey, AValue);
end;

function THashMapBuilder.AndBuild: IMapType;
begin
  EnsureInitialized;
  Result := FMap;
end;

end.
