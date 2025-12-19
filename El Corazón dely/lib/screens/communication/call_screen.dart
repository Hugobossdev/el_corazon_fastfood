import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/agora_call_service.dart';
import '../../models/order.dart';
import '../../services/app_service.dart';
import '../../ui/ui.dart';

/// Écran d'appel vocal/vidéo
class CallScreen extends StatefulWidget {
  final Order order;
  final CallType callType;
  final bool isIncoming;
  final String? callerName;

  const CallScreen({
    super.key,
    required this.order,
    required this.callType,
    this.isIncoming = false,
    this.callerName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraCallService _agoraService = AgoraCallService();
  StreamSubscription<CallEvent>? _callEventSubscription;
  StreamSubscription<int?>? _remoteUidSubscription;
  
  bool _isConnecting = true;
  bool _isCallActive = false;
  int? _remoteUid;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    _remoteUidSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      // Initialiser Agora si nécessaire
      if (!_agoraService.isInitialized) {
        final initialized = await _agoraService.initialize();
        if (!initialized) {
          if (mounted && context.mounted) {
            setState(() {
              _errorMessage = 'Impossible d\'initialiser Agora';
              _isConnecting = false;
            });
          }
          return;
        }
      }

      if (!mounted || !context.mounted) return;
      // Générer l'ID de canal et l'UID
      final channelId = AgoraCallService.generateChannelId(widget.order.id);
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;
      
      if (currentUser == null) {
        if (mounted && context.mounted) {
          setState(() {
            _errorMessage = 'Utilisateur non connecté';
            _isConnecting = false;
          });
        }
        return;
      }

      final uid = AgoraCallService.generateUid(currentUser.id);

      // Écouter les événements d'appel
      _callEventSubscription = _agoraService.callEventStream.listen((event) {
        _handleCallEvent(event);
      });

      _remoteUidSubscription = _agoraService.remoteUidStream.listen((uid) {
        if (mounted && context.mounted) {
          setState(() {
            _remoteUid = uid;
            if (uid != null) {
              _isCallActive = true;
              _isConnecting = false;
            }
          });
        }
      });

      // Rejoindre le canal
      final success = await _agoraService.joinChannel(
        channelId: channelId,
        callType: CallType.voice,
        uid: uid,
      );

      if (!success && mounted && context.mounted) {
        setState(() {
          _errorMessage = 'Impossible de rejoindre l\'appel';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isConnecting = false;
        });
      }
    }
  }

  void _handleCallEvent(CallEvent event) {
    if (!mounted || !context.mounted) return;
    switch (event.type) {
      case CallEventType.joined:
        setState(() {
          _isConnecting = false;
          _isCallActive = true;
        });
        break;
      case CallEventType.userJoined:
        setState(() {
          _isCallActive = true;
          _isConnecting = false;
        });
        break;
      case CallEventType.userLeft:
        setState(() {
          _isCallActive = false;
        });
        _endCall();
        break;
      case CallEventType.left:
        Navigator.of(context).pop();
        break;
      case CallEventType.disconnected:
        setState(() {
          _errorMessage = 'Connexion perdue';
        });
        break;
      case CallEventType.error:
        setState(() {
          _errorMessage = event.message ?? 'Erreur inconnue';
          _isConnecting = false;
        });
        break;
      case CallEventType.connected:
        setState(() {
          _isCallActive = true;
        });
        break;
    }
  }

  Future<void> _endCall() async {
    await _agoraService.leaveChannel();
    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête avec bouton retour
            Padding(
              padding: AppSpacing.pagePadding,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                    onPressed: _endCall,
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: Center(
                child: _buildCallContent(),
              ),
            ),

            // Contrôles d'appel
            if (_isCallActive || _isConnecting)
              _buildCallControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCallContent() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _endCall,
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    if (_isConnecting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: 24),
          Text(
            widget.isIncoming ? 'Appel entrant...' : 'Connexion...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.callerName ?? 'Client',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    // Vue d'appel active
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer,
          ),
          child: Center(
            child: Text(
              (widget.callerName ?? 'C').substring(0, 1).toUpperCase(),
              style: theme.textTheme.displaySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          widget.callerName ?? 'Client',
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Appel vocal',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_remoteUid != null) ...[
          const SizedBox(height: 8),
          Text(
            'UID: $_remoteUid',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }


  Widget _buildCallControls() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Micro
          _buildControlButton(
            icon: _agoraService.isMuted ? Icons.mic_off : Icons.mic,
            color: _agoraService.isMuted ? scheme.error : scheme.onSurface,
            onPressed: () => _agoraService.toggleMute(),
          ),

          // Haut-parleur
          _buildControlButton(
            icon: _agoraService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            color: _agoraService.isSpeakerOn ? scheme.onSurface : scheme.onSurfaceVariant,
            onPressed: () => _agoraService.toggleSpeaker(),
          ),

          // Raccrocher
          _buildControlButton(
            icon: Icons.call_end,
            color: scheme.onError,
            backgroundColor: scheme.error,
            onPressed: _endCall,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color? backgroundColor,
    bool isLarge = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: isLarge ? 64 : 56,
      height: isLarge ? 64 : 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: isLarge ? 32 : 24),
        onPressed: onPressed,
      ),
    );
  }
}


