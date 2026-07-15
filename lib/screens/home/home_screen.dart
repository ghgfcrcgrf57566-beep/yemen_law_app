import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/law.dart';
import '../../data/repositories/laws_repository.dart';
import '../law_detail/law_detail_screen.dart';
import 'widgets/law_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = LawsRepository.instance;
  final _searchController = TextEditingController();

  List<Law> _allLaws = [];
  List<Law> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  Future<void> _load() async {
    final laws = await _repo.getAllLaws();
    setState(() {
      _allLaws = laws;
      _filtered = laws;
      _loading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allLaws;
      } else {
        _filtered = _allLaws
            .where((law) =>
                law.name.contains(query) ||
                (law.shortName?.contains(query) ?? false))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('موسوعة القوانين اليمنية'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'ابحث عن قانون...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final law = _filtered[index];
                              return LawCard(
                                law: law,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LawDetailScreen(law: law),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('لا توجد نتائج مطابقة', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
