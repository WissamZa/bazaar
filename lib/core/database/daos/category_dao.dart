import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'category_dao.g.dart';

/// Data access for `categories`.
@DriftAccessor(tables: [Categories, Items])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $CategoriesTable get categories => attachedDatabase.categories;

  Stream<List<CategoryRow>> watchAll() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<CategoryRow>> all() => select(categories).get();

  Future<CategoryRow?> findById(int id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion companion) =>
      into(categories).insert(companion);

  Future<void> updateCategory(int id, CategoriesCompanion companion) =>
      (update(categories)..where((t) => t.id.equals(id))).write(companion);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();
}
