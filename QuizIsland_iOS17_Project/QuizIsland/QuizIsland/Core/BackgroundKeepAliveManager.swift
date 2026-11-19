import Foundation
import AVFoundation

final class BackgroundKeepAliveManager {
    static let shared = BackgroundKeepAliveManager()
    private var audioPlayer: AVAudioPlayer?
    private var stopTimer: Timer?
    
    private init() {}
    
    /// 仅在触发搜题瞬间开启静音后台保活，默认最长 75 秒后自动关闭以省电
    func startTemporaryKeepAlive(duration: TimeInterval = 75) {
        DispatchQueue.main.async {
            self.stopTimer?.invalidate()
            
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                
                if self.audioPlayer == nil {
                    let silentWavData = self.generateSilentWavData()
                    self.audioPlayer = try AVAudioPlayer(data: silentWavData)
                    self.audioPlayer?.numberOfLoops = -1
                    self.audioPlayer?.volume = 0.0
                }
                
                if self.audioPlayer?.isPlaying == false {
                    self.audioPlayer?.play()
                }
                
                self.stopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.stopKeepAlive()
                }
            } catch {
                print("[KeepAlive] Audio session setup failed: \(error)")
            }
        }
    }
    
    func stopKeepAlive() {
        DispatchQueue.main.async {
            self.stopTimer?.invalidate()
            self.stopTimer = nil
            self.audioPlayer?.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    /// 动态生成 1 秒标准 PCM 静音 WAV 数据，无需外部音频文件依赖
    private func generateSilentWavData() -> Data {
        let sampleRate: UInt32 = 8000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let numSamples: UInt32 = 8000
        let dataSize: UInt32 = numSamples * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let chunkSize: UInt32 = 36 + dataSize
        
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = numChannels * (bitsPerSample / 8)
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
