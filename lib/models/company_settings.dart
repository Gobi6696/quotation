enum PdfElementType { text, image }
enum PdfElementPosition { left, center, right }

class PdfElement {
  final String id;
  final PdfElementType type;
  String content;
  PdfElementPosition position;
  double size;
  int order;

  PdfElement({
    required this.id,
    required this.type,
    required this.content,
    this.position = PdfElementPosition.left,
    this.size = 12.0,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'position': position.name,
    'size': size,
    'order': order,
  };

  factory PdfElement.fromJson(Map<String, dynamic> json) => PdfElement(
    id: json['id'],
    type: PdfElementType.values.byName(json['type']),
    content: json['content'],
    position: PdfElementPosition.values.byName(json['position']),
    size: (json['size'] as num).toDouble(),
    order: json['order'] ?? 0,
  );
}

class CompanySettings {
  final List<PdfElement> headerElements;
  final List<PdfElement> footerElements;
  final List<PdfElement> firstPageElements;
  final List<PdfElement> lastPageElements;

  CompanySettings({
    this.headerElements = const [],
    this.footerElements = const [],
    this.firstPageElements = const [],
    this.lastPageElements = const [],
  });

  Map<String, dynamic> toJson() => {
    'headerElements': headerElements.map((e) => e.toJson()).toList(),
    'footerElements': footerElements.map((e) => e.toJson()).toList(),
    'firstPageElements': firstPageElements.map((e) => e.toJson()).toList(),
    'lastPageElements': lastPageElements.map((e) => e.toJson()).toList(),
  };

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
    headerElements: (json['headerElements'] as List? ?? []).map((e) => PdfElement.fromJson(e)).toList(),
    footerElements: (json['footerElements'] as List? ?? []).map((e) => PdfElement.fromJson(e)).toList(),
    firstPageElements: (json['firstPageElements'] as List? ?? []).map((e) => PdfElement.fromJson(e)).toList(),
    lastPageElements: (json['lastPageElements'] as List? ?? []).map((e) => PdfElement.fromJson(e)).toList(),
  );
}
