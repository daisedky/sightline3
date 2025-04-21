import 'package:flutter/material.dart';
import '../controllers/document_controller.dart';

class ViewAllScreen extends StatefulWidget {
  const ViewAllScreen({super.key});

  @override
  ViewAllScreenState createState() => ViewAllScreenState();
}

class ViewAllScreenState extends State<ViewAllScreen> {
  late DocumentController _documentController;

  @override
  void initState() {
    super.initState();
    _documentController = DocumentController();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    await _documentController.fetchUserDocuments();
    setState(() {}); // Trigger UI rebuild
  }

  @override
  Widget build(BuildContext context) {
    final files = _documentController.documents;

    return Scaffold(
      appBar: AppBar(
        title: Text('All Recent Files'),
        backgroundColor: Color(0xFF1E90FF),
      ),
      body: Container(
        color: Colors.white,
        child: files.isEmpty
            ? Center(
                child: Text(
                  'No files uploaded yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16.0),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(
                        file.fileType == 'pdf'
                            ? Icons.picture_as_pdf
                            : Icons.insert_drive_file,
                        color: Color(0xFF1E90FF),
                        size: 40,
                      ),
                      title: Text(
                        file.fileName.length > 20
                            ? '${file.fileName.substring(0, 20)}...'
                            : file.fileName,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        file.uploadedAt.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tapped: ${file.fileName}')),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
