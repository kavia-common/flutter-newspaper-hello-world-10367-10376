import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import 'category_tab.dart';

class EntertainmentTab extends StatelessWidget {
  const EntertainmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CategoryTab(category: AppConstants.entertainment);
  }
}
