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
}
