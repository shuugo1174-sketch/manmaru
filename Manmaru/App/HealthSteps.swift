import Foundation
import HealthKit
import WidgetKit

// iPhoneの「ヘルスケア」から、今日の歩数とゆうべ寝た時間を読む。
// 無料のApple IDではHealthKitが使えないことがある。そのときは何もしない（JSONの歩数を使う）。
@MainActor
final class HealthSteps: ObservableObject {
    static let shared = HealthSteps()

    @Published var todaySteps: Int?
    @Published var lastBedtime: Date?
    @Published var isAvailable = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()
    private var requested = false

    private var stepType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .stepCount) }
    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }

    /// 許可をもらって、歩数と睡眠を読む。失敗しても静かに終わる。
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable(), let stepType, let sleepType else {
            isAvailable = false
            return
        }
        if !requested {
            requested = true
            do {
                try await store.requestAuthorization(toShare: [], read: [stepType, sleepType])
            } catch {
                isAvailable = false
                return
            }
        }
        if let steps = await readTodaySteps(type: stepType) {
            todaySteps = steps
            AppGroup.defaults?.set(steps, forKey: AppGroup.todayStepsKey)
            AppGroup.defaults?.set(Date(), forKey: AppGroup.todayStepsDateKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
        lastBedtime = await readLastBedtime(type: sleepType)
    }

    /// ゆうべ 0:00〜4:59 に寝始めたら夜更かし
    var wasLateNight: Bool {
        guard let lastBedtime else { return false }
        let hour = Calendar.current.component(.hour, from: lastBedtime)
        return hour < 5
    }

    private func readTodaySteps(type: HKQuantityType) async -> Int? {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let sum = result?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: HKUnit.count())))
            }
            store.execute(query)
        }
    }

    /// きのうの18時からいままでで、いちばん最初の「寝ている」記録の始まり
    private func readLastBedtime(type: HKCategoryType) async -> Date? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let from = calendar.date(byAdding: .hour, value: -6, to: todayStart) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 50, sortDescriptors: [sort]) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample])?.first { sample in
                    sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                        && sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
                }
                continuation.resume(returning: asleep?.startDate)
            }
            store.execute(query)
        }
    }
}
