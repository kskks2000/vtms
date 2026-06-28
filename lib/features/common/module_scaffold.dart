import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/responsive.dart';

/// 각 모듈 화면이 공통으로 쓰는 플레이스홀더 스캐폴드.
/// 화면 폭에 따라 기능 카드 그리드의 열 수가 자동으로 바뀐다.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.description,
    this.features = const [],
  });

  final String title;
  final String description;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentConstrained(
      child: ListView(
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ResponsiveBuilder(
            builder: (context, size) {
              final columns = switch (size) {
                ScreenSize.mobile => 1,
                ScreenSize.tablet => 2,
                ScreenSize.desktop => 3,
              };
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: [
                  for (final f in features) _FeatureCard(label: f),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: theme.textTheme.titleMedium),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '준비 중',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
