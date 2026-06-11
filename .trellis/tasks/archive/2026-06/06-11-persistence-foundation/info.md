# Implementation Notes

## FTS synchronization

`.trellis/spec/guides/persistence-design.md` section 4 labels `item_fts` as contentless FTS5 with trigger synchronization, but `body_text` is derived from decoded `body_json` rather than a stored SQL column. A pure SQLite trigger cannot reconstruct the same text without adding a new `item.body_text` column or registering a custom SQLite function.

Task A keeps the documented `item_fts(title, excerpt, body_text, content='', tokenize='unicode61')` shape and uses repository-controlled synchronization instead:

- on `saveItem`, delete the old FTS entry with FTS5's contentless delete command, then insert the new payload using the item's `rowid`;
- on `deleteItem`, delete the FTS entry before deleting the item;
- `search` joins `item_fts.rowid` back to `item.rowid` to return item IDs.

This preserves the published schema while avoiding an undocumented `body_text` column.

## CJK query behavior

The local SQLite `unicode61` tokenizer did not match `本地优先` as a substring inside a longer CJK sentence during tests. To keep the built-in tokenizer while satisfying Chinese search, Task A normalizes CJK text and queries before FTS by inserting spaces around CJK scalars. This is not a custom tokenizer and does not change the schema.
