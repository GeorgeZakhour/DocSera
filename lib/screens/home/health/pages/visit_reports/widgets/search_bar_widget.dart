import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class SearchBarWidget extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const SearchBarWidget({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: AppLocalizations.of(context)!.search_doctor,
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.mainDark.withOpacity(0.7),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintStyle: TextStyle(
            fontSize: 13,
            color: AppColors.mainDark.withOpacity(0.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: AppColors.main.withOpacity(0.15),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: AppColors.main.withOpacity(0.15),
            ),
          ),
        ),
      ),
    );
  }
}
