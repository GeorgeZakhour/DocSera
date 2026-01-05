import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/services/audio_player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';

class AudioMessageBubble extends StatefulWidget {
  final String? url;
  final bool isUser;

  const AudioMessageBubble({
    super.key,
    required this.url,
    required this.isUser,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.durationStream.listen((d) {
        if (mounted) {
          setState(() {
            _duration = d;
            if (d.inMilliseconds > 0) _isLoaded = true;
          });
        }
    });
    _audioPlayer.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
    });
    
    // Attempt preload to get duration if possible or just rely on stream
    if (widget.url != null) {
       _audioPlayer.setSource(widget.url!);
    }
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _togglePlay() async {
    if (widget.url == null || widget.url!.isEmpty) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
        await _audioPlayer.play(widget.url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we assume loading when duration is zero (simplistic but works for now as player loads)
    // Better logic: if URL is present but duration is 0, show shimmer?
    // Note: AudioPlayerService might need initialization. 
    // Assuming existing logic was working for playback.
    
    // Fallback: If not loaded yet, show Shimmer
    // Actually, simple way: if _duration == zero, show shimmer layout?
    // But maybe we want the bubble to appear, just the "content" shimmers.

    final isLoading = _duration == Duration.zero && widget.url != null;
    
    return Container(
       padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h), // Increased padding
       constraints: BoxConstraints(minWidth: 160.w),
       decoration: BoxDecoration(
         color: widget.isUser ? AppColors.mainDark.withOpacity(0.9) : AppColors.grayMain.withOpacity(0.25),
         borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: widget.isUser ? Radius.circular(16.r) : Radius.zero,
            bottomRight: widget.isUser ? Radius.zero : Radius.circular(16.r),
         ),
       ),
       child: isLoading 
         ? Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               ShimmerWidget(width: 30.sp, height: 30.sp, radius: 15.sp), // Fake Play Button
               SizedBox(width: 8.w),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ShimmerWidget(width: 100.w, height: 4.h, radius: 2.r), // Fake Slider
                   SizedBox(height: 6.h),
                   ShimmerWidget(width: 40.w, height: 8.sp, radius: 2.r), // Fake Time
                 ],
               )
             ],
           )
         : Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               GestureDetector(
                 onTap: _togglePlay,
                 child: Container(
                   padding: EdgeInsets.all(8.r),
                   decoration: BoxDecoration(
                     color: widget.isUser ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.6),
                     shape: BoxShape.circle,
                   ),
                   child: Icon(
                     _isPlaying ? Icons.pause : Icons.play_arrow,
                     color: widget.isUser ? Colors.white : AppColors.main,
                     size: 24.sp,
                   ),
                 ),
               ),
               SizedBox(width: 12.w),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   SizedBox(
                     width: 140.w, // Slightly wider
                     child: LinearProgressIndicator(
                       value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0,
                       backgroundColor: widget.isUser ? Colors.white30 : Colors.grey.shade400,
                       valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isUser ? Colors.white : AppColors.main
                       ),
                       minHeight: 4.h, // Thicker line
                     ),
                   ),
                   SizedBox(height: 6.h),
                   Text(
                     "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                     style: AppTextStyles.getText3(context).copyWith(
                         color: widget.isUser ? Colors.white70 : Colors.black54,
                         fontSize: 10.sp,
                         fontWeight: FontWeight.w500,
                     ),
                   ),
                 ],
               ),
             ],
           ),
    );
  }
}
