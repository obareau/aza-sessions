import AppKit
import AVFoundation
import AZACore
import LocalAuthentication
import SwiftUI
import UserNotifications

/// Enregistrement d'une note audio (m4a AAC mono), comme les mémos de Journal.
/// Pas de transcription : la dictée a été retirée d'AZA en v3.25.0 (décision d'Olivier).
@MainActor
final class DiaryRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var target: Int?
    private var onFinish: ((URL, Int) -> Void)?

    func start(for entry: Int, onFinish: @escaping (URL, Int) -> Void) {
        error = nil
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: begin(entry, onFinish)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                DispatchQueue.main.async {
                    if ok { self.begin(entry, onFinish) }
                    else { self.error = "Micro refusé. Autorise AZA dans Réglages Système › Confidentialité › Micro." }
                }
            }
        default:
            error = "Micro refusé. Autorise AZA dans Réglages Système › Confidentialité › Micro."
        }
    }

    private func begin(_ entry: Int, _ onFinish: @escaping (URL, Int) -> Void) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aza-memo-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
                                       AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            guard r.record() else { error = "L'enregistrement n'a pas démarré (aucune entrée audio ?)."; return }
            recorder = r; target = entry; self.onFinish = onFinish
            recording = true; elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.elapsed = self?.recorder?.currentTime ?? 0 }
            }
        } catch {
            self.error = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let r = recorder, let t = target else { return }
        r.stop()
        timer?.invalidate(); timer = nil
        recording = false
        let url = r.url
        recorder = nil; target = nil
        onFinish?(url, t)
        onFinish = nil
    }
}

/// Lecture des notes audio — un seul son à la fois.
@MainActor
final class DiaryPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playing: String?
    @Published private(set) var progress: Double = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(_ id: String, url: URL) {
        if playing == id { stop(); return }
        stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.play()
        player = p; playing = id
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let p = self.player, p.duration > 0 else { return }
                self.progress = p.currentTime / p.duration
            }
        }
    }

    func stop() {
        player?.stop(); player = nil; playing = nil; progress = 0
        timer?.invalidate(); timer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }

    static func duration(_ url: URL) -> String {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return "" }
        let s = Int(p.duration.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Verrou du journal : Touch ID ou mot de passe de session (LocalAuthentication).
/// Se referme quand AZA passe à l'arrière-plan.
@MainActor
final class DiaryLock: ObservableObject {
    @Published private(set) var unlocked = false
    @Published var message = ""

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.unlocked = false }
        }
    }

    func unlock() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // Pas d'authentification possible (rare) : on ne bloque pas l'accès à ses propres textes.
            message = "Authentification indisponible sur ce Mac — journal ouvert."
            unlocked = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "ouvrir ton journal") { ok, e in
            DispatchQueue.main.async {
                self.unlocked = ok
                self.message = ok ? "" : (e?.localizedDescription ?? "Échec de l'authentification")
            }
        }
    }

    func lock() { unlocked = false }
}

/// Rappel quotidien d'écriture (le « planning » de Journal).
enum DiaryReminder {
    static let id = "aza-diary-reminder"

    static func apply(enabled: Bool, hour: Int, minute: Int, done: @escaping @MainActor (String) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { Task { @MainActor in done("Rappel désactivé") }; return }
        center.requestAuthorization(options: [.alert, .sound]) { ok, err in
            guard ok else {
                Task { @MainActor in
                    done("Notifications refusées\(err.map { " : \($0.localizedDescription)" } ?? "") — Réglages Système › Notifications › AZA")
                }
                return
            }
            let c = UNMutableNotificationContent()
            c.title = "Journal AZA"
            c.body = AZAData.reflections.randomElement() ?? "Quelques lignes pour aujourd'hui ?"
            c.sound = .default
            var comps = DateComponents(); comps.hour = hour; comps.minute = minute
            let req = UNNotificationRequest(identifier: id, content: c,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            center.add(req) { e in
                Task { @MainActor in done(e.map { "Rappel impossible : \($0.localizedDescription)" }
                                          ?? String(format: "✓ Rappel tous les jours à %02d:%02d", hour, minute)) }
            }
        }
    }
}
