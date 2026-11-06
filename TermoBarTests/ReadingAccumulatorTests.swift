import Foundation
import Testing

struct ReadingAccumulatorTests {
    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSinceReferenceDate: seconds) }

    @Test func firstRecordIsDueRightAwayAndLastsOneInterval() throws {
        var accumulator = ReadingAccumulator()
        #expect(accumulator.isDue(at: date(0), interval: 5))
        accumulator.addTemperature(average: 50, maximum: 60)
        accumulator.addTemperature(average: 54, maximum: 58)
        accumulator.addFans([1000, 3000])
        accumulator.addFans([])
        accumulator.addFans([2400])

        let closed = accumulator.close(at: date(0), interval: 5)
        let record = try #require(closed)

        #expect(record.date == date(0))
        #expect(record.duration == 5)
        #expect(record.averageTemperature == 52)
        #expect(record.maxTemperature == 60)
        #expect(record.fanSpeed == 2200)
        #expect(accumulator.lastRecordDate == date(0))
        #expect(!accumulator.hasPendingTemperature)
    }

    @Test func dueOnTheTickClosestToTheInterval() {
        var accumulator = ReadingAccumulator()
        accumulator.addTemperature(average: 50, maximum: 50)
        _ = accumulator.close(at: date(100), interval: 5)
        #expect(!accumulator.isDue(at: date(104.5), interval: 5))
        #expect(accumulator.isDue(at: date(104.8), interval: 5))
        #expect(accumulator.isDue(at: date(106), interval: 5))
    }

    @Test func durationIsTheTimeSinceTheLastRecordUpToThreeIntervals() {
        var accumulator = ReadingAccumulator()
        accumulator.addTemperature(average: 50, maximum: 50)
        _ = accumulator.close(at: date(0), interval: 5)
        accumulator.addTemperature(average: 50, maximum: 50)
        let next = accumulator.close(at: date(6), interval: 5)
        #expect(next?.duration == 6)
        // Mac acordando: o registro não representa o tempo dormindo.
        accumulator.addTemperature(average: 50, maximum: 50)
        let afterSleep = accumulator.close(at: date(600), interval: 5)
        #expect(afterSleep?.duration == 15)
    }

    @Test func withoutTemperatureNothingCloses() {
        var accumulator = ReadingAccumulator()
        accumulator.addFans([1200])
        #expect(accumulator.close(at: date(0), interval: 5) == nil)
        #expect(accumulator.lastRecordDate == nil)
        // As ventoinhas lidas continuam valendo para o próximo registro.
        accumulator.addTemperature(average: 40, maximum: 41)
        let record = accumulator.close(at: date(1), interval: 5)
        #expect(record?.fanSpeed == 1200)
        #expect(record?.duration == 5)
    }

    @Test func noFanReadingMeansNoFanSpeed() {
        var accumulator = ReadingAccumulator()
        accumulator.addTemperature(average: 40, maximum: 41)
        #expect(accumulator.hasPendingTemperature)
        let record = accumulator.close(at: date(0), interval: 1)
        #expect(record != nil)
        #expect(record?.fanSpeed == nil)
    }

    // MARK: - Virada do minuto

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    @Test func minuteClockReportsTheMinuteThatJustClosed() {
        var clock = MinuteClock()
        #expect(clock.advance(to: date(65), calendar: utc) == nil)
        #expect(clock.current == date(60))
        #expect(clock.advance(to: date(100), calendar: utc) == nil)
        #expect(clock.advance(to: date(121), calendar: utc) == DateInterval(start: date(60), end: date(120)))
        #expect(clock.current == date(120))
    }

    @Test func minuteClockSkipsMinutesWithoutReadingsAndClocksGoingBack() {
        var clock = MinuteClock()
        _ = clock.advance(to: date(60), calendar: utc)
        // Mac dormindo: o minuto fechado vai até o minuto atual.
        #expect(clock.advance(to: date(600), calendar: utc) == DateInterval(start: date(60), end: date(600)))
        // Relógio ajustado para trás: só recomeça a contar.
        #expect(clock.advance(to: date(300), calendar: utc) == nil)
        #expect(clock.current == date(300))
    }

    @Test func minuteSummaryTakesTheSamplesOfTheClosedMinute() throws {
        let samples = [55.0, 60, 65, 120, 125].map { makeSample(at: $0, temperature: $0) }
        let minute = DateInterval(start: date(60), end: date(120))

        let summary = try #require(samples.minuteSummary(of: minute))

        #expect(summary.date == date(60))
        #expect(summary.duration == Sample.minuteDuration)
        // 65 e 120 entram; 55, 60 (o próprio início) e 125 não.
        #expect(summary.averageTemperature == 92.5)
        #expect(samples.minuteSummary(of: DateInterval(start: date(200), end: date(260))) == nil)
    }
}
