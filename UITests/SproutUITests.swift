/// Sprout 冒烟 UI 测试（XCUITest）。
/// 覆盖三条主链路：首次家长设置 → 今日页三选一、复习模式 → 今日计划 → 练习页录音控件、
/// 四个根 tab 可见且可切换且每页有基本内容。
/// 源码无 launch argument / 测试钩子；onboarding 标记持久化在
/// Application Support/LocalState/state.json（非 UserDefaults），测试进程无法直接清除，
/// 因此每个用例启动后先经 completeOnboardingIfNeeded 自检：未完成设置当场走完，
/// 已完成则直接进入主界面，用例间无执行顺序依赖、可单独重跑。
/// 模拟服务有 0.3–0.8 秒随机延迟，所有等待一律用 waitForExistence(timeout:)，不用固定 sleep。
/// 模拟器无麦克风：只断言「开始录音」控件存在，不点击。
import XCTest


/// 冒烟用例集。单个断言失败即终止当前用例，避免级联误报。
final class SproutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 链路一：启动 → 家长设置页（昵称输入「测试」）→ 点「完成」→ 今日页三个日模式选择。
    /// 重跑时今日计划快照可能已存在（同日恢复），此时模式卡不再出现，降级断言「今日计划」。
    func testOnboardingToTodayFlow() throws {
        let app = launchApp()
        completeOnboardingIfNeeded(in: app)
        let newModeCard = app.staticTexts["学了新内容"]
        let planTitle = app.staticTexts["今日计划"]
        let reachedToday = newModeCard.waitForExistence(timeout: 10) || planTitle.exists
        XCTAssertTrue(reachedToday, "完成家长设置后未进入今日页")
        if newModeCard.exists {
            XCTAssertTrue(app.staticTexts["复习旧内容"].exists, "今日页缺少「复习旧内容」")
            XCTAssertTrue(app.staticTexts["没上课或不清楚"].exists, "今日页缺少「没上课或不清楚」")
        }
    }

    /// 链路二：今日页选「复习旧内容」→ 等待计划与「开始练习」→ 练习页录音控件出现。
    /// 重跑时计划快照可能已恢复（直接显示「开始练习」），此时跳过模式选择。
    func testReviewPlanFlow() throws {
        let app = launchApp()
        completeOnboardingIfNeeded(in: app)
        let startPractice = app.buttons["开始练习"]
        if !startPractice.waitForExistence(timeout: 3) {
            XCTAssertTrue(
                app.staticTexts["复习旧内容"].waitForExistence(timeout: 10),
                "今日页缺少「复习旧内容」模式卡"
            )
            /* 三张模式卡各有一个「就选这个」按钮，按布局顺序复习卡是第二个。 */
            let reviewPick = app.buttons.matching(identifier: "就选这个").element(boundBy: 1)
            XCTAssertTrue(reviewPick.exists, "未找到「复习旧内容」的选择按钮")
            scrollUntilHittable(reviewPick, in: app)
            reviewPick.tap()
        }
        XCTAssertTrue(startPractice.waitForExistence(timeout: 10), "今日计划未出现「开始练习」")
        scrollUntilHittable(startPractice, in: app)
        startPractice.tap()
        let recordButton = app.buttons["开始录音"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 10), "练习页录音控件未出现")
    }

    /// 链路三：日历 / 收藏 / 家长 tab 存在且可切换，每页加载出基本内容。
    func testTabsVisible() throws {
        let app = launchApp()
        completeOnboardingIfNeeded(in: app)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "根 tab 栏未出现")
        for name in ["今天", "日历", "收藏", "家长"] {
            XCTAssertTrue(tabBar.buttons[name].exists, "缺少 tab：\(name)")
        }
        tabBar.buttons["日历"].tap()
        XCTAssertTrue(
            textContaining("本月打卡", in: app).waitForExistence(timeout: 10),
            "日历页统计未加载"
        )
        tabBar.buttons["收藏"].tap()
        XCTAssertTrue(
            textContaining("素材为演示占位", in: app).waitForExistence(timeout: 10),
            "收藏页内容未加载"
        )
        tabBar.buttons["家长"].tap()
        XCTAssertTrue(
            app.buttons["切换账号 / 退出登录"].waitForExistence(timeout: 10),
            "家长页内容未加载"
        )
    }

    /// 启动应用并返回实例；源码无测试钩子，不传任何 launchArguments/Environment。
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    /// 未完成首次设置（出现「完成」按钮）时当场走完家长设置；已完成则直接返回。
    /// 等待教材行出现再提交，保证 selectedCourseEditionId 已默认选中，避免校验失败。
    private func completeOnboardingIfNeeded(in app: XCUIApplication) {
        let finishButton = app.buttons["完成"]
        guard finishButton.waitForExistence(timeout: 5) else { return }
        let courseReady = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "原创演示教材"))
            .firstMatch
        XCTAssertTrue(courseReady.waitForExistence(timeout: 10), "教材列表未加载")
        enterNickname("测试", in: app)
        scrollUntilHittable(finishButton, in: app)
        finishButton.tap()
    }

    /// 昵称含中文，typeText 无法键入（键盘无对应键位），改走模拟器剪贴板：
    /// 写入剪贴板 → 聚焦输入框 → 长按呼出编辑菜单 → 点粘贴（用户手势粘贴不触发隐私弹窗）。
    private func enterNickname(_ text: String, in app: XCUIApplication) {
        UIPasteboard.general.string = text
        let field = nicknameField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "未找到昵称输入框")
        let offset = field.elementType == .textField ? 0.5 : 0.7
        let target = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: offset))
        target.tap()
        target.press(forDuration: 1.2)
        let paste = app.menuItems
            .matching(NSPredicate(format: "label IN %@", ["Paste", "粘贴"]))
            .firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "粘贴菜单未出现")
        paste.tap()
        if app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
    }

    /// 定位昵称输入框。AppFormField 用 accessibilityElement(children: .combine)
    /// 合并了 label 与输入框：能直接查到 textField 就用；否则退化为合并容器
    /// （输入框位于容器下半部，点击偏移 0.7 处）。
    private func nicknameField(in app: XCUIApplication) -> XCUIElement {
        let byLabel = NSPredicate(format: "label CONTAINS %@", "孩子昵称")
        let textField = app.textFields.matching(byLabel).firstMatch
        if textField.exists { return textField }
        return app.descendants(matching: .any).matching(byLabel).firstMatch
    }

    /// 元素不在可视区时向上滑动直至可点击（最多 5 次）；滑动同时交互式收起键盘。
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var remaining = 5
        while !element.isHittable, remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }

    /// 按部分文案查询静态文本。
    private func textContaining(_ fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}
