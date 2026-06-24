class SalaryRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String status; // 'pending' or 'completed'

  SalaryRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'amount': amount,
    'status': status,
  };

  factory SalaryRecord.fromJson(Map<String, dynamic> json) => SalaryRecord(
    id: json['id'] ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    amount: (json['amount'] as num? ?? 0.0).toDouble(),
    status: json['status'] ?? 'pending',
  );
}

class Employee {
  final String id;
  final String name;
  final String mobileNumber;
  final double salary;
  final Map<String, dynamic> customFields;
  final List<SalaryRecord> salaries;

  Employee({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.salary,
    this.customFields = const {},
    this.salaries = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobileNumber': mobileNumber,
    'salary': salary,
    'customFields': customFields,
    'salaries': salaries.map((s) => s.toJson()).toList(),
  };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    mobileNumber: json['mobileNumber'] ?? '',
    salary: (json['salary'] as num? ?? 0.0).toDouble(),
    customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
    salaries: json['salaries'] != null
        ? (json['salaries'] as List).map((e) => SalaryRecord.fromJson(e)).toList()
        : const [],
  );
}
