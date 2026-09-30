import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../core/sessao/modelos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import 'admin_repo.dart';

const _nomesDosDias = {
  'seg': 'Segunda',
  'ter': 'Terça',
  'qua': 'Quarta',
  'qui': 'Quinta',
  'sex': 'Sexta',
  'sab': 'Sábado',
  'dom': 'Domingo',
};

final _formatoHora = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Confere o horário comercial antes de enviar (F06, item 19): formato `HH:MM`
/// e início antes do fim. Devolve a mensagem do primeiro problema, ou `null`.
String? validarHorario(Map<String, List<List<String>>> horario) {
  for (final dia in diasDaSemana) {
    for (final intervalo in horario[dia] ?? const <List<String>>[]) {
      final nome = _nomesDosDias[dia];
      if (intervalo.length != 2 || !intervalo.every(_formatoHora.hasMatch)) {
        return '$nome: use o formato HH:MM.';
      }
      if (intervalo[0].compareTo(intervalo[1]) >= 0) {
        return '$nome: o início (${intervalo[0]}) precisa ser antes do fim '
            '(${intervalo[1]}).';
      }
    }
  }
  return null;
}

/// Configuração da loja (F06, itens 17 a 21).
class LojaTela extends ConsumerStatefulWidget {
  const LojaTela({super.key});

  @override
  ConsumerState<LojaTela> createState() => _LojaTelaState();
}

class _LojaTelaState extends ConsumerState<LojaTela> {
  final _formulario = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _sla = TextEditingController();
  final _retencao = TextEditingController();
  Map<String, List<List<String>>> _horario = {};
  Map<String, double> _pesos = {};
  bool _carregado = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Os valores atuais vêm de `GET /me`.
    ref
        .read(sessaoProvider.notifier)
        .recarregar()
        .then((_) {}, onError: (_) {})
        .whenComplete(() {
          if (!mounted) return;
          final loja = ref.read(sessaoProvider).loja;
          if (loja != null) setState(() => _preencher(loja));
        });
  }

  void _preencher(Loja loja) {
    _nome.text = loja.nome;
    _sla.text = '${loja.slaRespostaMin}';
    _retencao.text = '${loja.retencaoMeses}';
    _horario = {
      for (final dia in diasDaSemana)
        dia: [
          for (final i in loja.horarioComercial[dia] ?? const <List<String>>[])
            [...i],
        ],
    };
    _pesos = {for (final c in criterios.keys) c: loja.pesosCriterios[c] ?? 1};
    _carregado = true;
  }

  @override
  void dispose() {
    _nome.dispose();
    _sla.dispose();
    _retencao.dispose();
    super.dispose();
  }

  Future<void> _escolherHora(String dia, int intervalo, int ponta) async {
    final partes = _horario[dia]![intervalo][ponta].split(':');
    final escolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(partes.first) ?? 8,
        minute: int.tryParse(partes.last) ?? 0,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhida == null) return;
    setState(() {
      _horario[dia]![intervalo][ponta] =
          '${escolhida.hour.toString().padLeft(2, '0')}:'
          '${escolhida.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _salvar() async {
    if (_salvando || !_formulario.currentState!.validate()) return;
    final problema = validarHorario(_horario);
    if (problema != null) return snack(context, problema);

    setState(() => _salvando = true);
    await executarAcao(context, () async {
      await ref
          .read(adminRepoProvider)
          .salvarLoja(
            nome: _nome.text.trim(),
            slaRespostaMin: int.parse(_sla.text),
            retencaoMeses: int.parse(_retencao.text),
            horarioComercial: _horario,
            pesosCriterios: _pesos,
          );
      // A sessão guarda a loja: recarrega depois de salvar.
      await ref.read(sessaoProvider.notifier).recarregar();
    }, sucesso: 'Configuração salva.');
    if (mounted) setState(() => _salvando = false);
  }

  String? _inteiro(String? v, int minimo, int maximo) {
    final n = int.tryParse(v ?? '');
    return n == null || n < minimo || n > maximo
        ? 'Informe um número de $minimo a $maximo'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/mais'),
        title: const Text('Configuração da loja'),
      ),
      body: !_carregado
          ? const Carregando()
          : Form(
              key: _formulario,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TextFormField(
                    controller: _nome,
                    decoration: const InputDecoration(
                      labelText: 'Nome da loja',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sla,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SLA de resposta (minutos)',
                      helperText:
                          'Tempo máximo para responder o cliente, contado só '
                          'no horário comercial.',
                      helperMaxLines: 2,
                    ),
                    validator: (v) => _inteiro(v, 1, 1440),
                  ),
                  const TituloSecao('Horário comercial'),
                  for (final dia in diasDaSemana) _dia(dia),
                  const TituloSecao('Peso dos critérios na nota'),
                  Text(
                    'Peso maior = o critério conta mais na nota geral. Vale '
                    'para as próximas auditorias.',
                    style: tema.textTheme.bodySmall,
                  ),
                  for (final c in criterios.entries)
                    Row(
                      children: [
                        Expanded(flex: 4, child: Text(c.value)),
                        Expanded(
                          flex: 5,
                          child: Slider(
                            value: _pesos[c.key]!.clamp(0, 10),
                            max: 10,
                            divisions: 20,
                            label: formatarNota(_pesos[c.key]),
                            onChanged: (v) => setState(() => _pesos[c.key] = v),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            formatarNota(_pesos[c.key]),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  const TituloSecao('Retenção de dados'),
                  TextFormField(
                    controller: _retencao,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Retenção (meses)',
                      helperText:
                          'Conversas e auditorias mais antigas que isso são '
                          'apagadas automaticamente. 0 = não apagar.',
                      helperMaxLines: 3,
                    ),
                    validator: (v) => _inteiro(v, 0, 1200),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: Text(_salvando ? 'Salvando…' : 'Salvar'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dia(String dia) {
    final intervalos = _horario[dia]!;
    final aberto = intervalos.isNotEmpty;

    Widget hora(int intervalo, int ponta) => OutlinedButton(
      onPressed: () => _escolherHora(dia, intervalo, ponta),
      child: Text(intervalos[intervalo][ponta]),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nomesDosDias[dia]!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(aberto ? 'Aberto' : 'Fechado'),
                Switch(
                  value: aberto,
                  // Dia fechado vai como lista vazia.
                  onChanged: (abrir) => setState(() {
                    _horario[dia] = abrir
                        ? [
                            ['08:00', '18:00'],
                          ]
                        : [];
                  }),
                ),
              ],
            ),
            for (var i = 0; i < intervalos.length; i++)
              Row(
                children: [
                  hora(i, 0),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('às'),
                  ),
                  hora(i, 1),
                  const Spacer(),
                  if (intervalos.length > 1)
                    IconButton(
                      tooltip: 'Remover o intervalo',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => intervalos.removeAt(i)),
                    ),
                ],
              ),
            if (aberto)
              TextButton.icon(
                onPressed: () => setState(
                  () => intervalos.add([intervalos.last[1], '18:00']),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar intervalo'),
              ),
          ],
        ),
      ),
    );
  }
}
