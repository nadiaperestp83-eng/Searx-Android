import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buscador Privado',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.grey[700]),
        ),
      ),
      home: SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // ⚠️ SUBSTITUA PELA SUA URL DO RAILWAY
  final String _baseUrl = 'https://searxng-railway-production-9bcc.up.railway.app';

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _results = [];
    });

    try {
      final url = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        setState(() => _results = results.cast<Map<String, dynamic>>());
      } else {
        setState(() => _errorMessage = 'Erro: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro de conexão: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buscador Privado', style: TextStyle(color: Colors.grey[800])),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de pesquisa estilo Google
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            setState(() {
                              _controller.clear();
                              _results = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (text) => setState(() {}),
                onSubmitted: (value) => _search(value),
              ),
            ),
          ),

          // Loading
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.blue),
            ),

          // Erro
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
            ),

          // Resultados estilo Google
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final item = _results[i];
                final title = item['title'] ?? 'Sem título';
                final url = item['url'] ?? '';
                final content = item['content'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Abrir URL (futuro)
                        },
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _extractDomain(url),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        content,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
}
