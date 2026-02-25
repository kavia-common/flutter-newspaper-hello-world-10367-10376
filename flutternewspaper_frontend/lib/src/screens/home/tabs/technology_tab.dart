import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class TechnologyTab extends StatelessWidget {
  const TechnologyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.technology);
  }
}
