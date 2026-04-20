import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// A modal bottom sheet shown when a patient attempts to upload a file while
/// their storage is at 100 %.
///
/// Lists up to 5 of their largest documents so they can delete files to free
/// space. Auto-dismisses (returns `true`) via [BlocListener] when a deletion
/// brings usage below 100 %. Returns `false` if the user closes without
/// freeing enough space.
class StorageFullBottomSheet extends StatefulWidget {
  final StorageQuotaCubit cubit;
  final Future<void> Function(String documentId) onDeleteDocument;
  final VoidCallback? onViewAllDocuments;

  const StorageFullBottomSheet({
    super.key,
    required this.cubit,
    required this.onDeleteDocument,
    this.onViewAllDocuments,
  });

  // ---------------------------------------------------------------------------
  // Static show() entry-point
  // ---------------------------------------------------------------------------

  /// Shows the bottom sheet and returns `true` if the user freed enough space.
  static Future<bool> show(
    BuildContext context, {
    required Future<void> Function(String documentId) onDeleteDocument,
    VoidCallback? onViewAllDocuments,
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
    final docName =
        doc['name']?.toString() ?? doc['title']?.toString() ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Delete Document?',
          style: AppTextStyles.getTitle2(context)
              .copyWith(color: AppColors.blackText),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$docName"? '
          'This action cannot be undone.',
          style: AppTextStyles.getText1(context)
              .copyWith(color: AppColors.textSubColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n?.cancel ?? 'Cancel',
              style: AppTextStyles.getText1(context)
                  .copyWith(color: AppColors.textSubColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n?.delete ?? 'Delete',
              style: AppTextStyles.getText1(context)
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
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
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatSize(dynamic raw) {
    if (raw == null) return '—';
    final bytes = (raw as num?)?.toInt() ?? 0;
    return _formatBytesLocal(bytes);
  }

  String _formatBytesLocal(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int idx = 0;
    while (value >= 1024 && idx < units.length - 1) {
      value /= 1024;
      idx++;
    }
    final str = value == value.truncate()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$str ${units[idx]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<StorageQuotaCubit, StorageQuotaState>(
      listener: (ctx, state) {
        // Auto-dismiss when usage drops below 100 %
        if (state is StorageQuotaLoaded && state.quota.usedPercentage < 100) {
          Navigator.of(ctx).pop(true);
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              children: [
                // ---- Drag handle ----
                Padding(
                  padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // ---- Scrollable content ----
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---- Title ----
                        Row(
                          children: [
                            Icon(Icons.storage_rounded,
                                color: Colors.red.shade600, size: 20.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: BlocBuilder<StorageQuotaCubit,
                                  StorageQuotaState>(
                                builder: (context, state) {
                                  final maxLabel = state is StorageQuotaLoaded
                                      ? state.quota.maxFormatted
                                      : '300 MB';
                                  return Text(
                                    '${l10n?.storageFullTitle ?? 'Storage Full'} ($maxLabel)',
                                    style: AppTextStyles.getTitle2(context)
                                        .copyWith(color: Colors.red.shade700),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),

                        // ---- Full red progress bar ----
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: 1.0,
                            minHeight: 6.h,
                            backgroundColor: Colors.red.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red.shade600),
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // ---- Guidance text ----
                        Text(
                          l10n?.storageFullBody ??
                              'Free up space to upload new files.',
                          style: AppTextStyles.getText1(context)
                              .copyWith(color: AppColors.textSubColor),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          l10n?.storageLargestFiles ??
                              'Here are your largest documents:',
                          style: AppTextStyles.getText2(context).copyWith(
                              color: AppColors.blackText,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 12.h),

                        // ---- Document list ----
                        if (_loadingDocs)
                          _buildLoadingList()
                        else if (_documents.isEmpty)
                          _buildEmptyState(context)
                        else
                          _buildDocumentList(context, l10n),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),

                // ---- "View All Documents" button ----
                if (widget.onViewAllDocuments != null)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16.w,
                      right: 16.w,
                      bottom:
                          MediaQuery.paddingOf(context).bottom + 12.h,
                      top: 4.h,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                          widget.onViewAllDocuments!();
                        },
                        icon: Icon(Icons.folder_open_outlined,
                            size: 16.sp, color: AppColors.main),
                        label: Text(
                          l10n?.storageViewAll ?? 'View All Documents',
                          style: AppTextStyles.getText1(context)
                              .copyWith(color: AppColors.main),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.main),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10.r)),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builders
  // ---------------------------------------------------------------------------

  Widget _buildLoadingList() {
    return Column(
      children: List.generate(
        5,
        (_) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Container(
            height: 56.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10.r),
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
        child: Text(
          'No documents found.',
          style: AppTextStyles.getText1(context)
              .copyWith(color: AppColors.textSubColor),
        ),
      ),
    );
  }

  Widget _buildDocumentList(
      BuildContext context, AppLocalizations? l10n) {
    final docs = _documents.take(5).toList();
    return Column(
      children: docs.map((doc) {
        final docId = doc['id']?.toString() ?? '';
        final name =
            doc['name']?.toString() ?? doc['title']?.toString() ?? '—';
        final date =
            _formatDate(doc['created_at'] ?? doc['uploaded_at']);
        final sizeLabel =
            _formatSize(doc['file_size'] ?? doc['size']);
        final isDeleting = _deletingIds.contains(docId);

        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.main, size: 20.sp),
              title: Text(
                name,
                style: AppTextStyles.getText2(context)
                    .copyWith(color: AppColors.blackText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$date · $sizeLabel',
                style: AppTextStyles.getText3(context)
                    .copyWith(color: AppColors.textSubColor),
              ),
              trailing: isDeleting
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade600,
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade600, size: 20.sp),
                      onPressed: () => _confirmDelete(context, doc),
                      tooltip: l10n?.delete ?? 'Delete',
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
