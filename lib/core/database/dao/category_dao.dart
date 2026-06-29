import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/category.dart';

class CategoryDao {
  CategoryDao._();
  static final CategoryDao instance = CategoryDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Category category) async {
    final db = await _db;
    return db.insert(
      'categories',
      category.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Category category) async {
    final db = await _db;
    return db.update(
      'categories',
      category.copyWith(createdAt: category.createdAt).toDb(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Category?> findById(int id) async {
    final db = await _db;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Category.fromDb(rows.first);
  }

  Future<List<Category>> all() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map(Category.fromDb).toList();
  }
}
