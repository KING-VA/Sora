//
//  SettingsViewModule.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct SettingsViewModule: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @EnvironmentObject var moduleManager: ModuleManager
    
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var moduleUrl: String = ""
    
    var body: some View {
        VStack {
            Form {
                if moduleManager.modules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.app")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Modules")
                            .font(.headline)
                        Text("Click the plus button to add a module!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                else {
                    ForEach(moduleManager.modules) { module in
                        Button {
                            selectedModuleId = module.id.uuidString
                        } label: {
                            HStack {
                                KFImage(URL(string: module.metadata.iconUrl))
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .padding(.trailing, 10)
                                
                                VStack(alignment: .leading) {
                                    HStack(alignment: .bottom, spacing: 4) {
                                        Text(module.metadata.sourceName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("v\(module.metadata.version)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Author: \(module.metadata.author.name)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Language: \(module.metadata.language)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if module.id.uuidString == selectedModuleId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 25, height: 25)
                                }
                            }
                            .contentShape(Rectangle())
                            //                        Make the module focusable
                            .focusable()
                            .onTapGesture {
                                selectedModuleId = module.id.uuidString
                            }
                            .contextMenu {
#if !os(tvOS)
                                Button(action: {
                                    UIPasteboard.general.string = module.metadataUrl
                                    DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                }) {
                                    Label("Copy URL", systemImage: "doc.on.doc")
                                }
#endif
                                Button(role: .destructive) {
                                    if selectedModuleId != module.id.uuidString {
                                        moduleManager.deleteModule(module)
                                        DropManager.shared.showDrop(title: "Module Removed", subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(selectedModuleId == module.id.uuidString)
                            }
#if !os(tvOS)
                            .swipeActions {
                                if selectedModuleId != module.id.uuidString {
                                    Button(role: .destructive) {
                                        moduleManager.deleteModule(module)
                                        DropManager.shared.showDrop(title: "Module Removed", subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
#endif
                        }
                    }
                }
            }
            .navigationTitle("Modules")
            .navigationBarItems(trailing: Button(action: {
                showAddModuleAlert()
            }) {
                Image(systemName: "plus")
                    .resizable()
                    .padding(5)
            })
            .refreshable {
                isRefreshing = true
                await moduleManager.refreshModules()
                isRefreshing = false
            }
        }
        .onAppear {
            Task {
                await moduleManager.refreshModules()
#if os(tvOS)
                //                If on tvOS and modules are not empty and selectedmodule is not empy, automatically add the first to selected modules
                if !moduleManager.modules.isEmpty && selectedModuleId == nil {
                    selectedModuleId = moduleManager.modules.first?.id.uuidString
                }
#endif
            }
        }
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                }
            )
        }
    }
    
    func showAddModuleAlert() {
        let alert = UIAlertController(title: "Add Module", message: "Enter the URL of the module file", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/module.json"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let url = alert.textFields?.first?.text {
                displayModuleView(url: url)
            }
        }))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func displayModuleView(url: String) {
        DispatchQueue.main.async {
            let addModuleView = ModuleAdditionSettingsView(moduleUrl: url).environmentObject(moduleManager)
            let hostingController = UIHostingController(rootView: addModuleView)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(hostingController, animated: true, completion: nil)
            }
        }
    }
}
