# Path mix-use audit

**Generated**: 2026-08-23T22:01Z
**Script**: `scripts/path-mixuse-audit.sh`
**Scope**: `core/src/**/*.pas`, `compiler/**/*.pas`
**Semantics**: unchanged (PathDir facade vs FsPathDir Go).

## Dual-track anchors (fail-closed)

| Anchor | Location | Expected |
|--------|----------|----------|
| bare PathDir | test_path | `PathDir('file.txt') = ''` |
| bare FsPathDir | test_fs | `FsPathDir('file.txt') = '.'` |

Status: **PASS** (anchors present).

## A. FsPathDir sites (8)

```
core/src/nextpas.core.fs.path.pas:16:function FsPathDir(const APath: string): string;
core/src/nextpas.core.fs.path.pas:92:function FsPathDir(const APath: string): string;
core/src/nextpas.core.fs.path.pas:104:  ADir := FsPathDir(APath);
core/src/nextpas.core.path.pas:123:  Result := FsPathDir(APath);
core/src/nextpas.core.path.pas:321:  LDir := FsPathDir(AFileName);
core/src/nextpas.core.fs.pas:638:  Result := nextpas.core.fs.path.FsPathDir(APath);
core/src/nextpas.core.fs.util.pas:613:        Target := FsPathJoin([FsPathDir(P), Target]);
core/src/nextpas.core.fs.util.pas:622:    Parent := FsPathDir(P);
```

## B. PathDir call sites (6)

```
core/src/nextpas.core.tls.logging.pas:365:  LDir := nextpas.core.fs.PathDir(AFileName);
core/src/nextpas.core.tls.freepascal.earlydatareplay.dirstore.pas:333:  LDir := nextpas.core.fs.PathDir(LLockFileName);
core/src/nextpas.core.tls.freepascal.earlydatareplay.dirstore.pas:565:  LParentDirectory := nextpas.core.fs.PathDir(FDirectoryName);
core/src/nextpas.core.tls.freepascal.earlydatareplay.fileprovider.pas:242:  LDir := PathDir(LLockFileName);
core/src/nextpas.core.http.client.helpers.pas:228:    LDestDir := nextpas.core.fs.PathDir(ADestPath);
core/src/nextpas.core.git.libgit2.pas:254:    p := PathDir(p);
```

## C. Co-use nextpas.core.path + nextpas.core.fs (19) — warn

- `compiler/backend/np_backend_plan.pas`
- `compiler/frontend/np_package_lock.pas`
- `compiler/frontend/np_package_manifest.pas`
- `compiler/frontend/np_unit_resolver.pas`
- `compiler/frontend/np_workspace_model.pas`
- `compiler/sema/np_semantic_analyzer.pas`
- `compiler/tests/test_installed_target_unit_call_binding.pas`
- `compiler/tests/test_semantic_reexported_type_member_call.pas`
- `compiler/tests/test_unit_resolver_implementation_cycle.pas`
- `compiler/tests/test_unit_root_implicit_system.pas`
- `compiler/toolchain/np_toolchain_plan.pas`
- `compiler/toolchain/np_toolchain_profiles.pas`
- `compiler/toolchain/np_toolchain_runner.pas`
- `core/src/nextpas.core.fs.pas`
- `core/src/nextpas.core.path.pas`
- `core/src/nextpas.core.system.sysutils.pas`
- `core/src/nextpas.core.test.helpers.pas`
- `core/src/nextpas.core.test.runner.context.pas`
- `core/src/nextpas.core.tls.freepascal.earlydatareplay.fileprovider.pas`

## D. PathJoin style counts

| Form | Approx count |
|------|--------------|
| PathJoin2( | 2 |
| FsPathJoin( | 18 |
| PathJoin([ | 3 |
| PathJoin(a,b) style | 2 |

## Conclusion

- `path.PathDir` and `fs.PathDir` both squeeze bare-name dir to empty; risk is **FsPathDir** vs **PathDir**, not path vs fs PathDir.
- Call sites using `fs.PathDir` / `PathDir` on lock/file paths (tls/http/git) are typically non-bare → **low risk**.
- Co-use of path+fs units is **warn-only**; review when adding new joins.
- **No confirmed production bug** from this static pass (U4).

## Re-run

```bash
bash scripts/path-mixuse-audit.sh
bash scripts/path-contract-check.sh
```
