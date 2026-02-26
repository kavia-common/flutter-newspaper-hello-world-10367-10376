import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.sports);
  }
}
