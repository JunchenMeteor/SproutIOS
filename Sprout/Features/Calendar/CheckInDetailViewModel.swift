/// 打卡详情视图模型。
/// 拉取单条打卡详情与反馈摘要；录音只解析本机文件 URL，
/// 本机找不到时按保留策略文案提示，不作为加载失败。
import Foundation

@Observable
final class CheckInDetailViewModel {
    enum State {
        case loading
        case loaded(CheckInDetail)
        case failed(String)
    }

    private let backend: any BackendService
    let checkInId: String
    private(set) var state: State = .loading
    private(set) var audioUnavailable = false

    init(backend: any BackendService, checkInId: String) {
        self.backend = backend
        self.checkInId = checkInId
    }

    /// 加载打卡详情；失败进入可重试的错误态。
    func load() async {
        state = .loading
        do {
            state = .loaded(try await backend.fetchCheckIn(checkInId: checkInId))
        } catch {
            state = .failed("详情加载失败，请稍后重试")
        }
    }

    /// 本机录音文件缺失时切换为「录音不可用」提示。
    func markAudioUnavailable() {
        audioUnavailable = true
    }
}
