# FountainCodexLaneKit Plans

## v0.1.1 — wire-correct app-server initialization

- Launches the explicitly supplied runtime with `app-server --stdio`.
- Sends `initialize` once, then the `initialized` notification, before normal requests.
- Omits the `jsonrpc` header required to be absent on the Codex JSONL wire.
- Protocol authority checked against OpenAI Codex `main` at commit `9bf673718a4605b49e47d00762121d372af95439`.

## v0.1.0 — transport and instrument foundation

- Explicit runtime admission and provenance inputs.
- Isolated child process and newline-delimited JSON-RPC transport.
- Typed lifecycle/event mirror with cancellation and shutdown.
- Existing `reframe/lane.handshake` boundary without guessed Codex operation topics.
- No claim of pinned runtime, account acceptance, Reframe binding, live acceptance, or release beyond this package.

## Next governed slice

Pin the official Codex app-server schema revision and add typed account, thread, turn, approval, interruption, and
terminal-result operations only after their exact MIDI2 IDL identities are reviewed and generated.
