import CoreData
import Foundation

/// PRD FR-7: high-frequency autosave of the in-progress canvas (color included — unlike the
/// SketchFormula DSL, the draft keeps everything so a relaunch restores exactly what was there).
/// The Core Data model is built in code (no .xcdatamodeld) to keep this a single self-contained file.
/// FR-10 added the optional `pixelFormulaJSON` attribute; adding an optional attribute is a
/// lightweight migration, which `NSPersistentContainer` performs automatically.
@objc(DraftCanvasEntity)
final class DraftCanvasEntity: NSManagedObject {
    @NSManaged var elementsJSON: Data?
    @NSManaged var pixelFormulaJSON: Data?
    @NSManaged var updatedAt: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<DraftCanvasEntity> {
        NSFetchRequest<DraftCanvasEntity>(entityName: "DraftCanvasEntity")
    }
}

/// What the draft store round-trips: shapes plus the optional pixel-formula backdrop.
nonisolated struct DraftCanvas {
    var elements: [SketchElement] = []
    var pixelFormula: PixelFormulaArtwork?
}

private enum DraftCanvasModel {
    static func make() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "DraftCanvasEntity"
        entity.managedObjectClassName = NSStringFromClass(DraftCanvasEntity.self)

        let elementsJSON = NSAttributeDescription()
        elementsJSON.name = "elementsJSON"
        elementsJSON.attributeType = .binaryDataAttributeType
        elementsJSON.isOptional = true

        let pixelFormulaJSON = NSAttributeDescription()
        pixelFormulaJSON.name = "pixelFormulaJSON"
        pixelFormulaJSON.attributeType = .binaryDataAttributeType
        pixelFormulaJSON.isOptional = true

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = true

        entity.properties = [elementsJSON, pixelFormulaJSON, updatedAt]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}

final class DraftCanvasStore: @unchecked Sendable {
    static let shared = DraftCanvasStore()

    private let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "DraftCanvas", managedObjectModel: DraftCanvasModel.make())
        for description in container.persistentStoreDescriptions {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error { print("DraftCanvasStore load error: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func load() -> DraftCanvas {
        let request = DraftCanvasEntity.fetchRequest()
        request.fetchLimit = 1
        guard let entity = try? container.viewContext.fetch(request).first else { return DraftCanvas() }
        var draft = DraftCanvas()
        if let data = entity.elementsJSON,
           let elements = try? JSONDecoder().decode([SketchElement].self, from: data) {
            draft.elements = elements
        }
        if let data = entity.pixelFormulaJSON {
            draft.pixelFormula = try? JSONDecoder().decode(PixelFormulaArtwork.self, from: data)
        }
        return draft
    }

    /// Fire-and-forget save on a background context — called from a Combine debounce, never
    /// directly from a gesture handler (PRD FR-7/FR-9).
    func save(_ elements: [SketchElement], pixelFormula: PixelFormulaArtwork? = nil) {
        let context = container.newBackgroundContext()
        guard let data = try? JSONEncoder().encode(elements) else { return }
        let pixelData = pixelFormula.flatMap { try? JSONEncoder().encode($0) }
        context.perform {
            let request = DraftCanvasEntity.fetchRequest()
            request.fetchLimit = 1
            let entity = (try? context.fetch(request).first) ?? DraftCanvasEntity(context: context)
            entity.elementsJSON = data
            entity.pixelFormulaJSON = pixelData
            entity.updatedAt = Date()
            try? context.save()
        }
    }
}
