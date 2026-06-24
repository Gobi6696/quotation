class MaterialLog {
  final String id;
  final String quotationId;
  final String quoteNumber;
  final String clientName;
  final String name;
  final double quantity;
  final String size;
  final double price;
  final String? image;
  final Map<String, dynamic> customFields;
  final DateTime? purchaseDate;

  MaterialLog({
    required this.id,
    required this.quotationId,
    required this.quoteNumber,
    required this.clientName,
    required this.name,
    required this.quantity,
    required this.size,
    required this.price,
    this.image,
    this.customFields = const {},
    this.purchaseDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'quotationId': quotationId,
    'quoteNumber': quoteNumber,
    'clientName': clientName,
    'name': name,
    'quantity': quantity,
    'size': size,
    'price': price,
    'image': image,
    'customFields': customFields,
    'purchaseDate': purchaseDate?.toIso8601String(),
  };

  factory MaterialLog.fromJson(Map<String, dynamic> json) => MaterialLog(
    id: json['id'] ?? '',
    quotationId: json['quotationId'] ?? '',
    quoteNumber: json['quoteNumber'] ?? '',
    clientName: json['clientName'] ?? '',
    name: json['name'] ?? '',
    quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
    size: json['size'] ?? '',
    price: (json['price'] as num? ?? 0.0).toDouble(),
    image: json['image'],
    customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
    purchaseDate: json['purchaseDate'] != null ? DateTime.tryParse(json['purchaseDate']) : null,
  );
}
