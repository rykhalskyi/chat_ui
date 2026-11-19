import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.database);

  static const fileName = 'chat_ui.db';
  static const schemaVersion = 1;

  final Database database;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute('''
            CREATE TABLE conversations (
              id            TEXT PRIMARY KEY,
              title         TEXT NOT NULL,
              model_id      TEXT NOT NULL,
              system_prompt TEXT,
              created_at    INTEGER NOT NULL,
              updated_at    INTEGER NOT NULL
            )
          ''');
          batch.execute('''
            CREATE TABLE messages (
              id                TEXT PRIMARY KEY,
              conversation_id   TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
              seq               INTEGER NOT NULL,
              role              TEXT NOT NULL,
              content           TEXT NOT NULL DEFAULT '',
              reasoning         TEXT,
              status            TEXT NOT NULL,
              error             TEXT,
              model_id          TEXT,
              prompt_tokens     INTEGER,
              completion_tokens INTEGER,
              cost              REAL,
              created_at        INTEGER NOT NULL
            )
          ''');
          batch.execute(
            'CREATE INDEX idx_messages_conv ON messages(conversation_id, seq)',
          );
          await batch.commit(noResult: true);
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => database.close();
}
