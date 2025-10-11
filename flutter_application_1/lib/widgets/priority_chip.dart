// For highlighting high-priority items
import 'package:flutter/material.dart';

class PriorityChip extends StatelessWidget {
  final String label;
  const PriorityChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), backgroundColor: Colors.redAccent);
  }
}
