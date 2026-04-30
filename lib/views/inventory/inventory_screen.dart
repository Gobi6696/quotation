import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../controllers/inventory_controller.dart';
import '../../models/quotation_model.dart';
import '../quotation/quotation_editor_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-sync from drive when opening inventory
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryController>(context, listen: false).syncFromDrive();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Master Inventory',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF6A11CB)),
            onPressed: () async {
              await inventory.syncFromDrive();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventory synced with Drive')),
                );
              }
            },
          ),
        ],
      ),
      body: inventory.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)))
          : inventory.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No items in inventory',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _addItem(context, inventory),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Your First Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: inventory.items.length,
                  itemBuilder: (context, index) {
                    final item = inventory.items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: item.images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(item.images.first),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[100],
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.image_outlined, color: Colors.grey),
                              ),
                        title: Text(
                          item.displayName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${item.isUnitBased ? "Unit Based" : "Area Based"} | ₹${item.isUnitBased ? item.unitRate : item.ratePerSqFt}',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                              onPressed: () => _editItem(context, item, inventory),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteConfirm(context, item, inventory),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context, inventory),
        label: Text('Add Item', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _addItem(BuildContext context, InventoryController controller) {
    final newItem = QuotationItem();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedItemEditor(
          item: newItem,
          onSave: (item) => controller.saveItem(item),
          isInventoryMode: true,
        ),
      ),
    );
  }

  void _editItem(BuildContext context, QuotationItem item, InventoryController controller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedItemEditor(
          item: item,
          onSave: (updatedItem) => controller.saveItem(updatedItem),
          isInventoryMode: true,
        ),
      ),
    );
  }

  void _deleteConfirm(BuildContext context, QuotationItem item, InventoryController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Item', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${item.displayName}" from inventory?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              controller.deleteItem(item.id);
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
