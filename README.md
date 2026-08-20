# FountainCodexLaneKit

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://www.swift.org)
[![MIDI 2.0](https://img.shields.io/badge/MIDI-2.0-blue.svg)](https://www.midi.org/midi-2-0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

FountainCodexLaneKit is a public Fountain Coach FCIS-KIT boundary for embedding an explicitly supplied Codex
app-server runtime in a Swift host. It owns runtime admission, an isolated child-process boundary, typed
newline-delimited JSON-RPC transport, lifecycle/event mirroring, cancellation, shutdown, and the existing MIDI2 lane
handshake surface.

The kit is deliberately product-neutral. It owns no Reframe views, FountainStore records, AX projection, credentials,
prompts, manuscript material, provider payloads, or release claims. The consumer supplies the host Store, AX, scenario,
and live-acceptance witnesses.

## Use

```swift
dependencies: [
    .package(url: "https://github.com/Fountain-Coach/FountainCodexLaneKit.git", from: "0.1.0")
]
```

The `v0.1.1` release performs the required app-server `initialize` / `initialized` handshake and uses Codex's JSONL
wire shape. The exact Codex app-server method inventory must be
pinned and reviewed before a consumer adds typed account, thread, turn, or approval operations.

## FCIS-KIT boundary

- **Owns:** explicit runtime admission, process lifecycle, JSON-RPC correlation, typed lifecycle events, cancellation,
  shutdown, and the reusable `reframe/lane.handshake` projection.
- **Consumes:** a verified executable URL, protocol revision, runtime digest, app-specific `CODEX_HOME`, and a host
  environment supplied by the consumer.
- **Does not own:** PATH/shell discovery, credentials, automatic approval, product semantics, Store/AX evidence, or
  live/released claims.

Reachability is not admission. A handshake with `credentialVerified == false` remains non-admitted and cannot authorize
a provider lane by itself.

## Validation

```sh
swift test
```

See [FCIS_COMPLIANCE.md](FCIS_COMPLIANCE.md) for the public/private boundary and release gates.

## References

- [Chapter 88 — CodexKit Is a Governed Codex App-Server Boundary](https://governance.fountain.coach/chapters/88-codexkit-is-a-governed-codex-app-server-boundary/)
- [Fountain Coach FCIS-KIT standards](https://github.com/Fountain-Coach/.github/tree/main/docs)
- [Official Codex App Server overview](https://openai.com/index/unlocking-the-codex-harness/)
- [MIDI2 backplane](https://github.com/Fountain-Coach/midi-backplane)
