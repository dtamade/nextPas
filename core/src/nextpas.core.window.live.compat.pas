unit nextpas.core.window.live.compat;

{ window.live compat — 已弃用 Snapshot 隔离层（family shard compat, owner window.impl 间接）。
  职责：彻底隔离主类 TWindowLiveRegistry 对外优雅度污染，主类仅暴露 SnapshotTo 池化零堆抖动；
  兼容层通过 class helper 提供 deprecated Snapshot 薄转发至 SnapshotTo 单源 via bytes.ops ManagedEnsureCapacityExact+ArrayRawCopy inline 零拷贝 O(1)；
  隔离后调用点经 -Wdeprecated 提示迁移至 SnapshotTo(var ADest) 池化复用，零额外堆，资源托管不丢；
  边界：仅 compat 侧 uses window.live，不经门面 re-export，编译期需 window.* 家族内 uses，L0-L3 与四件套守 CONTRACT。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.live;

type
  TWindowLiveRegistryCompatHelper = class helper for TWindowLiveRegistry
    function Snapshot: TWindowLiveSnapshot; deprecated 'use SnapshotTo(var ADest) pooling zero heap jitter; Snapshot alloc per call triggers heap churn on per-frame high-freq, migrate to SnapshotTo(var ADest) pooling via bytes.ops single source';
  end;

implementation

function TWindowLiveRegistryCompatHelper.Snapshot: TWindowLiveSnapshot;
begin
  Result := nil;
  Self.SnapshotTo(Result);
end;

end.
