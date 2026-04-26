import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../../controllers/quotation_controller.dart';
import '../quotation/quotation_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/template_editor_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _showLogoutDialog(
    BuildContext context,
    AuthController authController,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
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
              await authController.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Logout',
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
    final authController = Provider.of<AuthController>(context);
    final quoteController = Provider.of<QuotationController>(context);
    final photoURL =
        authController.user?.photoURL ??
        authController.localUserData?['photoURL'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Quotation Master',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF6A11CB)),
            onPressed: () async {
              await quoteController.syncWithDrive();
              if (context.mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Sync completed')));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ),
              child: photoURL != null && photoURL.isNotEmpty
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(photoURL),
                    )
                  : const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, size: 18),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back,',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            authController.user?.displayName ?? 'User',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionTitle('Quotation Management'),
            Row(
              children: [
                _buildMenuCard(
                  context,
                  'New Quote',
                  Icons.add_circle,
                  const Color(0xFF6A11CB),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuotationEditorScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                _buildMenuCard(
                  context,
                  'History',
                  Icons.history,
                  Colors.orange,
                  () => _showHistoryBottomSheet(context, quoteController),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildSectionTitle('PDF Designer'),
            Row(
              children: [
                _buildMenuCard(
                  context,
                  'Header/Footer',
                  Icons.design_services,
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TemplateEditorScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                _buildMenuCard(
                  context,
                  'First/Last Page',
                  Icons.description,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
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

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: FadeInUp(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 40),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryBottomSheet(
    BuildContext context,
    QuotationController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Quotation History',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Expanded(
              child: Consumer<QuotationController>(
                builder: (context, quoteController, _) {
                  return quoteController.quotations.isEmpty
                      ? Center(
                          child: Text(
                            'No history found',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: quoteController.quotations.length,
                          itemBuilder: (context, i) {
                            final q = quoteController.quotations[i];
                            return Dismissible(
                              key: Key(q.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      'Delete Quotation',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete this quotation? This will also remove it from Google Drive.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                              },
                              onDismissed: (direction) async {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }

                                await quoteController.deleteQuotation(q.id);

                                if (context.mounted) {
                                  Navigator.pop(context); // Close loader
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Quotation deleted'),
                                    ),
                                  );
                                }
                              },
                              child: ListTile(
                                title: Text(
                                  q.clientName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(q.quoteNumber),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${q.grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF6A11CB),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              'Delete Quotation',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this quotation? This will also remove it from Google Drive.',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: Text(
                                                  'Cancel',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
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

                                        if (confirmed == true) {
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          }

                                          await quoteController
                                              .deleteQuotation(q.id);

                                          if (context.mounted) {
                                            Navigator.pop(
                                                context); // Close loader
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Quotation deleted'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          QuotationEditorScreen(quotation: q),
                                    ),
                                  );
                                },
                              ),
                            );
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
}
