import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class ManageItemsSheet extends ConsumerStatefulWidget {
  final String title;
  final String itemLabel; // e.g. "Category", "Payment Source"
  final String hintText;  // e.g. "Source name (e.g. Cash)"
  final List<String> items;

  final Future<void> Function(String name) onAdd;
  final Future<void> Function(String name) onDelete;
  final Future<void> Function(String oldName, String newName) onUpdate;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  const ManageItemsSheet({
    super.key,
    required this.title,
    required this.itemLabel,
    required this.hintText,
    required this.items,
    required this.onAdd,
    required this.onDelete,
    required this.onUpdate,
    required this.onReorder,
  });

  @override
  ConsumerState<ManageItemsSheet> createState() => _ManageItemsSheetState();
}

class _ManageItemsSheetState extends ConsumerState<ManageItemsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _editingItemName;
  bool _isReordering = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isReordering ? Icons.grid_view_rounded : Icons.swap_vert_rounded,
                      color: _isReordering ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _isReordering = !_isReordering;
                        _editingItemName = null;
                        _controller.clear();
                        _focusNode.unfocus();
                      });
                    },
                    tooltip: _isReordering ? 'Grid View' : 'Reorder Items',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isReordering
                ? 'REORDER ${widget.itemLabel.toUpperCase()}S (DRAG TO SORT)'
                : 'ACTIVE ${widget.itemLabel.toUpperCase()}S (TAP TO EDIT, \'X\' TO DELETE)',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No custom ${widget.itemLabel.toLowerCase()}s active. Add one below!',
                style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
              ),
            )
          else if (_isReordering)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ReorderableListView(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) async {
                  await widget.onReorder(oldIndex, newIndex);
                },
                children: [
                  for (int index = 0; index < widget.items.length; index++)
                    ListTile(
                      key: ValueKey(widget.items[index]),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      tileColor: TallyTapTheme.obsidianCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                      ),
                      leading: const Icon(Icons.drag_handle_rounded, color: TallyTapTheme.primaryMint, size: 20),
                      title: Text(
                        widget.items[index],
                        style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      trailing: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        height: 24,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: TallyTapTheme.textGray, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: widget.items.map((item) {
                    final isEditingThis = _editingItemName == item;
                    return InputChip(
                      label: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isEditingThis ? TallyTapTheme.obsidianBg : TallyTapTheme.textLight,
                        ),
                      ),
                      backgroundColor: isEditingThis ? TallyTapTheme.primaryMint : TallyTapTheme.obsidianCard,
                      selectedColor: TallyTapTheme.primaryMint,
                      checkmarkColor: TallyTapTheme.obsidianBg,
                      onPressed: () {
                        setState(() {
                          _editingItemName = item;
                          _controller.text = item;
                          _focusNode.requestFocus();
                        });
                      },
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        color: isEditingThis ? TallyTapTheme.obsidianBg : TallyTapTheme.primaryMint,
                        size: 14,
                      ),
                      onDeleted: () async {
                        if (_editingItemName == item) {
                          setState(() {
                            _editingItemName = null;
                            _controller.clear();
                            _focusNode.unfocus();
                          });
                        }
                        await widget.onDelete(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted ${widget.itemLabel.toLowerCase()}: $item'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(
                          color: isEditingThis ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                          width: 0.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (!_isReordering) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editingItemName != null
                      ? 'RENAME "$_editingItemName"'
                      : 'ADD NEW ${widget.itemLabel.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: TallyTapTheme.textGray,
                  ),
                ),
                if (_editingItemName != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _editingItemName = null;
                        _controller.clear();
                        _focusNode.unfocus();
                      });
                    },
                    child: const Text(
                      'CANCEL EDIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _editingItemName != null
                          ? 'New name for $_editingItemName'
                          : widget.hintText,
                      hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                      filled: true,
                      fillColor: TallyTapTheme.obsidianCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;

                    if (_editingItemName != null) {
                      final oldName = _editingItemName!;
                      if (text != oldName) {
                        await widget.onUpdate(oldName, text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Renamed "$oldName" to "$text"'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                      setState(() {
                        _editingItemName = null;
                        _controller.clear();
                        _focusNode.unfocus();
                      });
                    } else {
                      await widget.onAdd(text);
                      _controller.clear();
                      _focusNode.unfocus();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${widget.itemLabel.toLowerCase()}: $text'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    _editingItemName != null
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_rounded,
                    color: TallyTapTheme.primaryMint,
                    size: 36,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
