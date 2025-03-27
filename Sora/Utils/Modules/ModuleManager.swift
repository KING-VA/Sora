//
//  ModuleManager.swift
//  Sora
//
//  Created by Francesco on 26/01/25.
//

import Foundation

class ModuleManager: ObservableObject {
    @Published var modules: [ScrapingModule] = []
    private let addedModulesDict = UserDefaults.standard
    
    private let fileManager = FileManager.default
    private let modulesFileName = "modules.json"
    
    init() {
        loadModules()
    }
    
    private func getDocumentsDirectory() -> URL {
        #if !os(tvOS)
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #else
//        return the path of the cache directory
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #endif
    }
    
    private func getModulesFilePath() -> URL {
        getDocumentsDirectory().appendingPathComponent(modulesFileName)
    }
    
    func loadModules() {
        #if os(tvOS)
//        Use the NSUserDefaults to rebuild the modules
        for (key, metadataUrl) in addedModulesDict.dictionaryRepresentation() {
            guard let metadataUrl = metadataUrl as? String else { continue }
            // Ensure key starts with "module_"
            if key.starts(with: "module_") {
                Logger.shared.log("Rebuilding module: \(key.replacingOccurrences(of: "module_", with: ""))")
                Task {
                    let _ = try? await addModule(metadataUrl: metadataUrl)
                }
            }
        }
        // Wait for all modules to be added
        sleep(1)
        #endif
        let url = getModulesFilePath()
        guard let data = try? Data(contentsOf: url) else { return }
        modules = (try? JSONDecoder().decode([ScrapingModule].self, from: data)) ?? []
        removeDuplicateModules()
    }
    
    // Create function to remove duplication modules (check to see if the metadataUrl is already present)
    func removeDuplicateModules() {
        for module1 in modules {
            for module2 in modules {
                if module1.id != module2.id {
                    if module1.metadataUrl == module2.metadataUrl {
                        deleteModule(module2)
                    }
                }
            }
        }
    }
    
    private func saveModules() {
        let url = getModulesFilePath()
        guard let data = try? JSONEncoder().encode(modules) else { return }
        try? data.write(to: url)
    }
    
    func addModule(metadataUrl: String) async throws -> ScrapingModule {
        guard let url = URL(string: metadataUrl) else {
            throw NSError(domain: "Invalid metadata URL", code: -1)
        }
        
        if modules.contains(where: { $0.metadataUrl == metadataUrl }) {
            throw NSError(domain: "Module already exists", code: -1)
        }
        
        #if os(tvOS)
        // Check to see if the url is already in the addedModulesDict
        if addedModulesDict.object(forKey: "module_" + metadataUrl) != nil {
            throw NSError(domain: "Module already exists", code: -1)
        }
        #endif
        
        let (metadataData, _) = try await URLSession.custom.data(from: url)
        let metadata = try JSONDecoder().decode(ModuleMetadata.self, from: metadataData)
        
        guard let scriptUrl = URL(string: metadata.scriptUrl) else {
            throw NSError(domain: "Invalid script URL", code: -1)
        }
        
        let (scriptData, _) = try await URLSession.custom.data(from: scriptUrl)
        guard let jsContent = String(data: scriptData, encoding: .utf8) else {
            throw NSError(domain: "Invalid script encoding", code: -1)
        }
        
        #if os(tvOS)
//        Add to addedModulesDict so that we can rebuild later
        addedModulesDict.set(metadataUrl, forKey: "module_" + metadataUrl)
        #endif
        
        let fileName = "\(UUID().uuidString).js"
        let localUrl = getDocumentsDirectory().appendingPathComponent(fileName)
        try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
        
        let module = ScrapingModule(
            metadata: metadata,
            localPath: fileName,
            metadataUrl: metadataUrl
        )
        
        DispatchQueue.main.async {
            self.modules.append(module)
            self.saveModules()
            Logger.shared.log("Added module: \(module.metadata.sourceName)")
        }
        removeDuplicateModules()
        return module
    }
    
    func deleteModule(_ module: ScrapingModule) {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        try? fileManager.removeItem(at: localUrl)
        
        modules.removeAll { $0.id == module.id }
        saveModules()
        Logger.shared.log("Deleted module: \(module.metadata.sourceName)")
    }
    
    func getModuleContent(_ module: ScrapingModule) throws -> String {
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        return try String(contentsOf: localUrl, encoding: .utf8)
    }
    
    func refreshModules() async {
        for (index, module) in modules.enumerated() {
            do {
                let (metadataData, _) = try await URLSession.custom.data(from: URL(string: module.metadataUrl)!)
                let newMetadata = try JSONDecoder().decode(ModuleMetadata.self, from: metadataData)
                
                if newMetadata.version != module.metadata.version {
                    guard let scriptUrl = URL(string: newMetadata.scriptUrl) else {
                        throw NSError(domain: "Invalid script URL", code: -1)
                    }
                    
                    let (scriptData, _) = try await URLSession.custom.data(from: scriptUrl)
                    guard let jsContent = String(data: scriptData, encoding: .utf8) else {
                        throw NSError(domain: "Invalid script encoding", code: -1)
                    }
                    
                    let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
                    try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
                    
                    let updatedModule = ScrapingModule(
                        id: module.id,
                        metadata: newMetadata,
                        localPath: module.localPath,
                        metadataUrl: module.metadataUrl,
                        isActive: module.isActive
                    )
                    
                    await MainActor.run {
                        self.modules[index] = updatedModule
                        self.saveModules()
                    }
                    
                    Logger.shared.log("Updated module: \(module.metadata.sourceName) to version \(newMetadata.version)")
                }
            } catch {
                Logger.shared.log("Failed to refresh module: \(module.metadata.sourceName) - \(error.localizedDescription)")
            }
        }
    }
}
