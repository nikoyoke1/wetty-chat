import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/style_config.dart';
import '../../application/voice_message_playback_controller.dart';
import '../../domain/conversation_message.dart';
import '../../../models/message_models.dart';
import 'message_bubble_meta.dart';
import 'message_bubble_presentation.dart';
import 'message_render_spec.dart';
import 'message_sender_header.dart';
import 'message_thread_indicator.dart';
import 'voice_message_bubble.dart';

class VoiceMessageBubbleFallback extends ConsumerStatefulWidget {
  const VoiceMessageBubbleFallback({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.renderSpec,
    this.resolvedDuration,
    this.message,
    this.presentation,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final MessageRenderSpec renderSpec;
  final Duration? resolvedDuration;
  final ConversationMessage? message;
  final MessageBubblePresentation? presentation;

  @override
  ConsumerState<VoiceMessageBubbleFallback> createState() =>
      _VoiceMessageBubbleFallbackState();
}

class _VoiceMessageBubbleFallbackState
    extends ConsumerState<VoiceMessageBubbleFallback> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerProvider);
    final controller = ref.read(
      voiceMessagePlaybackControllerProvider.notifier,
    );
    final isActive = playbackState.isActive(widget.attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhase.idle;
    final duration =
        widget.attachment.duration ??
        widget.resolvedDuration ??
        playbackState.durationFor(widget.attachment.id);
    final livePosition = switch (phase) {
      VoiceMessagePlaybackPhase.completed => duration ?? Duration.zero,
      _ => isActive ? playbackState.position : Duration.zero,
    };
    final sliderPosition = _dragPosition ?? livePosition;
    final clampedSliderPosition = duration == null
        ? sliderPosition
        : _clampDuration(sliderPosition, Duration.zero, duration);
    final waveformWidth = voiceMessageUniformWaveformWidth;
    final bubbleWidth = _fallbackBubbleWidthForWaveformWidth(waveformWidth);
    final bubbleColor =
        widget.presentation?.bubbleColor ??
        (widget.isMe
            ? context.appColors.chatSentBubble
            : context.appColors.chatReceivedBubble);
    final metaColor =
        widget.presentation?.metaColor ?? context.appColors.textSecondary;
    final accent = widget.isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue.resolveFrom(context);
    final buttonBackground = widget.isMe
        ? CupertinoColors.white.withAlpha(36)
        : accent.withAlpha(28);
    final canPlay = widget.attachment.url.isNotEmpty;
    final secondaryText = isActive && phase == VoiceMessagePlaybackPhase.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${_formatDuration(clampedSliderPosition)} / ${_formatDuration(duration)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canPlay
          ? () => controller.togglePlayback(widget.attachment)
          : null,
      child: Container(
        width: bubbleWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.renderSpec.showSenderName &&
                widget.message != null &&
                widget.presentation != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: MessageBubblePresentation.senderHeaderBodyGap,
                ),
                child: MessageSenderHeader(
                  senderName: widget.presentation!.senderName,
                  textColor: widget.presentation!.textColor,
                  gender: widget.message!.sender.gender,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: buttonBackground,
                    shape: BoxShape.circle,
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(32),
                    onPressed: canPlay
                        ? () => controller.togglePlayback(widget.attachment)
                        : null,
                    child: _PlaybackIcon(phase: phase, iconColor: accent),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: waveformWidth,
                  child: CupertinoSlider(
                    value: _sliderValue(clampedSliderPosition, duration),
                    min: 0,
                    max: _sliderMax(duration),
                    activeColor: accent,
                    onChanged: duration == null || !isActive
                        ? null
                        : (value) {
                            setState(() {
                              _dragPosition = Duration(
                                milliseconds: value.round(),
                              );
                            });
                          },
                    onChangeEnd: duration == null || !isActive
                        ? null
                        : (value) async {
                            final nextPosition = Duration(
                              milliseconds: value.round(),
                            );
                            setState(() {
                              _dragPosition = null;
                            });
                            await controller.seekToAttachment(
                              widget.attachment,
                              nextPosition,
                            );
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    secondaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        appSecondaryTextStyle(
                          context,
                          fontSize: AppFontSizes.meta,
                        ).copyWith(
                          color:
                              isActive &&
                                  phase == VoiceMessagePlaybackPhase.error
                              ? CupertinoColors.systemRed.resolveFrom(context)
                              : metaColor,
                        ),
                  ),
                ),
                if (widget.message != null && widget.presentation != null) ...[
                  const SizedBox(width: 8),
                  MessageBubbleMeta(
                    message: widget.message!,
                    presentation: widget.presentation!,
                    isMe: widget.isMe,
                  ),
                ],
              ],
            ),
            if (widget.renderSpec.showThreadIndicator &&
                widget.message != null &&
                widget.presentation != null &&
                widget.message!.threadInfo != null &&
                widget.message!.threadInfo!.replyCount > 0) ...[
              const SizedBox(height: 4),
              MessageThreadIndicator(
                threadInfo: widget.message!.threadInfo!,
                isMe: widget.isMe,
                presentation: widget.presentation!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaybackIcon extends StatelessWidget {
  const _PlaybackIcon({required this.phase, required this.iconColor});

  final VoiceMessagePlaybackPhase phase;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case VoiceMessagePlaybackPhase.loading:
        return CupertinoActivityIndicator(color: iconColor);
      case VoiceMessagePlaybackPhase.playing:
        return Icon(CupertinoIcons.pause_fill, size: 18, color: iconColor);
      case VoiceMessagePlaybackPhase.error:
        return Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemRed.resolveFrom(context),
        );
      case VoiceMessagePlaybackPhase.idle:
      case VoiceMessagePlaybackPhase.ready:
      case VoiceMessagePlaybackPhase.paused:
      case VoiceMessagePlaybackPhase.completed:
        return Icon(CupertinoIcons.play_fill, size: 18, color: iconColor);
    }
  }
}

double _sliderValue(Duration position, Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return 0;
  }
  return _clampDuration(
    position,
    Duration.zero,
    duration,
  ).inMilliseconds.toDouble();
}

double _sliderMax(Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return 1;
  }
  return duration.inMilliseconds.toDouble();
}

String _formatDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

double _fallbackBubbleWidthForWaveformWidth(double waveformWidth) {
  return 24 + 32 + 10 + waveformWidth;
}
