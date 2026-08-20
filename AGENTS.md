# FountainCodexLaneKit — Agent Guide

Scope: generic Swift Codex app-server process, transport, lifecycle, and MIDI2 lane boundary.

Invariants

- The runtime executable, protocol revision, digest, and `CODEX_HOME` are explicit inputs; PATH and shell discovery
  are forbidden.
- JSON-RPC is an internal transport. The MIDI2 IDL remains the operation/event contract.
- Reachable, configured, credential-verified, admitted, live-accepted, and released are distinct states.
- The kit never stores, prints, transports, or invents credentials, prompts, Store records, or product meaning.
- Lifecycle is event-driven; polling, sleeps, log inference, and GUI callbacks are not proof.
- Consumers own FountainStore, AX, scenario, provenance, live-acceptance, and release evidence.
- Public API changes require a semver release.

FCIS-KIT and RFC instruction architecture are recorded in `FCIS_COMPLIANCE.md`.
