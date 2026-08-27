//
//  VoiceSearchSheet.swift
//  SpiceMonk
//
//

import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Voice Search Manager

@MainActor
final class VoiceSearchManager: ObservableObject {

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var soundLevel: CGFloat = 0.0
    @Published var errorMessage: String? = nil
    @Published var isAuthorized: Bool = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN")) ?? SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isAuthorized = (speechStatus == .authorized) && (micStatus == .authorized)
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                Task { @MainActor in
                    let granted = (status == .authorized) && micGranted
                    self.isAuthorized = granted
                    completion(granted)
                }
            }
        }
    }

    func startListening(onAutoFinish: @escaping (String) -> Void) {
        stopListening()
        errorMessage = nil
        transcript = ""

        requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.errorMessage = "Please grant microphone and speech recognition permissions in Settings to search by voice."
                return
            }

            self.beginAudioEngine(onAutoFinish: onAutoFinish)
        }
    }

    private func beginAudioEngine(onAutoFinish: @escaping (String) -> Void) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                errorMessage = "Unable to create speech request."
                return
            }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = text
                    self.resetSilenceTimer(with: text, onAutoFinish: onAutoFinish)
                }

                if error != nil || (result?.isFinal == true) {
                    self.stopListening()
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)

                // Calculate RMS sound level for live waveform / ripple effect
                let channelData = buffer.floatChannelData?[0]
                let channelDataLength = Int(buffer.frameLength)
                if let channelData, channelDataLength > 0 {
                    var sum: Float = 0.0
                    for i in 0..<channelDataLength {
                        sum += channelData[i] * channelData[i]
                    }
                    let rms = sqrt(sum / Float(channelDataLength))
                    let level = min(max(CGFloat(rms * 10.0), 0.0), 1.0)
                    Task { @MainActor in
                        self?.soundLevel = level
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
            stopListening()
        }
    }

    private func resetSilenceTimer(with text: String, onAutoFinish: @escaping (String) -> Void) {
        silenceTimer?.invalidate()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // If user pauses speaking for 1.8 seconds, automatically finish voice search
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                let finalQuery = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalQuery.isEmpty {
                    self.stopListening()
                    onAutoFinish(finalQuery)
                }
            }
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
        soundLevel = 0.0
    }
}

// MARK: - Voice Search Bottom Sheet View

struct VoiceSearchSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VoiceSearchManager()
    let onSearch: (String) -> Void

    private let sampleSuggestions = [
        "Organic Haldi",
        "Red Chilli Powder",
        "Black Pepper",
        "Mustard Seeds",
        "Garam Masala",
        "Coriander Powder",
        "Mirchi"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator handle
            Capsule()
                .fill(Color(hex: "D9DFD9"))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Search")
                        .font(.appFont(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(manager.isRecording ? "Listening to your spices request…" : "Tap the mic to speak")
                        .font(.appFont(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    manager.stopListening()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appFont(size: 22))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 10)

            // Central Animated Pulsing Mic Visualizer
            micVisualizer
                .padding(.vertical, 8)

            Spacer(minLength: 10)

            // Live Transcript Display
            transcriptCard
                .padding(.horizontal, 20)

            // Quick suggestion chips
            suggestionChips
                .padding(.top, 12)

            Spacer(minLength: 12)

            // Bottom Actions (if transcript exists)
            if !manager.transcript.isEmpty {
                bottomActions
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                Color.clear
                    .frame(height: 16)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            manager.startListening { query in
                triggerSearch(query)
            }
        }
        .onDisappear {
            manager.stopListening()
        }
    }

    // MARK: - Visualizer

    private var micVisualizer: some View {
        ZStack {
            if manager.isRecording {
                // Outer ripple wave 2
                Circle()
                    .fill(AppTheme.brandGreen.opacity(0.10))
                    .frame(width: 130 + manager.soundLevel * 30, height: 130 + manager.soundLevel * 30)
                    .animation(.easeOut(duration: 0.25), value: manager.soundLevel)

                // Outer ripple wave 1
                Circle()
                    .fill(AppTheme.brandGreen.opacity(0.20))
                    .frame(width: 105 + manager.soundLevel * 20, height: 105 + manager.soundLevel * 20)
                    .animation(.easeOut(duration: 0.2), value: manager.soundLevel)
            }

            // Main Mic Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if manager.isRecording {
                    manager.stopListening()
                } else {
                    manager.startListening { query in
                        triggerSearch(query)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: manager.isRecording
                                    ? [AppTheme.brandGreen, Color(hex: "0D552F")]
                                    : [AppTheme.accentSoft, Color(hex: "E8EDE9")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)
                        .shadow(color: manager.isRecording ? AppTheme.brandGreen.opacity(0.35) : .clear, radius: 12, y: 5)

                    Image(systemName: manager.isRecording ? "mic.fill" : "mic")
                        .font(.appFont(size: 28, weight: .bold))
                        .foregroundStyle(manager.isRecording ? .white : AppTheme.brandGreen)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(height: 140)
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        VStack(spacing: 8) {
            if let error = manager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.accentRed)
                    Text(error)
                        .font(.appFont(size: 13))
                        .foregroundStyle(AppTheme.accentRed)
                }
                .padding(12)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if manager.transcript.isEmpty {
                Text(manager.isRecording ? "Say something like \"Haldi powder\", \"Jeera\"…" : "Tap the microphone above to speak")
                    .font(.appFont(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 48)
            } else {
                Text("“\(manager.transcript)”")
                    .font(.appFont(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "F7F8F7"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking for:")
                .font(.appFont(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sampleSuggestions, id: \.self) { suggestion in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            triggerSearch(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.appFont(size: 11))
                                    .foregroundStyle(AppTheme.brandGreen)
                                Text(suggestion)
                                    .font(.appFont(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: 12) {
            if !manager.transcript.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    manager.transcript = ""
                    manager.startListening { query in
                        triggerSearch(query)
                    }
                } label: {
                    Text("Clear")
                        .font(.appFont(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "F0F2F0"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    triggerSearch(manager.transcript)
                } label: {
                    HStack(spacing: 6) {
                        Text("Search Now")
                            .font(.appFont(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.appFont(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.brandGreen.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func triggerSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        manager.stopListening()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSearch(trimmed)
        }
    }
}
