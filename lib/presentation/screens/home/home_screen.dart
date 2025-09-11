import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import 'widgets/search_bar_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 896),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.gavel,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Búsqueda Legal México RAG',
                  style: AppTextStyles.heading1.copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Sistema inteligente de búsqueda en documentos legales mexicanos '
                  'y biblioteca jurídica UNAM',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Search Bar
                SearchBarWidget(
                  onSearch: (query) {
                    Navigator.pushNamed(
                      context,
                      '/search-results',
                      arguments: query,
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Quick search suggestions
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildQuickSearchChip(
                      context,
                      'Responsabilidad civil',
                      Icons.description,
                    ),
                    _buildQuickSearchChip(
                      context,
                      'Contratos mercantiles',
                      Icons.business,
                    ),
                    _buildQuickSearchChip(
                      context,
                      'Derecho laboral',
                      Icons.work,
                    ),
                    _buildQuickSearchChip(
                      context,
                      'Amparo directo',
                      Icons.shield,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearchChip(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primaryBlue),
      label: Text(label),
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/search-results',
          arguments: label,
        );
      },
      backgroundColor: AppColors.white,
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: AppTextStyles.fontFamily,
      ),
      side: const BorderSide(color: AppColors.borderLight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
