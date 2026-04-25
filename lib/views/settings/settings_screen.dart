import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/quotation_controller.dart';
import 'template_editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text('Layout Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(25),
        children: [
          _buildMenuTile(
            context,
            'Full PDF Designer',
            'Customize Header, Footer, First & Last Pages',
            Icons.dashboard_customize,
            const Color(0xFF6A11CB),
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TemplateEditorScreen())),
          ),
          const SizedBox(height: 20),
          _buildMenuTile(
            context,
            'Sync with Google Drive',
            'Restore or Backup your data manually',
            Icons.cloud_sync,
            const Color(0xFF2575FC),
            () async {
              final controller = Provider.of<QuotationController>(context, listen: false);
              await controller.syncWithDrive();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync completed!')),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          _buildInfoBox(),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
          const SizedBox(height: 10),
          _infoLine('1. Go to Designer.'),
          _infoLine('2. Add content to Header, Footer, First or Last page tabs.'),
          _infoLine('3. Everything is saved to Local & Google Drive automatically.'),
        ],
      ),
    );
  }

  Widget _infoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue.shade700)),
    );
  }
}
