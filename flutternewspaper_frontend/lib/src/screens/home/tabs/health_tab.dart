import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class HealthTab extends StatelessWidget {
  const HealthTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.health);
  }
}
