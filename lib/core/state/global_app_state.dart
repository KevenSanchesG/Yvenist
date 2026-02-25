import 'package:flutter/material.dart';

// Gerenciamento de Estado Global
final ValueNotifier<List<Map<String, dynamic>>> favoritesNotifier = ValueNotifier([]);
final ValueNotifier<List<Map<String, dynamic>>> partyNotifier = ValueNotifier([]);