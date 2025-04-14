//
//  SystemAudioRecorder.swift
//  HiddenWindowMCP
//
//  Created by Maxim Frolov on 4/8/25.
//

import Foundation
import AVFoundation
import CoreAudio

// This class extends the functionality of AudioRecorder to attempt to capture system audio
// on macOS using AVCaptureSession and other native macOS audio APIs.
class SystemAudioRecorder {
    // Singleton instance
    static let shared = SystemAudioRecorder()
    
    // Audio engine components
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var audioFile: AVAudioFile?
    
    // Current recording state
    private(set) var isRecording = false
    private var currentRecordingURL: URL?
    
    // Initialize components
    private init() {
        setupAudioEngine()
    }
    
    // Set up the audio engine for recording
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        
        guard let audioEngine = audioEngine, let mixerNode = mixerNode else {
            print("Failed to create audio engine components")
            return
        }
        
        // Add mixer node to the engine
        audioEngine.attach(mixerNode)
        
        // Connect the input node (microphone) to the mixer
        let inputNode = audioEngine.inputNode
        audioEngine.connect(inputNode, to: mixerNode, format: inputNode.outputFormat(forBus: 0))
        
        // Set the mixer tap format to high quality
        let tapFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: 44100,
                                      channels: 2,
                                      interleaved: false)
        
        // Install tap on the mixer to collect audio
        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] (buffer, time) in
            guard let self = self, let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing to audio file: \(error.localizedDescription)")
            }
        }
        
        // Start the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }
    
    // Generate a filename for recording
    private func generateFilename() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        return desktopURL.appendingPathComponent("Recording_\(dateString).m4a")
    }
    
    // Start recording
    func startRecording() -> Bool {
        guard let audioEngine = audioEngine, let mixerNode = mixerNode else {
            print("Audio engine not properly configured")
            return false
        }
        
        // Make sure the engine is running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print("Failed to start audio engine: \(error.localizedDescription)")
                return false
            }
        }
        
        // Generate output file URL
        let outputFileURL = generateFilename()
        currentRecordingURL = outputFileURL
        
        // Create audio file
        let recordingFormat = mixerNode.outputFormat(forBus: 0)
        do {
            audioFile = try AVAudioFile(forWriting: outputFileURL, 
                                      settings: recordingFormat.settings,
                                      commonFormat: .pcmFormatFloat32,
                                      interleaved: false)
            isRecording = true
            return true
        } catch {
            print("Failed to create audio file: \(error.localizedDescription)")
            return false
        }
    }
    
    // Stop recording
    func stopRecording() -> URL? {
        guard isRecording, let mixerNode = mixerNode else {
            return nil
        }
        
        // Remove the tap and close the file
        mixerNode.removeTap(onBus: 0)
        audioFile = nil
        isRecording = false
        
        // Return the URL to the recording
        return currentRecordingURL
    }
}
