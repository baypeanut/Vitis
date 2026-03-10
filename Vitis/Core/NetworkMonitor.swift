
import Network

/// Authoritative connectivity observer backed by NWPathMonitor.
/// Starts on first access; lives for the app lifetime.
final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.vitis.network", qos: .utility)
    private var _path: NWPath

    /// True when NWPathMonitor reports a satisfied path.
    var isConnected: Bool { _path.status == .satisfied }

    private init() {
        _path = monitor.currentPath
        monitor.pathUpdateHandler = { [weak self] path in self?._path = path }
        monitor.start(queue: queue)
    }
}
