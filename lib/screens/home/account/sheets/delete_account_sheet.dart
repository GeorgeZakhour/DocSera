import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/danger/account_danger_cubit.dart';
// State is defined in the cubit file


class DeleteAccountSheet extends StatelessWidget {
  const DeleteAccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountDangerCubit, AccountDangerState>(
        builder: (context, state) {
          final isLoading = state is AccountDangerLoading;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.deleteMyAccount,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Warning Text
                Text(
                  AppLocalizations.of(context)!.deleteAccountWarningText,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 16.h),

                // Cancel
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blackText,
                    ),
                  ),
                ),

                // Confirm Delete (🔥 ONLY Cubit Call)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // ⬅️ Close sheet only
                    await context.read<AccountDangerCubit>().deleteMyAccount();
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    AppLocalizations.of(context)!.confirmDeleteMyAccount,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
    );
  }
}
