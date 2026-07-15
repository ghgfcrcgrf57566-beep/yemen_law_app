import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/law.dart';
import '../../data/models/bab.dart';
import '../../data/models/fasl.dart';
import '../../data/models/madda.dart';
import '../../data/repositories/laws_repository.dart';
import '../article/article_list_screen.dart';
import '../article/article_detail_screen.dart';
import 'widgets/section_tile.dart';

/// شاشة عرض تفاصيل قانون: تعمل بشكل عام (Generic) لعرض أي مستوى من
/// مستويات التقسيم الهرمي (كتاب/قسم/باب) عبر تمرير [bab] الحالي، أو
/// عرض المستوى الجذري للقانون عند تركه فارغًا (null).
class LawDetailScreen extends StatefulWidget {
  final Law law;
  final Bab? bab;

  const LawDetailScreen({super.key, required this.law, this.bab});

  @override
  State<LawDetailScreen> createState() => _LawDetailScreenState();
}

class _LawDetailScreenState extends State<LawDetailScreen> {
  final _repo = LawsRepository.instance;

  List<Bab> _subAbwab = [];
  List<Fasl> _fusul = [];
  List<Madda> _mawad = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bab = widget.bab;
    if (bab == null) {
      final subAbwab = await _repo.getAbwab(widget.law.id);
      final rootMawad = await _repo.getRootMawad(widget.law.id);
      setState(() {
        _subAbwab = subAbwab;
        _fusul = [];
        _mawad = rootMawad;
        _loading = false;
      });
    } else {
      final subAbwab = await _repo.getAbwab(widget.law.id, parentBabId: bab.id);
      final fusul = await _repo.getFusul(bab.id);
      final mawad = await _repo.getMawadByBab(bab.id);
      setState(() {
        _subAbwab = subAbwab;
        _fusul = fusul;
        _mawad = mawad;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bab?.displayName ?? widget.law.name;
    final isEmpty = _subAbwab.isEmpty && _fusul.isEmpty && _mawad.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? const Center(child: Text('لا يوجد محتوى', style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    if (widget.bab == null) _LawHeader(law: widget.law),
                    ..._subAbwab.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SectionTile(
                            icon: Icons.folder_outlined,
                            title: b.displayName,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LawDetailScreen(law: widget.law, bab: b),
                              ),
                            ),
                          ),
                        )),
                    ..._fusul.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SectionTile(
                            icon: Icons.article_outlined,
                            title: f.displayName,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ArticleListScreen(law: widget.law, fasl: f),
                              ),
                            ),
                          ),
                        )),
                    if (_mawad.isNotEmpty) ...[
                      if (_subAbwab.isNotEmpty || _fusul.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
                      ..._mawad.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SectionTile(
                              icon: Icons.description_outlined,
                              title: 'مادة (${m.number})',
                              subtitle: m.body,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ArticleDetailScreen(maddaId: m.id),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
    );
  }
}

class _LawHeader extends StatelessWidget {
  final Law law;
  const _LawHeader({required this.law});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${law.articlesCount} مادة قانونية',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
