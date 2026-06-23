import 'package:flutter/material.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Settings _settings = Settings();
  final TextEditingController _urlController = TextEditingController();
  String _safeSearch = '0';
  bool _loading = true;

  final Map<String, String> _safeSearchLabels = {
    '0': 'Nada',
    '1': 'Moderada',
    '2': 'Rigorosa',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _settings.getURL();
    final safe = await _settings.getSafeSearch();
    setState(() {
      _urlController.text = url;
      _safeSearch = safe;
      _loading = false;
    });
  }

  Future<void> _saveURL() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _settings.setURL(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL salva com sucesso'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSafeSearchSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Pesquisa Segura',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ..._safeSearchLabels.entries.map((entry) {
                  final selected = _safeSearch == entry.key;
                  return ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 16,
                        color: selected
                            ? const Color(0xFF4285F4)
                            : const Color(0xFF1a1a1a),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF4285F4))
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.grey),
                    onTap: () async {
                      await _settings.setSafeSearch(entry.key);
                      setState(() => _safeSearch = entry.key);
                      if (mounted) Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5f6368)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
            color: Color(0xFF1a1a1a),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4285F4)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // URL do SearXNG
                const Text(
                  'Instância SearXNG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4285F4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1a1a1a),
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://sua-instancia.com',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: Color(0xFF4285F4)),
                        onPressed: _saveURL,
                        tooltip: 'Salvar URL',
                      ),
                    ),
                    onSubmitted: (_) => _saveURL(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'URL da sua instância SearXNG no Railway ou outro servidor',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),

                const SizedBox(height: 32),
                const Divider(height: 1, color: Color(0xFFe8eaed)),
                const SizedBox(height: 32),

                // SafeSearch
                const Text(
                  'Privacidade',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4285F4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _showSafeSearchSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesquisa Segura',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1a1a1a),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _safeSearchLabels[_safeSearch] ?? 'Nada',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF5f6368)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Sobre
                const Divider(height: 1, color: Color(0xFFe8eaed)),
                const SizedBox(height: 24),
                const Text(
                  'Sobre',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4285F4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SearxGo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buscador privado usando SearXNG.\nResultados abertos via DuckDuckGo.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
