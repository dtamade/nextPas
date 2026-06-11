# System Runtime Contracts

This document records S2-level runtime contract names for `nextpas.core.system`. These names are
compiler/runtime handshake contracts, not public ABI, not final exported symbol names. They are contract vocabulary only, not public Pascal facade.

The purpose is to keep managed lifetime work explicit before implementation starts:

- The compiler decides when a managed operation is required.
- `nextpas.core.system` owns the contract vocabulary for the RTL root.
- `nextpas.core.mem` owns allocator and heap-manager implementation details.
- Runtime implementation must add leak-sensitive tests before any helper starts owning memory.

## Contract Rules

- A contract name describes semantics, not a backend private helper string.
- A contract name must not imply that S0/S1 already implements the behavior.
- All allocation and release paths must be traceable to the `nextpas.core.mem` owner boundary.
- Managed lifetime helpers must be safe under early exits and partial initialization.
- Any future implementation that owns memory must include heaptrc or equivalent leak-sensitive evidence.

## Program Termination

`np.system.halt` is the compiler/runtime contract for explicit program
termination. It describes the language-runtime intent to terminate the current
program with an exit code; it is not a callable `nextpas.core.system` facade and
does not freeze a backend syscall ABI.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.halt` | explicit program termination with compiler-selected exit-code expression | system contract vocabulary, compiler/HIR implementation |

Rules:

- The semantic source node is `halt-call-runtime`; sema owns selecting the exit
  expression and sequencing required cleanup before termination.
- HIR may project the contract as HIR intrinsic `halt`; this is a compiler/HIR
  lowering detail, not a public Pascal symbol.
- Current LLVM output may use syscall inline assembly as backend-private
  termination lowering evidence. This backend-private termination lowering is
  not public ABI and must not become a facade contract.
- Future process shutdown and unit finalization integration must preserve the
  separation between explicit termination intent and backend-private process
  exit mechanics.

## Managed String

Managed string runtime work covers reference tracking, assignment, finalization and copy-on-write decisions
for compiler-emitted operations. Advanced Unicode, parsing, formatting and text algorithms remain in
`nextpas.core.text`.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.string_init` | initialize a managed string slot to a safe empty state | system contract, runtime implementation deferred |
| `np.system.string_fini` | finalize a managed string slot and release owned storage if needed | system contract over mem owner |
| `np.system.string_assign` | assign one managed string value to another with correct lifetime behavior | system contract over text/mem owners |

Non-goals for this stage:

- No public `StringInit` / `StringAssign` Pascal facade.
- No Unicode algorithm ownership transfer from `nextpas.core.text`.
- No assumption that string storage layout is finalized.

## Dynamic Array

Dynamic array contracts describe managed array lifetime and resizing semantics. Element-specific initialization
or finalization must be driven by compiler-known element type metadata, not guessed by the runtime.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.dynarray_init` | initialize a dynamic array slot to nil/empty truth | system contract, runtime implementation deferred |
| `np.system.dynarray_fini` | finalize an array slot and its managed elements when required | system contract over mem owner |
| `np.system.dynarray_set_length` | resize an array while preserving valid initialized prefix semantics | system contract over mem owner |

Rules:

- Resizing must define failure behavior before implementation appears.
- Element finalization must be explicit for managed element types.
- Allocation must route through the heap manager owned by `nextpas.core.mem`.
- Compiler HIR may project `np.system.dynarray_set_length`,
  `np.system.dynarray_fini` and element contracts such as
  `np.system.string_fini` for `array of string` and
  `np.system.interface_release` for `array of interface`. Backend-private
  helpers such as `@np_dynarray_resize`, `@np_dynarray_release` and
  `@np_dynarray_fault` remain implementation details, not public ABI.
- The dynamic-array fault helper is current backend evidence for rejecting
  impossible helper states in generated LLVM. It is not a public runtime-fault
  taxonomy, not a Pascal exception facade, and not proof that all dynamic-array
  failure semantics are finalized.
- Managed dynamic-array contract tests prove semantic contract projection only.
  They must not use backend-private LLVM helper calls as evidence that element
  finalization semantics are implemented.
- Borrowed dynamic-array parameters, even with managed element types, must not
  project owned `set_length` or `fini` contracts.

## Interface Reference

Interface reference contracts define addref/release semantics at the language-runtime boundary. This document
does not decide whether a future implementation uses COM-style reference counting, compiler-owned elision,
or a mixed strategy.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.interface_addref` | retain an interface reference when compiler semantics require it | system contract, implementation deferred |
| `np.system.interface_release` | release an interface reference and trigger destruction if appropriate | system contract over object/mem owners |

Rules:

- Nil interface references must be safe.
- Release ordering must be deterministic and testable.
- Any interaction with object destruction must align with `np.system.object_free`.

## Object Free

`np.system.object_free` is the compiler/runtime contract for object `Free`
lowering. It describes the semantic lifecycle group for a class instance, not a
callable Pascal facade and not a public ABI exported from `nextpas.core.system`.

The current source-backed System truth is intentionally small:
`rtl/core/system/System.pas` provides `TObject.Create`, virtual
`TObject.Destroy`, and `TObject.Free` as the minimum compiler-visible object
root. That source-backed unit lets implicit runtime analysis bind ordinary
class `Free` calls to real `TObject.Free` / effective `Destroy` truth instead of
falling back to host RTL guesses. It does not make the core facade expose
`TObject`, and it does not mean the full nextPas `System` runtime is complete.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.object_free` | nil-safe object `Free` operation with effective destroy and heap-release intent | system contract vocabulary, compiler/runtime implementation |
| `np.system.object_free.destroy` | owned destructor call inside the object-free lifecycle group | compiler selects the effective `Destroy`; runtime preserves ordering |
| `np.system.object_free.cleanup` | optional compiler-planned field cleanup before heap release | compiler owns class field cleanup plan; nested managed contracts own element cleanup |
| `np.system.object_free.release` | release the object allocation after destroy and cleanup have run | system contract over allocator/mem owner |

Rules:

- The semantic source node is `object-free-runtime`; its operand records the
  receiver, effective `destroy`, `cleanup-class`, `nil-guard true`, and
  `heap-release true`.
- Compiler HIR may project the lifecycle group as
  `np.system.object_free`, `np.system.object_free.destroy`,
  `np.system.object_free.cleanup`, and `np.system.object_free.release`.
- A backend-private helper such as `@np_object_free_release` is an implementation
  detail. It may appear in LLVM-focused tests as backend evidence, but it
  is not public ABI and must not become a callable facade symbol.
- The current LLVM helper path reads the object allocation header, checks the
  object magic, and splits into `@np_object_release_valid` or
  `@np_object_release_invalid`. These are backend/runtime boundary hooks for
  source-backed System object ownership proof, not allocator free completion,
  public ABI, or a promise that invalid release diagnostics are final.
- The release helper must stay field-agnostic and must not walk object fields.
  Field dynamic-array, string, interface, and managed-record cleanup stays in
  compiler-planned cleanup calls or the relevant managed runtime contracts.
- Allocation header shape, magic values, free-list policy, invalid-release
  handling, and allocator internals remain compiler/runtime/mem details. The
  stable system contract is nil-safe destroy, cleanup, and release ordering.

## Managed Record

Managed record contracts describe initialization and finalization points for record fields that contain
managed values. The compiler owns the layout and field plan; runtime executes the plan.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.managed_record_init` | initialize managed fields in a record according to compiler-provided metadata | system contract, implementation deferred |
| `np.system.managed_record_fini` | finalize initialized managed fields in reverse-safe order | system contract over nested owners |

Rules:

- Partial initialization must have a defined cleanup path.
- Finalization must be idempotent only where compiler semantics require it; do not silently mask double-finalize bugs.
- Record field ownership stays explicit; system does not own text, array, interface or heap internals.

## Heap Manager

The heap manager is the allocation boundary used by runtime-managed values, but the implementation owner is
`nextpas.core.mem`. `nextpas.core.system` can define when the runtime needs heap services; it must not grow
a private allocator or bypass mem ownership.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.heap_alloc` | allocate runtime-managed storage through the canonical heap path | system contract over `nextpas.core.mem` |
| `np.system.heap_free` | release runtime-managed storage through the canonical heap path | system contract over `nextpas.core.mem` |

Rules:

- The heap manager contract must preserve size/alignment truth needed by mem.
- Out-of-memory behavior must map to canonical exception/error taxonomy.
- Any implementation must prove leak-sensitive behavior before it can be treated as Ready.

## Verification Expectations

Before any runtime-owned implementation lands, add focused tests for:

- success and failure paths for each helper family;
- partial initialization cleanup;
- zero-length and nil inputs;
- heaptrc 0 leak evidence for managed string, dynamic array, interface reference and managed record paths;
- source-contract checks proving helper names remain documented and owner boundaries remain explicit.
