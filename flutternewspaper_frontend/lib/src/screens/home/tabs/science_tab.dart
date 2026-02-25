import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class ScienceTab extends StatelessWidget {
  const ScienceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.science);
  }
}
