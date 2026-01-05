import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/audio_message_bubble.dart';
import '../../../../../utils/full_page_loader.dart';
import 'package:shimmer/shimmer.dart';

class ResolvedImagesBubble extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final Future<List<String>> Function(List<Map<String, dynamic>>) resolveImageUrls;
  final Widget Function(BuildContext, List<String>) builder;

  const ResolvedImagesBubble({
    super.key,
    required this.images,
    required this.resolveImageUrls,
    required this.builder,
  });

  @override
  State<ResolvedImagesBubble> createState() => _ResolvedImagesBubbleState();
}

class _ResolvedImagesBubbleState extends State<ResolvedImagesBubble> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedImagesBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) {
      _future = _resolve();
    }
  }

  Future<List<String>> _resolve() async {
    final result = List<String>.filled(widget.images.length, "", growable: false);
    final serverImages = <Map<String, dynamic>>[];
    final indices = <int>[];

    for (int i = 0; i < widget.images.length; i++) {
      final img = widget.images[i];
      // Check for local path (Optimistic UI)
      if (img['localPath'] != null && img['localPath'].toString().isNotEmpty) {
        result[i] = img['localPath'] as String;
      } else {
        serverImages.add(img);
        indices.add(i);
      }
    }

    if (serverImages.isNotEmpty) {
      try {
        final urls = await widget.resolveImageUrls(serverImages);
        for (int j = 0; j < urls.length; j++) {
           if (j < indices.length) {
             result[indices[j]] = urls[j];
           }
        }
      } catch (e) {
        debugPrint("Error resolving images: $e");
      }
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snapshot) {
        // If we have data (even partial/local), show it.
        // Or strictly wait? FutureBuilder waits for _future completion.
        // _resolve is async, so it waits for server resolution. 
        // We want INSTANT display for local. 
        // Ideally _resolve should yield local first? No, Future completes once.
        // If there are ONLY local images, it completes fast.
        // If mixed, it waits for SERVER images. 
        // To be truly instant for local images in a mixed batch (rare), we'd need streaming.
        // But for likely case (all local OR all server), this is fine. 
        // If User sends 5 images, they are ALL local. Instant.
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: ClipRRect(
               borderRadius: BorderRadius.circular(12.r),
               child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                     width: 150.w,
                     height: 150.w,
                     color: Colors.white,
                  ),
               ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

class ResolvedAudioBubble extends StatefulWidget {
  final String? url;
  final String? path;
  final bool isUser;

  const ResolvedAudioBubble({
    super.key,
    required this.url,
    required this.path,
    required this.isUser,
  });

  @override
  State<ResolvedAudioBubble> createState() => _ResolvedAudioBubbleState();
}

class _ResolvedAudioBubbleState extends State<ResolvedAudioBubble> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<String> _resolve() async {
    if (widget.url != null && widget.url!.isNotEmpty) return widget.url!;
    if (widget.path != null) {
      // ✅ Check for local path (Optimistic UI)
      if (widget.path!.startsWith('/') || widget.path!.startsWith('file:')) {
        return widget.path!;
      }

      try {
        return await Supabase.instance.client.storage
            .from('chat.attachments')
            .createSignedUrl(widget.path!, 60 * 60);
      } catch (e) {
        return Supabase.instance.client.storage
            .from('chat.attachments')
            .getPublicUrl(widget.path!);
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
              width: 150.w,
              height: 40.h,
              color: Colors.grey.shade200,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return AudioMessageBubble(
          url: snapshot.data,
          isUser: widget.isUser,
        );
      },
    );
  }
}
