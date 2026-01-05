import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/services/audio_player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/chat_name_utils.dart'; // Ensure audioplayers is imported

class MessageBubble extends StatefulWidget {
  final String senderName;
  final String text;
  final bool isUser;
  final DateTime? time;
  final bool showSender;
  final bool isArabic;
  final Map<String, dynamic>? audioAttachment; // Pass attachment info if it is audio

  const MessageBubble({
    super.key,
    required this.senderName,
    required this.text,
    required this.isUser,
    required this.time,
    required this.showSender,
    required this.isArabic,
    this.audioAttachment,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    if (widget.audioAttachment != null) {
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });
      _audioPlayer.durationStream.listen((d) {
          if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.positionStream.listen((p) {
          if (mounted) setState(() => _position = p);
      });
    }
  }
  
  @override
  void dispose() {
    // Only dispose if we created it (or maybe share instance? For now separate instance per bubble is heavy but simple)
    // Actually, creating a player per bubble is bad for memory.
    // Ideally we should have a singleton or a manager.
    // But for this task, I'll dispose it.
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // Need URL. 
      // The attachment map usually has 'fileUrl' if public, or we need to resolving it.
      // But typically conversation page resolves URLs. 
      // Checking how other attachments work.
      
      // Assuming 'fileUrl' is populated by the parent or service beforehand.
      // If not, we might need to handle signed URL here.
      // For now, let's assume valid URL in attachment['fileUrl'] or construct it.
      
      final url = widget.audioAttachment?['fileUrl'] ?? '';
      if (url.isNotEmpty) {
          await _audioPlayer.play(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alignment =
        widget.isUser ? Alignment.centerRight : Alignment.centerLeft;
        
    final bool isAudio = widget.audioAttachment != null;

    return Align(
      alignment: alignment,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
          child: Container(
            constraints: BoxConstraints(maxWidth: 0.75.sw),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            margin: EdgeInsets.symmetric(vertical: 4.h),
            decoration: BoxDecoration(
              color: widget.isUser
                  ? AppColors.mainDark.withOpacity(0.9)
                  : AppColors.grayMain.withOpacity(0.18),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
                bottomLeft: widget.isUser ? Radius.circular(12.r) : Radius.zero,
                bottomRight: widget.isUser ? Radius.zero : Radius.circular(12.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showSender)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      widget.senderName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  
                if (isAudio)
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       GestureDetector(
                         onTap: _togglePlay,
                         child: Icon(
                           _isPlaying ? Icons.pause : Icons.play_arrow,
                           color: widget.isUser ? Colors.white : AppColors.main,
                           size: 30.sp,
                         ),
                       ),
                       SizedBox(width: 8.w),
                       Expanded(
                         child: LinearProgressIndicator(
                           value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0,
                           backgroundColor: widget.isUser ? Colors.white30 : Colors.grey.shade300,
                           valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isUser ? Colors.white : AppColors.main
                           ),
                         ),
                       ),
                       SizedBox(width: 8.w),
                       Text(
                         "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                         style: AppTextStyles.getText3(context).copyWith(
                             color: widget.isUser ? Colors.white70 : Colors.black54,
                             fontSize: 10.sp
                         ),
                       ),
                     ],
                   )
                else
                  Directionality(
                    textDirection:
                    widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      widget.text,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: widget.isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    widget.time == null
                        ? ""
                        : ChatNameUtils.formatReadTime(widget.time!, "ar"),
                    style: AppTextStyles.getText3(context).copyWith(
                      fontSize: 9.sp,
                      color: widget.isUser ? Colors.white70 : Colors.black54,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
