unit nextpas.core.window.fake.ffi;
{$I nextpas.core.settings.inc}
interface
// Fake backend has no native ABI; ffi is intentional no-op placeholder
// to satisfy 4-piece uniformity (base←ffi←loader←impl).
implementation
end.
