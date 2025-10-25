import 'package:flutter/material.dart';

/// Utility class for vault icons
class VaultIcons {
  static const List<String> available = [
    'lock',
    'work',
    'home',
    'family_restroom',
    'school',
    'shopping_cart',
    'credit_card',
    'cloud',
    'security',
    'folder',
  ];

  static IconData getIcon(String iconName) {
    switch (iconName) {
      case 'lock':
        return Icons.lock;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'school':
        return Icons.school;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'credit_card':
        return Icons.credit_card;
      case 'cloud':
        return Icons.cloud;
      case 'security':
        return Icons.security;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.lock;
    }
  }
}

/// Utility class for vault colors
class VaultColors {
  static const List<Color> available = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];
}
