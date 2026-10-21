import XCTest

final class AppFlowTests: XCTestCase {
    @MainActor func testGameFlowAndPersistence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        func shot(_ name: String) { let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item) }
        XCTAssertTrue(app.buttons["Начать игру"].waitForExistence(timeout: 10)); shot("01-home")
        app.buttons["Начать игру"].tap()
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5)); shot("02-packs-uikit")
        app.buttons["Дальше"].tap()
        XCTAssertTrue(app.textFields["Название команды"].firstMatch.waitForExistence(timeout: 5)); shot("03-teams")
        app.buttons["Дальше"].tap()
        XCTAssertTrue(app.buttons["К игре"].waitForExistence(timeout: 5)); shot("04-settings")
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0)
        app.buttons["К игре"].tap()
        XCTAssertTrue(app.buttons["Мы готовы"].waitForExistence(timeout: 5)); shot("05-ready")
        app.buttons["Мы готовы"].tap()
        XCTAssertTrue(app.buttons["↑  Угадано"].waitForExistence(timeout: 5)); shot("06-word")
        let word = app.staticTexts["wordCard"]
        let initial = word.label
        word.swipeUp()
        XCTAssertTrue(app.staticTexts["wordCard"].waitForExistence(timeout: 2))
        XCTAssertNotEqual(app.staticTexts["wordCard"].label, initial)
        XCTAssertTrue(app.staticTexts["1 угадано"].waitForExistence(timeout: 3))
        app.staticTexts["wordCard"].swipeDown()
        XCTAssertTrue(app.staticTexts["1 угадано"].waitForExistence(timeout: 3))
        app.buttons["Отменить последнее слово"].tap()
        XCTAssertTrue(app.staticTexts["1 угадано"].exists)
        app.buttons["Пауза"].tap()
        XCTAssertTrue(app.staticTexts["Таймер остановлен"].waitForExistence(timeout: 3)); shot("14-pause")
        app.buttons["Продолжить"].tap()
        XCTAssertTrue(app.buttons["Завершить слово"].waitForExistence(timeout: 40)); shot("07-common")
        app.buttons["Завершить слово"].tap()
        XCTAssertTrue(app.staticTexts["Кто угадал?"].waitForExistence(timeout: 3)); shot("09-award")
        app.buttons.containing(.staticText, identifier: "Медведи").firstMatch.tap()
        XCTAssertTrue(app.buttons["Сохранить результат"].waitForExistence(timeout: 3)); shot("10-result")
        app.buttons["Сохранить результат"].tap()
        XCTAssertTrue(app.buttons["Следующий ход"].waitForExistence(timeout: 3)); shot("11-score")
        app.buttons["Следующий ход"].tap()
        XCTAssertTrue(app.staticTexts["Медведи"].exists)
        app.buttons["Мы готовы"].tap(); app.buttons["Пауза"].tap()
        app.buttons["Завершить игру"].tap()
        app.buttons["Завершить игру"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Ещё партию"].waitForExistence(timeout: 5)); shot("12-winner")
        app.buttons["Проверить слова"].tap()
        XCTAssertTrue(app.navigationBars["Проверка слов"].waitForExistence(timeout: 3)); shot("13-review")
        app.buttons["Закрыть"].tap()
        app.buttons["На главную"].tap()
        app.tabBars.buttons["История"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Лисички —")).firstMatch.waitForExistence(timeout: 3)); shot("15-history")
    }
    @MainActor func testGeneratorWithoutKey() {
        let app = XCUIApplication(); app.launchArguments = ["-ui-testing"]; app.launch()
        app.buttons["Начать игру"].tap(); app.buttons["＋ Своя тема с ИИ"].tap()
        let topic = app.textFields["Тема набора"]; XCTAssertTrue(topic.waitForExistence(timeout: 3)); topic.tap(); topic.typeText("Кухня\n")
        app.buttons["Создать набор"].tap()
        XCTAssertTrue(app.staticTexts["generationError"].waitForExistence(timeout: 55))
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = "16-generator-error"; item.lifetime = .keepAlways; add(item)
    }
}
