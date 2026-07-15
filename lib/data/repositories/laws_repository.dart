import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../models/law.dart';
import '../models/bab.dart';
import '../models/fasl.dart';
import '../models/madda.dart';

class LawsRepository {
  LawsRepository._internal();
  static final LawsRepository instance = LawsRepository._internal();

  Future<Database> get _db async => DBHelper.instance.database;

  // ---------------------------------------------------------------------
  // القوانين
  // ---------------------------------------------------------------------

  Future<List<Law>> getAllLaws() async {
    final db = await _db;
    final rows = await db.query('laws', orderBy: 'order_num ASC');
    return rows.map(Law.fromMap).toList();
  }

  Future<Law?> getLawById(int id) async {
    final db = await _db;
    final rows = await db.query('laws', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Law.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------
  // الأبواب (يدعم التداخل: كتاب/قسم/باب عبر parent_bab_id)
  // ---------------------------------------------------------------------

  /// يعيد الأبواب المباشرة (top-level) لقانون معيّن، أو أبواب فرعية إن
  /// مُرِّر [parentBabId].
  Future<List<Bab>> getAbwab(int lawId, {int? parentBabId}) async {
    final db = await _db;
    final rows = await db.query(
      'abwab',
      where: parentBabId == null
          ? 'law_id = ? AND parent_bab_id IS NULL'
          : 'law_id = ? AND parent_bab_id = ?',
      whereArgs: parentBabId == null ? [lawId] : [lawId, parentBabId],
      orderBy: 'order_num ASC',
    );
    return rows.map(Bab.fromMap).toList();
  }

  Future<bool> babHasChildren(int babId) async {
    final db = await _db;
    final childBabs = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM abwab WHERE parent_bab_id = ?',
      [babId],
    ));
    if ((childBabs ?? 0) > 0) return true;
    final fusul = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM fusul WHERE bab_id = ?',
      [babId],
    ));
    return (fusul ?? 0) > 0;
  }

  // ---------------------------------------------------------------------
  // الفصول
  // ---------------------------------------------------------------------

  Future<List<Fasl>> getFusul(int babId) async {
    final db = await _db;
    final rows = await db.query(
      'fusul',
      where: 'bab_id = ?',
      whereArgs: [babId],
      orderBy: 'order_num ASC',
    );
    return rows.map(Fasl.fromMap).toList();
  }

  // ---------------------------------------------------------------------
  // المواد
  // ---------------------------------------------------------------------

  Future<List<Madda>> getMawadByFasl(int faslId) async {
    final db = await _db;
    final rows = await db.query(
      'mawad',
      where: 'fasl_id = ?',
      whereArgs: [faslId],
      orderBy: 'order_num ASC',
    );
    return rows.map(Madda.fromMap).toList();
  }

  Future<List<Madda>> getMawadByBab(int babId) async {
    final db = await _db;
    final rows = await db.query(
      'mawad',
      where: 'bab_id = ? AND fasl_id IS NULL',
      whereArgs: [babId],
      orderBy: 'order_num ASC',
    );
    return rows.map(Madda.fromMap).toList();
  }

  /// المواد التي تنتمي مباشرة إلى القانون دون أي باب (نادر: مقدمة قبل أول باب).
  Future<List<Madda>> getRootMawad(int lawId) async {
    final db = await _db;
    final rows = await db.query(
      'mawad',
      where: 'law_id = ? AND bab_id IS NULL AND fasl_id IS NULL',
      whereArgs: [lawId],
      orderBy: 'order_num ASC',
    );
    return rows.map(Madda.fromMap).toList();
  }

  Future<Madda?> getMaddaById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.*, l.name AS law_name, b.label AS bab_label, f.label AS fasl_label
      FROM mawad m
      JOIN laws l ON l.id = m.law_id
      LEFT JOIN abwab b ON b.id = m.bab_id
      LEFT JOIN fusul f ON f.id = m.fasl_id
      WHERE m.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return Madda.fromMap(rows.first);
  }

  /// يبحث برقم المادة داخل قانون معيّن (أو كل القوانين إن كان lawId فارغًا).
  Future<List<Madda>> getMaddaByNumber(String number, {int? lawId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.*, l.name AS law_name, b.label AS bab_label, f.label AS fasl_label
      FROM mawad m
      JOIN laws l ON l.id = m.law_id
      LEFT JOIN abwab b ON b.id = m.bab_id
      LEFT JOIN fusul f ON f.id = m.fasl_id
      WHERE m.number = ? ${lawId != null ? 'AND m.law_id = ?' : ''}
      ORDER BY l.order_num, m.order_num
    ''', lawId != null ? [number, lawId] : [number]);
    return rows.map(Madda.fromMap).toList();
  }

  // ---------------------------------------------------------------------
  // البحث الشامل (نص كامل عبر FTS5) داخل جميع القوانين أو قانون واحد
  // ---------------------------------------------------------------------

  Future<List<Madda>> search(String query, {int? lawId, int limit = 100}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final db = await _db;

    // إن كان البحث رقمًا صرفًا، ابحث برقم المادة مباشرة أيضًا
    final isNumeric = RegExp(r'^\d+$').hasMatch(trimmed);
    if (isNumeric) {
      return getMaddaByNumber(trimmed, lawId: lawId);
    }

    final ftsQuery = _buildFtsQuery(trimmed);
    try {
      final rows = await db.rawQuery('''
        SELECT m.*, l.name AS law_name, b.label AS bab_label, f.label AS fasl_label
        FROM mawad_fts fts
        JOIN mawad m ON m.id = fts.rowid
        JOIN laws l ON l.id = m.law_id
        LEFT JOIN abwab b ON b.id = m.bab_id
        LEFT JOIN fusul f ON f.id = m.fasl_id
        WHERE mawad_fts MATCH ? ${lawId != null ? 'AND m.law_id = ?' : ''}
        ORDER BY rank
        LIMIT ?
      ''', lawId != null ? [ftsQuery, lawId, limit] : [ftsQuery, limit]);
      return rows.map(Madda.fromMap).toList();
    } catch (_) {
      // إن فشل استعلام FTS (مثلاً بسبب رموز خاصة) نرجع لبحث LIKE بسيط كخطة بديلة
      final rows = await db.rawQuery('''
        SELECT m.*, l.name AS law_name, b.label AS bab_label, f.label AS fasl_label
        FROM mawad m
        JOIN laws l ON l.id = m.law_id
        LEFT JOIN abwab b ON b.id = m.bab_id
        LEFT JOIN fusul f ON f.id = m.fasl_id
        WHERE m.body LIKE ? ${lawId != null ? 'AND m.law_id = ?' : ''}
        ORDER BY l.order_num, m.order_num
        LIMIT ?
      ''', lawId != null ? ['%$trimmed%', lawId, limit] : ['%$trimmed%', limit]);
      return rows.map(Madda.fromMap).toList();
    }
  }

  /// يحوّل نص المستخدم إلى استعلام FTS5 آمن (كل كلمة مع بادئة * للمطابقة الجزئية).
  String _buildFtsQuery(String input) {
    final words = input
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.replaceAll('"', ''))
        .map((w) => '"$w"*')
        .toList();
    return words.join(' AND ');
  }

  // ---------------------------------------------------------------------
  // المفضلة
  // ---------------------------------------------------------------------

  Future<void> addFavorite(int maddaId) async {
    final db = await _db;
    await db.insert(
      'favorites',
      {'mada_id': maddaId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(int maddaId) async {
    final db = await _db;
    await db.delete('favorites', where: 'mada_id = ?', whereArgs: [maddaId]);
  }

  Future<bool> isFavorite(int maddaId) async {
    final db = await _db;
    final rows = await db.query('favorites', where: 'mada_id = ?', whereArgs: [maddaId]);
    return rows.isNotEmpty;
  }

  Future<List<Madda>> getFavorites() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.*, l.name AS law_name, b.label AS bab_label, f.label AS fasl_label
      FROM favorites fav
      JOIN mawad m ON m.id = fav.mada_id
      JOIN laws l ON l.id = m.law_id
      LEFT JOIN abwab b ON b.id = m.bab_id
      LEFT JOIN fusul f ON f.id = m.fasl_id
      ORDER BY fav.created_at DESC
    ''');
    return rows.map(Madda.fromMap).toList();
  }
}
