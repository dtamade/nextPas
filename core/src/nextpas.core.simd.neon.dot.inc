// Intentional empty include:
// wide dot helpers intentionally stay on the base scalar slots until NEON owns
// a real implementation.
// Keep this file as an audited include boundary so docs/tests can point at the
// retired NEON dot-wrapper layer without reintroducing scalar forwarders that
// add no runtime value and make dispatch ownership harder to audit.
