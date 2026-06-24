import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/employee_model.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  // Aggregate work history for the employee from quotations and bills
  List<Map<String, dynamic>> _getWorkHistory(
    QuotationController controller,
    String employeeName,
  ) {
    final List<Map<String, dynamic>> history = [];
    final allDocs = [...controller.quotations, ...controller.bills];

    for (final doc in allDocs) {
      final matches = doc.workLogs.where(
        (log) =>
            log.employeeName.trim().toLowerCase() ==
            employeeName.trim().toLowerCase(),
      );
      if (matches.isNotEmpty) {
        // Find the earliest work date in this doc for the employee
        final earliestDate = matches
            .map((m) => m.date)
            .reduce(
              (value, element) => value.isBefore(element) ? value : element,
            );
        history.add({
          'clientName': doc.clientName,
          'docType': doc.isBill ? 'Bill' : 'Quotation',
          'docNo': doc.quoteNumber,
          'status': doc.status,
          'date': earliestDate,
        });
      }
    }

    // Sort history by date descending
    history.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    return history;
  }

  void _showAddSalaryDialog(BuildContext context, Employee employee) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: employee.salary.toStringAsFixed(0),
    );
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'completed';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Add Salary Record",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Amount
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Salary Amount",
                        prefixText: "₹",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Required';
                        if (double.tryParse(val) == null)
                          return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Picker Button
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
                        decoration: InputDecoration(
                          labelText: "Salary Month / Date",
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF6A11CB),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: "Payout Status",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedStatus = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isLoading = true;
                            });
                            try {
                              final newRecord = SalaryRecord(
                                id: const Uuid().v4(),
                                date: selectedDate,
                                amount: double.parse(amountController.text),
                                status: selectedStatus,
                              );

                              final updatedEmp = Employee(
                                id: employee.id,
                                name: employee.name,
                                mobileNumber: employee.mobileNumber,
                                salary: employee.salary,
                                customFields: employee.customFields,
                                salaries: [...employee.salaries, newRecord],
                              );

                              await Provider.of<QuotationController>(
                                context,
                                listen: false,
                              ).saveEmployee(updatedEmp);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Salary record added.'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setDialogState(() {
                                  isLoading = false;
                                });
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          "Add Payout",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleSalaryStatus(
    Employee employee,
    SalaryRecord record,
  ) async {
    final updatedSalaries = employee.salaries.map((s) {
      if (s.id == record.id) {
        return SalaryRecord(
          id: s.id,
          date: s.date,
          amount: s.amount,
          status: s.status == 'completed' ? 'pending' : 'completed',
        );
      }
      return s;
    }).toList();

    final updatedEmp = Employee(
      id: employee.id,
      name: employee.name,
      mobileNumber: employee.mobileNumber,
      salary: employee.salary,
      customFields: employee.customFields,
      salaries: updatedSalaries,
    );

    await Provider.of<QuotationController>(
      context,
      listen: false,
    ).saveEmployee(updatedEmp);
  }

  void _deleteSalaryRecord(
    BuildContext context,
    Employee employee,
    SalaryRecord record,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "Delete Salary Payout",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete this payout of ₹${record.amount.toStringAsFixed(0)} on ${DateFormat('dd MMM yyyy').format(record.date)}?",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final updatedSalaries = employee.salaries
                  .where((s) => s.id != record.id)
                  .toList();

              final updatedEmp = Employee(
                id: employee.id,
                name: employee.name,
                mobileNumber: employee.mobileNumber,
                salary: employee.salary,
                customFields: employee.customFields,
                salaries: updatedSalaries,
              );

              await Provider.of<QuotationController>(
                context,
                listen: false,
              ).saveEmployee(updatedEmp);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salary record deleted.')),
                );
              }
            },
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF2E7D32); // Green
      case 'pending':
        return const Color(0xFFEF6C00); // Orange
      case 'processing':
        return const Color(0xFF1565C0); // Blue
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteController = Provider.of<QuotationController>(context);

    // Watch for the latest employee updates reactively
    final latestEmployee = quoteController.employees.firstWhere(
      (e) => e.id == widget.employee.id,
      orElse: () => widget.employee,
    );

    final workHistory = _getWorkHistory(quoteController, latestEmployee.name);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A1A),
        title: Text(
          latestEmployee.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Profile Summary Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(
                            0xFF6A11CB,
                          ).withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            size: 28,
                            color: Color(0xFF6A11CB),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestEmployee.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    latestEmployee.mobileNumber,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Monthly Salary Rate",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${latestEmployee.salary.toStringAsFixed(0)}/mo",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF2E7D32),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Total Paid Salaries",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${latestEmployee.salaries.where((s) => s.status == 'completed').fold(0.0, (sum, s) => sum + s.amount).toStringAsFixed(0)}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF1565C0),
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (latestEmployee.customFields.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        "Additional Information",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: latestEmployee.customFields.entries.map((
                          entry,
                        ) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              "${entry.key}: ${entry.value}",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
            ),
            const SizedBox(height: 24),

            // Work History / Client Projects Section
            Row(
              children: [
                const Icon(
                  Icons.business_center,
                  size: 20,
                  color: Color(0xFF6A11CB),
                ),
                const SizedBox(width: 8),
                Text(
                  "Work History & Clients",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (workHistory.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      "No client work logged for this employee yet.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workHistory.length,
                itemBuilder: (context, index) {
                  final work = workHistory[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        work['clientName'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "${work['docType']} Ref: ${work['docNo']}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "Assigned: ${DateFormat('dd MMM yyyy').format(work['date'] as DateTime)}",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            work['status'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(
                              work['status'],
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          (work['status'] as String).toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: _getStatusColor(work['status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Salaries Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 20,
                        color: Color(0xFF6A11CB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Salary Payout History",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () =>
                      _showAddSalaryDialog(context, latestEmployee),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: Text(
                    "Add Payout",
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6A11CB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (latestEmployee.salaries.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      "No salary payouts logged yet. Tap 'Add Payout' above to start.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: latestEmployee.salaries.length,
                itemBuilder: (context, index) {
                  final salary = latestEmployee.salaries[index];
                  final formattedDate = DateFormat(
                    'dd MMM yyyy',
                  ).format(salary.date);
                  final isPaid = salary.status == 'completed';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isPaid
                                ? Colors.green[50]
                                : Colors.orange[50],
                            child: Icon(
                              isPaid
                                  ? Icons.check_circle
                                  : Icons.hourglass_empty,
                              color: isPaid
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "₹${salary.amount.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Toggle Status Badge
                          GestureDetector(
                            onTap: () =>
                                _toggleSalaryStatus(latestEmployee, salary),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isPaid
                                            ? Colors.green[700]!
                                            : Colors.orange[700]!)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      (isPaid
                                              ? Colors.green[700]!
                                              : Colors.orange[700]!)
                                          .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    salary.status.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: isPaid
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.swap_horiz,
                                    size: 11,
                                    color: isPaid
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteSalaryRecord(
                              context,
                              latestEmployee,
                              salary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
