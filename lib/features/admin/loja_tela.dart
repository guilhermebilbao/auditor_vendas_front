import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../core/sessao/modelos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import '../assinatura/assinatura_repo.dart';
import '../assinatura/loja_inativa_tela.dart';
import 'admin_repo.dart';
import 'boas_vindas.dart';

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
  final _boasVindasTexto = TextEditingController();
  final _boasVindasEspera = TextEditingController();
  bool _boasVindasAtiva = false;
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
    _boasVindasAtiva = loja.boasVindasAtiva;
    _boasVindasTexto.text = loja.boasVindasTexto;
    _boasVindasEspera.text = '${loja.boasVindasEsperaSeg}';
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
    _boasVindasTexto.dispose();
    _boasVindasEspera.dispose();
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
            boasVindasAtiva: _boasVindasAtiva,
            boasVindasTexto: _boasVindasTexto.text.trim(),
            boasVindasEsperaSeg: int.parse(_boasVindasEspera.text),
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
                  const _SecaoAssinatura(),
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
                  const TituloSecao('Boas-vindas automática'),
                  _SecaoBoasVindas(
                    ativa: _boasVindasAtiva,
                    aoLigar: (v) => setState(() => _boasVindasAtiva = v),
                    texto: _boasVindasTexto,
                    espera: _boasVindasEspera,
                    nomeLoja: _nome.text,
                    validarEspera: (v) => _inteiro(v, 30, 600),
                  ),
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

/// Boas-vindas automática (spec 22, etapa 3, item 1): o interruptor, o texto com
/// as variáveis, a prévia e a espera.
class _SecaoBoasVindas extends StatefulWidget {
  const _SecaoBoasVindas({
    required this.ativa,
    required this.aoLigar,
    required this.texto,
    required this.espera,
    required this.nomeLoja,
    required this.validarEspera,
  });

  final bool ativa;
  final ValueChanged<bool> aoLigar;
  final TextEditingController texto;
  final TextEditingController espera;
  final String nomeLoja;
  final FormFieldValidator<String> validarEspera;

  @override
  State<_SecaoBoasVindas> createState() => _SecaoBoasVindasState();
}

class _SecaoBoasVindasState extends State<_SecaoBoasVindas> {
  @override
  void initState() {
    super.initState();
    widget.texto.addListener(_atualizar);
  }

  @override
  void dispose() {
    widget.texto.removeListener(_atualizar);
    super.dispose();
  }

  void _atualizar() => setState(() {});

  /// Põe a variável onde está o cursor (ou no fim).
  void _inserir(String variavel) {
    final c = widget.texto;
    final s = c.selection;
    final inicio = s.isValid ? s.start : c.text.length;
    final fim = s.isValid ? s.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(inicio, fim, variavel),
      selection: TextSelection.collapsed(offset: inicio + variavel.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final previa = montarBoasVindas(
      widget.texto.text,
      cliente: 'Maria Souza',
      vendedor: 'Carlos Lima',
      loja: widget.nomeLoja.isEmpty ? 'Sua loja' : widget.nomeLoja,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enviar boas-vindas a clientes novos'),
          value: widget.ativa,
          onChanged: widget.aoLigar,
        ),
        Text(
          'Enviada pelo WhatsApp do vendedor, uma vez por cliente novo, só no '
          'horário comercial e até 5 minutos antes de fechar. Não conta como '
          'resposta do vendedor: o cliente continua "sem resposta" até ele '
          'responder.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.texto,
          minLines: 2,
          maxLines: 5,
          maxLength: tamanhoMaxBoasVindas,
          decoration: const InputDecoration(
            labelText: 'Texto',
            hintText:
                'Olá, {cliente}! Aqui é o {vendedor}, da {loja}. Já vi sua '
                'mensagem e te respondo em instantes.',
            hintMaxLines: 3,
            alignLabelWithHint: true,
          ),
          validator: (v) =>
              validarTextoBoasVindas(v ?? '', ativa: widget.ativa),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final v in variaveisBoasVindas)
              ActionChip(label: Text(v), onPressed: () => _inserir(v)),
          ],
        ),
        if (widget.texto.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Prévia', style: tema.textTheme.labelLarge),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tema.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              previa,
              style: TextStyle(color: tema.colorScheme.onTertiaryContainer),
            ),
          ),
          Text(
            'Com nomes de exemplo. Sem o nome do cliente no WhatsApp, '
            '{cliente} é omitido.',
            style: tema.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.espera,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Espera antes de enviar (segundos)',
            helperText:
                'Contada só no horário comercial. Se o vendedor responder '
                'antes, a boas-vindas não é enviada.',
            helperMaxLines: 2,
          ),
          validator: widget.validarEspera,
        ),
      ],
    );
  }
}

/// Assinatura, só de leitura e sem link de pagamento (spec 19, item 38). Loja de
/// contrato, sem plano, não mostra nada. No teste grátis, mostra o prazo, as
/// cotas de hoje e o "Quero assinar", que manda o link por e-mail (spec 20).
class _SecaoAssinatura extends ConsumerWidget {
  const _SecaoAssinatura();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assinatura = ref.watch(assinaturaProvider).value;
    if (assinatura == null || assinatura.planoNome == null) {
      return const SizedBox.shrink();
    }
    final inadimplente = assinatura.inadimplenteDesde;
    final trialAte = assinatura.trialAte;
    final emTrial = assinatura.estado == EstadoLoja.trial && trialAte != null;
    final situacao = switch (assinatura.estado) {
      _ when emTrial => 'Teste grátis até ${formatarData(trialAte)}',
      'trial_encerrado' => 'Teste grátis encerrado',
      'suspensa' => 'Suspensa',
      'em_revisao' => 'Em análise',
      'aguardando_pagamento' => 'Aguardando o primeiro pagamento',
      _ when inadimplente != null =>
        'Pagamento em atraso desde ${formatarData(inadimplente)}',
      _ => 'Em dia',
    };
    final maximo = assinatura.planoMaxInstancias;
    final proxima = assinatura.proximaCobranca;
    final cartao = Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('Plano ${assinatura.planoNome}'),
            subtitle: maximo == null ? null : Text('Até $maximo WhatsApps'),
          ),
          if (emTrial) ...[
            ListTile(
              leading: const Icon(Icons.hourglass_bottom),
              title: const Text('Limites do teste grátis'),
              subtitle: Text(
                [
                  if (ref.watch(sessaoProvider).loja?.maxInstancias
                      case final max?)
                    'Até $max WhatsApps',
                  if (assinatura.auditoriasRestantesHoje case final n?)
                    _restantes(n, 'auditoria', 'auditorias'),
                  if (assinatura.transcricoesRestantesHoje case final n?)
                    _restantes(
                      n,
                      'transcrição de áudio',
                      'transcrições de áudio',
                    ),
                ].join('\n'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: BotaoLinkPagamento(rotulo: 'Quero assinar'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Próxima cobrança'),
            subtitle: Text(
              proxima == null ? '—' : formatarDiaCalendario(proxima),
            ),
          ),
          ListTile(
            leading: Icon(
              inadimplente == null && (assinatura.estado == 'ativa' || emTrial)
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
            ),
            title: const Text('Situação'),
            subtitle: Text(situacao),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const TituloSecao('Assinatura'), cartao],
    );
  }
}

/// "Hoje: 1 auditoria restante" / "Hoje: 0 auditorias restantes".
String _restantes(int n, String singular, String plural) =>
    n == 1 ? 'Hoje: 1 $singular restante' : 'Hoje: $n $plural restantes';
