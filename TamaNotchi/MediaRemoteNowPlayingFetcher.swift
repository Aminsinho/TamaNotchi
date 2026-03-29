import CoreFoundation
import Foundation

/// Lee el reproductor del sistema (Spotify, Safari/Chrome, Music, etc.) vía MediaRemote.framework.
/// API privada: no aplica a Mac App Store; sí a apps firmadas / notarizadas por fuera.
enum MediaRemoteNowPlayingFetcher {
    private static let bundle: CFBundle? = {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework") as CFURL
        return CFBundleCreate(kCFAllocatorDefault, url)
    }()

    /// `void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t, void (^)(NSDictionary *))`
    private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void

    private static let getNowPlaying: MRMediaRemoteGetNowPlayingInfoFn? = {
        guard let bundle else { return nil }
        guard let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { return nil }
        return unsafeBitCast(ptr, to: MRMediaRemoteGetNowPlayingInfoFn.self)
    }()

    static func fetchNowPlayingInfo(completion: @escaping (NSDictionary?) -> Void) {
        guard let getNowPlaying else {
            completion(nil)
            return
        }
        getNowPlaying(DispatchQueue.global(qos: .userInitiated), completion)
    }
}
