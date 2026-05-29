import Foundation

enum DatePresentation {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let interval = max(0, Int(now.timeIntervalSince(date)))
        if interval < 10 {
            return "刚刚"
        }
        if interval < 60 {
            return "\(interval) 秒前"
        }

        let minutes = interval / 60
        if minutes < 60 {
            return "\(minutes) 分钟前"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时前"
        }

        let days = hours / 24
        if days == 1 {
            return "昨天"
        }
        if days < 7 {
            return "\(days) 天前"
        }

        return absolute(date)
    }

    static func absolute(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "zh_Hans"))
                .year()
                .month()
                .day()
                .hour()
                .minute(),
        )
    }
}
