import 'package:flutter/material.dart';

/// 与 Frappe「COS Work Mini Program.icon_key」对应的 Material 图标映射；未知键返回 null。
abstract final class MiniProgramMaterialIcons {
  static const Map<String, IconData> _map = {
    'dashboard_outlined': Icons.dashboard_outlined,
    'fact_check_outlined': Icons.fact_check_outlined,
    'link_outlined': Icons.link_outlined,
    'inventory_2_outlined': Icons.inventory_2_outlined,
    'inventory_outlined': Icons.inventory_2_outlined,
    'apps_outlined': Icons.apps_outlined,
    'home_outlined': Icons.home_outlined,
    'settings_outlined': Icons.settings_outlined,
    'person_outlined': Icons.person_outlined,
    'description_outlined': Icons.description_outlined,
    'receipt_long_outlined': Icons.receipt_long_outlined,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'local_shipping_outlined': Icons.local_shipping_outlined,
    'account_balance_outlined': Icons.account_balance_outlined,
    'build_outlined': Icons.build_outlined,
    'precision_manufacturing_outlined': Icons.precision_manufacturing_outlined,
  };

  static IconData? resolve(String? key) {
    if (key == null) return null;
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    return _map[k];
  }
}
