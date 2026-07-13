# Typed System Contract HIR Boundary Design

> Status: approved M1 implementation detail
>
> Scope: object-free contract family only

## Make the typed ledger control production behavior

`compiler/ir/np_system_contracts.pas` already gives each compiler/System
handshake a `TSystemContractKind`, but the production HIR and LLVM path still
branches on `THIRInstr.IntrinsicName`. The ledger is therefore descriptive,
not authoritative.

This slice makes typed identity authoritative for the first complete contract
family:

```text
semantic object-free node kind
  -> THIRInstr.SystemContractKind
  -> typed LLVM emitter dispatch
  -> object destroy, cleanup, and release behavior
```

The existing semantic name remains on the HIR instruction as a stable text
projection for diagnostics, dumps, and compatibility. It no longer decides
which object-free lowering runs.

## Keep the representation explicit

`THIRInstr` gains two fields:

```pascal
HasSystemContract: Boolean;
SystemContractKind: TSystemContractKind;
```

The Boolean is intentional. Existing instructions are initialized with
`FillChar`, and the zero value of `TSystemContractKind` is a real contract.
Treating zero as "none" would silently alias an ordinary intrinsic to process
initialization.

`AssignSystemContract` is the only constructor helper for this state. It:

1. validates that the ledger entry has a semantic name;
2. sets the presence bit and typed kind; and
3. projects the ledger's semantic name into `IntrinsicName`.

`IsSystemContract` compares the presence bit and kind. Consumers must use this
helper instead of comparing `IntrinsicName` with an `np.system.*` constant.

## Type the object-free family end to end through HIR

The HIR builder assigns these identities:

| HIR operation | Typed identity |
| --- | --- |
| nil guard and object-free sequence start | `sckObjectFree` |
| owned `Destroy` dispatch | `sckObjectFreeDestroy` |
| generated field cleanup call | `sckObjectFreeCleanup` |
| heap release | `sckObjectFreeRelease` |

`ProcessObjectFreeRuntime` derives `sckObjectFree` from the already parsed
typed HIR node kind. It does not trust `TTypedHirNode.DisplayName` to select
backend behavior.

The LLVM emitter handles any instruction with `HasSystemContract=True` before
legacy intrinsic-name dispatch. It accepts the four object-free kinds in this
slice and fails closed for any other typed contract until that family has an
explicit lowering.

## Preserve compatibility without preserving authority

`IntrinsicName` remains populated with the canonical semantic name. Existing
HIR dumps and tests can still display `np.system.object_free.*`, and later
serialization work does not need an immediate format migration.

The compatibility field must satisfy both rules:

- changing it cannot change typed object-free lowering;
- a raw string without `HasSystemContract` cannot activate object-free lowering.

Later slices can remove the compatibility projection after all HIR consumers,
serialization, and diagnostics use typed identities explicitly.

## Verify behavior, not only source shape

The existing executable HIR object-free contract test becomes the focused
regression. Its semantic fixture uses a deliberately untrusted display name.
The test then requires:

- exact typed identities for guard, destroy, and release instructions;
- canonical ledger names in the compatibility projection;
- pointer-typed receiver operands;
- LLVM nil guard, conditional branch, destroy call, cleanup/release ordering,
  and runtime declarations.

The current implementation fails this test because it copies the untrusted
display string into `IntrinsicName` and the emitter uses that string to decide
whether to emit the object-free sequence.

## Keep this slice bounded

This slice does not:

- move `TSystemContractKind` into the semantic layer;
- type every semantic runtime contract or HIR intrinsic;
- change MIR ownership or make MIR the only backend path;
- add the System contract fingerprint;
- change object-free runtime behavior or ABI;
- claim that M1 typed-contract migration is complete.

The next contract families should reuse the same representation in dependency
order: process/unit lifecycle, strings, dynamic arrays, interfaces, exceptions,
then allocation and fault boundaries.
