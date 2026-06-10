import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol.dart';
import '../room_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _server = TextEditingController(text: 'ws://hedgegod.tech:8080/ws');
  final _nick = TextEditingController(text: 'guest');
  final _code = TextEditingController();
  String _mode = modeSignal;
  bool _showServer = false;

  @override
  void dispose() {
    _server.dispose();
    _nick.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(roomControllerProvider);
    final ctrl = ref.read(roomControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final busy = state.connecting;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.graphic_eq, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('team4tune',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                      Text(l10n.appSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nick,
              decoration: InputDecoration(
                labelText: l10n.nicknamePlaceholder,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.createRoomTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l10n.createRoomSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: modeSignal,
                          label: Text(l10n.modeSignalLabel),
                          icon: const Icon(Icons.sync),
                        ),
                        ButtonSegment(
                          value: modeStream,
                          label: Text(l10n.modeStreamLabel),
                          icon: const Icon(Icons.cell_tower),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => ctrl.createRoom(_server.text, _nick.text, _mode),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.createRoomButton),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.joinRoomTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.roomCodePlaceholder,
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => ctrl.joinRoom(_server.text, _code.text, _nick.text),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.joinRoomButton),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showServer = !_showServer),
                icon: Icon(_showServer ? Icons.expand_less : Icons.expand_more),
                label: Text(l10n.serverSettings),
              ),
            ),
            if (_showServer)
              TextField(
                controller: _server,
                decoration: InputDecoration(
                  labelText: l10n.serverLabel,
                  prefixIcon: const Icon(Icons.dns_outlined),
                ),
              ),
            if (busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(state.error!,
                          style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
