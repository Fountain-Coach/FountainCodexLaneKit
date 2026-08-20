# FCIS Compliance — FountainCodexLaneKit

Initial public repository declaration for `v0.1.0`.

## Binding standards

### FCIS-KIT

| Rule | Evidence |
| --- | --- |
| KIT-01 | This declaration, `AGENTS.md`, `PLANS.md`, and `Package.swift` name the owned seam and dependencies. |
| KIT-02 | The package has no third-party dependency and uses only Apple Foundation APIs. |
| KIT-03 | The seam is generic: host meaning, Store, AX, credentials, and acceptance remain consumer-owned. |
| KIT-04 | The initial public package is released as immutable semver `v0.1.0`. |
| KIT-05 | No revision pins or path dependencies. |
| KIT-07 | Release requires a clean tree, annotated tag, GitHub release, and green `swift test`. |
| KIT-08 | The kit is released upstream before a consumer depends on it. |
| KIT-11 | The package suite proves runtime admission, lane handshake semantics, and lifecycle sequencing. |
| KIT-13 | No UI, rendered output, private Store data, or consumer fixture is shipped. |

### Publication and source policy

This repository is public by an explicit Fountain Coach visibility decision on 2026-08-20. The public scope is limited
to the generic kit boundary, tests, governance documentation, and release provenance. It contains no Reframe runtime
source, credentials, prompts, manuscript material, private Store records, deployment details, or consumer fixtures.

### OpenAI attribution boundary

OpenAI is an external protocol/service reference. The kit does not imply endorsement, partnership, or ownership by
OpenAI. OpenAI marks remain the property of OpenAI; product-specific protocol revisions and compatibility evidence must
be recorded before a consumer claims implementation support.

## Falsification

```sh
rg -n 'import (SwiftUI|AppKit|UIKit|FoundationModels|CoreML)' Sources/   # must be empty
rg -n '\.package\(.*path:' Package.swift                              # must be empty
swift test
```
