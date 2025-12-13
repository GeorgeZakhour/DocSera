import 'package:docsera/screens/home/health/widgets/health_master_item.dart';
import 'package:docsera/screens/home/health/widgets/health_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// ----------------------------------------------------------------
/// GENERIC MASTER SEARCH STEP  (with header text + ARB support)
/// ----------------------------------------------------------------
class HealthMasterSearchStep<T> extends StatefulWidget {
  /// يبحث داخل الـ master list
  final Future<List<T>> Function(String query) onSearch;

  /// استخراج العنوان من الـ item
  final String Function(T item, bool isArabic) getTitle;

  /// استخراج الوصف من الـ item
  final String Function(T item, bool isArabic) getSubtitle;

  /// آيكون العنصر
  final IconData icon;

  /// هل هذا العنصر Disabled؟
  final bool Function(T item) isDisabled;

  /// عند اختيار عنصر
  final Function(T item) onSelect;

  /// نص عندما لا يوجد نتائج — من ARB
  final String emptyResultsText;

  /// نص الشارة عندما يكون العنصر موجود مسبقاً — من ARB
  final String alreadyAddedText;

  /// نص الهيدر فوق السيرش — من ARB
  final String? headerText;

  /// القيمة التي ستستعمل داخل نص الـ Search hint (مثل: الحساسية، العملية...)
  final String searchValue;

  const HealthMasterSearchStep({
    super.key,
    required this.onSearch,
    required this.getTitle,
    required this.getSubtitle,
    required this.icon,
    required this.isDisabled,
    required this.onSelect,
    required this.emptyResultsText,
    required this.alreadyAddedText,
    required this.searchValue,
    this.headerText,
  });

  @override
  State<HealthMasterSearchStep<T>> createState() =>
      _HealthMasterSearchStepState<T>();
}

class _HealthMasterSearchStepState<T> extends State<HealthMasterSearchStep<T>> {
  final TextEditingController _searchController = TextEditingController();

  List<T> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
    _searchController.addListener(() {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);

    final res = await widget.onSearch(query);

    // ترتيب العناصر بحيث المتاح يظهر أولاً
    res.sort((a, b) {
      final ad = widget.isDisabled(a);
      final bd = widget.isDisabled(b);
      if (ad && !bd) return 1;
      if (!ad && bd) return -1;
      return 0;
    });

    setState(() {
      _results = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),

        /// HEADER TEXT (optional)
        if (widget.headerText != null) ...[
          Text(
            widget.headerText!,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 11.sp,
              color: AppColors.grayMain,
            ),
          ),
          SizedBox(height: 10.h),
        ],

        /// SEARCH FIELD (NOW DYNAMIC)
        HealthSearchField(
          controller: _searchController,
          hint: t.health_search_hint(widget.searchValue),
          onClear: () {
            _searchController.clear();
            _performSearch('');
          },
        ),

        SizedBox(height: 12.h),

        /// RESULTS LIST
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.main))
              : _results.isEmpty
              ? Center(
            child: Text(
              widget.emptyResultsText,
              style: AppTextStyles.getText3(context).copyWith(
                fontSize: 12.sp,
                color: AppColors.grayMain,
              ),
            ),
          )
              : ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              final disabled = widget.isDisabled(item);

              return HealthMasterTile(
                title: widget.getTitle(item, isArabic),
                subtitle: widget.getSubtitle(item, isArabic),
                icon: widget.icon,
                disabled: disabled,
                selected: false,
                badgeText:
                disabled ? widget.alreadyAddedText : null,
                onTap: disabled ? null : () => widget.onSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
