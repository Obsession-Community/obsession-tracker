import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

/// In-app document viewer for text files and PDFs.
///
/// Supports:
/// - Text files (.txt, .md, .rtf, .json, .xml, .csv, etc.)
/// - PDF files (.pdf)
class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.title,
    required this.filePath,
  });

  final String title;
  final String filePath;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final String _extension;
  bool _isLoading = true;
  String? _error;

  // For text files
  String? _textContent;

  // For PDF files
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _extension = widget.filePath.split('.').last.toLowerCase();
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        setState(() {
          _error = 'File not found';
          _isLoading = false;
        });
        return;
      }

      if (_isPdf) {
        await _loadPdf(file);
      } else {
        await _loadTextFile(file);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTextFile(File file) async {
    try {
      final content = await file.readAsString();
      setState(() {
        _textContent = content;
        _isLoading = false;
      });
    } catch (e) {
      // Try reading as bytes if string decode fails
      try {
        final bytes = await file.readAsBytes();
        final content = String.fromCharCodes(bytes);
        setState(() {
          _textContent = content;
          _isLoading = false;
        });
      } catch (e2) {
        setState(() {
          _error = 'Unable to read file contents';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPdf(File file) async {
    try {
      // PdfControllerPinch expects a Future<PdfDocument>
      final documentFuture = PdfDocument.openFile(file.path);
      final document = await documentFuture;
      setState(() {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(file.path),
        );
        _totalPages = document.pagesCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to open PDF: $e';
        _isLoading = false;
      });
    }
  }

  bool get _isPdf => _extension == 'pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Copy button for text files
          if (!_isPdf && _textContent != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to clipboard',
              onPressed: _copyToClipboard,
            ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareDocument,
          ),
        ],
      ),
      body: _buildBody(),
      // Page navigation for PDFs
      bottomNavigationBar: _isPdf && _pdfController != null && _totalPages > 1
          ? _buildPdfNavigation()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _shareDocument,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with other app'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdf) {
      return _buildPdfViewer();
    } else {
      return _buildTextViewer();
    }
  }

  Widget _buildTextViewer() {
    if (_textContent == null) {
      return const Center(child: Text('No content'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _textContent!,
        style: TextStyle(
          fontFamily: _isCodeFile ? 'monospace' : null,
          fontSize: _isCodeFile ? 13 : 15,
          height: 1.5,
        ),
      ),
    );
  }

  bool get _isCodeFile {
    return [
      'json', 'xml', 'html', 'htm',
      'gpx', 'kml', 'yaml', 'yml',
      'ini', 'cfg', 'conf', 'log',
      'csv', 'tsv',
    ].contains(_extension);
  }

  Widget _buildPdfViewer() {
    if (_pdfController == null) {
      return const Center(child: Text('Unable to load PDF'));
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (_, error) => Center(
          child: Text('Error loading page: $error'),
        ),
      ),
    );
  }

  Widget _buildPdfNavigation() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: _currentPage > 1
                  ? () => _pdfController?.jumpToPage(1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => _pdfController?.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              'Page $_currentPage of $_totalPages',
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages
                  ? () => _pdfController?.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: _currentPage < _totalPages
                  ? () => _pdfController?.jumpToPage(_totalPages)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard() {
    if (_textContent == null) return;

    Clipboard.setData(ClipboardData(text: _textContent!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _shareDocument() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        subject: widget.title,
      ),
    );
  }
}
