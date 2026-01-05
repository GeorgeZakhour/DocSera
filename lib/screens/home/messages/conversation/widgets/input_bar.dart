import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/services/voice_recorder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(String path) onSendAudio;
  final VoidCallback onAddAttachment;
  final bool isEnabled;
  final bool hasAttachments;

  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSendAudio,
    required this.onAddAttachment,
    required this.isEnabled,
    this.hasAttachments = false,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> with TickerProviderStateMixin {
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isButtonPressed = false; // Add this flag to track physical touch
  DateTime? _startTime;
  Timer? _timer;
  String _recordDuration = "00:00";
  Offset _dragOffset = Offset.zero;

  late AnimationController _micScaleController;
  late AnimationController _lockAnimController;
  late Animation<Offset> _lockSlideAnimation;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });

    _micScaleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        lowerBound: 1.0,
        upperBound: 1.5,
    );

    _lockAnimController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 800), // Slower animation
    );

    _lockSlideAnimation = Tween<Offset>(
       begin: const Offset(0, 0),
       end: const Offset(0, -50),
    ).animate(CurvedAnimation(parent: _lockAnimController, curve: Curves.easeOut));
  }

  // ... (dispose remains same)
  @override
  void dispose() {
    _timer?.cancel();
    _micScaleController.dispose();
    _lockAnimController.dispose();
    _voiceRecorder.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final permission = await Permission.microphone.request();

    // Check if button is passed (race condition prevention)
    if (!_isButtonPressed) return;

    if (permission.isGranted) {
      final path = await _voiceRecorder.getTemporaryPath();
      try {
        await _voiceRecorder.start(path: path);
      } catch (e) {
        debugPrint("🎤 Error: $e");
        return;
      }

      // Double check
      if (!_isButtonPressed) {
         await _voiceRecorder.stop();
         return;
      }

      setState(() {
        _isRecording = true;
        _isLocked = false;
        _startTime = DateTime.now();
        _recordDuration = "00:00";
        _dragOffset = Offset.zero;
      });

      _startTimer();
      _micScaleController.forward();
      _lockAnimController.forward();
    } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Microphone permission required.")),
           );
        }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    _micScaleController.reverse();
    _lockAnimController.reverse();

    if (!_isRecording) return;

    final path = await _voiceRecorder.stop();

    // Check duration to discard accidental short taps (e.g. < 500ms)
    final duration = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    bool isShort = duration.inMilliseconds < 500;

    if (cancel || isShort) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } else {
      if (path != null) {
         widget.onSendAudio(path);
      }
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _dragOffset = Offset.zero;
        _startTime = null;
      });
    }
  }

  void _lockRecording() {
    if (_isLocked) return;
    setState(() {
      _isLocked = true;
    });
    // Maybe show a toast or feedback
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime == null) return;
      final duration = DateTime.now().difference(_startTime!);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _recordDuration = "$minutes:$seconds";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check Directionality for simple localization logic for Hint
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final hint = isRtl ? "اكتب رسالة..." : "Type a message...";
    final showSendButton = widget.controller.text.trim().isNotEmpty || widget.hasAttachments;

    // Determine visuals for Mic
    Color micColor = _isRecording ? AppColors.orange : AppColors.main; 
    IconData micIcon = _isRecording ? Icons.mic : Icons.mic_none;

    return Padding(
      padding: EdgeInsets.only(bottom: 20.h, left: 16.w, right: 16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock Indicator (Sliding Up)
          if (_isRecording && !_isLocked)
             Align(
               alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft, 
               child: Transform.translate(
                 offset: Offset(isRtl ? -20.w : 20.w, _dragOffset.dy), 
                 child: Opacity(
                   opacity: (_dragOffset.dy < -20) ? 1.0 : 0.0,
                   child: FadeTransition(
                     opacity: _lockAnimController,
                     child: Container(
                       margin: EdgeInsets.only(bottom: 10.h),
                       padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(20.r),
                         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                       ),
                       child: Column(
                         children: [
                           Icon(Icons.lock_open, size: 18.sp, color: Colors.grey),
                           Icon(Icons.keyboard_arrow_up, size: 18.sp, color: Colors.grey),
                         ],
                       ),
                     ),
                   ),
                 ),
               ),
             ),
             
          ClipRRect(
            borderRadius: BorderRadius.circular(30.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.grayMain.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                     // 1. Attach Button (+) 
                     IgnorePointer(
                       ignoring: _isRecording || _isLocked,
                       child: Opacity(
                         opacity: (_isRecording || _isLocked) ? 0.0 : 1.0,
                         child: GestureDetector(
                           onTap: widget.isEnabled ? widget.onAddAttachment : null,
                           behavior: HitTestBehavior.opaque,
                           child: Padding(
                             padding: EdgeInsets.all(6.r),
                             child: Icon(Icons.add, size: 24.sp, color: AppColors.main),
                           ),
                         ),
                       ),
                     ),
                     
                     // 2. Mic Button (Left side)
                     // Constant GestureDetector to ensure continuous gesture tracking
                     GestureDetector(
                          key: const ValueKey('mic_gesture_detector'),
                          onTapDown: (_) {
                            if (widget.isEnabled && !_isRecording) {
                               debugPrint("👇 Mic Button Pressed");
                               _isButtonPressed = true;
                               _startRecording();
                            }
                          },
                          onTapUp: (_) {
                             debugPrint("👆 Mic Button Released");
                             _isButtonPressed = false;
                             // Stop if recording and NOT locked
                             if (_isRecording && !_isLocked) _stopRecording();
                          },
                          onTapCancel: () {
                             debugPrint("❌ Mic Button Canceled");
                             _isButtonPressed = false;
                             // Cancel if recording and NOT locked
                             if (_isRecording && !_isLocked) _stopRecording(cancel: true);
                          },
                          onPanStart: (_) {
                             // If pan starts immediately without tapDown (rare but possible)
                             if (widget.isEnabled && !_isRecording) {
                                _isButtonPressed = true;
                                _startRecording();
                             }
                          },
                          onPanUpdate: (details) {
                              if (_isRecording && !_isLocked) {
                                  setState(() => _dragOffset += details.delta);
                                  // Lock Logic (Slide Up)
                                  if (_dragOffset.dy < -40) {
                                      _lockRecording();
                                  }
                              }
                          },
                          onPanEnd: (_) {
                              // Similar to onTapUp
                              _isButtonPressed = false;
                              if (_isRecording && !_isLocked) {
                                  _stopRecording();
                              }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: ScaleTransition(
                              scale: _micScaleController,
                              child: Container(
                                padding: EdgeInsets.all(6.r),
                                child: Icon(
                                  micIcon, 
                                  color: micColor,
                                  size: 24.sp,
                                ),
                              ),
                            ),
                          ),
                     ),
                     
                     SizedBox(width: 4.w),
      
                     // 3. Middle Area (Timer or Input)
                     Expanded(
                       child: _isRecording
                       ? Container(
                           height: 40.h,
                           alignment: Alignment.center,
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Container(
                                  width: 8.w, height: 8.w,
                                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                               ),
                               SizedBox(width: 6.w),
                               Text(
                                   _recordDuration,
                                   style: AppTextStyles.getText2(context).copyWith(
                                     color: Colors.black87, 
                                     fontWeight: FontWeight.bold,
                                     fontSize: 14.sp,
                                     fontFeatures: [const FontFeature.tabularFigures()],
                                   ),
                               ),
                             ],
                           ),
                         )
                       : Container(
                        constraints: BoxConstraints(maxHeight: 100.h, minHeight: 40.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25.r),
                          border: Border.all(
                              color: _focusNode.hasFocus ? AppColors.main : Colors.grey.shade300, 
                              width: _focusNode.hasFocus ? 1.0 : 0.5
                          ),
                        ),
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          enabled: widget.isEnabled,
                          minLines: 1,
                          maxLines: 5,
                          style: AppTextStyles.getText3(context).copyWith(fontSize: 13.sp),
                          onChanged: (val) { setState((){}); },
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: AppTextStyles.getText3(context).copyWith(
                              fontSize: 13.sp,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          ),
                        ),
                      ),
                   ),
                     
                     SizedBox(width: 6.w),
      
                     // 4. Right Side (Cancel / Send)
                     if (_isRecording) ...[
                        // Always show Cancel 'X'
                        GestureDetector(
                          onTap: () => _stopRecording(cancel: true),
                          child: Container(
                            padding: EdgeInsets.all(6.r),
                            child: Icon(Icons.close, color: Colors.grey, size: 24.sp),
                          ),
                        ),
                        
                        // If Locked, also show Send button
                        if (_isLocked) ... [
                           SizedBox(width: 8.w),
                           GestureDetector(
                              onTap: () => _stopRecording(), 
                              child: Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: const BoxDecoration(
                                  color: AppColors.main,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.send, color: Colors.white, size: 16.sp),
                              ),
                           )
                        ]
                     ] else if (showSendButton)
                        GestureDetector(
                           onTap: widget.isEnabled ? widget.onSend : null,
                           child: Container(
                             padding: EdgeInsets.all(8.r),
                             decoration: const BoxDecoration(
                               color: AppColors.main,
                               shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.send, color: Colors.white, size: 16.sp),
                            ),
                        )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
