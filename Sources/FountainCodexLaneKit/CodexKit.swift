import Foundation

public enum CodexKitError: Error, Equatable, Sendable {
    case runtimeNotExecutable(URL)
    case runtimeNotFound(URL)
    case incompatibleProtocol(expected: String, actual: String)
    case notStarted
    case alreadyStarted
    case terminated(Int32)
    case invalidResponse
    case remote(String)
    case cancelled
}

public struct CodexRuntimeDescriptor: Sendable, Equatable {
    public let executableURL: URL
    public let protocolRevision: String
    public let runtimeDigest: String
    public let codexHome: URL
    public let environment: [String: String]

    public init(
        executableURL: URL,
        protocolRevision: String,
        runtimeDigest: String,
        codexHome: URL,
        environment: [String: String] = [:]
    ) {
        self.executableURL = executableURL.standardizedFileURL
        self.protocolRevision = protocolRevision
        self.runtimeDigest = runtimeDigest
        self.codexHome = codexHome.standardizedFileURL
        self.environment = environment
    }

    public func validate(fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw CodexKitError.runtimeNotFound(executableURL)
        }
        guard fileManager.isExecutableFile(atPath: executableURL.path) else {
            throw CodexKitError.runtimeNotExecutable(executableURL)
        }
        guard !protocolRevision.isEmpty, !runtimeDigest.isEmpty else {
            throw CodexKitError.invalidResponse
        }
    }

    func childEnvironment() -> [String: String] {
        var result = environment
        result["CODEX_HOME"] = codexHome.path
        return result
    }
}

public enum CodexKitPhase: String, Codable, Sendable {
    case discovered
    case admitting
    case admitted
    case running
    case streaming
    case cancelling
    case settled
    case failed
    case stopped
}

public struct CodexKitEvent: Codable, Equatable, Sendable {
    public let operation: String
    public let correlationID: String
    public let executionID: String
    public let sequence: UInt64
    public let phase: CodexKitPhase
    public let method: String?
    public let payload: [String: JSONValue]

    public init(
        operation: String,
        correlationID: String,
        executionID: String,
        sequence: UInt64,
        phase: CodexKitPhase,
        method: String? = nil,
        payload: [String: JSONValue] = [:]
    ) {
        self.operation = operation
        self.correlationID = correlationID
        self.executionID = executionID
        self.sequence = sequence
        self.phase = phase
        self.method = method
        self.payload = payload
    }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw CodexKitError.invalidResponse }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct MIDI2LaneHandshake: Codable, Equatable, Sendable {
    public static let topic = "reframe/lane.handshake"
    public static let responseTopic = "reframe/lane.handshake.result"

    public let operation: String
    public let operationVersion: String
    public let role: String
    public let instrumentID: String
    public let laneID: String
    public let sessionID: String
    public let scope: String
    public let idempotencyKey: String

    public init(operation: String, operationVersion: String, role: String, instrumentID: String, laneID: String, sessionID: String, scope: String, idempotencyKey: String) {
        self.operation = operation
        self.operationVersion = operationVersion
        self.role = role
        self.instrumentID = instrumentID
        self.laneID = laneID
        self.sessionID = sessionID
        self.scope = scope
        self.idempotencyKey = idempotencyKey
    }
}

public struct MIDI2LaneHandshakeResult: Codable, Equatable, Sendable {
    public enum Readiness: String, Codable, Sendable { case unknown, configured, reachable, admitted, unavailable }

    public let operation: String
    public let operationVersion: String
    public let role: String
    public let instrumentID: String
    public let laneID: String
    public let readiness: Readiness
    public let detail: String
    public let evidence: [String]
    public let credentialRequired: Bool
    public let credentialVerified: Bool
    public let terminal: Bool

    public init(operation: String, operationVersion: String, role: String, instrumentID: String, laneID: String, readiness: Readiness, detail: String, evidence: [String], credentialRequired: Bool, credentialVerified: Bool, terminal: Bool) {
        self.operation = operation
        self.operationVersion = operationVersion
        self.role = role
        self.instrumentID = instrumentID
        self.laneID = laneID
        self.readiness = readiness
        self.detail = detail
        self.evidence = evidence
        self.credentialRequired = credentialRequired
        self.credentialVerified = credentialVerified
        self.terminal = terminal
    }
}

/// Product-neutral Codex app-server boundary and reusable MIDI2 lane instrument.
/// It never discovers a runtime through PATH/shell and never persists or emits credentials.
public actor CodexKitInstrument {
    public let descriptor: CodexRuntimeDescriptor
    public let instrumentID: String
    public let laneID: String

    private var process: Process?
    private var input: FileHandle?
    private var nextRequestID: UInt64 = 0
    private var nextSequence: UInt64 = 0
    private var continuations: [String: CheckedContinuation<[String: JSONValue], Error>] = [:]
    private var eventContinuation: AsyncStream<CodexKitEvent>.Continuation?

    public init(descriptor: CodexRuntimeDescriptor, instrumentID: String = "lane.codex.session", laneID: String = "codex") {
        self.descriptor = descriptor
        self.instrumentID = instrumentID
        self.laneID = laneID
    }

    public func events() -> AsyncStream<CodexKitEvent> {
        let (stream, continuation) = AsyncStream<CodexKitEvent>.makeStream()
        eventContinuation = continuation
        return stream
    }

    public func start(initialize: Bool = true) async throws {
        guard process == nil else { throw CodexKitError.alreadyStarted }
        try descriptor.validate()
        let child = Process()
        child.executableURL = descriptor.executableURL
        child.arguments = ["app-server", "--stdio"]
        child.environment = descriptor.childEnvironment()
        let childInput = Pipe()
        let childOutput = Pipe()
        child.standardInput = childInput
        child.standardOutput = childOutput
        child.standardError = Pipe()
        try child.run()
        process = child
        input = childInput.fileHandleForWriting
        emit(operation: "codex.instrument.start", phase: .discovered, payload: ["protocolRevision": .string(descriptor.protocolRevision), "runtimeDigest": .string(descriptor.runtimeDigest)])
        Task { [weak self] in await self?.readOutput(childOutput.fileHandleForReading) }
        guard initialize else { return }
        _ = try await request(
            method: "initialize",
            params: ["clientInfo": .object([
                "name": .string("fountain_coach_codex_kit"),
                "title": .string("Fountain Coach CodexKit"),
                "version": .string("0.1.1")
            ])],
            operation: "codex.protocol.initialize",
            correlationID: "codex-initialize",
            executionID: "codex-initialize"
        )
        try writeNotification(method: "initialized", params: [:])
    }

    public func handshake(_ request: MIDI2LaneHandshake) async throws -> MIDI2LaneHandshakeResult {
        guard process != nil else { throw CodexKitError.notStarted }
        emit(operation: request.operation, correlationID: request.idempotencyKey, phase: .admitting)
        let result = MIDI2LaneHandshakeResult(operation: request.operation, operationVersion: request.operationVersion, role: request.role, instrumentID: request.instrumentID, laneID: request.laneID, readiness: .reachable, detail: "Codex app-server process admitted; credential state remains host-owned", evidence: ["runtimeDigest:\(descriptor.runtimeDigest)", "protocolRevision:\(descriptor.protocolRevision)"], credentialRequired: true, credentialVerified: false, terminal: true)
        // Reachability is not admission. The host must complete credential/account policy before it can promote
        // this instrument to `admitted`; the kit never manufactures that fact from a live child process.
        emit(operation: request.operation, correlationID: request.idempotencyKey, phase: .settled, payload: ["readiness": .string(result.readiness.rawValue)])
        return result
    }

    public func request(method: String, params: [String: JSONValue], operation: String, correlationID: String, executionID: String) async throws -> [String: JSONValue] {
        guard process != nil, let input else { throw CodexKitError.notStarted }
        nextRequestID += 1
        let id = String(nextRequestID)
        emit(operation: operation, correlationID: correlationID, executionID: executionID, phase: .running, method: method)
        let result = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                continuations[id] = continuation
                do {
                    // Codex app-server uses JSON-RPC semantics but omits the jsonrpc header on its JSONL wire.
                    let message: [String: JSONValue] = ["id": .string(id), "method": .string(method), "params": .object(params)]
                    let data = try JSONEncoder().encode(message)
                    input.write(data + Data([0x0A]))
                } catch { continuation.resume(throwing: error) }
            }
        }, onCancel: { [weak self] in Task { await self?.cancelRequest(id: id, operation: operation, correlationID: correlationID, executionID: executionID) } })
        emit(operation: operation, correlationID: correlationID, executionID: executionID, phase: .settled, method: method, payload: result)
        return result
    }

    private func writeNotification(method: String, params: [String: JSONValue]) throws {
        guard let input else { throw CodexKitError.notStarted }
        let message: [String: JSONValue] = ["method": .string(method), "params": .object(params)]
        input.write(try JSONEncoder().encode(message) + Data([0x0A]))
    }

    public func shutdown() {
        process?.terminate()
        process = nil
        input = nil
        emit(operation: "codex.instrument.shutdown", phase: .stopped)
        eventContinuation?.finish()
        eventContinuation = nil
    }

    private func cancelRequest(id: String, operation: String, correlationID: String, executionID: String) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CodexKitError.cancelled)
        emit(operation: operation, correlationID: correlationID, executionID: executionID, phase: .cancelling)
    }

    private func readOutput(_ output: FileHandle) async {
        do {
            for try await line in output.bytes.lines {
                guard let data = line.data(using: .utf8), let message = try? JSONDecoder().decode([String: JSONValue].self, from: data) else { continue }
                if case .string(let id)? = message["id"], let continuation = continuations.removeValue(forKey: id) {
                    if case .object(let error)? = message["error"], case .string(let detail)? = error["message"] { continuation.resume(throwing: CodexKitError.remote(detail)) }
                    else if case .object(let result)? = message["result"] { continuation.resume(returning: result) }
                    else { continuation.resume(throwing: CodexKitError.invalidResponse) }
                } else if case .string(let method)? = message["method"] {
                    emit(operation: "codex.protocol.event", phase: .streaming, method: method, payload: message)
                }
            }
        } catch { }
    }

    private func emit(operation: String, correlationID: String = "", executionID: String = "", phase: CodexKitPhase, method: String? = nil, payload: [String: JSONValue] = [:]) {
        nextSequence += 1
        eventContinuation?.yield(CodexKitEvent(operation: operation, correlationID: correlationID, executionID: executionID, sequence: nextSequence, phase: phase, method: method, payload: payload))
    }
}
