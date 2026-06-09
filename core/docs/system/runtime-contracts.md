# System Runtime Contracts

This document records S2-level runtime contract names for `nextpas.core.system`. These names are
compiler/runtime handshake contracts, not public ABI, not final exported symbol names, and not callable
Pascal facade functions in the S0/S1 module.

The purpose is to keep managed lifetime work explicit before implementation starts:

- The compiler decides when a managed operation is required.
- `nextpas.core.system` owns the contract vocabulary for the RTL root.
- `nextpas.core.mem` owns allocator and heap-manager implementation details.
- Runtime implementation must add leak-sensitive tests before any helper starts owning memory.
- FPC-compatible source may provide a stage0 host fallback, but `np.system.*`
  remains the semantic authority.

## Contract Rules

- A contract name describes semantics, not a backend private helper string.
- A contract name must not imply that S0/S1 already implements the behavior.
- All allocation and release paths must be traceable to the `nextpas.core.mem` owner boundary.
- Managed lifetime helpers must be safe under early exits and partial initialization.
- Any future implementation that owns memory must include heaptrc or equivalent leak-sensitive evidence.

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
