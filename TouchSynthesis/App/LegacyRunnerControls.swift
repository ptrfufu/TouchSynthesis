import Network
import SwiftUI

@MainActor
final class LegacyRunnerSession: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var status = ""
    @Published private(set) var screenshot: UIImage?

    private var listener: NWListener?
    private var connection: NWConnection?
    private var timeout: Task<Void, Never>?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    func start(_ job: LegacyRunnerJob) {
        guard !active, job.isValid else { return }
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.requiredLocalEndpoint = .hostPort(host: LegacyRunnerLink.host, port: LegacyRunnerLink.port)
        do {
            let listener = try NWListener(using: parameters)
            self.listener = listener
            active = true
            status = "Preparing the runner…"
            screenshot = nil
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor in
                    guard let self, let listener, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        self.status = "Now open TouchSynthesis Runner from TrollStore."
                    case .failed(let error): self.finish(error.localizedDescription)
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self, weak listener] connection in
                Task { @MainActor in
                    guard let self, let listener, self.listener === listener, self.connection == nil else {
                        connection.cancel()
                        return
                    }
                    self.accept(connection, job: job)
                }
            }
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TouchSynthesisRunner") { [weak self] in
                Task { @MainActor in self?.finish("iOS ended the background session. Run the job again.") }
            }
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 40_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish("Runner timed out. Start again and open TouchSynthesis Runner from TrollStore promptly.")
            }
            listener.start(queue: .main)
        } catch {
            finish(error.localizedDescription)
        }
    }

    func cancel() { finish("Cancelled") }

    private func accept(_ connection: NWConnection, job: LegacyRunnerJob) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                switch state {
                case .ready: self.exchange(job, over: connection)
                case .failed(let error): self.finish(error.localizedDescription)
                default: break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func exchange(_ job: LegacyRunnerJob, over connection: NWConnection) {
        status = "Runner connected. Waiting for the result…"
        LegacyRunnerLink.send(job, over: connection, limit: LegacyRunnerLink.maxJobSize) { [weak self] error in
            Task { @MainActor in
                guard let self, self.connection === connection else { return }
                if let error { self.finish(error.localizedDescription); return }
                LegacyRunnerLink.receive(LegacyRunnerResult.self, over: connection, limit: LegacyRunnerLink.maxResultSize) { [weak self] result in
                    Task { @MainActor in
                        guard let self, self.connection === connection else { return }
                        switch result {
                        case .success(let reply):
                            self.screenshot = reply.png.flatMap { UIImage(data: $0) }
                            self.finish(reply.error ?? (self.screenshot == nil ? "Runner returned no image." : "Completed. Screenshot received."))
                        case .failure(let error): self.finish(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    private func finish(_ message: String) {
        status = message
        active = false
        timeout?.cancel()
        timeout = nil
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

struct LegacyRunnerControls: View {
    @StateObject private var session = LegacyRunnerSession()
    @AppStorage("legacyRunnerTarget") private var target = ""
    @State private var action = LegacyRunnerJob.Action.screenshot
    @State private var x = 0.5
    @State private var y = 0.7
    @State private var endX = 0.5
    @State private var endY = 0.3

    private var job: LegacyRunnerJob {
        LegacyRunnerJob(target: target.trimmingCharacters(in: .whitespacesAndNewlines), action: action, x: x, y: y, endX: endX, endY: endY)
    }

    var body: some View {
        Form {
            Section("UI Automation") {
                TextField("Target app bundle ID", text: $target)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Action", selection: $action) {
                    ForEach(LegacyRunnerJob.Action.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                if action != .screenshot {
                    Text("Coordinates are fractions of the target app screenshot, with (0, 0) at the top left.")
                        .font(.footnote)
                    field("Start X", value: $x)
                    field("Start Y", value: $y)
                    if action == .swipe {
                        field("End X", value: $endX)
                        field("End Y", value: $endY)
                    }
                }
                Button("Start UI Automation") { session.start(job) }
                    .disabled(!job.isValid || session.active)
                if session.active { Button("Cancel", role: .cancel) { session.cancel() } }
                if !session.status.isEmpty { Text(session.status) }
            }
            if let image = session.screenshot {
                Image(uiImage: image).resizable().scaledToFit()
            }
        }
        .navigationTitle("TouchSynthesis")
    }

    private func field(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
