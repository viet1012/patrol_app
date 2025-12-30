import 'package:flutter/material.dart';
import 'common_ui_helper.dart';

enum ReportError { noImage, noMachine, noComment }

class ReportValidator {
  ReportValidator._();

  static bool validate({
    required BuildContext context,
    required List images,
    required String? selectedMachine,
    required String comment,
  }) {
    if (images.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: "Photo Required",
        message: "Please take at least one photo before continuing.",
      );
      return false;
    }

    if (selectedMachine == null) {
      CommonUI.showWarning(
        context: context,
        title: "Information Required",
        message: "Please select all required information.",
      );
      return false;
    }

    if (comment.trim().isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: "Comment Required",
        message: "Please enter a comment.",
      );
      return false;
    }

    return true;
  }
}
