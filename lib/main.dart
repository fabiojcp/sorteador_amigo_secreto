import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:asuka/asuka.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:observe_internet_connectivity/observe_internet_connectivity.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sorteador de amigo secreto',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sorteador Amigo Secreto'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<TextEditingController> nomeControllers = [TextEditingController()];

  List<TextEditingController> emailControllers = [TextEditingController()];

  TextEditingController mensagemController = TextEditingController();

  Map<String, String> emails = {};

  Map<String, String> imagens = {};

  int index = 0;

  final username = 'sorteiopaul@gmail.com';
  final password = 'lifc jmwx vkvt bznu';

  Future<bool> checkInternetConection() async {
    final hasInternet = await InternetConnectivity().hasInternetConnection;
    if (!hasInternet) {
      AsukaSnackbar.alert(
              "Conexão com internet instável ou não existente, tente novamente")
          .show();
    }
    return hasInternet;
  }

  Future<String> encodeImageToBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> generateHtml(
    String nomeRemetente,
    String nomeSorteado,
  ) async {
    return """
<p>Opa $nomeRemetente, você sorteou:</p>
<h1>$nomeSorteado!</h1>
<p>${mensagemController.text}</p>
""";
  }

  sendEmail(
      {required String email,
      required String nomeSorteado,
      required String nomeRemetente}) async {
    if (await checkInternetConection() == false) {
      return;
    }

    final smtpServer = gmail(username, password);

    final imagePath = imagens[nomeSorteado]!;

    final htmlContent = await generateHtml(nomeRemetente, nomeSorteado);

    final message = Message()
      ..from = Address(username, 'Sorteador do Fábio')
      ..recipients.add(email)
      ..subject = 'Amigo Secreto dos Viados 😀}'
      ..html = htmlContent
      ..attachments.add(FileAttachment(File(imagePath))..cid = nomeRemetente);

    try {
      await send(message, smtpServer);
      if (kDebugMode) {
        print('Email $nomeRemetente enviado');
      }
    } on MailerException catch (e) {
      if (kDebugMode) {
        print('Message not sent.');
      }
      for (var p in e.problems) {
        if (kDebugMode) {
          print('Problem: ${p.code}: ${p.msg}');
        }
      }
    }
  }

  Future<String> sortearNomes({
    required String nomeEnvio,
    required List<String> nomesSorteados,
  }) async {
    // Sortear um nome e um email da lista de emails onde não pode ser o nomeEnvio e nem um nomeSorteado
    final random = Random();
    final nomes = emails.keys.toList();
    final nomeSorteado = nomes[random.nextInt(nomes.length)];
    if (nomeSorteado == nomeEnvio || nomesSorteados.contains(nomeSorteado)) {
      return sortearNomes(nomeEnvio: nomeEnvio, nomesSorteados: nomesSorteados);
    }
    return nomeSorteado;
  }

  Future<bool> sortear() async {
    try {
      List<String> nomesSorteados = [];
      String nomeSorteado = '';

      for (var nome in emails.keys) {
        nomeSorteado =
            await sortearNomes(nomeEnvio: nome, nomesSorteados: nomesSorteados);
        nomesSorteados.add(nomeSorteado);
        try {
          sendEmail(
              email: emails[nome]!,
              nomeSorteado: nomeSorteado,
              nomeRemetente: nome);
          nomeSorteado = '';
        } on Error {
          return false;
        }
      }
    } on Error {
      return false;
    }
    return true;
  }

  Future<bool> pegarImagem({required String nome}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      imagens.addAll(
        {
          nome: result.files.single.path!,
        },
      );
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemCount: emails.length + 1,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        enabled: index == emails.length,
                        controller: nomeControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Nome',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        enabled: index == emails.length,
                        controller: emailControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Email',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 24,
                        height: 24,
                        child: index == emails.length
                            ? const Icon(Icons.check_circle, color: Colors.grey)
                            : const Icon(Icons.check_circle,
                                color: Colors.green)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                showDialog(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(builder: (context, setState) {
                        return AlertDialog(
                          title:
                              const Text('Confirme os dados antes de enviar!'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < emails.length; i++)
                                ListTile(
                                  onTap: () async {
                                    if (await pegarImagem(
                                      nome: nomeControllers[i].text,
                                    )) {
                                      setState(() {});
                                    }
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundImage: imagens.containsKey(
                                      nomeControllers[i].text,
                                    )
                                        ? FileImage(
                                            File(imagens[
                                                nomeControllers[i].text]!),
                                          )
                                        : null,
                                    child: imagens.containsKey(
                                            nomeControllers[i].text)
                                        ? Container()
                                        : Text(
                                            nomeControllers[i]
                                                .text[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              height: 0.0,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                  title: Text(nomeControllers[i].text),
                                  subtitle: Text(emailControllers[i].text),
                                ),
                              const SizedBox(
                                height: 12,
                              ),
                              TextField(
                                controller: mensagemController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Digite uma mensagem para o amigo secreto',
                                  hintStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal),
                                  labelText: 'Mensagem (opcional)',
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (await sortear()) {
                                  AsukaSnackbar.success(
                                      'Emails enviados com sucesso!');
                                } else {
                                  AsukaSnackbar.alert('Erro ao enviar emails');
                                }
                                Navigator.pop(context);
                              },
                              child: const Text('Sortear'),
                            ),
                          ],
                        );
                      });
                    });
              },
              child: const Text('Enviar Email'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nome = nomeControllers[index].text.trim();
          final email = emailControllers[index].text.trim();

          if (nome.isEmpty || email.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Por favor, preencha ambos os campos!'),
              ),
            );
            return;
          }

          setState(() {
            emails.addAll({
              nome: email,
            });
            nomeControllers.add(TextEditingController());
            emailControllers.add(TextEditingController());
            index++;
          });
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
