import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('incoming_events');
    await Hive.openBox('feed_items');
    await Hive.openBox('settings');
    await Hive.openBox('tasks');
  }

  static Box get incomingEvents => Hive.box('incoming_events');
  static Box get feedItems => Hive.box('feed_items');
  static Box get settings => Hive.box('settings');
  static Box get tasks => Hive.box('tasks');
}
