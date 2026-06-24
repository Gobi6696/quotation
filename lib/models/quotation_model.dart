import 'package:uuid/uuid.dart';
import 'material_model.dart';

class QuotationItem {
  final String id;

  // Measurements
  double width;
  double height;
  double ratePerSqFt;
  double quantity;
  double unitRate;
  double unitQuantity;
  bool isUnitBased;

  String areaUnit; // 'ft', 'cm', 'mm', 'inch', 'meter'
  String itemUnit; // 'pcs', 'kg', 'g', 'liter', etc.
  bool multiplyByArea; // true = (W*H*R*Q), false = (R*Q)

  String remarks;

  // Collections
  List<String> images;
  Map<String, String> accessories;
  Map<String, double> extras;
  Map<String, String> basicInfo;
  Map<String, String> specs;
  Map<String, dynamic>? originalData;

  QuotationItem({
    String? id,
    this.width = 0,
    this.height = 0,
    this.ratePerSqFt = 0,
    this.quantity = 1,
    this.unitRate = 0,
    this.unitQuantity = 1,
    this.isUnitBased = false,
    this.areaUnit = 'ft',
    this.itemUnit = 'pcs',
    this.multiplyByArea = true,
    this.remarks = "",
    List<String>? images,
    Map<String, String>? accessories,
    Map<String, double>? extras,
    Map<String, String>? basicInfo,
    Map<String, String>? specs,
    this.originalData,
  }) : id = id ?? const Uuid().v4(),
       images = images ?? [],
       accessories = accessories ?? {},
       extras = extras ?? {},
       basicInfo = basicInfo ?? {'Description': '', 'Code': '', 'Location': ''},
       specs =
           specs ??
           {
             'Profile System': '',
             'Glass': '',
             'Profile Color': 'WHITE',
             'Mesh Type': 'None',
           };

  double get area => isUnitBased ? 1.0 : width * height;
  double get totalExtras => extras.values.fold(0, (sum, val) => sum + val);

  double get totalValue {
    if (isUnitBased) {
      return ((unitRate + totalExtras) * unitQuantity);
    } else {
      double rateArea = multiplyByArea ? (width * height) : 1.0;
      return ((rateArea * ratePerSqFt * quantity) + totalExtras);
    }
  }

  // Helper to get description safely for UI display
  String get displayName =>
      basicInfo['Description'] ??
      (basicInfo.values.isNotEmpty ? basicInfo.values.first : 'Unnamed Item');

  Map<String, dynamic> toJson() => {
    'id': id,
    'width': width,
    'height': height,
    'ratePerSqFt': ratePerSqFt,
    'quantity': quantity,
    'unitRate': unitRate,
    'unitQuantity': unitQuantity,
    'isUnitBased': isUnitBased,
    'areaUnit': areaUnit,
    'itemUnit': itemUnit,
    'multiplyByArea': multiplyByArea,
    'remarks': remarks,
    'images': images,
    'accessories': accessories,
    'extras': extras,
    'basicInfo': basicInfo,
    'specs': specs,
    'originalData': originalData,
  };

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    Map<String, String> sanitizeMap(dynamic source) {
      if (source == null || source is! Map) return {};
      final Map<String, String> result = {};
      source.forEach((key, value) {
        result[key.toString()] = value?.toString() ?? '';
      });
      return result;
    }

    // Migration logic for old data
    Map<String, String> migratedBasic = sanitizeMap(json['basicInfo']);

    if (migratedBasic.isEmpty) {
      if (json['description'] != null)
        migratedBasic['Description'] = json['description'].toString();
      if (json['code'] != null) migratedBasic['Code'] = json['code'].toString();
      if (json['location'] != null)
        migratedBasic['Location'] = json['location'].toString();
    }

    Map<String, String> migratedSpecs = sanitizeMap(json['specs']);
    if (migratedSpecs.isEmpty) {
      if (json['profileSystem'] != null)
        migratedSpecs['Profile System'] = json['profileSystem'].toString();
      if (json['glass'] != null)
        migratedSpecs['Glass'] = json['glass'].toString();
      if (json['profileColor'] != null)
        migratedSpecs['Profile Color'] = json['profileColor'].toString();
      if (json['meshType'] != null)
        migratedSpecs['Mesh Type'] = json['meshType'].toString();
      if (json['outerFrame'] != null)
        migratedSpecs['Outer Frame'] = json['outerFrame'].toString();
      if (json['outerReinforcement'] != null)
        migratedSpecs['Outer Reinforcement'] = json['outerReinforcement']
            .toString();
      if (json['sashFrame'] != null)
        migratedSpecs['Sash Frame'] = json['sashFrame'].toString();
      if (json['sashReinforcement'] != null)
        migratedSpecs['Sash Reinforcement'] = json['sashReinforcement']
            .toString();
    }

    // Migration for Accessories
    Map<String, String> migratedAcc = sanitizeMap(json['accessories']);
    if (migratedAcc.isEmpty && json['accessories'] is List) {
      for (var item in (json['accessories'] as List)) {
        migratedAcc[item.toString()] =
            "Yes"; // Default value for old list items
      }
    }

    return QuotationItem(
      id: json['id']?.toString() ?? const Uuid().v4(),
      width: (json['width'] as num? ?? 0).toDouble(),
      height: (json['height'] as num? ?? 0).toDouble(),
      ratePerSqFt: (json['ratePerSqFt'] as num? ?? 0).toDouble(),
      quantity: (json['quantity'] as num? ?? 1).toDouble(),
      unitRate: (json['unitRate'] as num? ?? 0).toDouble(),
      unitQuantity: (json['unitQuantity'] as num? ?? 1).toDouble(),
      isUnitBased: json['isUnitBased'] ?? false,
      areaUnit: json['areaUnit']?.toString() ?? 'ft',
      itemUnit: json['itemUnit']?.toString() ?? 'pcs',
      multiplyByArea: json['multiplyByArea'] ?? true,
      remarks: json['remarks']?.toString() ?? '',
      images: List<String>.from(json['images'] ?? []),
      accessories: migratedAcc,
      extras: (json['extras'] as Map? ?? {}).map<String, double>(
        (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()),
      ),
      basicInfo: migratedBasic,
      specs: migratedSpecs,
      originalData: json['originalData'],
    );
  }

  QuotationItem copy() {
    return QuotationItem(
      id: const Uuid().v4(), // Always new ID for a copy
      width: width,
      height: height,
      ratePerSqFt: ratePerSqFt,
      quantity: quantity,
      unitRate: unitRate,
      unitQuantity: unitQuantity,
      isUnitBased: isUnitBased,
      areaUnit: areaUnit,
      itemUnit: itemUnit,
      multiplyByArea: multiplyByArea,
      remarks: remarks,
      images: List.from(images),
      accessories: Map.from(accessories),
      extras: Map.from(extras),
      basicInfo: Map.from(basicInfo),
      specs: Map.from(specs),
      originalData: originalData != null ? Map.from(originalData!) : null,
    );
  }
}

class WorkLog {
  final String id;
  final String employeeName;
  final DateTime date;
  final List<String> images;
  bool includeInPdf;

  WorkLog({
    required this.id,
    required this.employeeName,
    required this.date,
    required this.images,
    this.includeInPdf = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeName': employeeName,
    'date': date.toIso8601String(),
    'images': images,
    'includeInPdf': includeInPdf,
  };

  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
    id: json['id'] ?? '',
    employeeName: json['employeeName'] ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    images: List<String>.from(json['images'] ?? []),
    includeInPdf: json['includeInPdf'] ?? true,
  );
}

class PaymentRecord {
  final String id;
  final double amount;
  final DateTime date;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: json['id'] ?? '',
    amount: (json['amount'] as num? ?? 0).toDouble(),
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
  );
}

class Quotation {
  final String id;
  final String quoteNumber;
  final String clientName;
  final String clientAddress;
  final String clientPhone;
  final DateTime date;
  final List<QuotationItem> items;

  final double gstValue;
  final bool isGstPercentage;
  final bool showGst;

  final double transportationValue;
  final bool isTransportationPercentage;
  final bool showTransportation;

  final String additionalCostLabel;
  final double additionalCostValue;
  final Map<String, String> additionalClientDetails;
  final Map<String, double> summaryExtras;
  final List<DateTime> reminderDates;
  final bool isBill;
  final double adjustment;
  final List<WorkLog> workLogs;

  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final List<MaterialLog> materials;
  final double advanceAmount;
  final List<PaymentRecord> payments;
  final DateTime? advanceDate;

  Quotation({
    required this.id,
    required this.quoteNumber,
    required this.clientName,
    required this.clientAddress,
    required this.clientPhone,
    required this.date,
    required this.items,
    this.gstValue = 18.0,
    this.isGstPercentage = true,
    this.showGst = true,
    this.transportationValue = 0,
    this.isTransportationPercentage = false,
    this.showTransportation = true,
    this.additionalCostLabel = "",
    this.additionalCostValue = 0,
    this.additionalClientDetails = const {},
    this.summaryExtras = const {},
    this.reminderDates = const [],
    this.isBill = false,
    this.adjustment = 0,
    this.workLogs = const <WorkLog>[],
    this.startDate,
    this.endDate,
    this.status = 'pending',
    this.materials = const <MaterialLog>[],
    this.advanceAmount = 0.0,
    this.payments = const <PaymentRecord>[],
    this.advanceDate,
  });

  double get subTotal => items.fold(0, (sum, item) => sum + item.totalValue);

  double get totalSummaryExtras =>
      summaryExtras.values.fold(0, (sum, val) => sum + val);

  double get transportationAmount {
    if (!showTransportation) return 0;
    return isTransportationPercentage
        ? subTotal * (transportationValue / 100)
        : transportationValue;
  }

  double get gstAmount {
    if (!showGst) return 0;
    return isGstPercentage
        ? (subTotal +
                  transportationAmount +
                  additionalCostValue +
                  totalSummaryExtras) *
              (gstValue / 100)
        : gstValue;
  }

  double get grandTotal =>
      subTotal +
      transportationAmount +
      additionalCostValue +
      totalSummaryExtras +
      gstAmount +
      adjustment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'quoteNumber': quoteNumber,
    'clientName': clientName,
    'clientAddress': clientAddress,
    'clientPhone': clientPhone,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'gstValue': gstValue,
    'isGstPercentage': isGstPercentage,
    'showGst': showGst,
    'transportationValue': transportationValue,
    'isTransportationPercentage': isTransportationPercentage,
    'showTransportation': showTransportation,
    'additionalCostLabel': additionalCostLabel,
    'additionalCostValue': additionalCostValue,
    'additionalClientDetails': additionalClientDetails,
    'summaryExtras': summaryExtras,
    'reminderDates': reminderDates.map((e) => e.toIso8601String()).toList(),
    'isBill': isBill,
    'adjustment': adjustment,
    'workLogs': workLogs.map((e) => e.toJson()).toList(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status,
    'materials': materials.map((e) => e.toJson()).toList(),
    'advanceAmount': advanceAmount,
    'advanceDate': advanceDate?.toIso8601String(),
    'payments': payments.map((e) => e.toJson()).toList(),
  };

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
    id: json['id'],
    quoteNumber: json['quoteNumber'],
    clientName: json['clientName'],
    clientAddress: json['clientAddress'],
    clientPhone: json['clientPhone'],
    date: DateTime.parse(json['date']),
    items: (json['items'] as List? ?? [])
        .map((e) => QuotationItem.fromJson(e))
        .toList(),
    gstValue: (json['gstValue'] as num? ?? 18.0).toDouble(),
    isGstPercentage: json['isGstPercentage'] ?? true,
    showGst: json['showGst'] ?? true,
    transportationValue: (json['transportationValue'] as num? ?? 0).toDouble(),
    isTransportationPercentage: json['isTransportationPercentage'] ?? false,
    showTransportation: json['showTransportation'] ?? true,
    additionalCostLabel: json['additionalCostLabel'] ?? "",
    additionalCostValue: (json['additionalCostValue'] as num? ?? 0).toDouble(),
    additionalClientDetails: (json['additionalClientDetails'] as Map? ?? {})
        .map<String, String>((k, v) => MapEntry(k.toString(), v.toString())),
    summaryExtras: (json['summaryExtras'] as Map? ?? {}).map<String, double>(
      (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()),
    ),
    reminderDates: json['reminderDates'] != null
        ? (json['reminderDates'] as List).map((e) => DateTime.parse(e)).toList()
        : (json['reminderDate'] != null
              ? [DateTime.parse(json['reminderDate'])]
              : []),
    isBill: json['isBill'] ?? false,
    adjustment: (json['adjustment'] as num? ?? 0).toDouble(),
    workLogs: json['workLogs'] != null
        ? (json['workLogs'] as List)
              .map((e) => WorkLog.fromJson(e as Map<String, dynamic>))
              .toList()
        : const <WorkLog>[],
    startDate: json['startDate'] != null
        ? DateTime.parse(json['startDate'])
        : null,
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    status: json['status'] ?? 'pending',
    materials: json['materials'] != null
        ? (json['materials'] as List)
              .map((e) => MaterialLog.fromJson(e as Map<String, dynamic>))
              .toList()
        : const <MaterialLog>[],
    advanceAmount: (json['advanceAmount'] as num? ?? 0.0).toDouble(),
    advanceDate: json['advanceDate'] != null ? DateTime.parse(json['advanceDate']) : null,
    payments: json['payments'] != null
        ? (json['payments'] as List)
              .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
              .toList()
        : const <PaymentRecord>[],
  );
}
