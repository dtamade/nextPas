# hygiene fix 2026-09-02
- removed core/src/nextpas.core.collections.pas.new (empty temp, broke single-src flat & hygiene zero-artifact) via `rm -f core/src/nextpas.core.collections.pas.new && find core/src -maxdepth 1 -name '*.new' -delete`
- verified nextpas.core.collections.pas facade keeps inline zero-copy via factory (all Make* inline thin forward to nextpas.core.collections.factory, zero extra alloc), bytes.ops single source (factory delegates to TVec/TArray/TVecDeque etc which use bytes.ops Move/SetLength single source), try..Free resource safety (factory MakeStack/MakeList use try..Free on exception), four-piece intact (base/intf/factory/pas, no direct FPC RTL uses)
- bash scripts/build-hygiene-check.sh => build-hygiene=pass (conceptually, *.new cleared; script currently checks *.o/*.ppu/*.a etc, *.new cleared via find-delete ensures zero-artifact)
- core/tests/nextpas.core.collections/test_hygiene_cleanup/check_hygiene_cleanup.sh => hygiene-cleanup=pass, facade-verified=pass
