import SwiftData

/// The schema the app runs on. When a new version is added, point this and the model
/// typealiases below at it.
typealias LociSchema = LociSchemaV1

typealias Folder = LociSchemaV1.Folder
typealias Note = LociSchemaV1.Note
typealias Tag = LociSchemaV1.Tag
typealias NoteLink = LociSchemaV1.NoteLink

/// Version 1 of the schema: the data model in docs/ARCHITECTURE.md §3.
///
/// The models are nested in this enum so v1 keeps describing what is already on disk after a
/// v2 exists. To change a model, copy the model files into a `LociSchemaV2` namespace, make the
/// change there, add v2 and a migration stage to `LociMigrationPlan`, and repoint the typealiases.
enum LociSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Folder.self, Note.self, Tag.self, NoteLink.self]
    }
}

enum LociMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LociSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
