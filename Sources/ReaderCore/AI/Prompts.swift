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

    private static let summarySystemPrompt = """
    你是本地优先阅读器里的摘要助手。请只输出符合 schema 的 JSON,不要寒暄。摘要与要点使用中文,标签给 2 到 4 个短词。
    """

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

    private static let summarySchema: [String: Any] = [
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

    private static let translationSchema: [String: Any] = [
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
