import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const ChatEcoApp());
}

class ChatEcoApp extends StatelessWidget {
  const ChatEcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat de Eco',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatEcoPage(),
    );
  }
}

class Mensagem {
  const Mensagem({
    required this.texto,
    required this.origem,
    required this.horario,
  });

  final String texto;
  final String origem;
  final DateTime horario;
}

class ChatEcoPage extends StatefulWidget {
  const ChatEcoPage({super.key});

  @override
  State<ChatEcoPage> createState() => _ChatEcoPageState();
}

class _ChatEcoPageState extends State<ChatEcoPage> {
  final TextEditingController _mensagemController = TextEditingController();
  final TextEditingController _urlController = TextEditingController(
    text: 'wss://echo.websocket.events',
  );

  final StreamController<List<Mensagem>> _mensagensController =
      StreamController<List<Mensagem>>.broadcast();

  final List<Mensagem> _mensagens = [];
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;

  bool _conectado = false;
  bool _conectando = false;
  String _status = 'Desconectado';

  @override
  void initState() {
    super.initState();
    _emitirMensagens();
  }

  void _emitirMensagens() {
    if (!_mensagensController.isClosed) {
      _mensagensController.add(List.unmodifiable(_mensagens));
    }
  }

  void _atualizarStatus(String novoStatus) {
    setState(() {
      _status = novoStatus;
    });
  }

  void _marcarComoDesconectado() {
    setState(() {
      _conectado = false;
      _conectando = false;
      _channel = null;
    });
  }

  Future<void> _conectar() async {
    if (_conectando || _conectado) return;

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _atualizarStatus('Informe uma URL WebSocket.');
      return;
    }

    setState(() {
      _conectando = true;
      _status = 'Conectando...';
    });

    try {
      final uri = Uri.parse(url);
      final channel = WebSocketChannel.connect(uri);

      await channel.ready.timeout(const Duration(seconds: 8));

      _channel = channel;
      _socketSubscription = channel.stream.listen(
        (event) {
          _adicionarMensagem(texto: event.toString(), origem: 'Servidor');
        },
        onError: (error) {
          _atualizarStatus('Erro na conexão: $error');
          _marcarComoDesconectado();
        },
        onDone: () {
          _atualizarStatus('Conexão encerrada pelo servidor.');
          _marcarComoDesconectado();
        },
      );

      setState(() {
        _conectado = true;
        _conectando = false;
        _status = 'Conectado em $url';
      });
    } on TimeoutException {
      setState(() {
        _conectando = false;
        _status = 'Tempo esgotado ao conectar.';
      });
    } catch (error) {
      setState(() {
        _conectando = false;
        _status = 'Não foi possível conectar: $error';
      });
    }
  }

  void _desconectar() async {
    if (_channel != null) {
      _atualizarStatus('Desconectando...');
      await _socketSubscription?.cancel();
      await _channel?.sink.close();
      _marcarComoDesconectado();
      _atualizarStatus('Desconectado');
    }
  }

  void _adicionarMensagem({required String texto, required String origem}) {
    _mensagens.add(
      Mensagem(texto: texto, origem: origem, horario: DateTime.now()),
    );
    _emitirMensagens();
  }

  void _enviarMensagem() {
    final texto = _mensagemController.text.trim();

    if (!_conectado || _channel == null) {
      _atualizarStatus('Conecte antes de enviar.');
      return;
    }
    if (texto.isEmpty) return;

    _channel!.sink.add(texto);
    _adicionarMensagem(texto: texto, origem: 'Você');
    _mensagemController.clear();
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    _urlController.dispose();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _mensagensController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat de Eco - WebSockets'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    enabled: !_conectado && !_conectando,
                    decoration: const InputDecoration(
                      labelText: 'URL WebSocket',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _conectando
                      ? null
                      : (_conectado ? _desconectar : _conectar),
                  child: Text(_conectado ? 'Desconectar' : 'Conectar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              color: Colors.grey[200],
              child: Text(
                'Status: $_status',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Mensagem>>(
                stream: _mensagensController.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma mensagem por enquanto.'),
                    );
                  }
                  final lista = snapshot.data!;
                  return ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final msg = lista[index];
                      final isMe = msg.origem == 'Você';
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.teal[100] : Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${msg.origem}: ${msg.texto}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensagemController,
                    enabled: _conectado,
                    decoration: const InputDecoration(
                      hintText: 'Digite uma mensagem...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _conectado ? _enviarMensagem : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
