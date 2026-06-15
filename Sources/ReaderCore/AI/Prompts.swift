import Foundation

public struct ArticlePromptText: Equatable, Sendable {
    public var text: String
    public var wasTruncated: Bool
}

public enum Prompts {
    private static let maxArticleCharacters = 150_000

    static func articleText(for item: ReaderItem, maxCharacters: Int = maxArticleCharacters) -> ArticlePromptText {
        let bodyText = item.body
            .filter { $0.kind != .image }
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        var text = """
        标题:\(item.title)
        来源:\(item.source)
        摘要:\(item.excerpt)

        正文:
        \(bodyText)
        """

        guard text.count > maxCharacters else {
            return ArticlePromptText(text: text, wasTruncated: false)
        }

        text = String(text.prefix(maxCharacters)) + "\n\n[正文已截断]"
        return ArticlePromptText(text: text, wasTruncated: true)
    }

    static func summaryRequestBody(for item: ReaderItem, model: AnthropicModel) throws -> Data {
        let article = articleText(for: item)
        let payload: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 1024,
            "stream": false,
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": summarySchema
                ]
            ],
            "system": [
                [
                    "type": "text",
                    "text": summarySystemPrompt
                ],
                [
                    "type": "text",
                    "text": article.text,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": article.wasTruncated ? "请基于已截断正文生成结构化中文摘要。" : "请生成结构化中文摘要。"
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func translationRequestBody(for item: ReaderItem, targetLanguage: String, model: AnthropicModel) throws -> Data {
        let blocks = translationBlocks(for: item)
        let payload: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 2048,
            "stream": false,
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": translationSchema
                ]
            ],
            "system": [
                [
                    "type": "text",
                    "text": translationSystemPrompt(targetLanguage: targetLanguage)
                ],
                [
                    "type": "text",
                    "text": translationSourceText(title: item.title, blocks: blocks.values, wasTruncated: blocks.wasTruncated),
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "请翻译这些正文块,保持 id 不变。"
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func chatRequestBody(messages: [ChatMessage], item: ReaderItem?, model: AnthropicModel) throws -> Data {
        let payload: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 4096,
            "stream": true,
            "output_config": ["effort": "medium"],
            "system": chatSystemBlocks(for: item),
            "messages": anthropicMessages(from: messages)
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func remixRequestBody(type: String, items: [ReaderItem], model: AnthropicModel) throws -> Data {
        let payload: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 4096,
            "stream": true,
            "output_config": ["effort": "medium"],
            "system": [
                [
                    "type": "text",
                    "text": remixSystemPrompt(type: type)
                ],
                [
                    "type": "text",
                    "text": remixSourceText(for: items),
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "请生成可直接复制的 Markdown 草稿。"
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func connectionTestRequestBody(model: AnthropicModel) throws -> Data {
        let payload: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 16,
            "stream": false,
            "system": "只回答 ok。",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "ping"
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func openAISummaryRequestBody(for item: ReaderItem, model: String) throws -> Data {
        let article = articleText(for: item)
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "stream": false,
            "response_format": openAIJSONSchemaFormat(name: "reader_summary", schema: summarySchema),
            "messages": [
                ["role": "system", "content": summarySystemPrompt],
                [
                    "role": "user",
                    "content": """
                    \(article.text)

                    \(article.wasTruncated ? "请基于已截断正文生成结构化中文摘要。" : "请生成结构化中文摘要。")
                    """
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func openAITranslationRequestBody(for item: ReaderItem, targetLanguage: String, model: String) throws -> Data {
        let blocks = translationBlocks(for: item)
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "stream": false,
            "response_format": openAIJSONSchemaFormat(name: "reader_translation", schema: translationSchema),
            "messages": [
                ["role": "system", "content": translationSystemPrompt(targetLanguage: targetLanguage)],
                [
                    "role": "user",
                    "content": """
                    \(translationSourceText(title: item.title, blocks: blocks.values, wasTruncated: blocks.wasTruncated))

                    请翻译这些正文块,保持 id 不变。
                    """
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func openAIChatRequestBody(messages: [ChatMessage], item: ReaderItem?, model: String) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "messages": openAIMessages(from: messages, system: chatSystemPrompt(for: item))
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func openAIRemixRequestBody(type: String, items: [ReaderItem], model: String) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "messages": [
                ["role": "system", "content": "\(remixSystemPrompt(type: type))\n\n\(remixSourceText(for: items))"],
                ["role": "user", "content": "请生成可直接复制的 Markdown 草稿。"]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func openAIConnectionTestRequestBody(model: String) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 16,
            "stream": false,
            "messages": [
                ["role": "system", "content": "只回答 ok。"],
                ["role": "user", "content": "ping"]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private static func openAIJSONSchemaFormat(name: String, schema: [String: Any]) -> [String: Any] {
        [
            "type": "json_schema",
            "json_schema": [
                "name": name,
                "strict": true,
                "schema": schema
            ]
        ]
    }

    private static let summarySystemPrompt = """
    你是本地优先阅读器里的摘要助手。请只输出符合 schema 的 JSON,不要寒暄。摘要与要点使用中文,标签给 2 到 4 个短词。
    """

    private static let chatSystemPrompt = """
    你是本地优先阅读器里的阅读助手。请基于当前文章和对话上下文回答,优先使用中文,不要编造文章中没有的信息;不确定时直接说明。
    """

    private static func chatSystemBlocks(for item: ReaderItem?) -> [[String: Any]] {
        var blocks: [[String: Any]] = [
            [
                "type": "text",
                "text": chatSystemPrompt
            ]
        ]
        if let item {
            blocks.append([
                "type": "text",
                "text": articleText(for: item).text,
                "cache_control": ["type": "ephemeral"]
            ])
        }
        return blocks
    }

    private static func chatSystemPrompt(for item: ReaderItem?) -> String {
        guard let item else { return chatSystemPrompt }
        return "\(chatSystemPrompt)\n\n\(articleText(for: item).text)"
    }

    private static func anthropicMessages(from messages: [ChatMessage]) -> [[String: Any]] {
        var turns: [(role: String, text: String)] = []

        for message in messages {
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard message.role == .user || !turns.isEmpty else { continue }

            let role = message.role.rawValue
            if turns.last?.role == role {
                turns[turns.count - 1].text += "\n\n\(text)"
            } else {
                turns.append((role, text))
            }
        }

        if turns.isEmpty {
            turns.append(("user", "请帮助我理解这篇内容。"))
        }

        return turns.map { turn in
            [
                "role": turn.role,
                "content": [
                    [
                        "type": "text",
                        "text": turn.text
                    ]
                ]
            ]
        }
    }

    private static func openAIMessages(from messages: [ChatMessage], system: String) -> [[String: String]] {
        var output: [[String: String]] = [
            ["role": "system", "content": system]
        ]
        var turns: [(role: String, text: String)] = []

        for message in messages {
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard message.role == .user || !turns.isEmpty else { continue }

            let role = message.role.rawValue
            if turns.last?.role == role {
                turns[turns.count - 1].text += "\n\n\(text)"
            } else {
                turns.append((role, text))
            }
        }

        if turns.isEmpty {
            turns.append(("user", "请帮助我理解这篇内容。"))
        }

        output.append(contentsOf: turns.map { ["role": $0.role, "content": $0.text] })
        return output
    }

    private static func remixSystemPrompt(type: String) -> String {
        switch type {
        case "rx-thread":
            return "你是本地优先阅读器里的二创助手。请把来源内容改写成 5 条中文短帖,保留关键论点,每条独立成段,只输出 Markdown。"
        case "rx-weekly":
            return "你是本地优先阅读器里的周报助手。请把来源内容整理成本周阅读回顾,包含主题、条目要点和一句话收获,只输出 Markdown。"
        case "rx-cross":
            return "你是本地优先阅读器里的综述助手。请对多篇来源做交叉分析,指出共同点、差异和可继续追问的问题,只输出 Markdown。"
        default:
            return "你是本地优先阅读器里的读书笔记助手。请把来源内容整理成结构清晰的中文 Markdown 笔记,包含摘要、要点和可行动问题。"
        }
    }

    private static func translationSystemPrompt(targetLanguage: String) -> String {
        """
        你是本地优先阅读器里的翻译助手。请把输入正文逐块翻译成\(languageName(targetLanguage)),只输出符合 schema 的 JSON。保留原意、术语和段落语气,不要添加解释或寒暄。
        """
    }

    private static func languageName(_ language: String) -> String {
        switch language.lowercased() {
        case "zh", "zh-cn", "chinese":
            return "中文"
        case "en", "english":
            return "英文"
        default:
            return language
        }
    }

    private static func translationBlocks(for item: ReaderItem, maxCharacters: Int = maxArticleCharacters) -> (values: [[String: String]], wasTruncated: Bool) {
        var total = 0
        var values: [[String: String]] = []
        var wasTruncated = false

        for block in item.body where block.kind != .image {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let nextTotal = total + text.count
            if nextTotal > maxCharacters {
                wasTruncated = true
                break
            }
            total = nextTotal
            values.append([
                "id": block.id.uuidString,
                "kind": block.kind.rawValue,
                "language": block.language,
                "text": text
            ])
        }

        return (values, wasTruncated)
    }

    private static func translationSourceText(title: String, blocks: [[String: String]], wasTruncated: Bool) -> String {
        let encoded = (try? JSONSerialization.data(withJSONObject: blocks, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
        标题:\(title)
        \(wasTruncated ? "正文已按预算截断。" : "")
        blocks:
        \(encoded)
        """
    }

    private static func remixSourceText(for items: [ReaderItem], maxCharacters: Int = maxArticleCharacters) -> String {
        var remaining = maxCharacters
        var sections: [String] = []

        for item in items {
            guard remaining > 0 else { break }
            let article = articleText(for: item, maxCharacters: remaining)
            remaining -= article.text.count
            sections.append("""
            --- SOURCE \(sections.count + 1) ---
            \(article.text)
            """)
        }

        let joined = sections.isEmpty ? "无可用来源。" : sections.joined(separator: "\n\n")
        return remaining <= 0 ? joined + "\n\n[来源内容已截断]" : joined
    }

    static let summarySchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["text", "keys", "tagSuggestions"],
        "properties": [
            "text": [
                "type": "array",
                "items": ["type": "string"],
                "minItems": 1,
                "maxItems": 3
            ],
            "keys": [
                "type": "array",
                "items": ["type": "string"],
                "minItems": 3,
                "maxItems": 6
            ],
            "tagSuggestions": [
                "type": "array",
                "items": ["type": "string"],
                "minItems": 2,
                "maxItems": 4
            ]
        ]
    ]

    static let translationSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["translations"],
        "properties": [
            "translations": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["id", "text"],
                    "properties": [
                        "id": ["type": "string"],
                        "text": ["type": "string"]
                    ]
                ]
            ]
        ]
    ]
}
