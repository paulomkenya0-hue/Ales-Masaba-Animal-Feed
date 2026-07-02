import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings_sw.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';

/// CategoryManagementScreen - Super Admin anaongeza/anabadilisha jina/
/// anafuta Categories (hakuna kikomo cha idadi)
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCategories();
    });
  }

  Future<void> _showAddOrEditDialog({String? id, String? currentName}) async {
    final ctrl = TextEditingController(text: currentName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(id == null ? SW.newCategory : SW.categoryName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'mf. Pumba, Vitamini, Dawa'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(SW.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text(SW.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final provider = context.read<ProductProvider>();
    final ok = id == null ? (await provider.addCategory(name)) != null : await provider.updateCategory(id, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
      );
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final provider = context.read<ProductProvider>();
    final count = await provider.countProductsInCategory(id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${SW.deleteCategory}: $name'),
        content: Text(count > 0
            ? '$count ${SW.variantsCount}.\n${SW.categoryHasProducts}'
            : SW.confirmDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text(SW.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await provider.deleteCategory(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? SW.savedSuccess : SW.error)),
                );
              }
            },
            child: const Text(SW.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: const Text(SW.manageCategories)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showAddOrEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: categories.isEmpty
          ? const Center(child: Text(SW.noData))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final c = categories[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.category_outlined),
                    ),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showAddOrEditDialog(id: c.id, currentName: c.name),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () => _confirmDelete(c.id!, c.name),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
