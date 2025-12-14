import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @AppStorage(AppLanguage.storageKey)
    private var selectedLanguageRawValue = AppLanguage.system.rawValue

    @AppStorage("autoDetectSource")
    private var autoDetectSource = true
    
    @AppStorage("showReadingTime")
    private var showReadingTime = true

    private var selectedLanguage: Binding<AppLanguage> {
        Binding {
            AppLanguage(rawValue: selectedLanguageRawValue) ?? .system
        } set: { newValue in
            selectedLanguageRawValue = newValue.rawValue
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            languageSection
            bookmarkSettingsSection
            aboutSection
            dangerZoneSection
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var languageSection: some View {
        Section(header: Text("Genel")) {
            Picker("Uygulama Dili", selection: selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.titleKey)
                                .font(.body)
                            Text(language.descriptionKey)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(language)
                }
            }
            .pickerStyle(.inline)

            Text("Dil değişikliği uygulamayı yeniden başlatmadan uygulanır.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private var bookmarkSettingsSection: some View {
        Section("Bookmark Ayarları") {
            Toggle("Otomatik Kaynak Tespiti", isOn: $autoDetectSource)
            Toggle("Okuma Süresini Göster", isOn: $showReadingTime)
        }
    }
    
    private var aboutSection: some View {
        Section("Hakkında") {
            HStack {
                Text("Versiyon")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "mailto:support@example.com")!) {
                HStack {
                    Text("Destek")
                    Spacer()
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                // Cache temizleme işlemi
            } label: {
                Label("Önbelleği Temizle", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
