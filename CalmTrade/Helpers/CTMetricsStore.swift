//
//  CTMetricsStore.swift
//  CalmTrade
//
//  Device-agnostic Core Data repo for biometrics + provenance.
//  Crash-safe: no live NSManagedObject exposure, per-user store switching.
//

import Foundation
import CoreData
import os.log

// MARK: - Metric enums

public enum CTMetricKind: String, CaseIterable {
    case heartRate, restingHeartRate, rmssd, sdnn
    case sleepHours, steps, sleepScore
    case sleepAwake, sleepREM, sleepCore, sleepDeep
}

public enum CTMetricSource: String, CaseIterable, Codable {
    case appleHealth, polar, polarH10, polar360
}

// MARK: - Core Data stack

public final class CTMetricsStack {
    public static let shared = CTMetricsStack()
    public private(set) var container: NSPersistentContainer

    private init() {
        container = CTMetricsStack.makeContainer(for: SessionManager.shared.current?.id)
        
        NotificationCenter.default.addObserver(
            forName: .userAccountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let userId = (note.object as? User)?.id
            
            // 🔐 Block all Core Data readers and wait for them to drain
            UserStoreSwitchCoordinator.shared.beginSwitch()
            defer { UserStoreSwitchCoordinator.shared.endSwitch() }
            
            // Optionally drain background work on old container
            self.container.performBackgroundTask { ctx in
                ctx.performAndWait {
                    // drain any work if needed
                }
            }
            
            let oldContainer = self.container
            let newContainer = CTMetricsStack.makeContainer(for: userId)
            self.container = newContainer
            
            // Tear down old viewContext
            oldContainer.viewContext.reset()
            
            // Notify observers (readers will be unblocked only after endSwitch)
            NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
        }
    }

    private static func makeContainer(for userId: String?) -> NSPersistentContainer {
        let id = userId ?? "_anonymous"
        let model = makeModel()
        let container = NSPersistentContainer(name: "CalmData", managedObjectModel: model)

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let userDir = base.appendingPathComponent("Users/\(id)/Metrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        let url = userDir.appendingPathComponent("CalmData.sqlite")
        let desc = NSPersistentStoreDescription(url: url)
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [desc]

        container.loadPersistentStores { _, err in
            if let err = err {
                os_log("[CTMetricsStack] load error for %@: %@", id, err.localizedDescription)
            } else {
                os_log("[CTMetricsStack] ready for %@", id)
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ---------------------------------------------------------
        // ENTITY 1: CTBiometricSample (existing, unchanged)
        // ---------------------------------------------------------
        let bio = NSEntityDescription()
        bio.name = "CTBiometricSample"
        bio.managedObjectClassName = NSStringFromClass(CTBiometricSample.self)

        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }

        let id     = attr("id", .UUIDAttributeType)
        let kind   = attr("kind", .stringAttributeType)
        let source = attr("source", .stringAttributeType)
        let unit   = attr("unit", .stringAttributeType)
        let value  = attr("value", .doubleAttributeType)
        let date   = attr("date", .dateAttributeType)
        let user   = attr("userId", .stringAttributeType)

        bio.properties = [id, kind, source, unit, value, date, user]
        bio.uniquenessConstraints = [["userId", "kind", "date", "source"]]

        // ---------------------------------------------------------
        // ENTITY 2: SleepSegmentEntity (NEW)
        // ---------------------------------------------------------
        let sleep = NSEntityDescription()
        sleep.name = "SleepSegmentEntity"
        sleep.managedObjectClassName = NSStringFromClass(SleepSegmentEntity.self)

        let startDate = attr("startDate", .dateAttributeType)
        let endDate   = attr("endDate", .dateAttributeType)
        let stageRaw  = attr("stageRaw", .integer16AttributeType)
        let sourceRaw = attr("sourceRaw", .integer16AttributeType)
        let bucket    = attr("sleepDayStart", .dateAttributeType)

        sleep.properties = [startDate, endDate, stageRaw, sourceRaw, bucket]

        // ---------------------------------------------------------
        // Register both entities
        // ---------------------------------------------------------
        model.entities = [bio, sleep]
        return model
    }
}

// MARK: - Managed object

@objc(CTBiometricSample)
public final class CTBiometricSample: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kind: String
    @NSManaged public var source: String
    @NSManaged public var unit: String
    @NSManaged public var value: Double
    @NSManaged public var date: Date
    @NSManaged public var userId: String
}

public extension CTBiometricSample {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CTBiometricSample> {
        NSFetchRequest(entityName: "CTBiometricSample")
    }
    var ctSourceEnum: CTMetricSource { CTMetricSource(rawValue: source) ?? .appleHealth }
}

// MARK: - Repository

public final class CTMetricsRepository {
    public static let shared = CTMetricsRepository()
    
    private let switchCoordinator = UserStoreSwitchCoordinator.shared

    private var userId: String { SessionManager.shared.current?.id ?? "_anonymous" }

    private var viewContext: NSManagedObjectContext { CTMetricsStack.shared.container.viewContext }
    private func makeBgContext() -> NSManagedObjectContext {
        let ctx = CTMetricsStack.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }

    private init() {}

    // MARK: - DTO structs
    public struct CTBiometricPoint {
        public let date: Date
        public let value: Double
        public let unit: String
        public let source: CTMetricSource
    }

    public struct CTBiometricLatest {
        public let date: Date
        public let value: Double
        public let unit: String
        public let source: CTMetricSource
    }

    // MARK: - Upsert / Save
    @discardableResult
    public func upsert(kind: CTMetricKind,
                       value: Double,
                       unit: String,
                       source: CTMetricSource,
                       date: Date = Date()) -> CTBiometricPoint? {
        var result: CTBiometricPoint?

        switchCoordinator.withRead {
            let ctx = makeBgContext()
            ctx.performAndWait {
                assert(ctx.persistentStoreCoordinator === CTMetricsStack.shared.container.persistentStoreCoordinator,
                       "❌ bgContext is using a different PSC than the current container")

                let req = CTBiometricSample.fetchRequest()
                req.predicate = NSPredicate(
                    format: "userId == %@ AND kind == %@ AND source == %@ AND date == %@",
                    userId, kind.rawValue, source.rawValue, date as NSDate
                )
                req.fetchLimit = 1

                let obj = (try? ctx.fetch(req).first) ?? CTBiometricSample(context: ctx)
                if obj.objectID.isTemporaryID { obj.id = UUID() }
                obj.userId = userId
                obj.kind = kind.rawValue
                obj.source = source.rawValue
                obj.unit = unit
                obj.value = value
                obj.date = date

                do {
                    try ctx.save()
                    result = CTBiometricPoint(date: date, value: value, unit: unit, source: source)
                } catch {
                    os_log("[CTMetrics] save error: %@", type: .error, error.localizedDescription)
                }
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
        }
        return result
    }

    @discardableResult
    public func save(kind: CTMetricKind,
                     value: Double,
                     unit: String,
                     source: CTMetricSource,
                     date: Date = Date()) -> CTBiometricPoint? {
        upsert(kind: kind, value: value, unit: unit, source: source, date: date)
    }

    // MARK: - Latest
    public func latestValue(kind: CTMetricKind, source: CTMetricSource? = nil) -> CTBiometricLatest? {
        switchCoordinator.withRead {
            var out: CTBiometricLatest?
            viewContext.performAndWait {
                let req = CTBiometricSample.fetchRequest()
                var preds: [NSPredicate] = [
                    NSPredicate(format: "userId == %@ AND kind == %@", userId, kind.rawValue)
                ]
                if let s = source {
                    preds.append(NSPredicate(format: "source == %@", s.rawValue))
                }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
                req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                req.fetchLimit = 1

                if let s = try? viewContext.fetch(req).first {
                    let d = s.date
                    let v = s.value
                    let u = s.unit
                    let src = s.ctSourceEnum
                    out = .init(date: d, value: v, unit: u, source: src)
                }
            }
            return out
        }
    }

    // MARK: - Series (detached)
    public func seriesValues(kind: CTMetricKind,
                             from: Date,
                             to: Date,
                             source: CTMetricSource? = nil,
                             limit: Int = 5000) -> [CTBiometricPoint] {
        switchCoordinator.withRead {
            var pts: [CTBiometricPoint] = []
            viewContext.performAndWait {
                let req = CTBiometricSample.fetchRequest()
                var preds: [NSPredicate] = [
                    NSPredicate(format: "userId == %@ AND kind == %@ AND date >= %@ AND date <= %@",
                                userId, kind.rawValue, from as NSDate, to as NSDate)
                ]
                if let s = source {
                    preds.append(NSPredicate(format: "source == %@", s.rawValue))
                }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
                req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                req.fetchLimit = limit

                if let objs = try? viewContext.fetch(req) {
                    pts.removeAll(keepingCapacity: true)
                    for obj in objs {
                        let d = obj.date
                        let v = obj.value
                        let u = obj.unit
                        let s = obj.ctSourceEnum
                        pts.append(CTBiometricPoint(date: d, value: v, unit: u, source: s))
                    }
                }
            }
            return pts
        }
    }

    // Backwards alias (same data, detached)
    public func series(kind: CTMetricKind,
                       from: Date,
                       to: Date,
                       source: CTMetricSource? = nil,
                       limit: Int = 5000) -> [CTBiometricPoint] {
        seriesValues(kind: kind, from: from, to: to, source: source, limit: limit)
    }

    // MARK: - Sleep + Offline passthroughs
    func upsertSleepEpisode(_ epi: CTSleepEpisode) {
        SleepCache.shared.save(epi, userId: userId)
        NotificationCenter.default.post(name: .ctSleepUpdated, object: nil, userInfo: ["source": epi.source])
    }

    func latestPreferredSleepEpisode() -> CTSleepEpisode? { SleepCache.shared.latestPreferred(for: userId) }
    func preferredSleepEpisode(on date: Date) -> CTSleepEpisode? { SleepCache.shared.preferred(on: date, userId: userId) }

    func upsertOfflinePPGMeta(_ meta: OfflinePPGIngestor.SavedPPG) {
        OfflinePPGIndex.shared(for: userId).append(meta)
    }
    
    // MARK: - Unified Sleep Helper (for CalmScore etc.)
    /// Returns the latest night's full sleep duration (in hours),
    /// unified across Polar360 + Apple Health.
    public func latestUnifiedSleepHours() -> Double? {
        return SleepRepository.shared.latestNight()?.hours
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let ctMetricsDidMirror = Notification.Name("ct.metrics.mirrored")
    static let ctSleepUpdated = Notification.Name("ctSleepUpdated")
}

// MARK: - In-memory sleep cache (unchanged)

private final class SleepCache {
    static let shared = SleepCache()
    private init() {}

    private var episodes: [String: [String: [CTMetricSource: CTSleepEpisode]]] = [:]

    func save(_ epi: CTSleepEpisode, userId: String) {
        let key = Self.nightKey(for: epi.date)
        var userBucket = episodes[userId] ?? [:]
        var nightBucket = userBucket[key] ?? [:]
        nightBucket[epi.source] = epi
        userBucket[key] = nightBucket
        episodes[userId] = userBucket
    }

    func preferred(on date: Date, userId: String) -> CTSleepEpisode? {
        let key = Self.nightKey(for: date)
        guard let night = episodes[userId]?[key] else { return nil }
        if let polar = night[.polar360] { return polar }
        if let hk = night[.appleHealth] { return hk }
        return Array(night.values).last
    }

    func latestPreferred(for userId: String) -> CTSleepEpisode? {
        guard let nights = episodes[userId] else { return nil }
        for key in nights.keys.sorted().reversed() {
            let night = nights[key]!
            if let polar = night[.polar360] { return polar }
            if let hk = night[.appleHealth] { return hk }
            if let any = Array(night.values).last { return any }
        }
        return nil
    }

    private static func nightKey(for date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: cal.startOfDay(for: date))
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}

// MARK: - Offline PPG Index (unchanged)

final class OfflinePPGIndex {
    private static var cache: [String: OfflinePPGIndex] = [:]
    static func shared(for userId: String) -> OfflinePPGIndex {
        if let idx = cache[userId] { return idx }
        let new = OfflinePPGIndex(userId: userId)
        cache[userId] = new
        return new
    }

    private init(userId: String) {
        self.userId = userId
        load()
    }

    private let userId: String
    private let fm = FileManager.default
    private var items: [OfflinePPGIngestor.SavedPPG] = []
    private var idxURL: URL {
        let base = UserScope.appSupportURL.appendingPathComponent("OfflinePPG", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(userId)_index.json")
    }

    func append(_ meta: OfflinePPGIngestor.SavedPPG) {
        items.append(meta)
        save()
    }

    func all() -> [OfflinePPGIngestor.SavedPPG] { items }

    private func save() {
        do {
            let data = try JSONEncoder.iso8601.encode(items)
            try data.write(to: idxURL, options: .atomic)
        } catch {
            os_log("[PPGIndex] save error: %@", error.localizedDescription)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: idxURL) else { return }
        items = (try? JSONDecoder.iso8601.decode([OfflinePPGIngestor.SavedPPG].self, from: data)) ?? []
    }
}

// MARK: - Codable helpers

extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
