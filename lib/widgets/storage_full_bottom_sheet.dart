import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;

class StorageFullBottomSheet extends StatefulWidget {
  final StorageQuotaCubit cubit;
  final Future<void> Function(String documentId) onDeleteDocument;
  final VoidCallback? onViewAllDocuments;
  final bool autoDismiss;

  const StorageFullBottomSheet({
    super.key,
    required this.cubit,
    required this.onDeleteDocument,
    this.onViewAllDocuments,
    this.autoDismiss = true,
  });

  static Future<bool> show(
    BuildContext context, {
    required Future<void> Function(String documentId) onDeleteDocument,
    VoidCallback? onViewAllDocuments,
    bool autoDismiss = true,
  }) async {
    final cubit = context.read<StorageQuotaCubit>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocProvider<StorageQuotaCubit>.value(
          value: cubit,
          child: StorageFullBottomSheet(
            cubit: cubit,
            onDeleteDocument: onDeleteDocument,
            onViewAllDocuments: onViewAllDocuments,
            autoDismiss: autoDismiss,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  State<StorageFullBottomSheet> createState() => _StorageFullBottomSheetState();
}

class _StorageFullBottomSheetState extends State<StorageFullBottomSheet> {
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocs = true;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    final docs = await widget.cubit.getLargestDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> doc) async {
    final l10n = AppLocalizations.of(context);
    final docId = doc['id']?.toString() ?? '';
    final docName = doc['name']?.toString() ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444), size: 24.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                l10n?.deleteDocumentTitle ?? 'Delete Document',
                style: AppTextStyles.getTitle2(context)
                    .copyWith(color: AppColors.blackText),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                '${l10n?.deleteDocumentConfirm ?? 'Are you sure you want to delete'} "$docName"?',
                style: AppTextStyles.getText2(context)
                    .copyWith(color: AppColors.grayMain, height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    l10n?.delete ?? 'Delete',
                    style: AppTextStyles.getText1(context)
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  l10n?.cancel ?? 'Cancel',
                  style: AppTextStyles.getText2(context)
                      .copyWith(color: AppColors.grayMain),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingIds.add(docId));
    try {
      await widget.onDeleteDocument(docId);
      await widget.cubit.refreshAfterDelete();
      await _loadDocuments();
    } finally {
      if (mounted) setState(() => _deletingIds.remove(docId));
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<StorageQuotaCubit, StorageQuotaState>(
      listener: (ctx, state) {
        if (widget.autoDismiss &&
            state is StorageQuotaLoaded &&
            state.quota.usedPercentage < 100) {
          Navigator.of(ctx).pop(true);
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: BlocBuilder<StorageQuotaCubit, StorageQuotaState>(
                    builder: (context, state) {
                      final quota = state is StorageQuotaLoaded ? state.quota : null;
                      final pct = quota?.usedPercentage.clamp(0.0, 100.0) ?? 100.0;
                      final progress = (pct / 100.0).clamp(0.0, 1.0);
                      final isFull = pct >= 100;
                      final barColor = isFull
                          ? const Color(0xFFEF4444)
                          : pct >= 90
                              ? const Color(0xFFE05252)
                              : pct >= 70
                                  ? const Color(0xFFE8A84C)
                                  : AppColors.main;

                      return Column(
                        children: [
                          // Icon + title
                          Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  color: barColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  isFull ? Icons.cloud_off_rounded : Icons.cleaning_services_rounded,
                                  color: barColor,
                                  size: 20.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n?.storageManage ?? 'Manage Storage',
                                      style: AppTextStyles.getTitle2(context).copyWith(
                                        color: AppColors.blackText,
                                      ),
                                    ),
                                    if (quota != null)
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          '${quota.usedFormatted} / ${quota.maxFormatted}',
                                          style: AppTextStyles.getText3(context).copyWith(
                                            color: AppColors.grayMain,
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5.r),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6.h,
                              backgroundColor: barColor.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                          SizedBox(height: 8.h),

                          // Guidance text
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              isFull
                                  ? (l10n?.storageFullBody ?? 'Free up space to upload new files.')
                                  : (l10n?.storageLargestFiles ?? 'Here are your largest documents:'),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.grayMain,
                              ),
                            ),
                          ),
                          SizedBox(height: 4.h),
                        ],
                      );
                    },
                  ),
                ),

                // Divider
                Divider(height: 1.h, color: Colors.grey.shade200),

                // Document list
                Expanded(
                  child: _loadingDocs
                      ? _buildLoadingList()
                      : _documents.isEmpty
                          ? _buildEmptyState(context)
                          : ListView.separated(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 8.h),
                              itemCount: _documents.length,
                              separatorBuilder: (_, __) => SizedBox(height: 6.h),
                              itemBuilder: (context, index) {
                                return _buildDocumentCard(
                                    context, _documents[index], l10n);
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(
      BuildContext context, Map<String, dynamic> doc, AppLocalizations? l10n) {
    final docId = doc['id']?.toString() ?? '';
    final name = doc['name']?.toString() ?? '—';
    final date = _formatDate(doc['uploaded_at']);
    final sizeBytes = (doc['file_size_bytes'] as num?)?.toInt() ?? 0;
    final sizeLabel = StorageQuotaResult.formatBytes(sizeBytes);
    final isDeleting = _deletingIds.contains(docId);
    final fileType = (doc['file_type']?.toString() ?? '').toLowerCase();
    final isPdf = fileType.contains('pdf');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.main.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: AppColors.main,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 10.w),

          // Name + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.blackText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  date,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.grayMain,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),

          // File size badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                sizeLabel,
                style: AppTextStyles.getText3(context).copyWith(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),

          // Delete button
          isDeleting
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFEF4444),
                  ),
                )
              : GestureDetector(
                  onTap: () => _confirmDelete(context, doc),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      size: 16.sp,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              height: 56.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded,
                color: AppColors.grayMain, size: 32.sp),
            SizedBox(height: 8.h),
            Text(
              'No documents found.',
              style: AppTextStyles.getText1(context)
                  .copyWith(color: AppColors.grayMain),
            ),
          ],
        ),
      ),
    );
  }
}
