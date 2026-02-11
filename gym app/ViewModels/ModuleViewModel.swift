//
//  ModuleViewModel.swift
//  gym app
//
//  ViewModel for managing modules
//

import Foundation
import Combine

@MainActor
class ModuleViewModel: ObservableObject {
    @Published var modules: [Module] = []
    @Published var selectedModule: Module?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: DataRepository

    init(repository: DataRepository? = nil) {
        self.repository = repository ?? DataRepository.shared
        loadModules()
    }

    func loadModules() {
        isLoading = true
        repository.loadModules()
        modules = repository.modules
        isLoading = false
    }

    func saveModule(_ module: Module) {
        var moduleToSave = module
        // Clean up any orphaned superset IDs before saving
        moduleToSave.cleanupOrphanedSupersets()
        repository.saveModule(moduleToSave)
        modules = repository.modules
    }

    func deleteModule(_ module: Module) {
        repository.deleteModule(module)
        modules = repository.modules
    }

    func deleteModules(at offsets: IndexSet) {
        for index in offsets {
            deleteModule(modules[index])
        }
    }

    func createNewModule(name: String, type: ModuleType) -> Module {
        Module(name: name, type: type)
    }

    func getModule(id: UUID) -> Module? {
        modules.first { $0.id == id }
    }

    func modulesByType(_ type: ModuleType) -> [Module] {
        modules.filter { $0.type == type }
    }
}
