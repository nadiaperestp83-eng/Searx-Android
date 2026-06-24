import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'settings.dart';
import 'settingsPage.dart';
import 'browser_page.dart';

void main() => runApp(const SearxGoApp());

class SearxGoApp extends StatelessWidget {
  const SearxGoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SearxGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF5f6368)),
        ),
      ),
      home: const SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Settings _settings = Settings();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  String _safeSearch = '0';

  @override
  void initState() {
    super.initState();
    // Só atualiza o botão X — NÃO dispara busca
    _controller.addListener(() => setState(() {}));
    _loadSafeSearch();
  }

  Future<void> _loadSafeSearch() async {
    final safe = await _settings.getSafeSearch();
    setState(() => _safeSearch = safe);
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _focusNode.unfocus();
    final baseURL = await _settings.getURL();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
      _results = [];
    });

    try {
      final uri = Uri.parse(
        '$baseURL/search?q=${Uri.encodeComponent(q)}&format=json&safesearch=$_safeSearch',
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> raw = data['results'] ?? [];
        setState(() {
          _results = raw.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro ${response.statusCode}. Verifique a URL nas configurações.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sem conexão ou instância indisponível.';
        _isLoading = false;
      });
    }
  }

  void _openUrl(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BrowserPage(url: url)),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host;
    } catch (_) {
      return url;
    }
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _results = [];
      _hasSearched = false;
      _errorMessage = '';
      _isLoading = false;
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _hasSearched
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF5f6368)),
                onPressed: _clearSearch,
              ),
              title: _buildSearchBar(compact: true),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFF5f6368)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ).then((_) => _loadSafeSearch()),
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFF5f6368)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ).then((_) => _loadSafeSearch()),
                ),
              ],
            ),
      body: _hasSearched ? _buildResultsPage() : _buildHomePage(),
    );
  }

  Widget _buildHomePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SearxGo',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w300,
                color: Color(0xFF4285F4),
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 32),
            _buildSearchBar(compact: false),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _search(_controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F3F4),
                foregroundColor: const Color(0xFF1a1a1a),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Pesquisa Privada', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar({required bool compact}) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: compact ? const Color(0xFFF1F3F4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: compact
            ? null
            : Border.all(color: const Color(0xFFdfe1e5), width: 1),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16, color: Color(0xFF1a1a1a)),
        decoration: InputDecoration(
          hintText: 'Pesquisar...',
          hintStyle: const TextStyle(color: Color(0xFF9aa0a6), fontSize: 16),
          prefixIcon: GestureDetector(
            onTap: () => _search(_controller.text),
            child: const Icon(Icons.search, color: Color(0xFF9aa0a6), size: 22),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9aa0a6), size: 20),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildResultsPage() {
    return Column(
      children: [
        if (_isLoading)
          const LinearProgressIndicator(
            color: Color(0xFF4285F4),
            backgroundColor: Color(0xFFe8eaed),
          ),

        if (_errorMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFF3E0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Color(0xFFE65100), fontSize: 14),
            ),
          ),

        Expanded(
          child: _results.isEmpty && !_isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      if (_errorMessage.isEmpty)
                        Text(
                          'Nenhum resultado encontrado',
                          style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final item = _results[i];
                    final title = item['title'] ?? 'Sem título';
                    final url = item['url'] ?? '';
                    final content = item['content'] ?? '';
                    final domain = _extractDomain(url);

                    return InkWell(
                      onTap: () => _openUrl(url),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F3F4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.language,
                                      size: 12, color: Color(0xFF5f6368)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  domain,
                                  style: const TextStyle(
                                      color: Color(0xFF202124), fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF1a0dab),
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (content.isNotEmpty)
                              Text(
                                content,
                                style: const TextStyle(
                                  color: Color(0xFF4d5156),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFe8eaed)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
