import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/material_model.dart';
import '../../models/quotation_model.dart';
import '../../utils/pdf_helper.dart';

class GlobalMaterialsScreen extends StatefulWidget {
  const GlobalMaterialsScreen({super.key});

  @override
  State<GlobalMaterialsScreen> createState() => _GlobalMaterialsScreenState();
}

class _GlobalMaterialsScreenState extends State<GlobalMaterialsScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

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

  String _formatWhatsAppPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '91$clean';
    }
    return clean;
  }

  void _showShareMaterialSheet(MaterialLog mat) {
    final quoteController = Provider.of<QuotationController>(
      context,
      listen: false,
    );
    Quotation? quotation;
    try {
      quotation = quoteController.quotations.firstWhere(
        (q) => q.id == mat.quotationId,
        orElse: () =>
            quoteController.bills.firstWhere((b) => b.id == mat.quotationId),
      );
    } catch (e) {
      // ignore
    }
    final clientPhone = quotation?.clientPhone ?? "";

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
                        if (quotation != null) {
                          await _shareMaterialsAsPdf([mat], quotation);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cannot generate PDF: Quotation reference not found',
                              ),
                            ),
                          );
                        }
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

                        // If has image, suggest system share
                        if (mat.image != null && mat.image!.isNotEmpty) {
                          final files = [XFile(mat.image!)];
                          try {
                            await Share.shareXFiles(files, text: text);
                          } catch (e) {
                            print('Sharing error: $e');
                          }
                        } else {
                          // Text only WhatsApp or Share
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

  Future<void> _shareMaterialsAsPdf(
    List<MaterialLog> selectedMaterials,
    Quotation quotation,
  ) async {
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
        quotation,
        settings,
      );

      final tempDir = await getTemporaryDirectory();
      final String refName = quotation.quoteNumber.replaceAll('/', '_');
      final filePath = "${tempDir.path}/materials_${refName}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      final double totalCost = selectedMaterials.fold(
        0,
        (sum, m) => sum + (m.quantity * m.price),
      );
      String text = '*Material Details PDF*\n';
      text += '------------------------\n';
      text += '*Client:* ${quotation.clientName}\n';
      text += '*Doc Ref:* ${quotation.quoteNumber}\n';
      text += '*Total Materials:* ${selectedMaterials.length}\n';
      text += '*Calculated Total Price:* ₹${totalCost.toStringAsFixed(2)}\n';
      text += '\n_Sent from Quotation Master_';

      await Share.shareXFiles(
        [XFile(filePath)],
        text: text,
        subject: 'Material Details - ${quotation.clientName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating/sharing materials PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteController = Provider.of<QuotationController>(context);
    final allMaterials = quoteController.allMaterials;

    final filteredList = allMaterials.where((mat) {
      final query = _searchQuery.toLowerCase();
      final nameMatches = mat.name.toLowerCase().contains(query);
      final clientMatches = mat.clientName.toLowerCase().contains(query);
      final docMatches = mat.quoteNumber.toLowerCase().contains(query);
      return nameMatches || clientMatches || docMatches;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          'Materials Master',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by material, client or quote/bill no...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Materials List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.construction_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching materials found'
                                : 'No materials logged yet',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Refine your search using different keywords.'
                                : 'Go to Quotation / Bill details screen, and log material assignments.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final mat = filteredList[index];
                      // Attempt to retrieve client phone to pass to share sheet
                      String clientPhone = "";
                      try {
                        final doc = quoteController.quotations.firstWhere(
                          (q) => q.id == mat.quotationId,
                          orElse: () => quoteController.bills.firstWhere(
                            (b) => b.id == mat.quotationId,
                          ),
                        );
                        clientPhone = doc.clientPhone;
                      } catch (e) {}

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Material Name, Size, Share Button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (mat.image != null &&
                                      mat.image!.isNotEmpty) ...[
                                    GestureDetector(
                                      onTap: () =>
                                          _showFullScreenImage(mat.image!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(mat.image!),
                                          width: 55,
                                          height: 55,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mat.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Size: ${mat.size.isNotEmpty ? mat.size : "N/A"}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (mat.purchaseDate != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Purchase Date: ${DateFormat('dd MMM yyyy').format(mat.purchaseDate!)}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.teal[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share,
                                      color: Colors.indigo,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showShareMaterialSheet(mat),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Row 2: Qty, Unit Price, Total
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Quantity',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        mat.quantity.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price / Unit',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '₹${mat.price.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Total Cost',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '₹${(mat.quantity * mat.price).toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF6A11CB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Row 3: Document details / client reference
                              Row(
                                children: [
                                  const Icon(
                                    Icons.assignment,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '${mat.quoteNumber} | ${mat.clientName}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              if (mat.customFields.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: mat.customFields.entries.map((
                                    entry,
                                  ) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
