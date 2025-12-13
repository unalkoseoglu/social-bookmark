import SwiftUI

struct SettingsView: View {
    // MARK: - Properties

    @AppStorage(AppLanguage.storageKey)
    private var selectedLanguageRawValue = AppLanguage.system.rawValue

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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
