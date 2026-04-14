import 'package:flutter/material.dart';

/// Dashboard layout matching the Spendly mock: light gray canvas, white cards,
/// total spending + week bars, grouped transaction rows, FAB.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onSignOut,
  });

  final String? userName;
  final String userEmail;
  final Future<void> Function() onSignOut;

  static const _bg = Color(0xFFF2F2F2);
  static const _muted = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add expense — coming soon')),
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    _WorkspaceChip(
                      label: 'Personal',
                      onTap: () {},
                    ),
                    const Spacer(),
                    _IconCluster(
                      onSearch: () {},
                      onMenu: () {},
                      onSettings: () => _showSettingsMenu(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TotalSpendingCard(textTheme: textTheme),
                    const SizedBox(height: 20),
                    Text(
                      'Latest',
                      style: textTheme.labelLarge?.copyWith(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TransactionGroupCard(
                      children: const [
                        _TransactionRowData(
                          icon: Icons.music_note_rounded,
                          iconBg: Color(0xFF1DB954),
                          title: 'Spotify',
                          date: '10 Mar 2026',
                          amount: '\$20.98',
                        ),
                        _TransactionRowData(
                          icon: Icons.restaurant_rounded,
                          iconBg: Color(0xFFFF6B35),
                          title: 'Groceries',
                          date: '10 Mar 2026',
                          amount: '\$56.80',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Monday',
                      style: textTheme.labelLarge?.copyWith(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TransactionGroupCard(
                      children: const [
                        _TransactionRowData(
                          icon: Icons.directions_car_rounded,
                          iconBg: Color(0xFF000000),
                          title: 'Uber',
                          date: '9 Mar 2026',
                          amount: '\$26.40',
                        ),
                        _TransactionRowData(
                          icon: Icons.restaurant_rounded,
                          iconBg: Color(0xFFE85D04),
                          title: 'Dining out',
                          date: '9 Mar 2026',
                          amount: '\$16.20',
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(userName?.trim().isNotEmpty == true ? userName! : userEmail),
              subtitle: Text(userEmail, style: const TextStyle(color: _muted, fontSize: 13)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () => Navigator.pop(ctx, 'signOut'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'signOut') await onSignOut();
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCluster extends StatelessWidget {
  const _IconCluster({
    required this.onSearch,
    required this.onMenu,
    required this.onSettings,
  });

  final VoidCallback onSearch;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconButton(icon: Icons.search_rounded, onPressed: onSearch),
          _RoundIconButton(icon: Icons.menu_rounded, onPressed: onMenu),
          _RoundIconButton(icon: Icons.settings_outlined, onPressed: onSettings),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}

class _TotalSpendingCard extends StatelessWidget {
  const _TotalSpendingCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spending',
            style: textTheme.bodyMedium?.copyWith(
              color: HomeScreen._muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$120.38',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            height: 140,
            child: _WeekSpendingBars(),
          ),
        ],
      ),
    );
  }
}

/// Sun–Sat bars; only Mon + Tue visible (mock), grid 0–80.
class _WeekSpendingBars extends StatelessWidget {
  const _WeekSpendingBars();

  static const _labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  // Heights 0–80 scale
  static const _values = [0.0, 22.0, 68.0, 0.0, 0.0, 0.0, 0.0];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _BarChartPainter(values: _values, labels: _labels),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const maxY = 80.0;
    final chartBottom = size.height - 22;
    final chartTop = 8.0;
    final chartH = chartBottom - chartTop;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1;

    for (final y in [0, 20, 40, 60, 80]) {
      final t = y / maxY;
      final py = chartBottom - t * chartH;
      canvas.drawLine(Offset(28, py), Offset(size.width, py), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '$y',
          style: const TextStyle(fontSize: 10, color: HomeScreen._muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, py - tp.height / 2));
    }

    final n = values.length;
    final slotW = (size.width - 28) / n;
    final barW = slotW * 0.45;

    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, maxY);
      final h = (v / maxY) * chartH;
      final cx = 28 + i * slotW + slotW / 2;
      final left = cx - barW / 2;
      final top = chartBottom - h;

      if (v > 0) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barW, h),
          const Radius.circular(4),
        );
        canvas.drawRRect(r, Paint()..color = Colors.black);
      }

      final lp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 11, color: HomeScreen._muted, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(cx - lp.width / 2, chartBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TransactionRowData {
  const _TransactionRowData({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.date,
    required this.amount,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String date;
  final String amount;
}

class _TransactionGroupCard extends StatelessWidget {
  const _TransactionGroupCard({required this.children});

  final List<_TransactionRowData> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            _TransactionRow(data: children[i]),
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.data});

  final _TransactionRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  data.date,
                  style: const TextStyle(color: HomeScreen._muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            data.amount,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
