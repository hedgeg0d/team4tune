import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol.dart';
import '../room_controller.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(roomControllerProvider);
    final ctrl = ref.read(roomControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final room = state.room;
    if (room == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Text(l10n.roomTitle),
            const SizedBox(width: 10),
            ActionChip(
              avatar: const Icon(Icons.tag, size: 18),
              label: Text(
                room.roomCode,
                style: const TextStyle(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: room.roomCode));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.roomCodeCopied)));
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.syncTuningTooltip,
            icon: const Icon(Icons.speed),
            onPressed: () => _openSyncTuning(ctrl, state.catchupSpeed),
          ),
          if (room.isSelfHost)
            IconButton(
              tooltip: l10n.roomSettingsTooltip,
              icon: const Icon(Icons.tune),
              onPressed: () => _openSettings(ctrl, room.settings),
            ),
          IconButton(
            tooltip: l10n.leaveTooltip,
            icon: const Icon(Icons.logout),
            onPressed: () => ctrl.leave(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (state.reconnecting)
              Container(
                width: double.infinity,
                color: scheme.tertiaryContainer,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.reconnecting,
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _InfoChip(
                    icon: room.mode == modeSignal
                        ? Icons.sync
                        : Icons.cell_tower,
                    label: room.mode,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.people,
                    label: '${room.members.length}',
                  ),
                  const Spacer(),
                  if (_selfConfidence(room) != null) ...[
                    _SignalBars(confidence: _selfConfidence(room)!),
                    const SizedBox(width: 8),
                  ],
                  _ClockChip(
                    offsetMs: state.clockOffsetMs,
                    rttMs: state.clockRttMs,
                    driftMs: state.driftMs,
                    showDrift: state.playing,
                  ),
                ],
              ),
            ),
            _NowPlaying(
              track: _trackById(room, state.nowPlayingTrackId),
              playing: state.playing,
              positionMs: state.positionMs,
              buffering: state.buffering,
              canControl: _allowed(room, scopeControl),
              canSkip: _allowed(room, scopeSkip),
              onPause: ctrl.pause,
              onResume: ctrl.resume,
              onSeek: ctrl.seek,
              onSkip: ctrl.skip,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _url,
                      enabled: _allowed(room, scopeEnqueue),
                      decoration: InputDecoration(
                        hintText: _allowed(room, scopeEnqueue)
                            ? l10n.pasteTrackUrl
                            : l10n.onlyHostCanAdd,
                        prefixIcon: const Icon(Icons.link),
                      ),
                      onSubmitted: (_) => _enqueue(ctrl),
                    ),
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: l10n.uploadTrackTooltip,
                      onPressed: _allowed(room, scopeEnqueue)
                          ? () => _pickAndUpload(ctrl)
                          : null,
                      icon: const Icon(Icons.library_music),
                      iconSize: 24,
                    ),
                  ],
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _allowed(room, scopeEnqueue)
                        ? () => _enqueue(ctrl)
                        : null,
                    icon: const Icon(Icons.add),
                    iconSize: 26,
                  ),
                ],
              ),
            ),
            _SectionLabel(l10n.queueLabel(room.queue.length)),
            Expanded(
              child: room.queue.isEmpty
                  ? _EmptyQueue(color: scheme.onSurfaceVariant)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: room.queue.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _TrackCard(
                        track: room.queue[i],
                        isNowPlaying:
                            room.queue[i].id == state.nowPlayingTrackId,
                        canRemove: _allowed(room, scopeRemove),
                        onRemove: () => ctrl.removeTrack(room.queue[i].id),
                      ),
                    ),
            ),
            _Members(
              members: room.members,
              selfId: room.selfId,
              hostId: room.hostId,
            ),
          ],
        ),
      ),
    );
  }

  void _enqueue(RoomController ctrl) {
    if (_url.text.trim().isEmpty) return;
    ctrl.enqueue(_url.text);
    _url.clear();
  }

  Future<void> _pickAndUpload(RoomController ctrl) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    await ctrl.uploadAndEnqueue(path);
  }

  void _openSyncTuning(RoomController ctrl, double current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _SyncTuningSheet(initial: current, onChanged: ctrl.setCatchupSpeed),
    );
  }

  void _openSettings(RoomController ctrl, RoomSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _SettingsSheet(initial: settings, onChanged: ctrl.setSettings),
    );
  }
}

bool _allowed(RoomState room, String scope) =>
    room.settings.policyFor(scope) == policyEveryone || room.isSelfHost;

int? _selfConfidence(RoomState room) {
  for (final m in room.members) {
    if (m.id == room.selfId) return m.health?.confidence;
  }
  return null;
}

Track? _trackById(RoomState room, String? id) {
  if (id == null) return null;
  for (final t in room.queue) {
    if (t.id == id) return t;
  }
  return null;
}

String _fmt(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({
    required this.offsetMs,
    required this.rttMs,
    this.driftMs = 0,
    this.showDrift = false,
  });

  final int? offsetMs;
  final int? rttMs;
  final int driftMs;
  final bool showDrift;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final synced = offsetMs != null;
    final base = synced ? 'Δ${offsetMs}ms · ${rttMs}ms' : l10n.clockSyncing;
    final label = showDrift ? '$base · d${driftMs}ms' : base;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          synced ? Icons.schedule : Icons.sync_problem,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _NowPlaying extends StatefulWidget {
  const _NowPlaying({
    required this.track,
    required this.playing,
    required this.positionMs,
    required this.buffering,
    required this.canControl,
    required this.canSkip,
    required this.onPause,
    required this.onResume,
    required this.onSeek,
    required this.onSkip,
  });

  final Track? track;
  final bool playing;
  final int positionMs;
  final bool buffering;
  final bool canControl;
  final bool canSkip;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final void Function(int) onSeek;
  final VoidCallback onSkip;

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final track = widget.track;
    if (track == null) return const SizedBox.shrink();
    final total = track.durationMs ?? 0;
    final pos = (_drag ?? widget.positionMs.toDouble()).clamp(
      0.0,
      total > 0 ? total.toDouble() : 1.0,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.playing ? Icons.graphic_eq : Icons.pause,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nowPlaying,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.title ?? track.sourceUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.buffering)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton.filledTonal(
                  onPressed: widget.canControl
                      ? (widget.playing ? widget.onPause : widget.onResume)
                      : null,
                  icon: Icon(widget.playing ? Icons.pause : Icons.play_arrow),
                ),
              IconButton.filledTonal(
                onPressed: widget.canSkip ? widget.onSkip : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: pos,
              max: total > 0 ? total.toDouble() : 1.0,
              onChanged: widget.canControl && total > 0
                  ? (v) => setState(() => _drag = v)
                  : null,
              onChangeEnd: widget.canControl && total > 0
                  ? (v) {
                      widget.onSeek(v.toInt());
                      setState(() => _drag = null);
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(pos.toInt()),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
                if (total > 0)
                  Text(
                    _fmt(total),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 12,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music, size: 48, color: color),
          const SizedBox(height: 8),
          Text(l10n.queueEmpty, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.isNowPlaying,
    required this.canRemove,
    required this.onRemove,
  });

  final Track track;
  final bool isNowPlaying;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final ready = track.status == 'ready';
    final error = track.status == 'error';

    Widget leading;
    if (error) {
      leading = Icon(Icons.error_outline, color: scheme.error);
    } else if (ready) {
      leading = Icon(
        isNowPlaying ? Icons.graphic_eq : Icons.music_note,
        color: scheme.primary,
      );
    } else {
      leading = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isNowPlaying ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          track.title ?? track.sourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.status,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track.durationMs != null && track.durationMs! > 0)
              Text(_fmt(track.durationMs!)),
            if (canRemove && !isNowPlaying)
              IconButton(
                tooltip: l10n.removeTooltip,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.confidence});

  final int confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = confidence.clamp(0, 3);
    final color = level >= 3
        ? scheme.primary
        : level == 2
        ? scheme.tertiary
        : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 3,
            height: 5.0 + i * 3,
            margin: const EdgeInsets.symmetric(horizontal: 0.8),
            decoration: BoxDecoration(
              color: i < level ? color : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class _SyncTuningSheet extends StatefulWidget {
  const _SyncTuningSheet({required this.initial, required this.onChanged});

  final double initial;
  final void Function(double) onChanged;

  @override
  State<_SyncTuningSheet> createState() => _SyncTuningSheetState();
}

class _SyncTuningSheetState extends State<_SyncTuningSheet> {
  late double _speed = widget.initial.clamp(1.02, 1.30);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pct = ((_speed - 1.0) * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.syncTuningTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.syncTuningDescription,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                l10n.maxCatchup,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '${_speed.toStringAsFixed(2)}x  (+$pct%)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _speed,
            min: 1.02,
            max: 1.30,
            divisions: 28,
            label: '${_speed.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() => _speed = v),
            onChangeEnd: widget.onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.syncGentle,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              Text(
                l10n.syncAggressive,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial, required this.onChanged});

  final RoomSettings initial;
  final void Function(RoomSettings) onChanged;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late RoomSettings _s = widget.initial;

  void _update(RoomSettings next) {
    setState(() => _s = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.roomPermissions,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.roomPermissionsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _PolicyRow(
              label: l10n.permAddTracks,
              value: _s.enqueue,
              onChanged: (p) => _update(_s.copyWith(enqueue: p)),
            ),
            _PolicyRow(
              label: l10n.permSkip,
              value: _s.skip,
              onChanged: (p) => _update(_s.copyWith(skip: p)),
            ),
            _PolicyRow(
              label: l10n.permRemoveTracks,
              value: _s.remove,
              onChanged: (p) => _update(_s.copyWith(remove: p)),
            ),
            _PolicyRow(
              label: l10n.permControlPlayback,
              value: _s.control,
              onChanged: (p) => _update(_s.copyWith(control: p)),
            ),
            const Divider(height: 24),
            Text(l10n.syncMode, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.syncModeDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: syncResponsive,
                    label: Text(l10n.syncResponsiveLabel),
                  ),
                  ButtonSegment(
                    value: syncTight,
                    label: Text(l10n.syncTightLabel),
                  ),
                ],
                selected: {_s.sync},
                onSelectionChanged: (s) => _update(_s.copyWith(sync: s.first)),
              ),
            ),
            const Divider(height: 24),
            Text(
              l10n.cacheLimit,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cacheLimitDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: memLimitMinMb.toDouble(),
                    max: memLimitMaxMb.toDouble(),
                    divisions: memLimitMaxMb - memLimitMinMb,
                    value: _s.memLimitMb
                        .clamp(memLimitMinMb, memLimitMaxMb)
                        .toDouble(),
                    label: l10n.cacheLimitValue(_s.memLimitMb),
                    onChanged: (v) =>
                        setState(() => _s = _s.copyWith(memLimitMb: v.round())),
                    onChangeEnd: (v) =>
                        _update(_s.copyWith(memLimitMb: v.round())),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    l10n.cacheLimitValue(_s.memLimitMb),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: policyEveryone,
                label: Text(l10n.policyEveryone),
              ),
              ButtonSegment(value: policyHost, label: Text(l10n.policyHost)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({
    required this.members,
    required this.selfId,
    required this.hostId,
  });

  final List<Member> members;
  final String selfId;
  final String hostId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l10n.listeningLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in members)
                Chip(
                  avatar: CircleAvatar(
                    backgroundColor: scheme.primary,
                    child: Text(
                      (m.nick.isEmpty ? '?' : m.nick[0]).toUpperCase(),
                      style: TextStyle(color: scheme.onPrimary, fontSize: 13),
                    ),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.id == hostId) ...[
                        Icon(Icons.shield, size: 14, color: scheme.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(m.id == selfId ? l10n.memberYou(m.nick) : m.nick),
                      if (m.health != null) ...[
                        const SizedBox(width: 6),
                        _SignalBars(confidence: m.health!.confidence),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
