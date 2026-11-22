import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'room_code.dart';

/// A room this parent phone joined (V2 5.2).
@immutable
class RecentRoom {
  const RecentRoom({required this.code, required this.joinedAt, this.name});

  final String code;
  final String? name;
  final DateTime joinedAt;

  Map<String, Object?> toJson() => {'code': code, 'name': name, 'at': joinedAt.millisecondsSinceEpoch};

  static RecentRoom? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code'];
    final at = raw['at'];
    if (code is! String || !RoomCode.isValid(code) || at is! int) return null;
    final name = raw['name'];
    return RecentRoom(
      code: code,
      name: name is String && name.trim().isNotEmpty ? name : null,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}

/// Last rooms joined on this phone, newest first (at most [maxRooms]).
class RecentRoomStore {
  static const String _key = 'recentRooms';
  static const int maxRooms = 3;

  Future<List<RecentRoom>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(RecentRoom.fromJson).whereType<RecentRoom>().toList();
    } catch (e) {
      debugPrint('Loading recent rooms failed: $e');
      return const [];
    }
  }

  Future<List<RecentRoom>> remember(RecentRoom room) async {
    final rooms = [room, ...(await load()).where((r) => r.code != room.code)].take(maxRooms).toList();
    await _save(rooms);
    return rooms;
  }

  Future<List<RecentRoom>> forget(String code) async {
    final rooms = (await load()).where((r) => r.code != code).toList();
    await _save(rooms);
    return rooms;
  }

  Future<void> _save(List<RecentRoom> rooms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(rooms.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('Saving recent rooms failed: $e');
    }
  }
}
