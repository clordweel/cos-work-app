import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/cos_site_config.dart';
import 'cos_secure_storage_factory.dart';

const _kPrefsEntriesJson = 'cos_login_history_entries_v1';
const _kSecurePwdPrefix = 'cos_login_hist_pwd_';

/// 从历史列表回到登录页时携带的数据。
@immutable
class CosLoginHistoryPick {
  const CosLoginHistoryPick({
    required this.id,
    required this.originString,
    required this.username,
    required this.password,
  });

  final String id;
  final String originString;
  final String username;

  /// 自 Secure Storage 读取；缺失时为 null（需用户手输密码）。
  final String? password;
}

/// 一条历史登录记录（不含密码明文）。
@immutable
class CosLoginHistoryEntry {
  const CosLoginHistoryEntry({
    required this.id,
    required this.originString,
    required this.username,
    this.displayName,
    required this.groupLabel,
    required this.lastUsedMs,
  });

  final String id;
  final String originString;
  final String username;

  /// 登录成功后的展示名（如 full_name），用于头像首字等。
  final String? displayName;
  final String groupLabel;
  final int lastUsedMs;

  CosLoginHistoryEntry copyWith({
    String? originString,
    String? username,
    String? displayName,
    String? groupLabel,
    int? lastUsedMs,
  }) {
    return CosLoginHistoryEntry(
      id: id,
      originString: originString ?? this.originString,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      groupLabel: groupLabel ?? this.groupLabel,
      lastUsedMs: lastUsedMs ?? this.lastUsedMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'o': originString,
        'u': username,
        if (displayName != null && displayName!.isNotEmpty) 'n': displayName,
        'g': groupLabel,
        't': lastUsedMs,
      };

  static CosLoginHistoryEntry? fromJson(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final o = m['o'] as String?;
    final u = m['u'] as String?;
    final g = m['g'] as String?;
    final t = m['t'];
    if (id == null || o == null || u == null || g == null || t == null) {
      return null;
    }
    final n = m['n'] as String?;
    final last = t is int ? t : int.tryParse('$t');
    if (last == null) return null;
    return CosLoginHistoryEntry(
      id: id,
      originString: o,
      username: u,
      displayName: n,
      groupLabel: g,
      lastUsedMs: last,
    );
  }
}

/// 历史账号列表：元数据在 SharedPreferences，密码在 Secure Storage。
class CosLoginHistoryStore {
  CosLoginHistoryStore._();
  static final CosLoginHistoryStore instance = CosLoginHistoryStore._();

  final FlutterSecureStorage _secure = cosFlutterSecureStorage;

  /// 用户中心「切换账号」选凭证后先暂存，待登出后新建的 [LoginScreen] 消费并回填表单。
  CosLoginHistoryPick? _pendingPrefillAfterLogout;

  void stagePrefillForNextLoginScreen(CosLoginHistoryPick pick) {
    _pendingPrefillAfterLogout = pick;
  }

  CosLoginHistoryPick? consumePendingPrefillForLoginScreen() {
    final p = _pendingPrefillAfterLogout;
    _pendingPrefillAfterLogout = null;
    return p;
  }

  static String entryId(String originString, String username) {
    final bytes = utf8.encode('$originString\u0000${username.trim()}');
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String defaultGroupLabel(Uri origin) {
    final h = origin.host;
    if (h.isEmpty) return '未命名站点';
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ipv4.hasMatch(h)) return h;
    final parts = h.split('.');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first.toUpperCase();
    }
    return h.toUpperCase();
  }

  static String hostPortLine(String originString) {
    try {
      final o = CosSiteConfig.parseOrigin(originString);
      if (o.hasPort) return '${o.host}:${o.port}';
      return o.host;
    } catch (_) {
      return originString;
    }
  }

  Future<List<CosLoginHistoryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsEntriesJson);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <CosLoginHistoryEntry>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final ent = CosLoginHistoryEntry.fromJson(e);
          if (ent != null) out.add(ent);
        } else if (e is Map) {
          final ent = CosLoginHistoryEntry.fromJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (ent != null) out.add(ent);
        }
      }
      out.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveEntries(List<CosLoginHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefsEntriesJson,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  String _pwdKey(String id) => '$_kSecurePwdPrefix$id';

  Future<String?> readPassword(String id) async {
    return _secure.read(key: _pwdKey(id));
  }

  /// 登录成功后写入或更新一条历史（密码仅存 Secure Storage）。
  Future<void> recordSuccessfulLogin({
    required String originString,
    required String username,
    required String password,
    String? displayName,
  }) async {
    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty || password.isEmpty) return;
    Uri parsed;
    try {
      parsed = CosSiteConfig.parseOrigin(originString);
    } catch (_) {
      return;
    }
    final id = entryId(parsed.toString(), trimmedUser);
    final group = defaultGroupLabel(parsed);
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = await loadEntries();
    final idx = entries.indexWhere((e) => e.id == id);
    final nextName = displayName != null && displayName.trim().isNotEmpty
        ? displayName.trim()
        : (idx >= 0 ? entries[idx].displayName : null);
    final next = CosLoginHistoryEntry(
      id: id,
      originString: parsed.toString(),
      username: trimmedUser,
      displayName: nextName,
      groupLabel: idx >= 0 ? entries[idx].groupLabel : group,
      lastUsedMs: now,
    );
    if (idx >= 0) {
      entries[idx] = next;
    } else {
      entries.add(next);
    }
    entries.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
    await _saveEntries(entries);
    await _secure.write(key: _pwdKey(id), value: password);
  }

  Future<void> touchLastUsed(String id) async {
    final entries = await loadEntries();
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    entries[idx] = entries[idx].copyWith(lastUsedMs: now);
    entries.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
    await _saveEntries(entries);
  }

  Future<void> remove(String id) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveEntries(entries);
    await _secure.delete(key: _pwdKey(id));
  }

  Future<void> init() async {
    await loadEntries();
  }
}
