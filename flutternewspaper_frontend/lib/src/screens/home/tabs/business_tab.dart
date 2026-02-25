import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class BusinessTab extends StatelessWidget {
  const BusinessTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.business);
  }
}
