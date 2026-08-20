import Foundation
import XCTest
@testable import FountainCodexLaneKit

final class CodexKitTests: XCTestCase {
    func testLaneHandshakeUsesExistingIDLTopicsAndDoesNotClaimCredentialVerification() async throws {
        let executable = URL(fileURLWithPath: "/bin/sh")
        let descriptor = CodexRuntimeDescriptor(executableURL: executable, protocolRevision: "test-protocol", runtimeDigest: "sha256:test", codexHome: URL(fileURLWithPath: "/tmp/codex-kit-test"))
        let instrument = CodexKitInstrument(descriptor: descriptor)
        try await instrument.start()
        let request = MIDI2LaneHandshake(operation: MIDI2LaneHandshake.topic, operationVersion: "1", role: "llm.invoke", instrumentID: "lane.codex.session", laneID: "codex", sessionID: "test-session", scope: "test", idempotencyKey: "test-key")
        let result = try await instrument.handshake(request)
        XCTAssertEqual(MIDI2LaneHandshake.responseTopic, "reframe/lane.handshake.result")
        XCTAssertEqual(result.readiness, .reachable)
        XCTAssertFalse(result.credentialVerified)
        XCTAssertTrue(result.credentialRequired)
        XCTAssertNotEqual(result.readiness, .admitted)
        await instrument.shutdown()
    }

    func testRuntimeAdmissionRejectsNonExecutablePath() async {
        let descriptor = CodexRuntimeDescriptor(executableURL: URL(fileURLWithPath: "/definitely/missing/codex"), protocolRevision: "v1", runtimeDigest: "sha256:test", codexHome: URL(fileURLWithPath: "/tmp/codex-kit-test"))
        do {
            try descriptor.validate()
            XCTFail("expected explicit runtime admission failure")
        } catch let error as CodexKitError {
            XCTAssertEqual(error, .runtimeNotFound(descriptor.executableURL))
        } catch { XCTFail("unexpected error: \(error)") }
    }

    func testLifecycleSequencesAreMonotonic() async throws {
        let descriptor = CodexRuntimeDescriptor(executableURL: URL(fileURLWithPath: "/bin/sh"), protocolRevision: "v1", runtimeDigest: "sha256:test", codexHome: URL(fileURLWithPath: "/tmp/codex-kit-test"))
        let instrument = CodexKitInstrument(descriptor: descriptor)
        let stream = await instrument.events()
        try await instrument.start()
        _ = try await instrument.handshake(MIDI2LaneHandshake(operation: MIDI2LaneHandshake.topic, operationVersion: "1", role: "llm.invoke", instrumentID: "lane.codex.session", laneID: "codex", sessionID: "s", scope: "test", idempotencyKey: "k"))
        await instrument.shutdown()
        var sequences: [UInt64] = []
        for await event in stream {
            sequences.append(event.sequence)
            if event.phase == .stopped { break }
        }
        XCTAssertEqual(sequences, sequences.sorted())
        XCTAssertGreaterThanOrEqual(sequences.count, 3)
    }
}
