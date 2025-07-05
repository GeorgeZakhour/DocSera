import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';

class EditDocumentNameSheet extends StatefulWidget {
  final String initialName;
  final Function(String) onConfirm;
  final void Function(String)? onNameUpdated; // ← optional callback

  const EditDocumentNameSheet({
    Key? key,
    required this.initialName,
    required this.onConfirm,
    required this.onNameUpdated,

  }) : super(key: key);

  @override
  State<EditDocumentNameSheet> createState() => _EditDocumentNameSheetState();
}

class _EditDocumentNameSheetState extends State<EditDocumentNameSheet> {
  late TextEditingController _controller;
  String _name = "";

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _name = widget.initialName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24.w,
        right: 24.w,
        top: 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔹 Title + Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // Placeholder for alignment
              Text(
                locale.changeTheNameOfTheDocument,
                style: AppTextStyles.getTitle1(context),
              ),
              IconButton(
                icon:  Icon(Icons.close, size: 18.sp,),
                onPressed: () => Navigator.pop(context),
              ),

            ],
          ),

          SizedBox(height: 20.h),

          // 🔹 Label
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              locale.nameOfTheDocument,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp),
            ),
          ),
          SizedBox(height: 8.h),

          // 🔹 Text Field
          TextFormField(
            controller: _controller,
            textDirection: detectTextDirection(_controller.text),
            textAlign: getTextAlign(context),
            style: AppTextStyles.getText2(context),
            maxLength: 50,
            onChanged: (val) => setState(() => _name = val.trim()),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              counterText: "${_name.length}/50",
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            ),
          ),

          SizedBox(height: 20.h),

          // 🔹 Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _name.isEmpty
                  ? null
                  : () {
                Navigator.pop(context);
                widget.onConfirm(_name);
                widget.onNameUpdated?.call(_name); // ✅ هاد هو المكان الصح
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: _name.isEmpty ? Colors.grey[200] : AppColors.mainDark,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                locale.confirm.toUpperCase(),
                style: AppTextStyles.getTitle1(context).copyWith(
                  color: _name.isEmpty ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
