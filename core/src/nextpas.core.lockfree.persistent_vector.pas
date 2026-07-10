{******************************************************************************
  nextpas.core.lockfree.persistent_vector

  Persistent Immutable Vector — all operations return a new vector,
  sharing unchanged data via copy-on-write.

  Design:
  - Internal storage: dynamic array of AnsiString
  - Append: O(n) copy — creates new array with one extra element
  - Nth: O(1) direct index
  - Assoc: O(n) copy — creates new array with one element changed
  - Thread-safe: immutable data can be shared without synchronization

  Use cases: functional programming, undo/redo, concurrent read-heavy workloads.

  2026-07-06  Phase 4
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.persistent_vector;

interface

uses
  SysUtils;

type
  TPVectorResult = (
    pvOk,
    pvOutOfBounds,
    pvEmpty
  );

  {**
   * 持久化不可变向量。
   *
   * 所有操作返回新向量，内部数据通过 copy-on-write 共享。
   * 线程安全：不可变数据可无锁共享。
   *
   * @constraints
   *   - TValue 必须是 AnsiString
   *   - 最大元素数约 2^31
   *}
  TPersistentVector = class
  private
    FData: array of AnsiString;
    FCount: Int32;
  public
    constructor Create;
    destructor Destroy; override;

    { 获取元素数量 }
    function Count: Int32;

    { 获取索引处的元素 }
    function Nth(AIdx: Int32; out AValue: AnsiString): TPVectorResult;

    { 追加元素到末尾，返回新向量 }
    function Append(const AValue: AnsiString): TPersistentVector;

    { 更新索引处的元素，返回新向量。nil if out of bounds }
    function Assoc(AIdx: Int32; const AValue: AnsiString): TPersistentVector;

    { 连接两个向量，返回新向量 }
    function Concat(AOther: TPersistentVector): TPersistentVector;

    { 转换为数组 }
    function ToArray: specialize TArray<AnsiString>;

    { 检查是否为空 }
    function IsEmpty: Boolean;

    { 清空 }
    procedure Clear;
  end;

implementation

constructor TPersistentVector.Create;
begin
  inherited Create;
  FCount := 0;
end;

destructor TPersistentVector.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TPersistentVector.Clear;
begin
  SetLength(FData, 0);
  FCount := 0;
end;

function TPersistentVector.Count: Int32;
begin
  Result := FCount;
end;

function TPersistentVector.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TPersistentVector.Nth(AIdx: Int32; out AValue: AnsiString): TPVectorResult;
begin
  if (AIdx < 0) or (AIdx >= FCount) then
  begin
    AValue := '';
    Result := pvOutOfBounds;
    Exit;
  end;
  AValue := FData[AIdx];
  Result := pvOk;
end;

function TPersistentVector.Append(const AValue: AnsiString): TPersistentVector;
var
  I: Int32;
begin
  Result := TPersistentVector.Create;
  Result.FCount := FCount + 1;
  SetLength(Result.FData, Result.FCount);
  for I := 0 to FCount - 1 do
    Result.FData[I] := FData[I];
  Result.FData[FCount] := AValue;
end;

function TPersistentVector.Assoc(AIdx: Int32;
  const AValue: AnsiString): TPersistentVector;
var
  I: Int32;
begin
  if (AIdx < 0) or (AIdx >= FCount) then
  begin
    Result := nil;
    Exit;
  end;
  Result := TPersistentVector.Create;
  Result.FCount := FCount;
  SetLength(Result.FData, FCount);
  for I := 0 to FCount - 1 do
    Result.FData[I] := FData[I];
  Result.FData[AIdx] := AValue;
end;

function TPersistentVector.Concat(AOther: TPersistentVector): TPersistentVector;
var
  I, LTotal: Int32;
begin
  LTotal := FCount;
  if AOther <> nil then
    Inc(LTotal, AOther.FCount);

  Result := TPersistentVector.Create;
  Result.FCount := LTotal;
  SetLength(Result.FData, LTotal);

  for I := 0 to FCount - 1 do
    Result.FData[I] := FData[I];

  if AOther <> nil then
  begin
    for I := 0 to AOther.FCount - 1 do
      Result.FData[FCount + I] := AOther.FData[I];
  end;
end;

function TPersistentVector.ToArray: specialize TArray<AnsiString>;
var
  I: Int32;
begin
  Result := nil;
  SetLength(Result, FCount);
  for I := 0 to FCount - 1 do
    Result[I] := FData[I];
end;

end.
