import Foundation
import Network

struct LegacyRunnerJob: Codable {
    enum Action: String, Codable, CaseIterable, Identifiable {
        case screenshot, tap, swipe
        var id: Self { self }
    }

    let target: String
    let action: Action
    let x: Double
    let y: Double
    let endX: Double
    let endY: Double

    var isValid: Bool {
        target.utf8.count <= 255 && target.contains(".") &&
        target.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 } &&
        [x, y, endX, endY].allSatisfy { $0.isFinite && (0..<1).contains($0) } &&
        !target.hasPrefix("com.touchsynthesis.runner")
    }
}

struct LegacyRunnerResult: Codable {
    let png: Data?
    let error: String?
}

enum LegacyRunnerLink {
    static let host = NWEndpoint.Host("127.0.0.1")
    static let port = NWEndpoint.Port(integerLiteral: 38457)
    static let maxJobSize = 4096
    static let maxResultSize = 24_000_000

    enum LinkError: LocalizedError {
        case incompleteFrame, invalidLength
        var errorDescription: String? {
            switch self {
            case .incompleteFrame: return "The runner disconnected before sending its complete message."
            case .invalidLength: return "The runner sent an invalid message length."
            }
        }
    }

    static func send<T: Encodable>(_ value: T, over connection: NWConnection, limit: Int, completion: @escaping (Error?) -> Void) {
        do {
            let data = try JSONEncoder().encode(value)
            guard data.count <= limit else { throw LinkError.invalidLength }
            var length = UInt32(data.count).bigEndian
            var packet = Data(bytes: &length, count: 4)
            packet.append(data)
            connection.send(content: packet, completion: .contentProcessed { completion($0) })
        } catch {
            completion(error)
        }
    }

    static func receive<T: Decodable>(_ type: T.Type, over connection: NWConnection, limit: Int, completion: @escaping (Result<T, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { header, _, _, error in
            if let error { completion(.failure(error)); return }
            guard let header, header.count == 4 else { completion(.failure(LinkError.incompleteFrame)); return }
            let size = header.reduce(0) { ($0 << 8) | Int($1) }
            guard (1...limit).contains(size) else { completion(.failure(LinkError.invalidLength)); return }
            connection.receive(minimumIncompleteLength: size, maximumLength: size) { payload, _, _, error in
                if let error { completion(.failure(error)); return }
                guard let payload, payload.count == size else { completion(.failure(LinkError.incompleteFrame)); return }
                completion(Result { try JSONDecoder().decode(type, from: payload) })
            }
        }
    }
}
