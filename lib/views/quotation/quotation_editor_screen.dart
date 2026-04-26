import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/quotation_model.dart';
import '../../utils/pdf_helper.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/notification_service.dart';

class QuotationEditorScreen extends StatefulWidget {
  final Quotation? quotation;
  const QuotationEditorScreen({super.key, this.quotation});

  @override
  State<QuotationEditorScreen> createState() => _QuotationEditorScreenState();
}

class _QuotationEditorScreenState extends State<QuotationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _id;
  late TextEditingController _quoteNoController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientAddressController;
  late TextEditingController _clientPhoneController;
  late DateTime _selectedDate;
  List<QuotationItem> _items = [];
  TextEditingController? _transportationController;
  TextEditingController? _gstValueController;
  TextEditingController? _additionalCostLabelController;
  TextEditingController? _additionalCostValueController;
  DateTime? _reminderDate;

  double _gstValue = 18.0;
  bool _isGstPercentage = true;
  bool _showGst = true;

  double _transportation = 0;
  bool _isTransportationPercentage = false;
  bool _showTransportation = true;

  String _additionalCostLabel = "";
  double _additionalCostValue = 0;

  @override
  void initState() {
    super.initState();
    if (widget.quotation != null) {
      _id = widget.quotation!.id;
      _quoteNoController = TextEditingController(
        text: widget.quotation!.quoteNumber,
      );
      _clientNameController = TextEditingController(
        text: widget.quotation!.clientName,
      );
      _clientAddressController = TextEditingController(
        text: widget.quotation!.clientAddress,
      );
      _clientPhoneController = TextEditingController(
        text: widget.quotation!.clientPhone,
      );
      _selectedDate = widget.quotation!.date;
      _items = List.from(widget.quotation!.items);
      _gstValue = widget.quotation!.gstValue;
      _isGstPercentage = widget.quotation!.isGstPercentage;
      _showGst = widget.quotation!.showGst;
      _transportation = widget.quotation!.transportationValue;
      _isTransportationPercentage =
          widget.quotation!.isTransportationPercentage;
      _showTransportation = widget.quotation!.showTransportation;
      _additionalCostLabel = widget.quotation!.additionalCostLabel;
      _additionalCostValue = widget.quotation!.additionalCostValue;
      _reminderDate = widget.quotation!.reminderDate;
    } else {
      _id = const Uuid().v4();
      _quoteNoController = TextEditingController(
        text: "QT-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}",
      );
      _clientNameController = TextEditingController();
      _clientAddressController = TextEditingController();
      _clientPhoneController = TextEditingController();
      _selectedDate = DateTime.now();
      _items = [];
    }
    _transportationController = TextEditingController(
      text: _transportation.toString(),
    );
  }

  @override
  void dispose() {
    _quoteNoController.dispose();
    _clientNameController.dispose();
    _clientAddressController.dispose();
    _clientPhoneController.dispose();
    _transportationController?.dispose();
    _gstValueController?.dispose();
    _additionalCostLabelController?.dispose();
    _additionalCostValueController?.dispose();
    super.dispose();
  }

  double get _subTotal => _items.fold(0, (sum, item) => sum + item.totalValue);

  double get _transportationAmount {
    if (!_showTransportation) return 0;
    return _isTransportationPercentage
        ? _subTotal * (_transportation / 100)
        : _transportation;
  }

  double get _gstAmount {
    if (!_showGst) return 0;
    return _isGstPercentage
        ? (_subTotal + _transportationAmount + _additionalCostValue) *
              (_gstValue / 100)
        : _gstValue;
  }

  double get _grandTotal =>
      _subTotal + _transportationAmount + _additionalCostValue + _gstAmount;

  void _addItem() {
    setState(() {
      _items.add(
        QuotationItem(
          basicInfo: {'Description': 'New Item', 'Code': '', 'Location': ''},
        ),
      );
    });
  }

  void _editItem(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedItemEditor(
          item: _items[index],
          onSave: (updatedItem) {
            setState(() {
              _items[index] = updatedItem;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveQuote() async {
    if (_formKey.currentState!.validate()) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')),
        );
        return;
      }

      final quote = Quotation(
        id: _id,
        quoteNumber: _quoteNoController.text,
        clientName: _clientNameController.text,
        clientAddress: _clientAddressController.text,
        clientPhone: _clientPhoneController.text,
        date: _selectedDate,
        items: _items,
        gstValue: _gstValue,
        isGstPercentage: _isGstPercentage,
        showGst: _showGst,
        transportationValue: _transportation,
        isTransportationPercentage: _isTransportationPercentage,
        showTransportation: _showTransportation,
        additionalCostLabel: _additionalCostLabelController?.text ?? "",
        additionalCostValue: _additionalCostValue,
        reminderDate: _reminderDate,
      );

      await context.read<QuotationController>().saveQuotation(quote);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation saved and synced')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _scheduleReminder() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime scheduledDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (scheduledDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a future time')),
          );
          return;
        }

        await NotificationService().scheduleNotification(
          id: _id.hashCode,
          title: 'Quotation Follow-up',
          body:
              'Follow up with ${_clientNameController.text} for quote ${_quoteNoController.text}',
          scheduledDate: scheduledDateTime,
        );

        setState(() {
          _reminderDate = scheduledDateTime;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reminder set for ${DateFormat('MMM d, h:mm a').format(scheduledDateTime)}',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _shareQuotation() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final settings = context.read<QuotationController>().settings;
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set up Business Settings first')),
      );
      return;
    }

    try {
      final pdfData = await PdfHelper.generateQuotation(
        Quotation(
          id: _id,
          quoteNumber: _quoteNoController.text,
          clientName: _clientNameController.text,
          clientAddress: _clientAddressController.text,
          clientPhone: _clientPhoneController.text,
          date: _selectedDate,
          items: _items,
          gstValue: _gstValue,
          isGstPercentage: _isGstPercentage,
          showGst: _showGst,
          transportationValue: _transportation,
          isTransportationPercentage: _isTransportationPercentage,
          showTransportation: _showTransportation,
          additionalCostLabel: _additionalCostLabelController?.text ?? "",
          additionalCostValue: _additionalCostValue,
          reminderDate: _reminderDate,
        ),
        settings,
      );

      final tempDir = await getTemporaryDirectory();
      final filePath =
          "${tempDir.path}/${_quoteNoController.text.replaceAll('/', '_')}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Quotation for ${_clientNameController.text}',
        subject: 'Quotation ${_quoteNoController.text}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          widget.quotation == null ? 'New Quotation' : 'Edit Quotation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: _items.isEmpty
                ? null
                : () async {
                    final settings = context
                        .read<QuotationController>()
                        .settings;
                    if (settings == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please set up Business Settings first',
                          ),
                        ),
                      );
                      return;
                    }
                    final pdfData = await PdfHelper.generateQuotation(
                      Quotation(
                        id: _id,
                        quoteNumber: _quoteNoController.text,
                        clientName: _clientNameController.text,
                        clientAddress: _clientAddressController.text,
                        clientPhone: _clientPhoneController.text,
                        date: _selectedDate,
                        items: _items,
                        gstValue: _gstValue,
                        isGstPercentage: _isGstPercentage,
                        showGst: _showGst,
                        transportationValue: _transportation,
                        isTransportationPercentage: _isTransportationPercentage,
                        showTransportation: _showTransportation,
                        additionalCostLabel:
                            _additionalCostLabelController?.text ?? "",
                        additionalCostValue: _additionalCostValue,
                        reminderDate: _reminderDate,
                      ),
                      settings,
                    );
                    await Printing.layoutPdf(onLayout: (_) => pdfData);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFF6A11CB)),
            onPressed: _saveQuote,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Client Details'),
              _buildTextField('Quote Number', _quoteNoController),
              _buildTextField('Client Name', _clientNameController),
              _buildTextField(
                'Client Address',
                _clientAddressController,
                maxLines: 2,
              ),
              _buildTextField('Client Phone', _clientPhoneController),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Items'),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              ..._items.asMap().entries.map(
                (entry) => _buildItemCard(entry.key, entry.value),
              ),

              const SizedBox(height: 30),
              _buildSectionTitle('Summary'),
              _buildSummaryCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildItemCard(int index, QuotationItem item) {
    return Dismissible(
      key: Key(item.id),
      onDismissed: (_) {
        setState(() => _items.removeAt(index));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            onTap: () => _editItem(index),
            leading: item.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(item.images.first),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported),
                  ),
            title: Text(
              item.displayName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              item.basicInfo.entries
                  .where((e) => e.key.toLowerCase() != 'description')
                  .map((e) => "${e.key}: ${e.value}")
                  .take(2)
                  .join(" | "),
            ),
            trailing: Text(
              "₹${item.totalValue.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6A11CB),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _summaryRow("Sub Total", _subTotal),
          const Divider(height: 30),

          // Transportation Row
          Row(
            children: [
              Checkbox(
                value: _showTransportation,
                onChanged: (val) =>
                    setState(() => _showTransportation = val ?? true),
              ),
              Expanded(
                child: Text(
                  "Transportation",
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
              if (_showTransportation) ...[
                _buildModeToggle(
                  isPercentage: _isTransportationPercentage,
                  onChanged: (val) =>
                      setState(() => _isTransportationPercentage = val),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      prefixText: _isTransportationPercentage ? "% " : "₹",
                    ),
                    onChanged: (val) => setState(
                      () => _transportation = double.tryParse(val) ?? 0,
                    ),
                    controller: _transportationController ??=
                        TextEditingController(text: _transportation.toString()),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Additional Cost Row
          Row(
            children: [
              const SizedBox(width: 48), // Match checkbox width
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Extra Cost Label (e.g. Installation)",
                    hintStyle: TextStyle(fontSize: 12),
                    isDense: true,
                  ),
                  onChanged: (val) => _additionalCostLabel = val,
                  controller: _additionalCostLabelController ??=
                      TextEditingController(text: _additionalCostLabel),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    prefixText: "₹",
                    isDense: true,
                  ),
                  onChanged: (val) => setState(
                    () => _additionalCostValue = double.tryParse(val) ?? 0,
                  ),
                  controller: _additionalCostValueController ??=
                      TextEditingController(
                        text: _additionalCostValue.toString(),
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // GST Row
          Row(
            children: [
              Checkbox(
                value: _showGst,
                onChanged: (val) => setState(() => _showGst = val ?? true),
              ),
              Expanded(
                child: Text(
                  "GST",
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
              if (_showGst) ...[
                _buildModeToggle(
                  isPercentage: _isGstPercentage,
                  onChanged: (val) => setState(() => _isGstPercentage = val),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      prefixText: _isGstPercentage ? "% " : "₹",
                    ),
                    onChanged: (val) => setState(
                      () => _gstValue = double.tryParse(val) ?? 18.0,
                    ),
                    controller: _gstValueController ??= TextEditingController(
                      text: _gstValue.toString(),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (_showTransportation)
            _summaryRow(
              "Transportation Amount",
              _transportationAmount,
              isSmall: true,
            ),
          if (_showGst) _summaryRow("GST Amount", _gstAmount, isSmall: true),

          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Grand Total",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "₹${_grandTotal.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF6A11CB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scheduleReminder,
              icon: const Icon(Icons.notifications_active),
              label: const Text("Notify Me"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareQuotation,
              icon: const Icon(Icons.share),
              label: const Text("Share to WhatsApp"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle({
    required bool isPercentage,
    required Function(bool) onChanged,
  }) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _modeButton("%", isPercentage, () => onChanged(true)),
          _modeButton("₹", !isPercentage, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6A11CB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isSmall = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmall ? 2 : 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: isSmall ? 12 : 14,
            ),
          ),
          Text(
            "₹${value.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              fontWeight: isSmall ? FontWeight.normal : FontWeight.w600,
              fontSize: isSmall ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class AdvancedItemEditor extends StatefulWidget {
  final QuotationItem item;
  final Function(QuotationItem) onSave;

  const AdvancedItemEditor({
    super.key,
    required this.item,
    required this.onSave,
  });

  @override
  State<AdvancedItemEditor> createState() => _AdvancedItemEditorState();
}

class _AdvancedItemEditorState extends State<AdvancedItemEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late QuotationItem _editingItem;

  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _rateController;
  late TextEditingController _qtyController;
  late TextEditingController _remarksController;

  // Dynamic controllers for basicInfo
  final List<TextEditingController> _basicKeyControllers = [];
  final List<TextEditingController> _basicValueControllers = [];

  // Dynamic controllers for specs
  final List<TextEditingController> _specKeyControllers = [];
  final List<TextEditingController> _specValueControllers = [];

  // Dynamic controllers for accessories
  final List<TextEditingController> _accKeyControllers = [];
  final List<TextEditingController> _accValueControllers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _editingItem = QuotationItem.fromJson(widget.item.toJson());

    _widthController = TextEditingController(
      text: _editingItem.width.toString(),
    );
    _heightController = TextEditingController(
      text: _editingItem.height.toString(),
    );
    _rateController = TextEditingController(
      text: _editingItem.ratePerSqFt.toString(),
    );
    _qtyController = TextEditingController(
      text: _editingItem.quantity.toString(),
    );
    _remarksController = TextEditingController(text: _editingItem.remarks);

    // Initialize basicInfo controllers
    _editingItem.basicInfo.forEach((key, value) {
      _basicKeyControllers.add(TextEditingController(text: key));
      _basicValueControllers.add(TextEditingController(text: value));
    });

    // Initialize spec controllers
    _editingItem.specs.forEach((key, value) {
      _specKeyControllers.add(TextEditingController(text: key));
      _specValueControllers.add(TextEditingController(text: value));
    });

    // Initialize accessory controllers
    _editingItem.accessories.forEach((key, value) {
      _accKeyControllers.add(TextEditingController(text: key));
      _accValueControllers.add(TextEditingController(text: value));
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _rateController.dispose();
    _qtyController.dispose();
    _remarksController.dispose();
    for (var c in _basicKeyControllers) c.dispose();
    for (var c in _basicValueControllers) c.dispose();
    for (var c in _specKeyControllers) c.dispose();
    for (var c in _specValueControllers) c.dispose();
    for (var c in _accKeyControllers) c.dispose();
    for (var c in _accValueControllers) c.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _syncState() {
    _editingItem.width = double.tryParse(_widthController.text) ?? 0;
    _editingItem.height = double.tryParse(_heightController.text) ?? 0;
    _editingItem.ratePerSqFt = double.tryParse(_rateController.text) ?? 0;
    _editingItem.quantity = double.tryParse(_qtyController.text) ?? 1;
    _editingItem.remarks = _remarksController.text;

    // Sync basicInfo
    _editingItem.basicInfo.clear();
    for (int i = 0; i < _basicKeyControllers.length; i++) {
      if (_basicKeyControllers[i].text.isNotEmpty) {
        _editingItem.basicInfo[_basicKeyControllers[i].text] =
            _basicValueControllers[i].text;
      }
    }

    // Sync specs
    _editingItem.specs.clear();
    for (int i = 0; i < _specKeyControllers.length; i++) {
      if (_specKeyControllers[i].text.isNotEmpty) {
        _editingItem.specs[_specKeyControllers[i].text] =
            _specValueControllers[i].text;
      }
    }

    // Sync accessories
    _editingItem.accessories.clear();
    for (int i = 0; i < _accKeyControllers.length; i++) {
      if (_accKeyControllers[i].text.isNotEmpty) {
        _editingItem.accessories[_accKeyControllers[i].text] =
            _accValueControllers[i].text;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Values'),
            Tab(text: 'Specs'),
            Tab(text: 'Accessories'),
            Tab(text: 'Images'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _syncState();
              widget.onSave(_editingItem);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicTab(),
          _buildValuesTab(),
          _buildSpecsTab(),
          _buildAccessoriesTab(),
          _buildImagesTab(),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _basicKeyControllers.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _basicKeyControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Title',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _basicValueControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Data',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _basicKeyControllers[i].dispose();
                          _basicValueControllers[i].dispose();
                          _basicKeyControllers.removeAt(i);
                          _basicValueControllers.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _basicKeyControllers.add(TextEditingController());
                _basicValueControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Detail'),
          ),
        ],
      ),
    );
  }

  Widget _buildValuesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _editorField(
            'Width (ft)',
            _widthController,
            type: TextInputType.number,
          ),
          _editorField(
            'Height (ft)',
            _heightController,
            type: TextInputType.number,
          ),
          _editorField(
            'Rate per SqFt',
            _rateController,
            type: TextInputType.number,
          ),
          _editorField('Quantity', _qtyController, type: TextInputType.number),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Value:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '₹${_calculatePreviewValue().toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculatePreviewValue() {
    double w = double.tryParse(_widthController.text) ?? 0;
    double h = double.tryParse(_heightController.text) ?? 0;
    double r = double.tryParse(_rateController.text) ?? 0;
    double q = double.tryParse(_qtyController.text) ?? 1;
    return (w * h * r) * q;
  }

  Widget _buildSpecsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _specKeyControllers.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _specKeyControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Spec Title',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _specValueControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Data',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _specKeyControllers[i].dispose();
                          _specValueControllers[i].dispose();
                          _specKeyControllers.removeAt(i);
                          _specValueControllers.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _specKeyControllers.add(TextEditingController());
                _specValueControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Specification'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _accKeyControllers.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _accKeyControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Accessory',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _accValueControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Details',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _accKeyControllers[i].dispose();
                          _accValueControllers[i].dispose();
                          _accKeyControllers.removeAt(i);
                          _accValueControllers.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _accKeyControllers.add(TextEditingController());
                _accValueControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Accessory'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _editingItem.images.length,
              itemBuilder: (context, i) => Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_editingItem.images[i]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _editingItem.images.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final image = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (image != null)
                setState(() => _editingItem.images.add(image.path));
            },
            icon: const Icon(Icons.upload),
            label: const Text('Upload Image'),
          ),
        ],
      ),
    );
  }

  Widget _editorField(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
