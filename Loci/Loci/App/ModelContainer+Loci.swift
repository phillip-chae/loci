import SwiftData

extension ModelContainer {
    /// The library's container, on the current schema with its migration plan.
    ///
    /// Local-only until the sync milestone. Keep `cloudKitDatabase` explicit: once the target has
    /// an iCloud entitlement, the default (`.automatic`) would start syncing on its own.
    static func loci(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LociSchema.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: LociMigrationPlan.self,
            configurations: configuration
        )
    }
}
