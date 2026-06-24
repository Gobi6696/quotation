import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/employee_model.dart';
import 'employee_detail_screen.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  void _showAddEditEmployeeSheet({Employee? employee}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: employee?.name ?? "");
    final phoneController = TextEditingController(text: employee?.mobileNumber ?? "");
    final salaryController = TextEditingController(
      text: employee != null ? employee.salary.toStringAsFixed(0) : "",
    );

    // Dynamic custom fields lists
    final List<TextEditingController> keyControllers = [];
    final List<TextEditingController> valueControllers = [];

    if (employee != null) {
      employee.customFields.forEach((key, val) {
        keyControllers.add(TextEditingController(text: key));
        valueControllers.add(TextEditingController(text: val.toString()));
      });
    }

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
                        employee == null ? 'Onboard New Employee' : 'Edit Employee Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Name
                      _buildModalTextField('Full Name', nameController, (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        return null;
                      }),

                      // Phone
                      _buildModalTextField(
                        'Mobile Number', 
                        phoneController, 
                        (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (val.trim().length != 10) return 'Must be 10 digits';
                          return null;
                        },
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),

                      // Salary
                      _buildModalTextField(
                        'Monthly Salary (₹)', 
                        salaryController, 
                        (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Must be a valid number';
                          return null;
                        },
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      
                      // Dynamic Custom Fields section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Custom Details / Fields',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF6A11CB),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                keyControllers.add(TextEditingController());
                                valueControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Field'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (keyControllers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'No custom fields added yet. Tap "Add Field" to append details like Role, Address, Email, etc.',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ),

                      ...List.generate(keyControllers.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: keyControllers[idx],
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Field Title',
                                    hintText: 'e.g. Role, Joining Date',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: valueControllers[idx],
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Field Value',
                                    hintText: 'e.g. Welder, 12 June 2026',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () {
                                  setModalState(() {
                                    keyControllers[idx].dispose();
                                    valueControllers[idx].dispose();
                                    keyControllers.removeAt(idx);
                                    valueControllers.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 25),
                      
                      // Submit Row
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A11CB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setModalState(() {
                                          isSaving = true;
                                        });

                                        final Map<String, dynamic> customFields = {};
                                        for (int i = 0; i < keyControllers.length; i++) {
                                          if (keyControllers[i].text.trim().isNotEmpty) {
                                            customFields[keyControllers[i].text.trim()] =
                                                valueControllers[i].text.trim();
                                          }
                                        }

                                        final newEmp = Employee(
                                          id: employee?.id ?? const Uuid().v4(),
                                          name: nameController.text.trim(),
                                          mobileNumber: phoneController.text.trim(),
                                          salary: double.tryParse(salaryController.text.trim()) ?? 0.0,
                                          customFields: customFields,
                                        );

                                        await Provider.of<QuotationController>(
                                          context,
                                          listen: false,
                                        ).saveEmployee(newEmp);

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                employee == null
                                                    ? 'Employee onboarded successfully!'
                                                    : 'Employee updated successfully!',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Save Details',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
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
    String? Function(String?)? validator, {
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[50],
          counterText: "",
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
            borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Delete Employee',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${employee.name}? This will remove them from local storage and sync to Google Drive.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<QuotationController>(
                context,
                listen: false,
              ).deleteEmployee(employee.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee profile deleted.')),
                );
              }
            },
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
  }

  @override
  Widget build(BuildContext context) {
    final quoteController = Provider.of<QuotationController>(context);
    final list = quoteController.employees.where((emp) {
      final nameMatches = emp.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatches = emp.mobileNumber.contains(_searchQuery);
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Employees',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditEmployeeSheet(),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // Search Bar Section
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
                hintText: 'Search by name or mobile number...',
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Employees List
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching employees found'
                                : 'No employees onboarded yet',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching using a different name or number.'
                                : 'Tap the + button to onboard your first employee.',
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final emp = list[index];
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Color(0xFF6A11CB),
                                  width: 5,
                                ),
                              ),
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
                                          emp.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, color: Colors.indigo, size: 20),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EmployeeDetailScreen(employee: emp),
                                                ),
                                              );
                                            },
                                            tooltip: 'View Profile',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            onPressed: () => _showAddEditEmployeeSheet(employee: emp),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () => _showDeleteDialog(context, emp),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        emp.mobileNumber,
                                        style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13),
                                      ),
                                      const SizedBox(width: 20),
                                      const Icon(Icons.wallet, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        '₹${emp.salary.toStringAsFixed(0)}/mo',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (emp.customFields.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: emp.customFields.entries.map((entry) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                          child: Text(
                                            '${entry.key}: ${entry.value}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[800],
                                              fontWeight: FontWeight.w500,
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
