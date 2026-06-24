import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/quotation_model.dart';
import '../../models/employee_model.dart';
import '../../models/material_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/pdf_helper.dart';

class MyQuotationsBillsScreen extends StatefulWidget {
  const MyQuotationsBillsScreen({super.key});

  @override
  State<MyQuotationsBillsScreen> createState() =>
      _MyQuotationsBillsScreenState();
}

class _MyQuotationsBillsScreenState extends State<MyQuotationsBillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Quotations', 'Bills'

  @override
  void initState() {
    super.initState();
    // Auto-refresh from Google Drive on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuotationController>(context, listen: false).syncWithDrive();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quoteController = Provider.of<QuotationController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Quotations & Bills',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          if (quoteController.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3F51B5),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
              onPressed: () async {
                await quoteController.syncWithDrive();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sync completed successfully'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by client or quote number...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 10),
                _buildFilterChip('Quotations'),
                const SizedBox(width: 10),
                _buildFilterChip('Bills'),
              ],
            ),
          ),

          // Combined List
          Expanded(
            child: Consumer<QuotationController>(
              builder: (context, quoteController, _) {
                final allItems = [
                  ...quoteController.quotations,
                  ...quoteController.bills,
                ];

                // Sort by date descending
                allItems.sort((a, b) => b.date.compareTo(a.date));

                final filteredItems = allItems.where((item) {
                  final query = _searchController.text.toLowerCase();
                  final matchesSearch =
                      item.clientName.toLowerCase().contains(query) ||
                      item.quoteNumber.toLowerCase().contains(query);

                  bool matchesCategory = true;
                  if (_selectedFilter == 'Quotations') {
                    matchesCategory = !item.isBill;
                  } else if (_selectedFilter == 'Bills') {
                    matchesCategory = item.isBill;
                  }

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: FadeIn(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'No quotations or bills found',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return FadeInUp(
                      duration: Duration(
                        milliseconds: 200 + (index * 50).clamp(0, 300),
                      ),
                      child: _buildListItem(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterName) {
    final isSelected = _selectedFilter == filterName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F51B5) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
          border: isSelected ? null : Border.all(color: Colors.grey[200]!),
        ),
        child: Text(
          filterName,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(Quotation item) {
    final formattedDate = DateFormat('dd MMM yyyy').format(item.date);
    final isBill = item.isBill;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBill
              ? [
                  const Color.fromARGB(255, 41, 32, 219),
                  const Color.fromARGB(255, 30, 131, 179),
                ] // Green to light blue
              : [
                  const Color(0xFF6A11CB),
                  const Color(0xFF2575FC),
                ], // Purple to blue
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isBill ? const Color(0xFF10B981) : const Color(0xFF6A11CB))
                .withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      QuotationBillDetailsScreen(quotation: item),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Icon/Badge + Client Name + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Icon Badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBill ? Icons.receipt_long : Icons.description,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 12),
                      // Client Name and Document Type Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.clientName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Badge indicating Quotation or Bill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isBill ? 'BILL' : 'QUOTATION',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${item.grandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Grand Total',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: item.status == 'completed'
                                  ? Colors.green.shade600.withOpacity(0.85)
                                  : item.status == 'processing'
                                  ? Colors.amber.shade700.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: Colors.white.withOpacity(0.15),
                      height: 1,
                      thickness: 1,
                    ),
                  ),

                  // Row 2: Details & View Details Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sub details (Quote ID & Date)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quote Number & Date
                            Row(
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 13,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.quoteNumber,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            if (item.startDate != null ||
                                item.endDate != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.startDate != null ? DateFormat('dd MMM').format(item.startDate!) : '-'} to ${item.endDate != null ? DateFormat('dd MMM yyyy').format(item.endDate!) : '-'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Work Log Badge & View Details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.workLogs.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.engineering,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.workLogs.length} Log(s)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 11,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuotationBillDetailsScreen extends StatefulWidget {
  final Quotation quotation;
  const QuotationBillDetailsScreen({super.key, required this.quotation});

  @override
  State<QuotationBillDetailsScreen> createState() =>
      _QuotationBillDetailsScreenState();
}

class _QuotationBillDetailsScreenState
    extends State<QuotationBillDetailsScreen> {
  late Quotation _currentQuotation;
  final Set<String> _selectedMaterialIds = {};

  @override
  void initState() {
    super.initState();
    _currentQuotation = widget.quotation;
  }

  void _showAddWorkLogSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    List<String> selectedImages = [];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add Work Assignment Log',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Employee Name
                      Text(
                        'Assigned Employee Name',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameController,
                        enabled: !isSaving,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter employee name',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF3F51B5),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter employee name';
                          }
                          return null;
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final quoteCtrl = Provider.of<QuotationController>(
                            context,
                            listen: false,
                          );
                          final List<Employee> onboardedEmployees =
                              quoteCtrl.employees;
                          if (onboardedEmployees.isEmpty)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Select Onboarded Employee:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 38,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: onboardedEmployees.length,
                                    itemBuilder: (context, idx) {
                                      final emp = onboardedEmployees[idx];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ActionChip(
                                          label: Text(
                                            emp.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor:
                                              Colors.indigo.shade50,
                                          side: BorderSide(
                                            color: Colors.indigo.shade200,
                                          ),
                                          onPressed: isSaving
                                              ? null
                                              : () {
                                                  setModalState(() {
                                                    nameController.text =
                                                        emp.name;
                                                  });
                                                },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Date Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assignment Date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(selectedDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (pickedDate != null) {
                                      setModalState(() {
                                        selectedDate = pickedDate;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Pick Date'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF3F51B5),
                              elevation: 0,
                              side: BorderSide(color: Colors.grey[200]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Work Images
                      Text(
                        'Work Images',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedImages.isNotEmpty)
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, idx) {
                              final imgPath = selectedImages[idx];
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: FileImage(File(imgPath)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (!isSaving)
                                    Positioned(
                                      top: 2,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            selectedImages.removeAt(idx);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final img = await ImagePicker().pickImage(
                                        source: ImageSource.camera,
                                      );
                                      if (img != null) {
                                        setModalState(() {
                                          selectedImages.add(img.path);
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final img = await ImagePicker().pickImage(
                                        source: ImageSource.gallery,
                                      );
                                      if (img != null) {
                                        setModalState(() {
                                          selectedImages.add(img.path);
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setModalState(() {
                                          isSaving = true;
                                        });

                                        final newLog = WorkLog(
                                          id: const Uuid().v4(),
                                          employeeName: nameController.text
                                              .trim(),
                                          date: selectedDate,
                                          images: selectedImages,
                                        );

                                        final updatedLogs = List<WorkLog>.from(
                                          _currentQuotation.workLogs,
                                        )..add(newLog);

                                        final updatedQuotation = Quotation(
                                          id: _currentQuotation.id,
                                          quoteNumber:
                                              _currentQuotation.quoteNumber,
                                          clientName:
                                              _currentQuotation.clientName,
                                          clientAddress:
                                              _currentQuotation.clientAddress,
                                          clientPhone:
                                              _currentQuotation.clientPhone,
                                          date: _currentQuotation.date,
                                          items: _currentQuotation.items,
                                          gstValue: _currentQuotation.gstValue,
                                          isGstPercentage:
                                              _currentQuotation.isGstPercentage,
                                          showGst: _currentQuotation.showGst,
                                          transportationValue: _currentQuotation
                                              .transportationValue,
                                          isTransportationPercentage:
                                              _currentQuotation
                                                  .isTransportationPercentage,
                                          showTransportation: _currentQuotation
                                              .showTransportation,
                                          additionalCostLabel: _currentQuotation
                                              .additionalCostLabel,
                                          additionalCostValue: _currentQuotation
                                              .additionalCostValue,
                                          additionalClientDetails:
                                              _currentQuotation
                                                  .additionalClientDetails,
                                          summaryExtras:
                                              _currentQuotation.summaryExtras,
                                          reminderDates:
                                              _currentQuotation.reminderDates,
                                          isBill: _currentQuotation.isBill,
                                          adjustment:
                                              _currentQuotation.adjustment,
                                          workLogs: updatedLogs,
                                          materials:
                                              _currentQuotation.materials,
                                          startDate:
                                              _currentQuotation.startDate,
                                          endDate: _currentQuotation.endDate,
                                          status: _currentQuotation.status,
                                        );

                                        setState(() {
                                          _currentQuotation = updatedQuotation;
                                        });

                                        final quoteController =
                                            Provider.of<QuotationController>(
                                              context,
                                              listen: false,
                                            );
                                        if (_currentQuotation.isBill) {
                                          await quoteController.saveBill(
                                            updatedQuotation,
                                          );
                                        } else {
                                          await quoteController.saveQuotation(
                                            updatedQuotation,
                                          );
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Work assignment logged successfully',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F51B5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Save Log',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatWhatsAppPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '91$clean';
    }
    return clean;
  }

  void _showShareWorkLogSheet(WorkLog log) {
    bool shareName = true;
    bool shareDate = true;
    final formattedDate = DateFormat('dd MMM yyyy').format(log.date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Share Work Assignment',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the details to share with the client:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Checkbox: Employee Name
                  CheckboxListTile(
                    title: Text(
                      'Employee Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      log.employeeName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: shareName,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setModalState(() {
                        shareName = val ?? false;
                      });
                    },
                  ),

                  // Checkbox: Assignment Date
                  CheckboxListTile(
                    title: Text(
                      'Assignment Date',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: shareDate,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setModalState(() {
                        shareDate = val ?? false;
                      });
                    },
                  ),

                  // Fixed Checkbox: Images (if present)
                  if (log.images.isNotEmpty) ...[
                    const Divider(height: 20),
                    CheckboxListTile(
                      title: Text(
                        'Include Work Images',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${log.images.length} image(s) will be attached',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: true,
                      onChanged: null, // Fixed to true
                      activeColor: Colors.indigo,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: log.images.length,
                        itemBuilder: (context, imgIdx) {
                          final imgPath = log.images[imgIdx];
                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                              image: DecorationImage(
                                image: FileImage(File(imgPath)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (log.images.isNotEmpty)
                    Text(
                      'ℹ️ Note: WhatsApp does not allow direct image attachments via links. Use "Share Text & Images" to attach images automatically, or "Direct WhatsApp" to send text and attach images manually inside WhatsApp.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      'ℹ️ Note: This will open WhatsApp directly to the client\'s number with the message.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (log.images.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);

                          String text = '*Work Assignment Update*\n';
                          text += '------------------------\n';
                          text += '*Client:* ${_currentQuotation.clientName}\n';
                          if (_currentQuotation.isBill) {
                            text +=
                                '*Bill No:* ${_currentQuotation.quoteNumber}\n';
                          } else {
                            text +=
                                '*Quote No:* ${_currentQuotation.quoteNumber}\n';
                          }
                          if (shareName) {
                            text += '*Assigned Person:* ${log.employeeName}\n';
                          }
                          if (shareDate) {
                            text += '*Work Date:* $formattedDate\n';
                          }
                          text += '\n_Sent from Quotation Master_';

                          final phoneClean = _formatWhatsAppPhone(
                            _currentQuotation.clientPhone,
                          );
                          final encodedText = Uri.encodeComponent(text);
                          final whatsappUrl = Uri.parse(
                            'whatsapp://send?phone=$phoneClean&text=$encodedText',
                          );
                          final webUrl = Uri.parse(
                            'https://wa.me/$phoneClean?text=$encodedText',
                          );

                          try {
                            if (phoneClean.isNotEmpty &&
                                await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(whatsappUrl);
                            } else if (phoneClean.isNotEmpty &&
                                await canLaunchUrl(webUrl)) {
                              await launchUrl(webUrl);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open WhatsApp directly.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error opening WhatsApp: $e'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(
                          'Direct WhatsApp (Text Only)',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);

                          String text = '*Work Assignment Update*\n';
                          text += '------------------------\n';
                          text += '*Client:* ${_currentQuotation.clientName}\n';
                          if (_currentQuotation.isBill) {
                            text +=
                                '*Bill No:* ${_currentQuotation.quoteNumber}\n';
                          } else {
                            text +=
                                '*Quote No:* ${_currentQuotation.quoteNumber}\n';
                          }
                          if (shareName) {
                            text += '*Assigned Person:* ${log.employeeName}\n';
                          }
                          if (shareDate) {
                            text += '*Work Date:* $formattedDate\n';
                          }
                          text += '\n_Sent from Quotation Master_';

                          final xFiles = log.images
                              .map((p) => XFile(p))
                              .toList();
                          try {
                            await Share.shareXFiles(xFiles, text: text);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error sharing: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(
                          'Share Text & Images (System Share)',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);

                              String text = '*Work Assignment Update*\n';
                              text += '------------------------\n';
                              text +=
                                  '*Client:* ${_currentQuotation.clientName}\n';
                              if (_currentQuotation.isBill) {
                                text +=
                                    '*Bill No:* ${_currentQuotation.quoteNumber}\n';
                              } else {
                                text +=
                                    '*Quote No:* ${_currentQuotation.quoteNumber}\n';
                              }
                              if (shareName) {
                                text +=
                                    '*Assigned Person:* ${log.employeeName}\n';
                              }
                              if (shareDate) {
                                text += '*Work Date:* $formattedDate\n';
                              }
                              text += '\n_Sent from Quotation Master_';

                              final phoneClean = _formatWhatsAppPhone(
                                _currentQuotation.clientPhone,
                              );
                              final encodedText = Uri.encodeComponent(text);
                              final whatsappUrl = Uri.parse(
                                'whatsapp://send?phone=$phoneClean&text=$encodedText',
                              );
                              final webUrl = Uri.parse(
                                'https://wa.me/$phoneClean?text=$encodedText',
                              );

                              try {
                                if (phoneClean.isNotEmpty &&
                                    await canLaunchUrl(whatsappUrl)) {
                                  await launchUrl(whatsappUrl);
                                } else if (phoneClean.isNotEmpty &&
                                    await canLaunchUrl(webUrl)) {
                                  await launchUrl(webUrl);
                                } else {
                                  await Share.share(text);
                                }
                              } catch (e) {
                                await Share.share(text);
                              }
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: Text(
                              'Share',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteWorkLog(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Work Log',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this assignment log? This will also update Drive.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      final updatedLogs = List<WorkLog>.from(_currentQuotation.workLogs)
        ..removeAt(idx);

      final updatedQuotation = Quotation(
        id: _currentQuotation.id,
        quoteNumber: _currentQuotation.quoteNumber,
        clientName: _currentQuotation.clientName,
        clientAddress: _currentQuotation.clientAddress,
        clientPhone: _currentQuotation.clientPhone,
        date: _currentQuotation.date,
        items: _currentQuotation.items,
        gstValue: _currentQuotation.gstValue,
        isGstPercentage: _currentQuotation.isGstPercentage,
        showGst: _currentQuotation.showGst,
        transportationValue: _currentQuotation.transportationValue,
        isTransportationPercentage:
            _currentQuotation.isTransportationPercentage,
        showTransportation: _currentQuotation.showTransportation,
        additionalCostLabel: _currentQuotation.additionalCostLabel,
        additionalCostValue: _currentQuotation.additionalCostValue,
        additionalClientDetails: _currentQuotation.additionalClientDetails,
        summaryExtras: _currentQuotation.summaryExtras,
        reminderDates: _currentQuotation.reminderDates,
        isBill: _currentQuotation.isBill,
        adjustment: _currentQuotation.adjustment,
        workLogs: updatedLogs,
        materials: _currentQuotation.materials,
        startDate: _currentQuotation.startDate,
        endDate: _currentQuotation.endDate,
        status: _currentQuotation.status,
      );

      setState(() {
        _currentQuotation = updatedQuotation;
      });

      final quoteController = Provider.of<QuotationController>(
        context,
        listen: false,
      );
      if (_currentQuotation.isBill) {
        await quoteController.saveBill(updatedQuotation);
      } else {
        await quoteController.saveQuotation(updatedQuotation);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Work log deleted')));
      }
    }
  }

  void _showFullScreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: const Color(0xE6000000),
              ),
            ),
            InteractiveViewer(
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMaterialSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final sizeController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedImagePath;
    final List<TextEditingController> customKeyControllers = [];
    final List<TextEditingController> customValControllers = [];
    bool isSaving = false;
    DateTime? selectedPurchaseDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add Material Detail',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildModalTextField(
                        'Material Name',
                        nameController,
                        isSaving,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Please enter material name';
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              'Quantity',
                              quantityController,
                              isSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'Required';
                                if (double.tryParse(val) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              'Size / Spec',
                              sizeController,
                              isSaving,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'Required';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _buildModalTextField(
                        'Price per Unit (₹)',
                        priceController,
                        isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid';
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Purchase Date (Optional)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedPurchaseDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(selectedPurchaseDate!)
                                      : 'Not selected',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: selectedPurchaseDate != null
                                        ? Colors.black87
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (selectedPurchaseDate != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.red,
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          setModalState(() {
                                            selectedPurchaseDate = null;
                                          });
                                        },
                                ),
                              ElevatedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              selectedPurchaseDate ??
                                              DateTime.now(),
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365 * 5),
                                          ),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                        );
                                        if (pickedDate != null) {
                                          setModalState(() {
                                            selectedPurchaseDate = pickedDate;
                                          });
                                        }
                                      },
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: const Text('Pick Date'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF3F51B5),
                                  elevation: 0,
                                  side: BorderSide(color: Colors.grey[200]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Material Image',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedImagePath != null) ...[
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                                image: DecorationImage(
                                  image: FileImage(File(selectedImagePath!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (!isSaving)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedImagePath = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final img = await ImagePicker()
                                            .pickImage(
                                              source: ImageSource.camera,
                                            );
                                        if (img != null) {
                                          setModalState(() {
                                            selectedImagePath = img.path;
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final img = await ImagePicker()
                                            .pickImage(
                                              source: ImageSource.gallery,
                                            );
                                        if (img != null) {
                                          setModalState(() {
                                            selectedImagePath = img.path;
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Custom Details',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setModalState(() {
                                      customKeyControllers.add(
                                        TextEditingController(),
                                      );
                                      customValControllers.add(
                                        TextEditingController(),
                                      );
                                    });
                                  },
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.indigo,
                            ),
                            label: Text(
                              'Add Field',
                              style: GoogleFonts.poppins(
                                color: Colors.indigo,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customKeyControllers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: customKeyControllers.length,
                          itemBuilder: (context, idx) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: customKeyControllers[idx],
                                      enabled: !isSaving,
                                      style: GoogleFonts.poppins(fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: 'Label (e.g. Color)',
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: customValControllers[idx],
                                      enabled: !isSaving,
                                      style: GoogleFonts.poppins(fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: 'Value (e.g. Red)',
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            setModalState(() {
                                              customKeyControllers[idx]
                                                  .dispose();
                                              customValControllers[idx]
                                                  .dispose();
                                              customKeyControllers.removeAt(
                                                idx,
                                              );
                                              customValControllers.removeAt(
                                                idx,
                                              );
                                            });
                                          },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 30),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setModalState(() {
                                          isSaving = true;
                                        });

                                        final Map<String, dynamic>
                                        customFields = {};
                                        for (
                                          int i = 0;
                                          i < customKeyControllers.length;
                                          i++
                                        ) {
                                          final keyText =
                                              customKeyControllers[i].text
                                                  .trim();
                                          final valText =
                                              customValControllers[i].text
                                                  .trim();
                                          if (keyText.isNotEmpty) {
                                            customFields[keyText] = valText;
                                          }
                                        }

                                        final newMaterial = MaterialLog(
                                          id: const Uuid().v4(),
                                          quotationId: _currentQuotation.id,
                                          quoteNumber:
                                              _currentQuotation.quoteNumber,
                                          clientName:
                                              _currentQuotation.clientName,
                                          name: nameController.text.trim(),
                                          quantity:
                                              double.tryParse(
                                                quantityController.text,
                                              ) ??
                                              0.0,
                                          size: sizeController.text.trim(),
                                          price:
                                              double.tryParse(
                                                priceController.text,
                                              ) ??
                                              0.0,
                                          image: selectedImagePath,
                                          customFields: customFields,
                                          purchaseDate: selectedPurchaseDate,
                                        );

                                        final updatedMaterials =
                                            List<MaterialLog>.from(
                                              _currentQuotation.materials,
                                            )..add(newMaterial);

                                        final updatedQuotation = Quotation(
                                          id: _currentQuotation.id,
                                          quoteNumber:
                                              _currentQuotation.quoteNumber,
                                          clientName:
                                              _currentQuotation.clientName,
                                          clientAddress:
                                              _currentQuotation.clientAddress,
                                          clientPhone:
                                              _currentQuotation.clientPhone,
                                          date: _currentQuotation.date,
                                          items: _currentQuotation.items,
                                          gstValue: _currentQuotation.gstValue,
                                          isGstPercentage:
                                              _currentQuotation.isGstPercentage,
                                          showGst: _currentQuotation.showGst,
                                          transportationValue: _currentQuotation
                                              .transportationValue,
                                          isTransportationPercentage:
                                              _currentQuotation
                                                  .isTransportationPercentage,
                                          showTransportation: _currentQuotation
                                              .showTransportation,
                                          additionalCostLabel: _currentQuotation
                                              .additionalCostLabel,
                                          additionalCostValue: _currentQuotation
                                              .additionalCostValue,
                                          additionalClientDetails:
                                              _currentQuotation
                                                  .additionalClientDetails,
                                          summaryExtras:
                                              _currentQuotation.summaryExtras,
                                          reminderDates:
                                              _currentQuotation.reminderDates,
                                          isBill: _currentQuotation.isBill,
                                          adjustment:
                                              _currentQuotation.adjustment,
                                          workLogs: _currentQuotation.workLogs,
                                          startDate:
                                              _currentQuotation.startDate,
                                          endDate: _currentQuotation.endDate,
                                          status: _currentQuotation.status,
                                          materials: updatedMaterials,
                                        );

                                        setState(() {
                                          _currentQuotation = updatedQuotation;
                                        });

                                        final quoteController =
                                            Provider.of<QuotationController>(
                                              context,
                                              listen: false,
                                            );
                                        if (_currentQuotation.isBill) {
                                          await quoteController.saveBill(
                                            updatedQuotation,
                                          );
                                        } else {
                                          await quoteController.saveQuotation(
                                            updatedQuotation,
                                          );
                                        }

                                        for (var c in customKeyControllers)
                                          c.dispose();
                                        for (var c in customValControllers)
                                          c.dispose();

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Material details logged successfully',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F51B5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Save Log',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalTextField(
    String label,
    TextEditingController controller,
    bool isSaving, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !isSaving,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3F51B5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _deleteMaterial(int idx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Material Log',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this material log? This will also update Drive.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      final updatedMaterials = List<MaterialLog>.from(
        _currentQuotation.materials,
      )..removeAt(idx);

      final updatedQuotation = Quotation(
        id: _currentQuotation.id,
        quoteNumber: _currentQuotation.quoteNumber,
        clientName: _currentQuotation.clientName,
        clientAddress: _currentQuotation.clientAddress,
        clientPhone: _currentQuotation.clientPhone,
        date: _currentQuotation.date,
        items: _currentQuotation.items,
        gstValue: _currentQuotation.gstValue,
        isGstPercentage: _currentQuotation.isGstPercentage,
        showGst: _currentQuotation.showGst,
        transportationValue: _currentQuotation.transportationValue,
        isTransportationPercentage:
            _currentQuotation.isTransportationPercentage,
        showTransportation: _currentQuotation.showTransportation,
        additionalCostLabel: _currentQuotation.additionalCostLabel,
        additionalCostValue: _currentQuotation.additionalCostValue,
        additionalClientDetails: _currentQuotation.additionalClientDetails,
        summaryExtras: _currentQuotation.summaryExtras,
        reminderDates: _currentQuotation.reminderDates,
        isBill: _currentQuotation.isBill,
        adjustment: _currentQuotation.adjustment,
        workLogs: _currentQuotation.workLogs,
        startDate: _currentQuotation.startDate,
        endDate: _currentQuotation.endDate,
        status: _currentQuotation.status,
        materials: updatedMaterials,
      );

      setState(() {
        _currentQuotation = updatedQuotation;
      });

      final quoteController = Provider.of<QuotationController>(
        context,
        listen: false,
      );
      if (_currentQuotation.isBill) {
        await quoteController.saveBill(updatedQuotation);
      } else {
        await quoteController.saveQuotation(updatedQuotation);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Material log deleted')));
      }
    }
  }

  void _showShareMaterialSheet(MaterialLog mat, String clientPhone) {
    bool shareName = true;
    bool shareQty = true;
    bool shareSize = true;
    bool sharePrice = true;
    bool shareCustom = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Share Material Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the details to share with the client:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: Text(
                      'Material Name',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      mat.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: shareName,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setModalState(() => shareName = val ?? false),
                  ),

                  CheckboxListTile(
                    title: Text(
                      'Quantity',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      mat.quantity.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: shareQty,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setModalState(() => shareQty = val ?? false),
                  ),

                  CheckboxListTile(
                    title: Text(
                      'Size',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      mat.size,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: shareSize,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setModalState(() => shareSize = val ?? false),
                  ),

                  CheckboxListTile(
                    title: Text(
                      'Price',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      '₹${mat.price.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: sharePrice,
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) =>
                        setModalState(() => sharePrice = val ?? false),
                  ),

                  if (mat.customFields.isNotEmpty)
                    CheckboxListTile(
                      title: Text(
                        'Custom Details',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      value: shareCustom,
                      activeColor: Colors.indigo,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) =>
                          setModalState(() => shareCustom = val ?? false),
                    ),

                  if (mat.image != null && mat.image!.isNotEmpty) ...[
                    const Divider(height: 20),
                    ListTile(
                      leading: const Icon(Icons.image, color: Colors.indigo),
                      title: Text(
                        'Material Image Included',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Will be attached in System Share',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _shareMaterialsAsPdf([mat]);
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(
                        'Share as PDF',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);

                        String text = '*Material Details Update*\n';
                        text += '------------------------\n';
                        text += '*Client:* ${mat.clientName}\n';
                        text += '*Doc Ref:* ${mat.quoteNumber}\n';

                        if (shareName) text += '*Material Name:* ${mat.name}\n';
                        if (shareQty)
                          text +=
                              '*Quantity:* ${mat.quantity.toStringAsFixed(1)}\n';
                        if (shareSize) text += '*Size:* ${mat.size}\n';
                        if (sharePrice)
                          text += '*Price:* ₹${mat.price.toStringAsFixed(2)}\n';
                        if (mat.purchaseDate != null)
                          text +=
                              '*Purchase Date:* ${DateFormat('dd MMM yyyy').format(mat.purchaseDate!)}\n';

                        if (shareCustom && mat.customFields.isNotEmpty) {
                          text += '\n*Additional Info*:\n';
                          mat.customFields.forEach((key, value) {
                            text += '- $key: $value\n';
                          });
                        }
                        text += '\n_Sent from Quotation Master_';

                        final phoneClean = _formatWhatsAppPhone(clientPhone);

                        if (mat.image != null && mat.image!.isNotEmpty) {
                          final files = [XFile(mat.image!)];
                          try {
                            await Share.shareXFiles(files, text: text);
                          } catch (e) {
                            print('Sharing error: $e');
                          }
                        } else {
                          final encodedText = Uri.encodeComponent(text);
                          final whatsappUrl = Uri.parse(
                            'whatsapp://send?phone=$phoneClean&text=$encodedText',
                          );
                          final webUrl = Uri.parse(
                            'https://wa.me/$phoneClean?text=$encodedText',
                          );

                          try {
                            if (phoneClean.isNotEmpty &&
                                await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(whatsappUrl);
                            } else if (phoneClean.isNotEmpty &&
                                await canLaunchUrl(webUrl)) {
                              await launchUrl(webUrl);
                            } else {
                              await Share.share(text);
                            }
                          } catch (e) {
                            await Share.share(text);
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(
                        'Share Text (WhatsApp)',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _shareSelectedMaterials(List<MaterialLog> selectedMaterials) {
    if (selectedMaterials.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share Selected Materials',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to share ${selectedMaterials.length} selected materials:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _shareMaterialsAsPdf(selectedMaterials);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(
                    'Share as PDF Document',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _shareMaterialsAsText(selectedMaterials);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    'Share as WhatsApp Text',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareMaterialsAsPdf(List<MaterialLog> selectedMaterials) async {
    final settings = Provider.of<QuotationController>(
      context,
      listen: false,
    ).settings;
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set up Business Settings first')),
      );
      return;
    }

    try {
      final pdfData = await PdfHelper.generateMaterialsPdf(
        selectedMaterials,
        _currentQuotation,
        settings,
      );

      final tempDir = await getTemporaryDirectory();
      final String refName = _currentQuotation.quoteNumber.replaceAll('/', '_');
      final filePath = "${tempDir.path}/materials_${refName}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      final double totalCost = selectedMaterials.fold(
        0,
        (sum, m) => sum + (m.quantity * m.price),
      );
      String text = '*Material Details PDF*\n';
      text += '------------------------\n';
      text += '*Client:* ${_currentQuotation.clientName}\n';
      text += '*Doc Ref:* ${_currentQuotation.quoteNumber}\n';
      text += '*Total Materials:* ${selectedMaterials.length}\n';
      text += '*Calculated Total Price:* ₹${totalCost.toStringAsFixed(2)}\n';
      text += '\n_Sent from Quotation Master_';

      await Share.shareXFiles(
        [XFile(filePath)],
        text: text,
        subject: 'Material Details - ${_currentQuotation.clientName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating/sharing materials PDF: $e')),
        );
      }
    }
  }

  Future<void> _shareMaterialsAsText(
    List<MaterialLog> selectedMaterials,
  ) async {
    String text = '*Material Details Update*\n';
    text += '------------------------\n';
    text += '*Client:* ${_currentQuotation.clientName}\n';
    text += '*Doc Ref:* ${_currentQuotation.quoteNumber}\n\n';

    double totalCost = 0;
    for (int i = 0; i < selectedMaterials.length; i++) {
      final mat = selectedMaterials[i];
      final cost = mat.quantity * mat.price;
      totalCost += cost;

      text += '*${i + 1}. ${mat.name}*\n';
      if (mat.purchaseDate != null) {
        text +=
            '- Purchase Date: ${DateFormat('dd MMM yyyy').format(mat.purchaseDate!)}\n';
      }
      text += '- Size: ${mat.size}\n';
      text += '- Qty: ${mat.quantity.toStringAsFixed(1)}\n';
      text += '- Price: ₹${mat.price.toStringAsFixed(2)}\n';
      text += '- Total: ₹${cost.toStringAsFixed(2)}\n';
      if (mat.customFields.isNotEmpty) {
        mat.customFields.forEach((key, val) {
          text += '- $key: $val\n';
        });
      }
      text += '\n';
    }
    text += '------------------------\n';
    text += '*Calculated Total Price:* ₹${totalCost.toStringAsFixed(2)}\n';
    text += '\n_Sent from Quotation Master_';

    final phoneClean = _formatWhatsAppPhone(_currentQuotation.clientPhone);
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse(
      'whatsapp://send?phone=$phoneClean&text=$encodedText',
    );
    final webUrl = Uri.parse('https://wa.me/$phoneClean?text=$encodedText');

    try {
      if (phoneClean.isNotEmpty && await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else if (phoneClean.isNotEmpty && await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      } else {
        await Share.share(text);
      }
    } catch (e) {
      await Share.share(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuotationController>(
      builder: (context, quoteController, _) {
        final latest = _currentQuotation.isBill
            ? quoteController.bills.firstWhere(
                (b) => b.id == _currentQuotation.id,
                orElse: () => _currentQuotation,
              )
            : quoteController.quotations.firstWhere(
                (q) => q.id == _currentQuotation.id,
                orElse: () => _currentQuotation,
              );
        _currentQuotation = latest;

        final themeColor = _currentQuotation.isBill
            ? const Color(0xFF10B981)
            : const Color(0xFF6A11CB);
        final formattedDate = DateFormat(
          'dd MMM yyyy',
        ).format(_currentQuotation.date);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            title: Text(
              _currentQuotation.isBill ? 'Bill Details' : 'Quotation Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            actions: [
              if (quoteController.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3F51B5),
                      ),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
                  onPressed: () async {
                    await quoteController.syncWithDrive();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sync completed successfully'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                FadeInDown(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _currentQuotation.isBill
                            ? [
                                const Color.fromARGB(255, 15, 64, 156),
                                const Color(0xFF0EA5E9),
                              ]
                            : [
                                const Color(0xFF6A11CB),
                                const Color(0xFF2575FC),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            _currentQuotation.isBill
                                ? 'FINAL BILL'
                                : 'QUOTATION',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _currentQuotation.clientName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _currentQuotation.quoteNumber,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Schedule & Status Card
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildInfoCard(
                    title: 'Schedule & Status',
                    icon: Icons.calendar_today_outlined,
                    iconColor: themeColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Status',
                          _currentQuotation.status.toUpperCase(),
                          textColor: _currentQuotation.status == 'completed'
                              ? Colors.green[800]
                              : _currentQuotation.status == 'processing'
                              ? Colors.orange[800]
                              : Colors.grey[800],
                        ),
                        if (_currentQuotation.startDate != null)
                          _buildDetailRow(
                            'Start Date',
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(_currentQuotation.startDate!),
                          ),
                        if (_currentQuotation.endDate != null)
                          _buildDetailRow(
                            'End Date',
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(_currentQuotation.endDate!),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Client & Contact details Card
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildInfoCard(
                    title: 'Client Information',
                    icon: Icons.person_outline,
                    iconColor: themeColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Phone', _currentQuotation.clientPhone),
                        if (_currentQuotation.clientAddress.isNotEmpty)
                          _buildDetailRow(
                            'Address',
                            _currentQuotation.clientAddress,
                          ),
                        // Dynamic client details
                        ..._currentQuotation.additionalClientDetails.entries
                            .map((e) => _buildDetailRow(e.key, e.value)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Items Card
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildInfoCard(
                    title: 'Product Items',
                    icon: Icons.list_alt,
                    iconColor: themeColor,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentQuotation.items.length,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 20),
                      itemBuilder: (context, i) {
                        final item = _currentQuotation.items[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.displayName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '₹${item.totalValue.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.isUnitBased
                                  ? '${item.unitQuantity} ${item.itemUnit} @ ₹${item.unitRate}/${item.itemUnit}'
                                  : '${item.width} x ${item.height} ${item.areaUnit} | ${item.quantity} Pcs @ ₹${item.ratePerSqFt}/sq.ft',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (item.remarks.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Remarks: ${item.remarks}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Financial Summary Card
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildInfoCard(
                    title: 'Financial Summary',
                    icon: Icons.monetization_on_outlined,
                    iconColor: themeColor,
                    child: Column(
                      children: [
                        _buildSummaryPriceRow(
                          'Sub Total',
                          _currentQuotation.subTotal,
                        ),
                        if (_currentQuotation.showTransportation &&
                            _currentQuotation.transportationValue > 0)
                          _buildSummaryPriceRow(
                            'Transportation${_currentQuotation.isTransportationPercentage ? " (${_currentQuotation.transportationValue}%)" : ""}',
                            _currentQuotation.transportationAmount,
                          ),
                        if (_currentQuotation.additionalCostValue > 0)
                          _buildSummaryPriceRow(
                            _currentQuotation.additionalCostLabel.isNotEmpty
                                ? _currentQuotation.additionalCostLabel
                                : 'Additional Cost',
                            _currentQuotation.additionalCostValue,
                          ),
                        ..._currentQuotation.summaryExtras.entries.map(
                          (e) => _buildSummaryPriceRow(e.key, e.value),
                        ),
                        if (_currentQuotation.showGst)
                          _buildSummaryPriceRow(
                            'GST (${_currentQuotation.gstValue}%)',
                            _currentQuotation.gstAmount,
                          ),
                        if (_currentQuotation.adjustment != 0)
                          _buildSummaryPriceRow(
                            'Adjustment',
                            _currentQuotation.adjustment,
                          ),
                        const Divider(height: 25, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grand Total',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '₹${_currentQuotation.grandTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Work Assignments Logs Section
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_ind,
                                      color: Colors.indigo,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Work Assignments',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _showAddWorkLogSheet,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 25),
                        if (_currentQuotation.workLogs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No work assignments logged yet.',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _currentQuotation.workLogs.length,
                            separatorBuilder: (context, idx) =>
                                const Divider(height: 24),
                            itemBuilder: (context, idx) {
                              final log = _currentQuotation.workLogs[idx];
                              final logDate = DateFormat(
                                'dd MMM yyyy',
                              ).format(log.date);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.employeeName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              logDate,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.share_outlined,
                                              color: Colors.indigo,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _showShareWorkLogSheet(log),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _deleteWorkLog(idx),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (log.images.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 90,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: log.images.length,
                                        itemBuilder: (context, imgIdx) {
                                          final imgPath = log.images[imgIdx];
                                          return GestureDetector(
                                            onTap: () =>
                                                _showFullScreenImage(imgPath),
                                            child: Hero(
                                              tag: imgPath,
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  right: 10,
                                                ),
                                                width: 120,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.grey[200]!,
                                                  ),
                                                  image: DecorationImage(
                                                    image: FileImage(
                                                      File(imgPath),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Materials Logged Section
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.construction,
                                      color: Colors.teal,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Materials Logged',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_currentQuotation
                                            .materials
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Total Cost: ₹${_currentQuotation.materials.fold<double>(0, (sum, m) => sum + (m.quantity * m.price)).toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _showAddMaterialSheet,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 25),
                        if (_currentQuotation.materials.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedMaterialIds.length ==
                                        _currentQuotation.materials.length) {
                                      _selectedMaterialIds.clear();
                                    } else {
                                      _selectedMaterialIds.clear();
                                      _selectedMaterialIds.addAll(
                                        _currentQuotation.materials.map(
                                          (m) => m.id,
                                        ),
                                      );
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedMaterialIds.length ==
                                          _currentQuotation.materials.length
                                      ? Icons.deselect
                                      : Icons.select_all,
                                  size: 16,
                                  color: Colors.teal,
                                ),
                                label: Text(
                                  _selectedMaterialIds.length ==
                                          _currentQuotation.materials.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              if (_selectedMaterialIds.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _shareSelectedMaterials(
                                    _currentQuotation.materials
                                        .where(
                                          (m) => _selectedMaterialIds.contains(
                                            m.id,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  icon: const Icon(Icons.share, size: 14),
                                  label: Text(
                                    'Share Selected (${_selectedMaterialIds.length})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(height: 15),
                        ],
                        if (_currentQuotation.materials.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No material details logged yet.',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _currentQuotation.materials.length,
                            separatorBuilder: (context, idx) =>
                                const Divider(height: 24),
                            itemBuilder: (context, idx) {
                              final mat = _currentQuotation.materials[idx];

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8.0,
                                      right: 8.0,
                                    ),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _selectedMaterialIds.contains(
                                          mat.id,
                                        ),
                                        activeColor: Colors.teal,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedMaterialIds.add(mat.id);
                                            } else {
                                              _selectedMaterialIds.remove(
                                                mat.id,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    mat.name,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Size: ${mat.size}  |  Qty: ${mat.quantity.toStringAsFixed(1)}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Price: ₹${mat.price.toStringAsFixed(2)}  |  Total: ₹${(mat.quantity * mat.price).toStringAsFixed(2)}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.indigo,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (mat.purchaseDate !=
                                                      null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Purchase Date: ${DateFormat('dd MMM yyyy').format(mat.purchaseDate!)}',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .teal[700],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.share_outlined,
                                                    color: Colors.indigo,
                                                    size: 20,
                                                  ),
                                                  onPressed: () =>
                                                      _showShareMaterialSheet(
                                                        mat,
                                                        _currentQuotation
                                                            .clientPhone,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: () =>
                                                      _deleteMaterial(idx),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (mat.image != null &&
                                            mat.image!.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          GestureDetector(
                                            onTap: () => _showFullScreenImage(
                                              mat.image!,
                                            ),
                                            child: Container(
                                              width: 120,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.grey[200]!,
                                                ),
                                                image: DecorationImage(
                                                  image: FileImage(
                                                    File(mat.image!),
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (mat.customFields.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: mat.customFields.entries.map((
                                              entry,
                                            ) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.grey[200]!,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${entry.key}: ${entry.value}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textColor ?? Colors.black87,
                fontWeight: textColor != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPriceRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
