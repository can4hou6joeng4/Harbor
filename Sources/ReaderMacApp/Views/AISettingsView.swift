import ReaderCore
import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var apiKey = ""
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var selectedModel: AnthropicModel = .default
    @State private var selectedOpenAIModel: OpenAIModel = .default
    @State private var customProviderName = ""
    @State private var customBaseURLString = ""
    @State private var customModel = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            formSection(title: "Provider") {
                Picker("", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            customFields
            keyField
            modelField
            privacyNotice
            statusText
            actions
        }
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: load)
        .onChange(of: selectedProvider) { provider in
            store.selectAIProvider(provider)
            apiKey = ""
            statusMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Icon(name: "sparkles", size: 18)
                .foregroundStyle(ReaderStyle.accent)
            Text("AI 设置")
                .font(.system(size: 17, weight: .bold))
            Spacer()
            IconButton(icon: "close", title: "关闭", size: 28, iconSize: 13) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var customFields: some View {
        if selectedProvider == .custom {
            formSection(title: "自定义 Provider") {
                VStack(spacing: 8) {
                    TextField("名称", text: $customProviderName)
                        .textFieldStyle(.plain)
                        .controlFieldStyle(scheme: scheme)
                    TextField("Base URL,例如 https://api.example.com 或 https://api.example.com/v1", text: $customBaseURLString)
                        .textFieldStyle(.plain)
                        .controlFieldStyle(scheme: scheme)
                }
            }
        }
    }

    private var keyField: some View {
        formSection(title: "\(selectedProvider.displayName) API Key") {
            SecureField(store.maskedAPIKey(for: selectedProvider) ?? selectedProvider.keyPlaceholder, text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .controlFieldStyle(scheme: scheme)
        }
    }

    @ViewBuilder
    private var modelField: some View {
        switch selectedProvider {
        case .anthropic:
            formSection(title: "模型") {
                Picker("", selection: $selectedModel) {
                    ForEach(AnthropicModel.allCases) { model in
                        Text("\(model.displayName) · \(model.costHint)").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .openAI:
            formSection(title: "模型") {
                Picker("", selection: $selectedOpenAIModel) {
                    ForEach(OpenAIModel.allCases) { model in
                        Text("\(model.displayName) · \(model.costHint)").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .custom:
            formSection(title: "模型") {
                TextField("OpenAI-compatible 模型名", text: $customModel)
                    .textFieldStyle(.plain)
                    .controlFieldStyle(scheme: scheme)
            }
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Icon(name: "shield", size: 14)
                .foregroundStyle(ReaderStyle.accent)
                .padding(.top, 1)
            Text(privacyText)
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
        }
        .padding(10)
        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var statusText: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            TextIconButton(title: "保存并启用", icon: "check", role: .primary) {
                save()
            }

            TextIconButton(title: isTesting ? "测试中" : "测试连接", icon: "link") {
                testConnection()
            }
            .disabled(isTesting)

            Spacer()

            TextIconButton(title: "断开", icon: "close") {
                removeKey()
            }
        }
    }

    private var privacyText: String {
        let destination: String
        if selectedProvider == .custom {
            let name = customProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseURL = customBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            destination = baseURL.isEmpty ? (name.isEmpty ? "自定义 Provider" : name) : "\(name.isEmpty ? "自定义 Provider" : name) (\(baseURL))"
        } else {
            destination = selectedProvider.displayName
        }
        return "AI 处理会将所选内容发送至 \(destination);数据仍只保存在本地。"
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
            content()
        }
    }

    private func load() {
        selectedProvider = store.selectedAIProvider
        selectedModel = store.selectedAIModel
        selectedOpenAIModel = store.selectedOpenAIModel
        customProviderName = store.customProviderName
        customBaseURLString = store.customBaseURLString
        customModel = store.customModel
    }

    private func save() {
        do {
            try saveCurrentConfiguration()
            apiKey = ""
            statusMessage = "已保存"
        } catch {
            statusMessage = userFacingMessage(error)
        }
    }

    private func testConnection() {
        isTesting = true
        statusMessage = nil
        Task {
            do {
                try saveCurrentConfiguration()
                apiKey = ""
                try await store.testAIConnection()
                statusMessage = "连接正常"
            } catch {
                statusMessage = userFacingMessage(error)
            }
            isTesting = false
        }
    }

    private func saveCurrentConfiguration() throws {
        try store.saveAIConfiguration(
            apiKey: apiKey,
            provider: selectedProvider,
            anthropicModel: selectedModel,
            openAIModel: selectedOpenAIModel,
            customProviderName: customProviderName,
            customBaseURLString: customBaseURLString,
            customModel: customModel
        )
    }

    private func removeKey() {
        do {
            store.selectAIProvider(selectedProvider)
            try store.removeAIConfiguration()
            apiKey = ""
            statusMessage = "已断开"
        } catch {
            statusMessage = userFacingMessage(error)
        }
    }

    private func userFacingMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return "操作失败"
    }
}

private extension View {
    func controlFieldStyle(scheme: ColorScheme) -> some View {
        self
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
    }
}
