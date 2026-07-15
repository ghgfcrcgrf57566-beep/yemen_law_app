import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/models/madda.dart';
import '../../data/repositories/laws_repository.dart';
import '../../providers/favorites_provider.dart';

class ArticleDetailScreen extends StatefulWidget {
  final int maddaId;
  const ArticleDetailScreen({super.key, required this.maddaId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final _repo = LawsRepository.instance;
  Madda? _madda;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final madda = await _repo.getMaddaById(widget.maddaId);
    if (!mounted) return;
    setState(() {
      _madda = madda;
      _loading = false;
    });
    await context.read<FavoritesProvider>().ensureLoaded();
  }

  void _copy() {
    final madda = _madda;
    if (madda == null) return;
    Clipboard.setData(ClipboardData(text: madda.shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نص المادة')),
    );
  }

  void _share() {
    final madda = _madda;
    if (madda == null) return;
    Share.share(madda.shareText);
  }

  @override
  Widget build(BuildContext context) {
    final madda = _madda;
    final favorites = context.watch<FavoritesProvider>();
    final isFav = madda != null && favorites.isFavorite(madda.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(madda == null ? '' : 'مادة (${madda.number})'),
        actions: madda == null
            ? null
            : [
                IconButton(
                  icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_outline),
                  tooltip: 'إضافة للمفضلة',
                  onPressed: () => context.read<FavoritesProvider>().toggle(madda),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'نسخ',
                  onPressed: _copy,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'مشاركة',
                  onPressed: _share,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : madda == null
              ? const Center(child: Text('تعذر إيجاد المادة'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Breadcrumb(madda: madda),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'مادة (${madda.number})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              madda.body,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16.5,
                                height: 1.9,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final Madda madda;
  const _Breadcrumb({required this.madda});

  @override
  Widget build(BuildContext context) {
    final parts = [madda.lawName, madda.babLabel, madda.faslLabel]
        .where((e) => e != null && e.isNotEmpty)
        .toList();
    return Text(
      parts.join(' • '),
      textAlign: TextAlign.right,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
    );
  }
}
