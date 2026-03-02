import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/rest_api_service.dart';

// This widget was added as the new REST-driven side drawer.
// Focuses on categories, conversations, and transcript segments.
class SidePanel extends StatefulWidget {
  const SidePanel({
    super.key,
    required this.api,
  });

// Injected service instead of costructing it inside the widget
// so that the widget is easier to test and stays consistent with other dependencies.
  final RestApiService api;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  List<Category> _categories = [];
  List<Conversation> _conversations = [];
  List<ConversationVector> _vectors = [];

  Category? _selectedCategory;
  Conversation? _selectedConversation;

// Separate loading states were added so only the relevant section
// shows loading, instead of blanking out the whole drawer.
  bool _loadingCategories = false;
  bool _loadingConversations = false;
  bool _loadingVectors = false;

// Separate errors per section for more useful debugging and UX.
  String? _categoryError;
  String? _conversationError;
  String? _vectorError;

// Inline category creation UI.
  bool _showNewCategoryField = false;
  final _newCatController = TextEditingController();
  bool _creatingCategory = false;
  String? _createCategoryError;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadConversations();
  }

  @override
  void dispose() {
    _newCatController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });

    try {
      final cats = await widget.api.getCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _categoryError = 'Could not load categories — $e');
    } finally {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  Future<void> _loadConversations({int? categoryId}) async {
    setState(() {
      _loadingConversations = true;
      _conversationError = null;

      // Changing category clears selected conversation
      // and transcript segments because they may no longer match. (possible for change)
      _selectedConversation = null;
      _vectors = [];
      _vectorError = null;
    });

    try {
      final convs = await widget.api.getConversations(categoryId: categoryId);
      if (!mounted) return;
      setState(() => _conversations = convs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _conversationError = 'Could not load conversations — $e');
    } finally {
      if (mounted) {
        setState(() => _loadingConversations = false);
      }
    }
  }

  Future<void> _loadVectors(int conversationId) async {
    setState(() {
      _loadingVectors = true;
      _vectorError = null;
      _vectors = [];
    });

    try {
      final vecs = await widget.api.getVectors(conversationId);
      if (!mounted) return;
      setState(() => _vectors = vecs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _vectorError = 'Could not load transcripts — $e');
    } finally {
      if (mounted) {
        setState(() => _loadingVectors = false);
      }
    }
  }

  Future<void> _submitNewCategory() async {
    final name = _newCatController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _creatingCategory = true;
      _createCategoryError = null;
    });

    try {
      await widget.api.createCategory(name);
      if (!mounted) return;
      _newCatController.clear();
      setState(() => _showNewCategoryField = false);

      // After creating a new category, reload categories so the chip list updates.
      await _loadCategories();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _createCategoryError =
            e.statusCode == 409 ? '"$name" already exists' : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _createCategoryError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _creatingCategory = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    // These ids are preserved so refresh can store the selected conversations
    // instead of losing transcript context unnecessarily.
    final selectedCategoryId = _selectedCategory?.id;
    final selectedConversationId = _selectedConversation?.id;

    await _loadCategories();
    await _loadConversations(categoryId: selectedCategoryId);

    if (!mounted) return;

    if (selectedConversationId != null) {
      final restoredConversation =
          _conversations.cast<Conversation?>().firstWhere(
                (conversation) => conversation?.id == selectedConversationId,
                orElse: () => null,
              );

      if (restoredConversation != null) {
        setState(() {
          _selectedConversation = restoredConversation;
        });
        await _loadVectors(selectedConversationId);
      }
    }
  }

  void _selectCategory(Category? cat) {
    setState(() => _selectedCategory = cat);
    _loadConversations(categoryId: cat?.id);
  }

  void _selectConversation(Conversation conv) {
    // Tapping the selected conversation again collapses the transcript section.
    if (_selectedConversation?.id == conv.id) {
      setState(() {
        _selectedConversation = null;
        _vectors = [];
      });
    } else {
      setState(() => _selectedConversation = conv);
      _loadVectors(conv.id);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.day}.${local.month}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Focuses only on relevant data, could possibly add counts if needed/wanted
                    _buildSectionLabel('Categories'),
                    _buildCategoryChips(),
                    _buildNewCategoryRow(),
                    const Divider(height: 24),
                    _buildSectionLabel('Conversations'),
                    _buildConversationList(),
                    if (_selectedConversation != null) ...[
                      const Divider(height: 24),
                      _buildSectionLabel('Transcripts'),
                      _buildVectorList(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00239D),
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Refresh button added so that the drawer can re-fetch backend data
          // without needing to fully close/reopen it.
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed:
                (_loadingCategories || _loadingConversations || _loadingVectors)
                    ? null
                    : _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_categoryError != null) {
      return _ErrorRow(
        message: _categoryError!,
        onRetry: _loadCategories,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // "All" chip added so the user can clear category filtering.
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedCategory == null,
              onSelected: (_) => _selectCategory(null),
            ),
          ),
          ..._categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(cat.name),
                selected: _selectedCategory?.id == cat.id,
                onSelected: (_) => _selectCategory(cat),
              ),
            ),
          ),
          // "New" action chip added to open the inline category creation form.
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('New'),
            onPressed: () => setState(
              () => _showNewCategoryField = !_showNewCategoryField,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewCategoryRow() {
    if (!_showNewCategoryField) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCatController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Category name',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _submitNewCategory(),
                ),
              ),
              const SizedBox(width: 8),
              _creatingCategory
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.check,
                        color: Color(0xFF00239D),
                      ),
                      tooltip: 'Create',
                      onPressed: _submitNewCategory,
                    ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Cancel',
                onPressed: () => setState(() {
                  _showNewCategoryField = false;
                  _newCatController.clear();
                  _createCategoryError = null;
                }),
              ),
            ],
          ),
          if (_createCategoryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _createCategoryError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (_loadingConversations) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_conversationError != null) {
      return _ErrorRow(
        message: _conversationError!,
        onRetry: () => _loadConversations(categoryId: _selectedCategory?.id),
      );
    }

    if (_conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'No conversations yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _conversations.map((conv) {
        final isSelected = _selectedConversation?.id == conv.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              selected: isSelected,
              // Highlight added so the selected conversation is visually obvious.
              selectedTileColor:
                  const Color(0xFF00239D).withValues(alpha: 0.08),
              leading: Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: isSelected ? const Color(0xFF00239D) : Colors.grey[600],
              ),
              title: Text(
                conv.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                _formatDate(conv.timestamp),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: Icon(
                isSelected ? Icons.expand_less : Icons.chevron_right,
                size: 18,
              ),
              onTap: () => _selectConversation(conv),
            ),
            // Conversation summary shown only for the currently selected item
            // to keep the list compact.
            if (isSelected && conv.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                child: Text(
                  conv.summary,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildVectorList() {
    if (_loadingVectors) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vectorError != null) {
      return _ErrorRow(
        message: _vectorError!,
        onRetry: () => _loadVectors(_selectedConversation!.id),
      );
    }

    if (_vectors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No transcript segments for this conversation.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return Column(
      children: _vectors.asMap().entries.map((entry) {
        final vec = entry.value;
        final i = entry.key;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segment numbering added for easier reading/debugging.
                Text(
                  'Segment ${i + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  vec.text,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
