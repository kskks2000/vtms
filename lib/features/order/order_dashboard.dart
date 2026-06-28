import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/responsive.dart';
import 'order_models.dart';

/// 오더 모듈 랜딩(대시보드). 운송 오더 파이프라인의 현황을 한눈에 보여주고,
/// 주요 작업으로 진입하는 운영 콘솔 역할을 한다.
class OrderDashboard extends StatelessWidget {
  const OrderDashboard({
    super.key,
    required this.summary,
    required this.loadingSummary,
    required this.lookupError,
    required this.onRetry,
    required this.onNewOrder,
    required this.onOpenList,
    required this.onOpenBulk,
    required this.onOpenStatus,
  });

  final OrderSummary? summary;
  final bool loadingSummary;
  final String? lookupError;
  final VoidCallback onRetry;
  final VoidCallback onNewOrder;
  final VoidCallback onOpenList;
  final VoidCallback onOpenBulk;

  /// 파이프라인 단계 클릭 시 해당 상태로 필터링된 목록을 연다.
  final void Function(String status) onOpenStatus;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final content = ResponsiveBuilder(
      builder: (context, size) {
        final hPad = size.isMobile ? 16.0 : 28.0;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, size.isMobile ? 16 : 24, hPad, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      summary: summary,
                      size: size,
                      onNewOrder: onNewOrder,
                      onOpenList: onOpenList,
                    ),
                    if (lookupError != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBar(message: lookupError!, onRetry: onRetry),
                    ],
                    const SizedBox(height: 22),
                    _PipelineSection(
                      summary: summary,
                      loading: loadingSummary,
                      onOpenStatus: onOpenStatus,
                    ),
                    const SizedBox(height: 26),
                    const _SectionLabel(eyebrow: 'QUICK ACCESS', title: '바로가기'),
                    const SizedBox(height: 14),
                    _ActionGrid(
                      size: size,
                      onNewOrder: onNewOrder,
                      onOpenList: onOpenList,
                      onOpenBulk: onOpenBulk,
                      onOpenStatus: () => onOpenStatus(''),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (reduceMotion) return content;
    // 진입 시 한 번만 부드럽게 페이드/슬라이드 인.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: content,
    );
  }
}

// ── 디자인 토큰 (관제 콘솔 팔레트) ────────────────────────────────
class _Ink {
  static const navy = Color(0xFF0E1B2B); // 히어로 베이스
  static const navy2 = Color(0xFF16365C); // 히어로 그라데이션 끝
  static const slate = Color(0xFF64748B); // 대기 단계
  static const blue = Color(0xFF2563EB); // 진행/배차 단계
  static const amber = Color(0xFFF59E0B); // 운송중(라이브)
  static const teal = Color(0xFF0E9F6E); // 배송완료
  static const green = Color(0xFF047857); // 정산완료
  static const rose = Color(0xFFE11D48); // 취소
}

/// 오더 생애주기(취소 제외) 순서. 파이프라인의 골격.
const List<String> _lifecycle = [
  'draft',
  'confirmed',
  'planned',
  'tendered',
  'assigned',
  'in_transit',
  'delivered',
  'completed',
];

Color _stageColor(String status) {
  switch (status) {
    case 'draft':
    case 'confirmed':
      return _Ink.slate;
    case 'planned':
    case 'tendered':
    case 'assigned':
      return _Ink.blue;
    case 'in_transit':
      return _Ink.amber;
    case 'delivered':
      return _Ink.teal;
    case 'completed':
      return _Ink.green;
    case 'cancelled':
      return _Ink.rose;
    default:
      return _Ink.slate;
  }
}

// ── 숫자 포맷 ───────────────────────────────────────────────────
String _grouped(num n) {
  final s = n.round().abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _compactWon(num n) {
  if (n >= 100000000) {
    final v = n / 100000000;
    return '₩${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}억';
  }
  if (n >= 10000) return '₩${_grouped((n / 10000).round())}만';
  return '₩${_grouped(n)}';
}

const _tabular = [FontFeature.tabularFigures()];

// ── 히어로 밴드 ─────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({
    required this.summary,
    required this.size,
    required this.onNewOrder,
    required this.onOpenList,
  });

  final OrderSummary? summary;
  final ScreenSize size;
  final VoidCallback onNewOrder;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final inProgress = s?.sumOf(const ['planned', 'tendered', 'assigned', 'in_transit']);
    final kpis = <_HeroKpi>[
      _HeroKpi('전체 오더', s == null ? '—' : _grouped(s.total)),
      _HeroKpi('진행 중', inProgress == null ? '—' : _grouped(inProgress), accent: _Ink.amber),
      _HeroKpi('오늘 등록', s == null ? '—' : _grouped(s.today)),
      _HeroKpi('당월 매출', s == null ? '—' : _compactWon(s.monthRevenue)),
    ];

    final header = _heroHeader(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Ink.navy, _Ink.navy2],
        ),
        boxShadow: [
          BoxShadow(
            color: _Ink.navy.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 우상단의 은은한 광원으로 평면적인 네이비에 깊이를 준다.
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Ink.blue.withValues(alpha: 0.35),
                    _Ink.blue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size.isMobile ? 22 : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                SizedBox(height: size.isMobile ? 22 : 26),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                SizedBox(height: size.isMobile ? 18 : 22),
                _HeroKpiRow(kpis: kpis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _Ink.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ORDER MANAGEMENT · 운송 오더',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '오더 생성',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '운송 오더를 등록하고 파이프라인 전 단계를 관리합니다.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onNewOrder,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('오더 등록'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _Ink.navy,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onOpenList,
          icon: const Icon(Icons.list_alt_rounded, size: 18),
          label: const Text('오더 목록'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );

    if (size.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 20), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 20),
        actions,
      ],
    );
  }
}

class _HeroKpi {
  const _HeroKpi(this.label, this.value, {this.accent});
  final String label;
  final String value;
  final Color? accent;
}

class _HeroKpiRow extends StatelessWidget {
  const _HeroKpiRow({required this.kpis});
  final List<_HeroKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 560;
      final perRow = narrow ? 2 : kpis.length;
      const gap = 1.0;
      // 좁은 화면에서는 2열로 감싸고, 넓은 화면에서는 한 줄에 구분선과 함께 배치.
      if (narrow) {
        return Wrap(
          children: [
            for (var i = 0; i < kpis.length; i++)
              SizedBox(
                width: (c.maxWidth - 16) / perRow,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: i < kpis.length - perRow ? 18 : 0,
                  ),
                  child: _HeroKpiCell(kpis[i]),
                ),
              ),
          ],
        );
      }
      final children = <Widget>[];
      for (var i = 0; i < kpis.length; i++) {
        children.add(Expanded(child: _HeroKpiCell(kpis[i])));
        if (i < kpis.length - 1) {
          children.add(Container(
            width: gap,
            height: 38,
            color: Colors.white.withValues(alpha: 0.12),
          ));
        }
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
    });
  }
}

class _HeroKpiCell extends StatelessWidget {
  const _HeroKpiCell(this.kpi);
  final _HeroKpi kpi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kpi.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          kpi.value,
          style: TextStyle(
            color: kpi.accent ?? Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: _tabular,
          ),
        ),
      ],
    );
  }
}

// ── 파이프라인 (시그니처) ──────────────────────────────────────────
class _PipelineSection extends StatelessWidget {
  const _PipelineSection({
    required this.summary,
    required this.loading,
    required this.onOpenStatus,
  });

  final OrderSummary? summary;
  final bool loading;
  final void Function(String status) onOpenStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled = summary?.count('cancelled') ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel(eyebrow: 'PIPELINE', title: '오더 파이프라인', dense: true),
              const Spacer(),
              if (loading && summary == null)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                )
              else if (cancelled > 0)
                _CancelledChip(count: cancelled, onTap: () => onOpenStatus('cancelled')),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _lifecycle.length; i++) ...[
                  _PipelineNode(
                    status: _lifecycle[i],
                    count: summary?.count(_lifecycle[i]),
                    onTap: () => onOpenStatus(_lifecycle[i]),
                  ),
                  if (i < _lifecycle.length - 1) const _PipelineConnector(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineNode extends StatefulWidget {
  const _PipelineNode({required this.status, required this.count, required this.onTap});
  final String status;
  final int? count;
  final VoidCallback onTap;

  @override
  State<_PipelineNode> createState() => _PipelineNodeState();
}

class _PipelineNodeState extends State<_PipelineNode> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _stageColor(widget.status);
    final label = OrderEnums.statusLabel(widget.status);
    final active = (widget.count ?? 0) > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 118,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: _hover ? color.withValues(alpha: 0.06) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? color.withValues(alpha: 0.55) : scheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? color : color.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.count == null ? '—' : _grouped(widget.count!),
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.0,
                  fontFeatures: _tabular,
                  color: active ? color : scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 10),
              // 단계 색을 담은 진행 바. 건수가 있을 때만 채워진다.
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: active ? color : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineConnector extends StatelessWidget {
  const _PipelineConnector();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: SizedBox(
        width: 26,
        child: Row(
          children: [
            Expanded(child: Container(height: 1.5, color: scheme.outlineVariant)),
            Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _CancelledChip extends StatelessWidget {
  const _CancelledChip({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _Ink.rose.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Ink.rose.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_outlined, size: 14, color: _Ink.rose),
            const SizedBox(width: 6),
            Text(
              '취소 ${_grouped(count)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _Ink.rose,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 바로가기 액션 그리드 ─────────────────────────────────────────
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.size,
    required this.onNewOrder,
    required this.onOpenList,
    required this.onOpenBulk,
    required this.onOpenStatus,
  });

  final ScreenSize size;
  final VoidCallback onNewOrder;
  final VoidCallback onOpenList;
  final VoidCallback onOpenBulk;
  final VoidCallback onOpenStatus;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      // 액션 타일은 브랜드 블루 단색으로 통일한다. 색상 의미는 파이프라인이 전담하고,
      // 타일은 글리프로만 구분해 콘솔다운 절제된 인상을 준다.
      _ActionTile(
        icon: Icons.add_box_outlined,
        accent: _Ink.blue,
        title: '오더 등록',
        subtitle: '운송 주문을 신규 등록합니다',
        onTap: onNewOrder,
      ),
      _ActionTile(
        icon: Icons.manage_search_outlined,
        accent: _Ink.blue,
        title: '오더 목록 / 검색',
        subtitle: '등록된 오더를 조회·수정합니다',
        onTap: onOpenList,
      ),
      _ActionTile(
        icon: Icons.upload_file_outlined,
        accent: _Ink.blue,
        title: '오더 일괄 업로드',
        subtitle: 'CSV 로 여러 오더를 한 번에 등록',
        onTap: onOpenBulk,
      ),
      _ActionTile(
        icon: Icons.timeline_outlined,
        accent: _Ink.blue,
        title: '오더 상태 관리',
        subtitle: '상태별 조회 및 전이 처리',
        onTap: onOpenStatus,
      ),
    ];

    final cols = switch (size) {
      ScreenSize.desktop => 4,
      ScreenSize.tablet => 2,
      ScreenSize.mobile => 1,
    };
    final ratio = switch (size) {
      ScreenSize.desktop => 1.42,
      ScreenSize.tablet => 2.3,
      ScreenSize.mobile => 2.9,
    };

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: ratio,
      children: tiles,
    );
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? widget.accent.withValues(alpha: 0.5) : scheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? widget.accent.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hover ? 22 : 10,
                offset: Offset(0, _hover ? 10 : 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 23),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _hover ? widget.accent : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: _hover ? Colors.white : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 공용 소품 ───────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.eyebrow, required this.title, this.dense = false});
  final String eyebrow;
  final String title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: scheme.primary.withValues(alpha: 0.75),
          ),
        ),
        SizedBox(height: dense ? 2 : 4),
        Text(
          title,
          style: TextStyle(
            fontSize: dense ? 17 : 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
