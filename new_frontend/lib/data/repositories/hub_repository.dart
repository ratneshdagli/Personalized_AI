import 'package:isar/isar.dart';
import '../schema/hub.dart';

class HubRepository {
  final Isar _isar;

  HubRepository(this._isar);

  Future<List<Hub>> getAllHubs() async {
    return await _isar.hubs.where().sortBySortOrder().findAll();
  }

  Future<Hub?> getHubById(int id) async {
    return await _isar.hubs.get(id);
  }

  Future<Hub?> findByName(String name) async {
    return await _isar.hubs.filter().nameEqualTo(name, caseSensitive: false).findFirst();
  }

  Future<Hub> createHub(String name, {bool isDefault = false, String? colorHex, int sortOrder = 0}) async {
    final hub = Hub()
      ..name = name
      ..isDefault = isDefault
      ..colorHex = colorHex
      ..sortOrder = sortOrder;

    await _isar.writeTxn(() async {
      await _isar.hubs.put(hub);
    });

    return hub;
  }

  Future<bool> deleteHub(int id) async {
    // Don't delete default hubs if possible, or handle re-assignment
    // For now, simple deletion
    return await _isar.writeTxn(() async {
      return await _isar.hubs.delete(id);
    });
  }

  Future<Hub> getDefaultHub() async {
    final defaultHub = await _isar.hubs.filter().isDefaultEqualTo(true).findFirst();
    if (defaultHub != null) {
      return defaultHub;
    }

    // If no default hub exists, try to find "General" or create it
    final generalHub = await findByName('General');
    if (generalHub != null) {
      // Mark as default
      generalHub.isDefault = true;
      await _isar.writeTxn(() async {
        await _isar.hubs.put(generalHub);
      });
      return generalHub;
    }

    // Create default "General" hub
    return await createHub('General', isDefault: true, sortOrder: 0);
  }
  
  Future<void> ensureDefaultHubs() async {
    final defaults = [
      {'name': 'Urgent & Priority', 'color': '0xFFEF4444', 'order': 0},
      {'name': 'Conversations', 'color': '0xFF3B82F6', 'order': 1},
      {'name': 'Work & Email', 'color': '0xFF6366F1', 'order': 2},
      {'name': 'Reminders', 'color': '0xFFA855F7', 'order': 3},
      {'name': 'Finance', 'color': '0xFF22C55E', 'order': 4},
      {'name': 'News & Trends', 'color': '0xFFF59E0B', 'order': 5},
      {'name': 'Personal', 'color': '0xFFEC4899', 'order': 6},
    ];

    for (final def in defaults) {
      final exists = await findByName(def['name'] as String);
      if (exists == null) {
        await createHub(
          def['name'] as String,
          sortOrder: def['order'] as int,
          colorHex: def['color'] as String,
        );
      }
    }
    
    // Ensure General exists as fallback
    await getDefaultHub();
  }
}
