import Foundation
import Observation

enum ReadingPlanNotice: Equatable {
    case message(String)
    case openSettings(String)
}

@MainActor @Observable
final class ReadingPlanManager {
    private let repository: ReadingPlanRepository
    private let notifications: NotificationScheduling
    private let calendarWriter: CalendarEventWriting
    private let settings: SettingsRepository
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private(set) var current: ReadingPlan?
    var notice: ReadingPlanNotice?

    init(
        repository: ReadingPlanRepository,
        notifications: NotificationScheduling,
        calendarWriter: CalendarEventWriting,
        settings: SettingsRepository,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.notifications = notifications
        self.calendarWriter = calendarWriter
        self.settings = settings
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
        current = repository.current()
        expireIfNeeded()
    }

    var notificationDefault: Bool {
        settings.hasCreatedReadingPlan ? settings.planNotificationEnabled : true
    }

    var calendarDefault: Bool {
        settings.hasCreatedReadingPlan ? settings.planCalendarEnabled : false
    }

    var shouldShowPermissionRecoveryTip: Bool {
        !settings.permissionRecoveryTipShown && !notificationDefault
    }

    func markPermissionRecoveryTipShown() {
        settings.permissionRecoveryTipShown = true
    }

    func refresh() {
        current = repository.current()
        expireIfNeeded()
    }

    func expireIfNeeded() {
        guard let plan = current else { return }
        let today = calendar.startOfDay(for: dateProvider.now)
        let plannedDay = calendar.startOfDay(for: plan.start)
        guard today > plannedDay else { return }
        repository.delete(id: plan.id)
        current = nil
    }

    @discardableResult
    func create(
        from window: ReadingWindow,
        bookTitle: String,
        notificationEnabled: Bool? = nil,
        calendarEnabled: Bool? = nil
    ) async -> Bool {
        if let existing = current {
            guard await remove(existing, removesCalendar: true) else { return false }
        }

        var plan = ReadingPlan(
            id: UUID(),
            start: window.start,
            end: window.end,
            place: window.place,
            bookID: nil,
            reminderEnabled: notificationEnabled ?? notificationDefault,
            calendarEnabled: calendarEnabled ?? calendarDefault
        )
        settings.planNotificationEnabled = plan.reminderEnabled
        settings.planCalendarEnabled = plan.calendarEnabled

        if plan.reminderEnabled {
            do {
                let scheduled = try await notifications.schedule(session: plan)
                plan.reminderEnabled = scheduled
                if !scheduled {
                    settings.planNotificationEnabled = false
                    notice = .openSettings("Notification access is off. The plan was saved without a notification.")
                }
            } catch {
                plan.reminderEnabled = false
                settings.planNotificationEnabled = false
                notice = .message("The plan was saved without a notification.")
            }
        }

        if plan.calendarEnabled {
            do {
                plan.calendarEventID = try await calendarWriter.save(
                    session: plan,
                    bookTitle: bookTitle,
                    existingEventID: nil
                )
            } catch {
                plan.calendarEnabled = false
                settings.planCalendarEnabled = false
                notice = .openSettings("Calendar access is off. The plan was saved without a Calendar event.")
            }
        }

        repository.save(plan)
        settings.hasCreatedReadingPlan = true
        current = plan
        return true
    }

    @discardableResult
    func setNotification(_ enabled: Bool) async -> Bool {
        guard var plan = current else { return false }
        settings.planNotificationEnabled = enabled
        if enabled {
            do {
                let scheduled = try await notifications.schedule(session: plan)
                guard scheduled else {
                    settings.planNotificationEnabled = false
                    notice = .openSettings("Allow Notifications in Settings to add one to this plan.")
                    return false
                }
                plan.reminderEnabled = true
            } catch {
                settings.planNotificationEnabled = false
                notice = .openSettings("Allow Notifications in Settings to add one to this plan.")
                return false
            }
        } else {
            notifications.cancel(sessionID: plan.id)
            plan.reminderEnabled = false
        }
        repository.save(plan)
        current = plan
        return true
    }

    @discardableResult
    func setCalendar(_ enabled: Bool, bookTitle: String) async -> Bool {
        guard var plan = current else { return false }
        settings.planCalendarEnabled = enabled
        if enabled {
            do {
                plan.calendarEventID = try await calendarWriter.save(
                    session: plan,
                    bookTitle: bookTitle,
                    existingEventID: plan.calendarEventID
                )
                plan.calendarEnabled = true
            } catch {
                settings.planCalendarEnabled = false
                notice = .openSettings("Allow Calendar access in Settings to add this plan.")
                return false
            }
        } else {
            if let eventID = plan.calendarEventID {
                do { try calendarWriter.delete(eventID: eventID) }
                catch {
                    notice = .message("The Calendar event could not be removed. Try again.")
                    return false
                }
            }
            plan.calendarEnabled = false
            plan.calendarEventID = nil
        }
        repository.save(plan)
        current = plan
        return true
    }

    @discardableResult
    func deleteCurrent() async -> Bool {
        guard let current else { return true }
        return await remove(current, removesCalendar: true)
    }

    private func remove(_ plan: ReadingPlan, removesCalendar: Bool) async -> Bool {
        notifications.cancel(sessionID: plan.id)
        if removesCalendar, let eventID = plan.calendarEventID {
            do { try calendarWriter.delete(eventID: eventID) }
            catch {
                notice = .message("The Calendar event could not be removed. The plan was kept so you can retry.")
                return false
            }
        }
        repository.delete(id: plan.id)
        if current?.id == plan.id { current = nil }
        return true
    }
}
