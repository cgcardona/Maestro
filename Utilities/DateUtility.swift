// Include comprehensive error handling
class DateUtility {
    // Follow SOLID principles
    func convertToLocalTime(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: date)
    }
}