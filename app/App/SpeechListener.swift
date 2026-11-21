import Foundation
import AVFoundation
import Speech
import Observation

/// Listens with the speech recognition built into iOS (free, no account): on the device itself when
/// Arabic is supported there, otherwise Apple's recognition service. Keeps listening across pauses
/// until `stop()`, collecting what was heard in `finals` and `partial`. Nothing is recorded or kept:
/// the text lives only while the screen is open.
@MainActor @Observable
final class SpeechListener {
    private(set) var listening = false
    private(set) var partial = ""
    private(set) var finals: [String] = []
    private(set) var problem: String?
    /// Recognition runs fully on the device (works without internet).
    private(set) var onDevice = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var wanted = false
    @ObservationIgnored private var errors = 0

    /// Everything heard so far, in order.
    var text: String { (finals + [partial]).filter { !$0.isEmpty }.joined(separator: " ") }

    func clear() { finals = []; partial = "" }

    func start() {
        problem = nil
        guard let recognizer else { problem = "التعرف على الكلام العربي غير متاح في هذا الجهاز"; return }
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else { self.problem = "اسمح للتطبيق بالتعرف على الكلام من الإعدادات"; return }
                AVAudioApplication.requestRecordPermission { ok in
                    Task { @MainActor in
                        guard ok else { self.problem = "اسمح للتطبيق باستخدام الميكروفون من الإعدادات"; return }
                        guard recognizer.isAvailable else { self.problem = "التعرف على الكلام غير متاح الآن، تأكد من الاتصال بالإنترنت"; return }
                        self.wanted = true
                        self.begin()
                    }
                }
            }
        }
    }

    func stop() {
        let was = wanted || listening
        wanted = false
        end()
        if !partial.isEmpty { finals.append(partial); partial = "" }
        listening = false
        guard was else { return }
        // Back to playback, as the recitation player expects.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func begin() {
        guard wanted, let recognizer else { return }
        AudioCenter.shared.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { fail("تعذر تشغيل الميكروفون"); return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        onDevice = recognizer.supportsOnDeviceRecognition
        if onDevice { req.requiresOnDeviceRecognition = true }
        if #available(iOS 16, *) { req.addsPunctuation = false }
        request = req

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { fail("لا يوجد ميكروفون متاح"); return }
        Self.tap(input, format: format, into: req)
        engine.prepare()
        do { try engine.start() } catch { fail("تعذر بدء الاستماع"); return }
        listening = true

        task = Self.recognize(recognizer, req) { [weak self] text, final, error in
            Task { @MainActor in self?.handle(text: text, final: final, error: error) }
        }
    }

    /// Audio and recognition callbacks run off the main thread; kept out of the main-actor class.
    nonisolated private static func tap(_ input: AVAudioInputNode, format: AVAudioFormat, into req: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
    }

    nonisolated private static func recognize(_ r: SFSpeechRecognizer, _ req: SFSpeechAudioBufferRecognitionRequest,
                                              _ done: @escaping @Sendable (String?, Bool, Error?) -> Void) -> SFSpeechRecognitionTask {
        r.recognitionTask(with: req) { result, error in
            done(result?.bestTranscription.formattedString, result?.isFinal ?? false, error)
        }
    }

    private func handle(text: String?, final: Bool, error: Error?) {
        if let text, !text.isEmpty { partial = text; errors = 0 }
        guard final || error != nil else { return }
        if !partial.isEmpty { finals.append(partial); partial = "" }
        end()
        guard wanted else { listening = false; return }
        if error != nil && text == nil {
            errors += 1
            if errors > 5 { fail("توقف التعرف على الكلام، اضغط للمتابعة"); return }
        }
        // A task ends after a pause or about a minute; listening starts again while the user has not stopped.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            self.begin()
        }
    }

    private func end() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func fail(_ message: String) {
        problem = message
        wanted = false
        end()
        listening = false
    }
}
