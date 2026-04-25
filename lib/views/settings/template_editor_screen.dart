import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/quotation_controller.dart';
import '../../models/company_settings.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PdfElement> _headers = [];
  List<PdfElement> _footers = [];
  List<PdfElement> _firstPage = [];
  List<PdfElement> _lastPage = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final settings = context.read<QuotationController>().settings;
    if (settings != null) {
      _headers = List.from(settings.headerElements);
      _footers = List.from(settings.footerElements);
      _firstPage = List.from(settings.firstPageElements);
      _lastPage = List.from(settings.lastPageElements);
    }
  }

  void _addElement(List<PdfElement> list, PdfElementType type) async {
    String content = "New Text";
    if (type == PdfElementType.image) {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img == null) return;
      content = img.path;
    }

    setState(() {
      list.add(
        PdfElement(
          id: const Uuid().v4(),
          type: type,
          content: content,
          size: type == PdfElementType.text ? 12 : 30,
        ),
      );
    });
  }

  Future<void> _save() async {
    final settings = CompanySettings(
      headerElements: _headers,
      footerElements: _footers,
      firstPageElements: _firstPage,
      lastPageElements: _lastPage,
    );
    await context.read<QuotationController>().saveSettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Templates saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Layout Designer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Header'),
            Tab(text: 'Footer'),
            Tab(text: 'First Page'),
            Tab(text: 'Last Page'),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDesignerList(_headers),
          _buildDesignerList(_footers),
          _buildDesignerList(_firstPage),
          _buildDesignerList(_lastPage),
        ],
      ),
    );
  }

  Widget _buildDesignerList(List<PdfElement> list) {
    return Column(
      children: [
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No elements added yet',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _buildElementCard(list, i),
                ),
        ),
        _buildAddButtons(list),
      ],
    );
  }

  Widget _buildAddButtons(List<PdfElement> list) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _addElement(list, PdfElementType.text),
            icon: const Icon(Icons.text_fields),
            label: const Text('Add Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A11CB),
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _addElement(list, PdfElementType.image),
            icon: const Icon(Icons.image),
            label: const Text('Add Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2575FC),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementCard(List<PdfElement> list, int index) {
    final el = list[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              el.type == PdfElementType.text ? Icons.text_snippet : Icons.image,
              size: 20,
              color: Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                el.type == PdfElementType.text ? el.content : "Image Element",
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            Text(
              el.position.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                if (el.type == PdfElementType.text)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _formatButton(el, "**", "B"),
                            _formatButton(el, "_", "I"),
                            _formatButton(el, "~~", "S"),
                          ],
                        ),
                        const Divider(),
                        TextField(
                          onChanged: (val) => setState(() => el.content = val),
                          maxLines: null,
                          minLines: 5,
                          keyboardType: TextInputType.multiline,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Type your long text here...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          controller: TextEditingController(text: el.content)
                            ..selection = TextSelection.collapsed(
                              offset: el.content.length,
                            ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Position:'),
                    ToggleButtons(
                      isSelected: [
                        el.position == PdfElementPosition.left,
                        el.position == PdfElementPosition.center,
                        el.position == PdfElementPosition.right,
                      ],
                      onPressed: (idx) {
                        setState(() {
                          if (idx == 0) el.position = PdfElementPosition.left;
                          if (idx == 1) el.position = PdfElementPosition.center;
                          if (idx == 2) el.position = PdfElementPosition.right;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      children: const [
                        Icon(Icons.align_horizontal_left),
                        Icon(Icons.align_horizontal_center),
                        Icon(Icons.align_horizontal_right),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      el.type == PdfElementType.text
                          ? 'Font Size:'
                          : 'Image Width:',
                    ),
                    Expanded(
                      child: Slider(
                        value: el.size,
                        min: 5,
                        max: 300,
                        onChanged: (val) => setState(() => el.size = val),
                      ),
                    ),
                    Text(el.size.toInt().toString()),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(() => list.removeAt(index)),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatButton(PdfElement el, String marker, String label) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: () {
        setState(() {
          el.content = "$marker${el.content}$marker";
        });
      },
      icon: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: label == "B" ? FontWeight.bold : FontWeight.normal,
          fontStyle: label == "I" ? FontStyle.italic : FontStyle.normal,
          decoration: label == "S" ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
