import Foundation
import Speech
import Combine
import AVFoundation

class VoiceManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isListening = false
    @Published var partialText = ""
    
    func startListening(onResults: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    do {
                        try self.startRecording(onResults: onResults, onError: onError)
                    } catch {
                        onError("Could not start recording: \(error.localizedDescription)")
                    }
                case .denied:
                    onError("Speech recognition permission denied")
                case .restricted:
                    onError("Speech recognition restricted on this device")
                case .notDetermined:
                    onError("Speech recognition not yet authorized")
                @unknown default:
                    onError("Unknown authorization status")
                }
            }
        }
    }

    private func startRecording(onResults: @escaping (String) -> Void, onError: @escaping (String) -> Void) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            onError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                self.partialText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                if isFinal {
                    onResults(result.bestTranscription.formattedString)
                }
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isListening = false
                self.partialText = ""
                
                if let error = error {
                    // Ignore cancellation errors
                    if (error as NSError).code != 301 {
                        onError(error.localizedDescription)
                    }
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }
}
