# zen-gateway-codec

`D13` pure codec as library, not gateway.

Builds `TCompletionRequest` with `System+Tools+Thinking`, calls `EncodeResponsesRequest` straight to `nextpas.core.agent.provider.openai.responses` wire (no HTTP), prints JSON, then decodes via `DecodeResponsesResponse` and `NewResponsesWireDecoder` fold. Proves codec is reusable without transport.

## Build & Run

```bash
make -C core/examples/nextpas.core.agent/zen-gateway-codec build
make -C core/examples/nextpas.core.agent/zen-gateway-codec run
make -C core/examples/nextpas.core.agent/zen-gateway-codec clean test
# direct:
fpc -Fu../../../src -Fi../../../src -MObjFPC -Sh -O2 main.lpr
```

Offline, no network, no API keys. Codec is pure `TJsonText` in/out.
