/// 录音状态机（RecordingStateMachine）测试。
/// 覆盖 RecordingState.swift 转移表中的全部合法路径，以及非法转移被忽略且状态不变。
/// 状态机为纯值类型、无 IO，可直接驱动断言。
@testable import Sprout
import XCTest

final class RecordingStateMachineTests: XCTestCase {
    /// 主链路：idle → recording → recorded → queued → uploading → confirmed。
    func testHappyPathTransitions() {
        var machine = RecordingStateMachine()
        XCTAssertEqual(machine.state, .idle)
        XCTAssertEqual(machine.handle(.startTapped), .recording(duration: 0))
        let fileID = UUID()
        XCTAssertEqual(machine.handle(.stopTapped(fileID: fileID, duration: 4.5)),
                       .recorded(fileID: fileID, duration: 4.5))
        XCTAssertEqual(machine.handle(.submitTapped), .queued)
        XCTAssertEqual(machine.handle(.uploadStarted), .uploading)
        XCTAssertEqual(machine.handle(.uploadConfirmed), .confirmed)
    }

    /// 中断恢复：recording → interrupted →（shouldResume: true）→ recording 保留已录秒数。
    func testInterruptionResumeKeepsRecordedSeconds() {
        var machine = RecordingStateMachine()
        machine.handle(.startTapped)
        XCTAssertEqual(machine.handle(.interruptionBegan(recordedSeconds: 12.0)),
                       .interrupted(recordedSeconds: 12.0))
        XCTAssertEqual(machine.handle(.interruptionEnded(shouldResume: true)),
                       .recording(duration: 12.0))
    }

    /// 中断不恢复：interruptionEnded(false) 为原地事件，状态保持 interrupted。
    func testInterruptionEndedWithoutResumeStaysInterrupted() {
        var machine = RecordingStateMachine()
        machine.handle(.startTapped)
        machine.handle(.interruptionBegan(recordedSeconds: 7.0))
        XCTAssertEqual(machine.handle(.interruptionEnded(shouldResume: false)),
                       .interrupted(recordedSeconds: 7.0))
    }

    /// 重录：recorded + startTapped → recording(duration: 0)。
    func testRecordedCanRestartRecording() {
        var machine = RecordingStateMachine()
        machine.handle(.startTapped)
        machine.handle(.stopTapped(fileID: UUID(), duration: 3.0))
        XCTAssertEqual(machine.handle(.startTapped), .recording(duration: 0))
    }

    /// playbackFinished 为原地事件；recorded + reset 取消回 idle。
    func testPlaybackFinishedAndResetFromRecorded() {
        var machine = RecordingStateMachine()
        let fileID = UUID()
        machine.handle(.startTapped)
        machine.handle(.stopTapped(fileID: fileID, duration: 3.0))
        XCTAssertEqual(machine.handle(.playbackFinished), .recorded(fileID: fileID, duration: 3.0))
        XCTAssertEqual(machine.handle(.reset), .idle)
    }

    /// 错误路径：idle/recording/interrupted/uploading 下的失败事件进入 error 且 retryable 为 true。
    func testErrorTransitionsFromFailableStates() {
        var fromIdle = RecordingStateMachine()
        if case .error(_, let retryable) = fromIdle.handle(.permissionDenied) {
            XCTAssertTrue(retryable)
        } else {
            XCTFail("idle + permissionDenied 应进入 error")
        }
        var recording = RecordingStateMachine()
        recording.handle(.startTapped)
        if case .error(_, let retryable) = recording.handle(.diskFull) {
            XCTAssertTrue(retryable)
        } else {
            XCTFail("recording + diskFull 应进入 error")
        }
        var interrupted = RecordingStateMachine()
        interrupted.handle(.startTapped)
        interrupted.handle(.interruptionBegan(recordedSeconds: 1.0))
        XCTAssertEqual(interrupted.handle(.failed("编码失败")), .error(message: "编码失败", retryable: true))
        var uploading = RecordingStateMachine()
        uploading.handle(.startTapped)
        uploading.handle(.stopTapped(fileID: UUID(), duration: 1.0))
        uploading.handle(.submitTapped)
        uploading.handle(.uploadStarted)
        XCTAssertEqual(uploading.handle(.failed("上传失败")), .error(message: "上传失败", retryable: true))
    }

    /// reset 可从 interrupted/recorded/queued/error/confirmed 回到 idle。
    func testResetAllowedFromTerminalAndPausedStates() {
        var interrupted = RecordingStateMachine()
        interrupted.handle(.startTapped)
        interrupted.handle(.interruptionBegan(recordedSeconds: 2.0))
        XCTAssertEqual(interrupted.handle(.reset), .idle)
        var queued = RecordingStateMachine()
        queued.handle(.startTapped)
        queued.handle(.stopTapped(fileID: UUID(), duration: 2.0))
        queued.handle(.submitTapped)
        XCTAssertEqual(queued.handle(.reset), .idle)
        var errored = RecordingStateMachine()
        errored.handle(.permissionDenied)
        XCTAssertEqual(errored.handle(.reset), .idle)
        var confirmed = RecordingStateMachine()
        confirmed.handle(.startTapped)
        confirmed.handle(.stopTapped(fileID: UUID(), duration: 2.0))
        confirmed.handle(.submitTapped)
        confirmed.handle(.uploadStarted)
        confirmed.handle(.uploadConfirmed)
        XCTAssertEqual(confirmed.handle(.reset), .idle)
    }

    /// 非法转移被忽略且状态不变：idle 下 stopTapped/submitTapped/uploadConfirmed 等。
    func testIdleIgnoresNonStartEvents() {
        var machine = RecordingStateMachine()
        XCTAssertEqual(machine.handle(.stopTapped(fileID: UUID(), duration: 1.0)), .idle)
        XCTAssertEqual(machine.handle(.submitTapped), .idle)
        XCTAssertEqual(machine.handle(.uploadConfirmed), .idle)
        XCTAssertEqual(machine.handle(.interruptionEnded(shouldResume: true)), .idle)
    }

    /// confirmed 为终态：startTapped/failed 均被忽略，只能经 reset 离开。
    func testConfirmedIgnoresStartAndFailure() {
        var machine = RecordingStateMachine()
        machine.handle(.startTapped)
        machine.handle(.stopTapped(fileID: UUID(), duration: 1.0))
        machine.handle(.submitTapped)
        machine.handle(.uploadStarted)
        machine.handle(.uploadConfirmed)
        XCTAssertEqual(machine.handle(.startTapped), .confirmed)
        XCTAssertEqual(machine.handle(.failed("晚了")), .confirmed)
    }

    /// recording 与 uploading 不能直接 reset；recorded/queued/error 下的失败事件视为噪音。
    func testResetAndFailureNoiseIgnored() {
        var recording = RecordingStateMachine()
        recording.handle(.startTapped)
        XCTAssertEqual(recording.handle(.reset), .recording(duration: 0))
        var uploading = RecordingStateMachine()
        uploading.handle(.startTapped)
        uploading.handle(.stopTapped(fileID: UUID(), duration: 1.0))
        uploading.handle(.submitTapped)
        uploading.handle(.uploadStarted)
        XCTAssertEqual(uploading.handle(.reset), .uploading)
        var recorded = RecordingStateMachine()
        let fileID = UUID()
        recorded.handle(.startTapped)
        recorded.handle(.stopTapped(fileID: fileID, duration: 1.0))
        XCTAssertEqual(recorded.handle(.failed("噪音")), .recorded(fileID: fileID, duration: 1.0))
        var errored = RecordingStateMachine()
        errored.handle(.failed("第一次"))
        XCTAssertEqual(errored.handle(.failed("第二次")), .error(message: "第一次", retryable: true))
    }
}
