import ReaderCore
import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var apiKey = ""
    @State private var selectedModel: AnthropicModel = .default
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Anthropic API Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))

                SecureField(store.maskedAPIKey ?? "输入 Anthropic API Key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("模型")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))

                Picker("", selection: $selectedModel) {
                    ForEach(AnthropicModel.allCases) { model in
                        Text("\(model.displayName) · \(model.costHint)").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 8) {
                Icon(name: "shield", size: 14)
                    .foregroundStyle(ReaderStyle.accent)
                    .padding(.top, 1)
                Text("AI 处理会将所选内容发送至 Anthropic;数据仍只保存在本地。")
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
            }
            .padding(10)
            .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
        .padding(20)
        .frame(width: 420)
        .onAppear {
            selectedModel = store.selectedAIModel
        }
    }

    private func save() {
        do {
            try store.saveAIConfiguration(apiKey: apiKey, model: selectedModel)
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
                try store.saveAIConfiguration(apiKey: apiKey, model: selectedModel)
                apiKey = ""
                try await store.testAIConnection()
                statusMessage = "连接正常"
            } catch {
                statusMessage = userFacingMessage(error)
            }
            isTesting = false
        }
    }

    private func removeKey() {
        do {
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
