---
name: data-model-change
description: Safely add or change Nook SwiftData models, fields, relationships, schema versions, or migrations while staying CloudKit-sync-safe and App-Group-shared. Use for any change under Packages/NookKit/Sources/NookKit/Models or the store/migration code.
---

# Data model change

Pro users sync the SwiftData store to CloudKit (D8), and the widgets and App Intents read the same store. A model mistake shows up as a **runtime** failure, or as data loss for users who have already shipped. Follow this skill for every change.

## 1. Check it's needed
- Is the field in `docs/00_PRD.md` §8 or `docs/04_Architecture.md` §4? If not, it's a scope change: add a `D#` entry and check it's in the current phase.
- Can it be derived instead of stored? For example, `Item.warrantyEnd` is derived from `Warranty.endDate` (D21). Prefer derived.

## 2. CloudKit-safe rules (every one is required)
- [ ] Every stored property is **optional or has a default value**.
- [ ] Every relationship is **optional** and has an explicit **inverse** (`@Relationship(inverse: \…)`).
- [ ] The delete rule is `.cascade` (owned children) or `.nullify`. **Never `.deny`.**
- [ ] **No `@Attribute(.unique)`.** Identity is `var id: UUID = UUID()`, and sync duplicates are merged by `DedupeService`.
- [ ] No ordered relationships. Use an `order: Int` field.
- [ ] Enums are stored as `String` raw values, with a computed typed accessor.
- [ ] No blobs in the database. Photos and PDFs are files in the App Group; store the file name only.
- [ ] A new model is added to the schema's `models` list, **and** to the backup encoder and decoder (`Backup/`) and the CSV exporter if it's user-visible.

## 3. Version the schema
- For shipped or merged schemas, never edit `NookSchemaV<n>` in place. Create `NookSchemaV<n+1>: VersionedSchema` with the change.
- Add a stage to `NookMigrationPlan`:
  - `.lightweight` for additive or optional changes.
  - `.custom` when data must be transformed (for example, splitting a field). Keep custom migrations idempotent.
- Before P10 ships (and before any TestFlight), the team may collapse versions. Only do that with the lead's approval, noted in `decisions.md`.

## 4. Keep invariants in services
- Location fields change only through `LocationService.move(items:to:source:)`. It updates room and spot, appends a `LocationEvent`, sets `lastConfirmedAt`, reindexes Spotlight and reloads widgets.
- Container depth is at most one level (D3). Free limits live in `EntitlementStore`. Soft delete uses `deletedAt`.
- If the change affects search, update `searchText` generation and the `SearchIndex`.
- If it affects reminders, update the `desiredReminders` inputs (D13).
- If it touches Private items, make sure Spotlight, intents and widgets still exclude them.

## 5. Tests
- [ ] A unit test for the new fields and defaults and for the service invariants.
- [ ] A **migration test** that opens a store created with the previous schema, from a fixture in `Fixtures/stores/`, migrates it, and asserts the data.
- [ ] A backup round-trip test that includes the new field.
- [ ] A widget or intent read test if they display it.

## 6. Docs
- Update the table in `docs/04_Architecture.md` §4 (and PRD §8 if the scope changed) in the same PR.
- In the PR description, call out the schema version bump and the migration type.
