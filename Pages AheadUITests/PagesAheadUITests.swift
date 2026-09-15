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
        XCTAssertTrue(app.staticTexts["Pages Ahead"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts[
                "Pages Ahead combines the book you're reading with weather near you to suggest personalized reading windows."
            ].exists
        )
        app.buttons["Set Up My Reading Plan"].tap()
        addRequiredBook(in: app)
        XCTAssertTrue(app.navigationBars["Location"].waitForExistence(timeout: 5))
        app.buttons["Use Current Location"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Activity"].exists)
    }

    func testManualCityOnboarding() {
        let app = launch()
        app.buttons["Set Up My Reading Plan"].tap()
        addRequiredBook(in: app)
        XCTAssertTrue(app.navigationBars["Location"].waitForExistence(timeout: 5))
        let chooseCity = app.buttons["Choose a City Instead"]
        XCTAssertTrue(chooseCity.waitForExistence(timeout: 5))
        chooseCity.tap()
        let city = app.textFields["City"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        city.tap()
        city.typeText("Denpasar")
        app.buttons["Use City"].tap()
        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))
    }

    func testLibraryShowsAddBookAndSearchResults() {
        let app = launch()
        app.buttons["Set Up My Reading Plan"].tap()
        addRequiredBook(in: app)
        XCTAssertTrue(app.navigationBars["Location"].waitForExistence(timeout: 5))
        let useLocation = app.buttons["Use Current Location"]
        XCTAssertTrue(useLocation.waitForExistence(timeout: 5))
        useLocation.tap()

        XCTAssertTrue(app.tabBars.buttons["Reading Plan"].waitForExistence(timeout: 5))

        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()

        let addBook = app.buttons["Add Book"]
        XCTAssertTrue(addBook.waitForExistence(timeout: 5))
        addBook.tap()

        let search = app.textFields["book-catalog-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Piranesi")
        let result = app.staticTexts["Piranesi"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        let addButton = app.buttons["Add Piranesi"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        XCTAssertTrue(addButton.isEnabled)
        addButton.tap()

        XCTAssertTrue(app.staticTexts["Piranesi"].firstMatch.waitForExistence(timeout: 5))
    }

    private func addRequiredBook(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Your first book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What are you reading?"].exists)
        XCTAssertTrue(app.staticTexts["Personalized reading windows"].exists)
        let search = app.textFields["onboarding-book-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Left")
        let result = app.staticTexts["The Left Hand of Darkness"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        let continueButton = app.buttons["Continue with The Left Hand of Darkness"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
    }
}
