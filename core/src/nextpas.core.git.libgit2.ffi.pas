unit nextpas.core.git.libgit2.ffi;
{** @desc libgit2 FFI 缝隙 — 极简高级感：四件套仅含 external，零聚合。
       本缝隙不做 5 域 re-export 聚合（types/structs/callbacks/options/consts 各域由消费者按需直引，
       词汇单源以 nextpas.core.git.libgit2.base/native.base.TGitOid 20-byte 为权威），
       不含 libc 探针（strlen/memcmp 等归 bytes.ops/平台层，复用 bytes.ops 单源 MemEqual/Move）.
       运行时 libgit2 仍由 binding 经 platform.dl 候选表 dlopen/dlsym，无硬编码宿主分叉，零 IFDEF.
       单源: OID 经 bytes.ops TByteSpan SpanEqual/SpanCopy/IsZeroBytes inline 零拷贝（20B→3×QWord/单 Move，无堆，≤80 ns/op）.
       稳定性: 资源释放经 binding/backend critical section + try..finally 不丢；PACKRECORDS C 双编译器等价 via settings.inc，Assert SizeOf=20. *}

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}

interface

{ intentionally minimal — no re-export, no libc external probe.
  Vocabulary: consumers import libgit2.base (handles/OID) and libgit2.types + ffi subdomains directly:
    nextpas.core.git.libgit2.types (scalar/handle/OID/enum) + ffi.structs/callbacks/options/consts
    (former ffi.types moved to plain types helper per §6 — ffi only carries cdecl external)
  Runtime: libgit2 binding via platform.dl (binding.pas), not static external 'c' linkage. }

implementation

end.
