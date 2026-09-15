import XCTest

final class PagesAheadUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    func testBookFirstOnboardingReachesMainTabs() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Welcome to Pages Ahead"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Your data stays with you"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["Welcome to Pages Ahead"].waitForExistence(timeout: 5))
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["A few preferences go a long way"].waitForExistence(timeout: 5))
        app.buttons["Continue to Setup"].tap()
        completePreferences(in: app)
        addRequiredBook(in: app)
        completeLocation(in: app)
        XCTAssertTrue(app.staticTexts["Your best upcoming reading time"].waitForExistence(timeout: 5))
        app.buttons["I'll Do This Later"].tap()
        XCTAssertTrue(app.staticTexts["Everything is all set"].waitForExistence(timeout: 5))
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Activity"].exists)
    }

    func testSkipIntroStartsAtSetupAndCannotReturnToIntro() {
        let app = launch()
        app.buttons["Skip Intro"].tap()
        XCTAssertTrue(app.staticTexts["When do you like to read?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back"].exists)
        completePreferences(in: app)
        addRequiredBook(in: app)
        completeLocation(in: app)
        app.buttons["I'll Do This Later"].tap()
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))
    }

    func testPlanThenChooseReminder() {
        let app = launch()
        app.buttons["Skip Intro"].tap()
        completePreferences(in: app)
        addRequiredBook(in: app)
        completeLocation(in: app)
        XCTAssertTrue(app.staticTexts["Your best upcoming reading time"].waitForExistence(timeout: 5))
        app.buttons["Confirm This Time"].tap()
        XCTAssertTrue(app.staticTexts["Everything is all set"].waitForExistence(timeout: 5))
    }

    func testLibraryShowsAddBookAndSearchResults() {
        let app = launch()
        app.buttons["Skip Intro"].tap()
        completePreferences(in: app)
        addRequiredBook(in: app)
        completeLocation(in: app)
        app.buttons["I'll Do This Later"].tap()
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))

        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()

        let addBook = app.buttons["Add Book"]
        XCTAssertTrue(addBook.waitForExistence(timeout: 5))
        addBook.tap()

        let search = app.textFields["book-selection-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Piranesi")
        let result = app.staticTexts["Piranesi"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        let addButton = app.buttons["Add Selected Books"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        XCTAssertTrue(addButton.isEnabled)
        addButton.tap()

        XCTAssertTrue(app.staticTexts["Piranesi"].firstMatch.waitForExistence(timeout: 5))
    }

    private func addRequiredBook(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["What book are you reading?"].waitForExistence(timeout: 5))
        app.buttons["onboarding-add-books"].tap()
        let search = app.textFields["book-selection-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Left")
        let result = app.staticTexts["The Left Hand of Darkness"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        app.buttons["Add Selected Books"].tap()
        XCTAssertTrue(app.staticTexts["The Left Hand of Darkness"].waitForExistence(timeout: 2))
        app.buttons["Next"].tap()
    }

    private func completePreferences(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["When do you like to read?"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
    }

    private func completeLocation(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Enable your location"].waitForExistence(timeout: 5))
        app.buttons["Turn On Location"].tap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
    }
}
