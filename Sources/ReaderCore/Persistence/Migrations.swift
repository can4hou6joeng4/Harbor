import Foundation
import GRDB

public enum Migrations {
    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
            CREATE TABLE item (
              id TEXT PRIMARY KEY,
              kind TEXT NOT NULL,
              source TEXT NOT NULL,
              feed_id TEXT REFERENCES feed(id) ON DELETE SET NULL,
              author TEXT NOT NULL DEFAULT '',
              title TEXT NOT NULL,
              excerpt TEXT NOT NULL DEFAULT '',
              published_at REAL NOT NULL,
              reading_time INTEGER,
              duration TEXT,
              language TEXT NOT NULL DEFAULT 'zh',
              folder_id TEXT REFERENCES folder(id) ON DELETE SET NULL,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              is_unread INTEGER NOT NULL DEFAULT 1,
              progress REAL NOT NULL DEFAULT 0,
              reading_offset REAL NOT NULL DEFAULT 0,
              hue REAL NOT NULL DEFAULT 0,
              has_cover INTEGER NOT NULL DEFAULT 0,
              attachment_path TEXT,
              body_json TEXT NOT NULL,
              summary_json TEXT
            );

            CREATE TABLE highlight (
              id TEXT PRIMARY KEY,
              item_id TEXT NOT NULL REFERENCES item(id) ON DELETE CASCADE,
              quote TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_at REAL NOT NULL
            );

            CREATE TABLE tag (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color_hex TEXT NOT NULL
            );

            CREATE TABLE item_tag (
              item_id TEXT NOT NULL REFERENCES item(id) ON DELETE CASCADE,
              tag_id TEXT NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
              PRIMARY KEY (item_id, tag_id)
            );

            CREATE TABLE folder (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parent_id TEXT REFERENCES folder(id) ON DELETE CASCADE,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE feed (
              id TEXT PRIMARY KEY,
              platform TEXT NOT NULL,
              name TEXT NOT NULL,
              monogram TEXT NOT NULL,
              color_hex TEXT NOT NULL,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              url TEXT
            );

            CREATE VIRTUAL TABLE item_fts USING fts5(
              title,
              excerpt,
              body_text,
              content='',
              tokenize='unicode61'
            );

            CREATE INDEX item_feed_id_idx ON item(feed_id);
            CREATE INDEX item_folder_id_idx ON item(folder_id);
            CREATE INDEX item_published_at_idx ON item(published_at);
            CREATE INDEX highlight_item_id_idx ON highlight(item_id);
            CREATE INDEX item_tag_tag_id_idx ON item_tag(tag_id);
            CREATE INDEX folder_parent_id_idx ON folder(parent_id);
            CREATE INDEX feed_platform_idx ON feed(platform);
            """)
        }

        return migrator
    }
}
