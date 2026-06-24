import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/quotation_model.dart';
import '../../models/material_model.dart';

import '../../utils/pdf_helper.dart';
import '../../utils/excel_helper.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/notification_service.dart';
import '../../controllers/inventory_controller.dart';

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
  late TextEditingController _adjustmentController;
  List<DateTime> _reminderDates = [];
  bool _isAdjustmentNegative = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'pending';
  List<WorkLog> _workLogs = [];
  late TextEditingController _advanceAmountController;
  List<PaymentRecord> _payments = [];
  DateTime? _advanceDate;

  double _gstValue = 18.0;
  bool _isGstPercentage = true;
  bool _showGst = true;

  double _transportation = 0;
  bool _isTransportationPercentage = false;
  bool _showTransportation = true;

  String _additionalCostLabel = "";
  double _additionalCostValue = 0;
  bool _isLoading = false;

  // Dynamic Client Details
  final List<TextEditingController> _clientDetailKeyControllers = [];
  final List<TextEditingController> _clientDetailValueControllers = [];

  // Dynamic Summary Extras
  final List<TextEditingController> _summaryExtraKeyControllers = [];
  final List<TextEditingController> _summaryExtraValueControllers = [];

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
      _reminderDates = List.from(widget.quotation!.reminderDates);
      _adjustmentController = TextEditingController(
        text: widget.quotation!.adjustment.abs().toString(),
      );
      _isAdjustmentNegative = widget.quotation!.adjustment < 0;
      _startDate = widget.quotation!.startDate;
      _endDate = widget.quotation!.endDate;
      _status = widget.quotation!.status;
      _workLogs = List.from(widget.quotation!.workLogs);
      _advanceAmountController = TextEditingController(
        text: widget.quotation!.advanceAmount.toString(),
      );
      _payments = List.from(widget.quotation!.payments);
      _advanceDate = widget.quotation!.advanceDate;
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
      _adjustmentController = TextEditingController(text: "0");
      _startDate = null;
      _endDate = null;
      _status = 'pending';
      _workLogs = [];
      _advanceAmountController = TextEditingController(text: "0.0");
      _payments = [];
      _advanceDate = null;
      _gstValue = Provider.of<QuotationController>(
        context,
        listen: false,
      ).defaultGstValue;
    }
    _transportationController = TextEditingController(
      text: _transportation.toString(),
    );

    // Initialize dynamic fields if editing
    if (widget.quotation != null) {
      widget.quotation!.additionalClientDetails.forEach((key, value) {
        _clientDetailKeyControllers.add(TextEditingController(text: key));
        _clientDetailValueControllers.add(TextEditingController(text: value));
      });
      widget.quotation!.summaryExtras.forEach((key, value) {
        _summaryExtraKeyControllers.add(TextEditingController(text: key));
        _summaryExtraValueControllers.add(
          TextEditingController(text: value.toString()),
        );
      });
    }
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
    _advanceAmountController.dispose();
    for (var c in _clientDetailKeyControllers) c.dispose();
    for (var c in _clientDetailValueControllers) c.dispose();
    for (var c in _summaryExtraKeyControllers) c.dispose();
    for (var c in _summaryExtraValueControllers) c.dispose();
    _adjustmentController.dispose();
    super.dispose();
  }

  double get _subTotal => _items.fold(0, (sum, item) => sum + item.totalValue);

  double get _transportationAmount {
    if (!_showTransportation) return 0;
    return _isTransportationPercentage
        ? _subTotal * (_transportation / 100)
        : _transportation;
  }

  double get _totalSummaryExtras {
    double total = 0;
    for (var controller in _summaryExtraValueControllers) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  double get _gstAmount {
    if (!_showGst) return 0;
    return _isGstPercentage
        ? (_subTotal +
                  _transportationAmount +
                  _additionalCostValue +
                  _totalSummaryExtras) *
              (_gstValue / 100)
        : _gstValue;
  }

  double get _grandTotal {
    double adj = double.tryParse(_adjustmentController.text) ?? 0;
    if (_isAdjustmentNegative) adj = -adj;
    return _subTotal +
        _transportationAmount +
        _additionalCostValue +
        _totalSummaryExtras +
        _gstAmount +
        adj;
  }

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

      setState(() => _isLoading = true);
      try {
        final Map<String, String> additionalClientDetails = {};
        for (int i = 0; i < _clientDetailKeyControllers.length; i++) {
          if (_clientDetailKeyControllers[i].text.isNotEmpty) {
            additionalClientDetails[_clientDetailKeyControllers[i].text] =
                _clientDetailValueControllers[i].text;
          }
        }

        final Map<String, double> summaryExtras = {};
        for (int i = 0; i < _summaryExtraKeyControllers.length; i++) {
          if (_summaryExtraKeyControllers[i].text.isNotEmpty) {
            summaryExtras[_summaryExtraKeyControllers[i].text] =
                double.tryParse(_summaryExtraValueControllers[i].text) ?? 0;
          }
        }

        final double adjValue =
            double.tryParse(_adjustmentController.text) ?? 0;
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
          additionalClientDetails: additionalClientDetails,
          summaryExtras: summaryExtras,
          reminderDates: _reminderDates,
          isBill: widget.quotation?.isBill ?? false,
          adjustment: _isAdjustmentNegative ? -adjValue : adjValue,
          workLogs: _workLogs,
          materials: widget.quotation?.materials ?? const <MaterialLog>[],
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
          payments: _payments,
          advanceDate: _advanceDate,
        );

        if (quote.isBill) {
          await context.read<QuotationController>().saveBill(quote);
        } else {
          await context.read<QuotationController>().saveQuotation(quote);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                quote.isBill
                    ? 'Bill saved and synced'
                    : 'Quotation saved and synced',
              ),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving quotation: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleReminder({int? editIndex}) async {
    final DateTime? initialDate = editIndex != null
        ? _reminderDates[editIndex]
        : DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate!,
      firstDate: DateTime.now().subtract(
        const Duration(days: 30),
      ), // Allow picking recent past if editing
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        final DateTime manualDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (manualDateTime.isBefore(DateTime.now()) && editIndex == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a future time')),
          );
          return;
        }

        // Schedule 3 notifications for this specific follow-up date
        final notificationService = NotificationService();
        final String clientName = _clientNameController.text;
        final String quoteNo = _quoteNoController.text;

        // Base ID for this specific reminder entry
        // If editing, we use the same base ID to overwrite.
        // If adding, we use a new unique ID based on list length.
        final int baseId =
            _id.hashCode + (editIndex ?? _reminderDates.length) * 3;

        // 1. Manual Time
        await notificationService.scheduleNotification(
          id: baseId,
          title: 'Quotation Follow-up',
          body: 'Time to follow up with $clientName for quote $quoteNo',
          scheduledDate: manualDateTime,
        );

        // 2. Default Morning (9:00 AM)
        final DateTime morningTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          9,
          0,
        );
        if (morningTime.isAfter(DateTime.now())) {
          await notificationService.scheduleNotification(
            id: baseId + 1,
            title: 'Quotation Follow-up (Morning)',
            body: 'Morning reminder for $clientName ($quoteNo)',
            scheduledDate: morningTime,
          );
        }

        // 3. Default Evening (5:00 PM)
        final DateTime eveningTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          17,
          0,
        );
        if (eveningTime.isAfter(DateTime.now())) {
          await notificationService.scheduleNotification(
            id: baseId + 2,
            title: 'Quotation Follow-up (Evening)',
            body: 'Evening reminder for $clientName ($quoteNo)',
            scheduledDate: eveningTime,
          );
        }

        setState(() {
          if (editIndex != null) {
            _reminderDates[editIndex] = manualDateTime;
          } else {
            _reminderDates.add(manualDateTime);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reminders set for ${DateFormat('MMM d, h:mm a').format(manualDateTime)}',
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

    setState(() => _isLoading = true);
    try {
      final Map<String, String> additionalClientDetails = {};
      for (int i = 0; i < _clientDetailKeyControllers.length; i++) {
        if (_clientDetailKeyControllers[i].text.isNotEmpty) {
          additionalClientDetails[_clientDetailKeyControllers[i].text] =
              _clientDetailValueControllers[i].text;
        }
      }

      final Map<String, double> summaryExtras = {};
      for (int i = 0; i < _summaryExtraKeyControllers.length; i++) {
        if (_summaryExtraKeyControllers[i].text.isNotEmpty) {
          summaryExtras[_summaryExtraKeyControllers[i].text] =
              double.tryParse(_summaryExtraValueControllers[i].text) ?? 0;
        }
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
          additionalCostLabel: _additionalCostLabelController?.text ?? "",
          additionalCostValue: _additionalCostValue,
          additionalClientDetails: additionalClientDetails,
          summaryExtras: summaryExtras,
          reminderDates: _reminderDates,
          isBill: widget.quotation?.isBill ?? false,
          adjustment:
              (_isAdjustmentNegative ? -1 : 1) *
              (double.tryParse(_adjustmentController.text) ?? 0),
          workLogs: _workLogs,
          materials: widget.quotation?.materials ?? const <MaterialLog>[],
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
          payments: _payments,
          advanceDate: _advanceDate,
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndPreviewPdf() async {
    final settings = context.read<QuotationController>().settings;
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set up Business Settings first')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final Map<String, String> additionalClientDetails = {};
      for (int i = 0; i < _clientDetailKeyControllers.length; i++) {
        if (_clientDetailKeyControllers[i].text.isNotEmpty) {
          additionalClientDetails[_clientDetailKeyControllers[i].text] =
              _clientDetailValueControllers[i].text;
        }
      }

      final Map<String, double> summaryExtras = {};
      for (int i = 0; i < _summaryExtraKeyControllers.length; i++) {
        if (_summaryExtraKeyControllers[i].text.isNotEmpty) {
          summaryExtras[_summaryExtraKeyControllers[i].text] =
              double.tryParse(_summaryExtraValueControllers[i].text) ?? 0;
        }
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
          additionalCostLabel: _additionalCostLabelController?.text ?? "",
          additionalCostValue: _additionalCostValue,
          additionalClientDetails: additionalClientDetails,
          summaryExtras: summaryExtras,
          reminderDates: _reminderDates,
          isBill: widget.quotation?.isBill ?? false,
          adjustment:
              (_isAdjustmentNegative ? -1 : 1) *
              (double.tryParse(_adjustmentController.text) ?? 0),
          workLogs: _workLogs,
          materials: widget.quotation?.materials ?? const <MaterialLog>[],
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
          payments: _payments,
          advanceDate: _advanceDate,
        ),
        settings,
      );
      await Printing.layoutPdf(onLayout: (_) => pdfData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareQuotationExcel() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final Map<String, String> additionalClientDetails = {};
      for (int i = 0; i < _clientDetailKeyControllers.length; i++) {
        if (_clientDetailKeyControllers[i].text.isNotEmpty) {
          additionalClientDetails[_clientDetailKeyControllers[i].text] =
              _clientDetailValueControllers[i].text;
        }
      }

      final Map<String, double> summaryExtras = {};
      for (int i = 0; i < _summaryExtraKeyControllers.length; i++) {
        if (_summaryExtraKeyControllers[i].text.isNotEmpty) {
          summaryExtras[_summaryExtraKeyControllers[i].text] =
              double.tryParse(_summaryExtraValueControllers[i].text) ?? 0;
        }
      }

      final excelData = await ExcelHelper.generateQuotationExcel(
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
          additionalClientDetails: additionalClientDetails,
          summaryExtras: summaryExtras,
          reminderDates: _reminderDates,
          isBill: widget.quotation?.isBill ?? false,
          adjustment:
              (_isAdjustmentNegative ? -1 : 1) *
              (double.tryParse(_adjustmentController.text) ?? 0),
          workLogs: _workLogs,
          materials: widget.quotation?.materials ?? const <MaterialLog>[],
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
          payments: _payments,
          advanceDate: _advanceDate,
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath =
          "${tempDir.path}/${_quoteNoController.text.replaceAll('/', '_')}.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(excelData);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Quotation Excel for ${_clientNameController.text}',
        subject: 'Quotation ${_quoteNoController.text}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing Excel: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _convertToBill() {
    if (widget.quotation == null) return;

    // Create a copy of items and store their current state as originalData
    final billItems = _items.map((item) {
      final newItem = item.copy();
      // Store a snapshot without previous originalData to avoid recursive nesting
      final snapshot = item.toJson();
      snapshot.remove('originalData');
      newItem.originalData = snapshot;
      return newItem;
    }).toList();

    final bill = Quotation(
      id: const Uuid().v4(), // New ID for Bill
      quoteNumber: "BILL-${_quoteNoController.text}",
      clientName: _clientNameController.text,
      clientAddress: _clientAddressController.text,
      clientPhone: _clientPhoneController.text,
      date: DateTime.now(),
      items: billItems,
      gstValue: _gstValue,
      isGstPercentage: _isGstPercentage,
      showGst: _showGst,
      transportationValue: _transportation,
      isTransportationPercentage: _isTransportationPercentage,
      showTransportation: _showTransportation,
      additionalCostLabel: _additionalCostLabel,
      additionalCostValue: _additionalCostValue,
      additionalClientDetails: widget.quotation!.additionalClientDetails,
      summaryExtras: widget.quotation!.summaryExtras,
      reminderDates: _reminderDates,
      isBill: true,
      adjustment:
          (_isAdjustmentNegative ? -1 : 1) *
          (double.tryParse(_adjustmentController.text) ?? 0),
      workLogs: _workLogs,
      materials: widget.quotation!.materials,
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
      advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
      payments: _payments,
      advanceDate: _advanceDate,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuotationEditorScreen(quotation: bill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          widget.quotation == null
              ? 'New Quotation'
              : (widget.quotation!.isBill ? 'Edit Bill' : 'Edit Quotation'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          // if (widget.quotation != null && !widget.quotation!.isBill)
          //   IconButton(
          //     icon: const Icon(Icons.receipt, color: Colors.teal),
          //     tooltip: 'Convert to Bill',
          //     onPressed: _convertToBill,
          //   ),
          IconButton(
            icon: Icon(
              Icons.save,
              color: widget.quotation?.isBill == true
                  ? Colors.teal
                  : const Color(0xFF6A11CB),
            ),
            onPressed: _isLoading ? null : _saveQuote,
            tooltip: 'Save Quotation',
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
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
                  _buildTextField(
                    'Client Phone',
                    _clientPhoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (value.length != 10) return 'Must be 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Validity & Status'),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                                if (_endDate != null &&
                                    _startDate!.isAfter(_endDate!)) {
                                  _endDate = _startDate;
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Color(0xFF6A11CB),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _startDate != null
                                          ? DateFormat(
                                              'dd MMM yyyy',
                                            ).format(_startDate!)
                                          : 'Select Date',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: _startDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _startDate != null
                                            ? Colors.black87
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  (_endDate != null &&
                                      (_startDate == null ||
                                          !_endDate!.isBefore(_startDate!)))
                                  ? _endDate!
                                  : (_startDate ?? DateTime.now()),
                              firstDate:
                                  _startDate ??
                                  DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Color(0xFF2575FC),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _endDate != null
                                          ? DateFormat(
                                              'dd MMM yyyy',
                                            ).format(_endDate!)
                                          : 'Select Date',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: _endDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _endDate != null
                                            ? Colors.black87
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('Processing'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _status = val;
                          });
                        }
                      },
                    ),
                  ),
                  if (_workLogs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('Employee Assignment Logs'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: _workLogs.map((log) {
                          final formattedDate = DateFormat(
                            'dd MMM yyyy',
                          ).format(log.date);
                          return CheckboxListTile(
                            title: Text(
                              log.employeeName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            subtitle: Text(
                              'Assigned: $formattedDate',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            secondary: const Icon(
                              Icons.engineering,
                              color: Color(0xFF3F51B5),
                            ),
                            value: log.includeInPdf,
                            activeColor: const Color(0xFF3F51B5),
                            onChanged: (bool? val) {
                              setState(() {
                                log.includeInPdf = val ?? false;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ...List.generate(_clientDetailKeyControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              'Title',
                              _clientDetailKeyControllers[index],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              'Data',
                              _clientDetailValueControllers[index],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _clientDetailKeyControllers[index].dispose();
                                _clientDetailValueControllers[index].dispose();
                                _clientDetailKeyControllers.removeAt(index);
                                _clientDetailValueControllers.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _clientDetailKeyControllers.add(
                          TextEditingController(),
                        );
                        _clientDetailValueControllers.add(
                          TextEditingController(),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Client Detail'),
                  ),

                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Items'),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _addItem,
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
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
                ),
              ),
            ),
        ],
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
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          counterText: "", // Hide counter
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator:
            validator ??
            (value) => value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildItemCard(int index, QuotationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        onTap: () => _editItem(index),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(item.images.first),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.basicInfo.entries
                              .where(
                                (e) => e.key.toLowerCase() != 'description',
                              )
                              .map((e) => "${e.key}: ${e.value}")
                              .take(2)
                              .join(" | "),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.isUnitBased
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.isUnitBased ? "Unit Based" : "Area Based",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.isUnitBased
                                      ? Colors.blue[700]
                                      : Colors.green[700],
                                ),
                              ),
                            ),
                            if (!item.isUnitBased) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.multiplyByArea
                                      ? "Rate/Area"
                                      : "Fixed/Item",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.originalData != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          () {
                            final orig = QuotationItem.fromJson(
                              item.originalData!,
                            );
                            String sizeStr = orig.isUnitBased
                                ? "${orig.unitQuantity} ${orig.itemUnit}"
                                : "${orig.width}x${orig.height} ${orig.areaUnit}";
                            return "Quoted Ref: $sizeStr | Total: ₹${orig.totalValue.toStringAsFixed(2)}";
                          }(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),

              // Inline Edit Section (W, H, Rate)
              Row(
                children: [
                  if (!item.isUnitBased) ...[
                    Expanded(
                      child: InlineInput(
                        label: "W",
                        value: item.width.toString(),
                        onChanged: (val) => setState(
                          () => item.width = double.tryParse(val) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InlineInput(
                        label: "H",
                        value: item.height.toString(),
                        onChanged: (val) => setState(
                          () => item.height = double.tryParse(val) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: InlineInput(
                      label: item.isUnitBased ? "Rate" : "Rate/sqft",
                      value:
                          (item.isUnitBased ? item.unitRate : item.ratePerSqFt)
                              .toString(),
                      onChanged: (val) {
                        setState(() {
                          if (item.isUnitBased) {
                            item.unitRate = double.tryParse(val) ?? 0;
                          } else {
                            item.ratePerSqFt = double.tryParse(val) ?? 0;
                          }
                        });
                      },
                      prefix: "₹",
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Value",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "₹${item.totalValue.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6A11CB),
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            _qtyButton(Icons.remove, Colors.red, () {
                              setState(() {
                                if (item.isUnitBased) {
                                  if (item.unitQuantity > 1)
                                    item.unitQuantity--;
                                } else {
                                  if (item.quantity > 1) item.quantity--;
                                }
                              });
                            }),
                            Container(
                              width: 45,
                              alignment: Alignment.center,
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  double? newVal = double.tryParse(val);
                                  if (newVal != null && newVal > 0) {
                                    setState(() {
                                      if (item.isUnitBased) {
                                        item.unitQuantity = newVal;
                                      } else {
                                        item.quantity = newVal;
                                      }
                                    });
                                  }
                                },
                                controller:
                                    TextEditingController(
                                        text:
                                            (item.isUnitBased
                                                    ? item.unitQuantity
                                                    : item.quantity)
                                                .toInt()
                                                .toString(),
                                      )
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                          offset:
                                              (item.isUnitBased
                                                      ? item.unitQuantity
                                                      : item.quantity)
                                                  .toInt()
                                                  .toString()
                                                  .length,
                                        ),
                                      ),
                              ),
                            ),
                            _qtyButton(Icons.add, Colors.green, () {
                              setState(() {
                                if (item.isUnitBased) {
                                  item.unitQuantity++;
                                } else {
                                  item.quantity++;
                                }
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _showDeleteConfirm(index),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 30,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showDeleteConfirm(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _items.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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

          // Additional Cost Row (Now Dynamic)
          ...List.generate(_summaryExtraKeyControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Extra Cost Label",
                        hintStyle: TextStyle(fontSize: 12),
                        isDense: true,
                      ),
                      controller: _summaryExtraKeyControllers[index],
                      onChanged: (_) => setState(() {}),
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
                      controller: _summaryExtraValueControllers[index],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _summaryExtraKeyControllers[index].dispose();
                        _summaryExtraValueControllers[index].dispose();
                        _summaryExtraKeyControllers.removeAt(index);
                        _summaryExtraValueControllers.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          }),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _summaryExtraKeyControllers.add(TextEditingController());
                  _summaryExtraValueControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Extra Cost',
                style: TextStyle(fontSize: 12),
              ),
            ),
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
          ...List.generate(_summaryExtraKeyControllers.length, (index) {
            final label = _summaryExtraKeyControllers[index].text;
            final value =
                double.tryParse(_summaryExtraValueControllers[index].text) ?? 0;
            if (label.isEmpty && value == 0) return const SizedBox.shrink();
            return _summaryRow(
              label.isEmpty ? "Extra Cost" : label,
              value,
              isSmall: true,
            );
          }),
          if (_showGst) _summaryRow("GST Amount", _gstAmount, isSmall: true),

          const Divider(height: 30),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.quotation?.isBill == true
                      ? "Bill Adjustment (±)"
                      : "Adjustment (±)",
                  style: GoogleFonts.poppins(
                    color: widget.quotation?.isBill == true
                        ? Colors.teal
                        : const Color(0xFF6A11CB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    _modeButton(
                      "+",
                      !_isAdjustmentNegative,
                      () => setState(() => _isAdjustmentNegative = false),
                    ),
                    _modeButton(
                      "-",
                      _isAdjustmentNegative,
                      () => setState(() => _isAdjustmentNegative = true),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _adjustmentController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: InputBorder.none,
                          prefixText: "₹",
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.quotation?.isBill == true) ...[
            const SizedBox(height: 10),
            // Show original grand total as reference if it's a bill
            Builder(
              builder: (context) {
                double originalGrandTotal = 0;
                try {
                  // This is a bit heavy but accurate
                  final List<QuotationItem> originalItems = _items.map((item) {
                    if (item.originalData != null) {
                      return QuotationItem.fromJson(item.originalData!);
                    }
                    return item;
                  }).toList();

                  // Create a temporary quotation to calculate its grand total
                  final tempQuote = Quotation(
                    id: 'temp',
                    quoteNumber: '',
                    clientName: '',
                    clientAddress: '',
                    clientPhone: '',
                    date: DateTime.now(),
                    items: originalItems,
                    gstValue: widget.quotation?.gstValue ?? 18.0,
                    isGstPercentage: widget.quotation?.isGstPercentage ?? true,
                    showGst: widget.quotation?.showGst ?? true,
                    transportationValue:
                        widget.quotation?.transportationValue ?? 0,
                    isTransportationPercentage:
                        widget.quotation?.isTransportationPercentage ?? false,
                    showTransportation:
                        widget.quotation?.showTransportation ?? true,
                    additionalCostValue:
                        widget.quotation?.additionalCostValue ?? 0,
                    summaryExtras: widget.quotation?.summaryExtras ?? {},
                    adjustment: 0,
                    workLogs: widget.quotation?.workLogs ?? const <WorkLog>[],
                    materials:
                        widget.quotation?.materials ?? const <MaterialLog>[],
                    startDate: _startDate,
                    endDate: _endDate,
                    status: _status,
                  );
                  originalGrandTotal = tempQuote.grandTotal;
                } catch (e) {}

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Original Total",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "₹${originalGrandTotal.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.quotation?.isBill == true
                    ? "Final Bill Amount"
                    : "Grand Total",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.quotation?.isBill == true ? Colors.teal : null,
                ),
              ),
              Text(
                "₹${_grandTotal.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.quotation?.isBill == true
                      ? Colors.teal
                      : const Color(0xFF6A11CB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentsAndAdvancesSection(),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'PDF',
                  Icons.picture_as_pdf,
                  Colors.redAccent,
                  _items.isEmpty || _isLoading ? null : _generateAndPreviewPdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Excel',
                  Icons.table_chart,
                  Colors.green,
                  _items.isEmpty || _isLoading ? null : _shareQuotationExcel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Save',
                  Icons.save,
                  const Color(0xFF6A11CB),
                  _isLoading ? null : _saveQuote,
                ),
              ),
            ],
          ),
          if (widget.quotation != null && !widget.quotation!.isBill) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                'Convert to Bill',
                Icons.receipt,
                Colors.teal,
                _isLoading ? null : _convertToBill,
              ),
            ),
          ],
          const SizedBox(height: 15),

          // Multi-Reminder List
          if (_reminderDates.isNotEmpty) ...[
            Text(
              "Follow-up Reminders",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            ..._reminderDates.asMap().entries.map((entry) {
              final idx = entry.key;
              final date = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      size: 16,
                      color: Color(0xFF6A11CB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(date),
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                      onPressed: () => _scheduleReminder(editIndex: idx),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() => _reminderDates.removeAt(idx));
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _scheduleReminder(),
              icon: const Icon(Icons.notification_add_outlined),
              label: const Text("Add Follow-up Reminder"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A11CB),
                side: const BorderSide(color: Color(0xFF6A11CB)),
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
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Share Quotation',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ListTile(
                                leading: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                                title: const Text('Share as PDF'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _shareQuotation();
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.table_chart,
                                  color: Colors.green,
                                ),
                                title: const Text('Share as Excel'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _shareQuotationExcel();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.share),
              label: const Text("Share to WhatsApp"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
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

  void _showAddPaymentDialog() {
    DateTime selectedDate = DateTime.now();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                "Add Payment",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Payment Amount",
                      prefixText: "₹",
                      border: OutlineInputBorder(),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Payment Date",
                        prefixIcon: Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? amount = double.tryParse(
                      amountController.text,
                    );
                    if (amount != null && amount > 0) {
                      setState(() {
                        _payments.add(
                          PaymentRecord(
                            id: const Uuid().v4(),
                            amount: amount,
                            date: selectedDate,
                          ),
                        );
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Add", style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsAndAdvancesSection() {
    final themeColor = widget.quotation?.isBill == true
        ? Colors.teal
        : const Color(0xFF6A11CB);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Payments & Advances",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: themeColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showAddPaymentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    "Add Payment",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: themeColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Advance Payment Section
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _advanceDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _advanceDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Advance Date",
                        prefixIcon: Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        _advanceDate != null
                            ? DateFormat('dd MMM yyyy').format(_advanceDate!)
                            : "Select Date",
                        style: GoogleFonts.poppins(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _advanceAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Advance Amount",
                      prefixText: "₹",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            if (_payments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                "Additional Payments",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.payment,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "₹${payment.amount.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(payment.date),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _payments.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const Divider(height: 24),
            // Balance breakdown
            () {
              final double advAmt =
                  double.tryParse(_advanceAmountController.text) ?? 0.0;
              final double extraPaymentsSum = _payments.fold(
                0.0,
                (sum, p) => sum + p.amount,
              );
              final double totalPaid = advAmt + extraPaymentsSum;
              final double remaining = _grandTotal - totalPaid;
              if (remaining <= 0) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "TOTAL AMOUNT RECEIVED",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "Total Paid",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "₹${totalPaid.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "Remaining Balance",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "₹${remaining.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeColor,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }
}

class InlineInput extends StatefulWidget {
  final String label;
  final String value;
  final Function(String) onChanged;
  final String? prefix;

  const InlineInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefix,
  });

  @override
  State<InlineInput> createState() => _InlineInputState();
}

class _InlineInputState extends State<InlineInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Use an empty string if value is "0" or "0.0" to allow easier clearing
    String initialText = (widget.value == "0" || widget.value == "0.0")
        ? ""
        : widget.value;
    _controller = TextEditingController(text: initialText);
  }

  @override
  void didUpdateWidget(InlineInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    double? modelVal = double.tryParse(widget.value);
    double? ctrlVal = double.tryParse(_controller.text);

    // Only update if the numerical value changed from outside
    // and it's actually different from what the user is currently seeing/typing
    if (modelVal != ctrlVal) {
      // Special handling for 0/empty
      if ((modelVal == 0 || modelVal == null) && _controller.text.isEmpty) {
        return;
      }

      String newText = (modelVal == 0 || modelVal == null)
          ? ""
          : (modelVal == modelVal.toInt()
                ? modelVal.toInt().toString()
                : modelVal.toString());

      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixText: widget.prefix,
              hintText: "0",
            ),
          ),
        ),
      ],
    );
  }
}

class AdvancedItemEditor extends StatefulWidget {
  final QuotationItem item;
  final Function(QuotationItem) onSave;
  final bool isInventoryMode;

  const AdvancedItemEditor({
    super.key,
    required this.item,
    required this.onSave,
    this.isInventoryMode = false,
  });

  @override
  State<AdvancedItemEditor> createState() => _AdvancedItemEditorState();
}

class _AdvancedItemEditorState extends State<AdvancedItemEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late QuotationItem _editingItem;

  TextEditingController _widthController = TextEditingController();
  TextEditingController _heightController = TextEditingController();
  TextEditingController _rateController = TextEditingController();
  TextEditingController _qtyController = TextEditingController();
  TextEditingController _unitRateController = TextEditingController();
  TextEditingController _unitQtyController = TextEditingController();
  TextEditingController _remarksController = TextEditingController();

  // Dynamic controllers for basicInfo
  final List<TextEditingController> _basicKeyControllers = [];
  final List<TextEditingController> _basicValueControllers = [];

  // Dynamic controllers for specs
  final List<TextEditingController> _specKeyControllers = [];
  final List<TextEditingController> _specValueControllers = [];

  // Dynamic controllers for accessories
  final List<TextEditingController> _accKeyControllers = [];
  final List<TextEditingController> _accValueControllers = [];

  bool _saveToInventory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _editingItem = QuotationItem.fromJson(widget.item.toJson());

    _widthController.text = _editingItem.width.toString();
    _heightController.text = _editingItem.height.toString();
    _rateController.text = _editingItem.ratePerSqFt.toString();
    _qtyController.text = _editingItem.quantity.toString();
    _unitRateController.text = _editingItem.unitRate.toString();
    _unitQtyController.text = _editingItem.unitQuantity.toString();
    _remarksController.text = _editingItem.remarks;

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
    _unitRateController.dispose();
    _unitQtyController.dispose();
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
    _editingItem.unitRate = double.tryParse(_unitRateController.text) ?? 0;
    _editingItem.unitQuantity = double.tryParse(_unitQtyController.text) ?? 1;
    _editingItem.remarks = _remarksController.text;
    // _editingItem.isUnitBased is already synced via setState in the UI toggle

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
              if (_saveToInventory) {
                Provider.of<InventoryController>(
                  context,
                  listen: false,
                ).saveItem(_editingItem.copy());
              }
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
    final inventory = Provider.of<InventoryController>(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (inventory.items.isNotEmpty) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showInventoryPicker(context, inventory),
                icon: const Icon(Icons.inventory_2, color: Colors.white),
                label: Text(
                  'Import from Master Inventory',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
          if (!widget.isInventoryMode) ...[
            const Divider(height: 30),
            CheckboxListTile(
              title: const Text('Save this item to Master Inventory'),
              subtitle: const Text('Save for future quotations'),
              value: _saveToInventory,
              onChanged: (val) =>
                  setState(() => _saveToInventory = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF6A11CB),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  void _showInventoryPicker(
    BuildContext context,
    InventoryController inventory,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Item',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: inventory.items.length,
                itemBuilder: (context, index) {
                  final item = inventory.items[index];
                  return ListTile(
                    leading: item.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                              File(item.images.first),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image_not_supported),
                    title: Text(
                      item.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      item.isUnitBased ? 'Unit Based' : 'Area Based',
                    ),
                    onTap: () {
                      _applyInventoryItem(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyInventoryItem(QuotationItem master) {
    setState(() {
      _editingItem = master.copy();

      _widthController.text = _editingItem.width.toString();
      _heightController.text = _editingItem.height.toString();
      _rateController.text = _editingItem.ratePerSqFt.toString();
      _qtyController.text = _editingItem.quantity.toString();
      _unitRateController.text = _editingItem.unitRate.toString();
      _unitQtyController.text = _editingItem.unitQuantity.toString();
      _remarksController.text = _editingItem.remarks;

      _basicKeyControllers.clear();
      _basicValueControllers.clear();
      _editingItem.basicInfo.forEach((key, value) {
        _basicKeyControllers.add(TextEditingController(text: key));
        _basicValueControllers.add(TextEditingController(text: value));
      });

      _specKeyControllers.clear();
      _specValueControllers.clear();
      _editingItem.specs.forEach((key, value) {
        _specKeyControllers.add(TextEditingController(text: key));
        _specValueControllers.add(TextEditingController(text: value));
      });

      _accKeyControllers.clear();
      _accValueControllers.clear();
      _editingItem.accessories.forEach((key, value) {
        _accKeyControllers.add(TextEditingController(text: key));
        _accValueControllers.add(TextEditingController(text: value));
      });
    });
  }

  Widget _buildValuesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_editingItem.originalData != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Original Quoted Values',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  () {
                    final orig = QuotationItem.fromJson(
                      _editingItem.originalData!,
                    );
                    return Column(
                      children: [
                        _originalRow(
                          'Pricing Mode',
                          orig.isUnitBased ? 'Unit Based' : 'Area Based',
                        ),
                        if (orig.isUnitBased) ...[
                          _originalRow('Unit Price', '₹${orig.unitRate}'),
                          _originalRow(
                            'Quantity',
                            '${orig.unitQuantity} ${orig.itemUnit}',
                          ),
                        ] else ...[
                          _originalRow(
                            'Size',
                            '${orig.width} x ${orig.height} ${orig.areaUnit}',
                          ),
                          _originalRow('Rate', '₹${orig.ratePerSqFt}'),
                          _originalRow('Quantity', '${orig.quantity} Pcs'),
                        ],
                        const Divider(height: 15),
                        _originalRow(
                          'Quoted Total',
                          '₹${orig.totalValue.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    );
                  }(),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildModeToggle(
            label: 'Pricing Mode',
            value: _editingItem.isUnitBased,
            onChanged: (val) => setState(() => _editingItem.isUnitBased = val),
            activeLabel: 'Unit Based',
            inactiveLabel: 'Area Based',
          ),
          const SizedBox(height: 20),
          if (!_editingItem.isUnitBased) ...[
            _buildUnitSelector(),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _editorField(
                    'Width',
                    _widthController,
                    type: TextInputType.number,
                    suffix: _editingItem.areaUnit,
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 15,
                  ),
                  child: Text(
                    '*',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: _editorField(
                    'Height',
                    _heightController,
                    type: TextInputType.number,
                    suffix: _editingItem.areaUnit,
                    onChanged: (v) => setState(() {}),
                  ),
                ),
              ],
            ),
            _editorField(
              'Rate (₹)',
              _rateController,
              type: TextInputType.number,
              onChanged: (v) => setState(() {}),
            ),
            _editorField(
              'Quantity',
              _qtyController,
              type: TextInputType.number,
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _buildModeToggle(
              label: 'Calculation Basis',
              value: _editingItem.multiplyByArea,
              onChanged: (val) =>
                  setState(() => _editingItem.multiplyByArea = val),
              activeLabel: 'Rate per Area',
              inactiveLabel: 'Fixed per Item',
            ),
            const SizedBox(height: 10),
            Text(
              _editingItem.multiplyByArea
                  ? 'Formula: (Width * Height) * Rate * Qty'
                  : 'Formula: Rate * Qty (Area is for display only)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            _buildItemUnitSelector(),
            const SizedBox(height: 15),
            _editorField(
              'Unit Price (₹)',
              _unitRateController,
              type: TextInputType.number,
              onChanged: (v) => setState(() {}),
            ),
            _editorField(
              'Quantity',
              _unitQtyController,
              type: TextInputType.number,
              suffix: _editingItem.itemUnit,
              onChanged: (v) => setState(() {}),
            ),
          ],
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
    if (_editingItem.isUnitBased) {
      double r = double.tryParse(_unitRateController.text) ?? 0;
      double q = double.tryParse(_unitQtyController.text) ?? 1;
      return (r + _editingItem.totalExtras) * q;
    } else {
      double w = double.tryParse(_widthController.text) ?? 0;
      double h = double.tryParse(_heightController.text) ?? 0;
      double r = double.tryParse(_rateController.text) ?? 0;
      double q = double.tryParse(_qtyController.text) ?? 1;

      double rateArea = _editingItem.multiplyByArea ? (w * h) : 1.0;
      return ((rateArea * r * q) + _editingItem.totalExtras);
    }
  }

  Widget _buildUnitSelector() {
    final units = ['ft', 'meter', 'cm', 'mm', 'inch'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Area Measurement Unit',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _editingItem.areaUnit,
              isExpanded: true,
              items: units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) _convertUnits(_editingItem.areaUnit, val);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _convertUnits(String oldUnit, String newUnit) {
    // Conversion factors to Meter
    final toMeter = {
      'ft': 0.3048,
      'meter': 1.0,
      'cm': 0.01,
      'mm': 0.001,
      'inch': 0.0254,
    };

    double w = double.tryParse(_widthController.text) ?? 0;
    double h = double.tryParse(_heightController.text) ?? 0;

    // Convert current values to Meter first
    double wMeter = w * (toMeter[oldUnit] ?? 1);
    double hMeter = h * (toMeter[oldUnit] ?? 1);

    // Convert from Meter to new unit
    double wNew = wMeter / (toMeter[newUnit] ?? 1);
    double hNew = hMeter / (toMeter[newUnit] ?? 1);

    setState(() {
      _editingItem.areaUnit = newUnit;
      _widthController.text = wNew.toStringAsFixed(2);
      _heightController.text = hNew.toStringAsFixed(2);
    });
  }

  Widget _buildItemUnitSelector() {
    final commonUnits = [
      'pcs',
      'kg',
      'g',
      'tonne',
      'liter',
      'ml',
      'box',
      'set',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Unit',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: commonUnits.contains(_editingItem.itemUnit)
                        ? _editingItem.itemUnit
                        : null,
                    isExpanded: true,
                    hint: const Text('Select Unit'),
                    items: commonUnits
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _editingItem.itemUnit = val ?? 'pcs'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Manual Unit',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) => setState(() => _editingItem.itemUnit = val),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeToggle({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required String activeLabel,
    required String inactiveLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _modeSwitchButton(
                  inactiveLabel,
                  !value,
                  () => onChanged(false),
                ),
              ),
              Expanded(
                child: _modeSwitchButton(
                  activeLabel,
                  value,
                  () => onChanged(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeSwitchButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6A11CB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: active ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
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
    String? suffix,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          labelStyle: GoogleFonts.poppins(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _originalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.orange.shade800,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
