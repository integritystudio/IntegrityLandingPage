import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Text input field type.
enum FormTextFieldType { text, email, phone, url }

/// Reusable text field component with label, validation, and accessibility.
///
/// Consolidates repeated label, input, help text, and error message patterns.
///
/// Usage:
/// ```dart
/// FormTextField(
///   label: 'Email Address',
///   value: email,
///   onChanged: (value) => setState(() => email = value),
///   type: FormTextFieldType.email,
///   required: true,
///   placeholder: 'you@example.com',
///   errorText: errors['email'],
///   helpText: 'We\'ll use this to respond to your inquiry',
/// )
/// ```
class FormTextField extends StatelessWidget {
  /// Label text displayed above the field.
  final String label;

  /// Current field value.
  final String value;

  /// Called when the field value changes.
  final ValueChanged<String> onChanged;

  /// Input type (text, email, phone, url).
  final FormTextFieldType type;

  /// Whether the field is required.
  final bool required;

  /// Placeholder text.
  final String? placeholder;

  /// Error message to display.
  final String? errorText;

  /// Screen reader help text.
  final String? helpText;

  /// Autocomplete hint.
  final String? autofillHint;

  /// Whether to obscure the field value (for passwords).
  final bool obscureText;

  /// Whether the field is enabled.
  final bool enabled;

  /// Focus node for the field.
  final FocusNode? focusNode;

  /// Called when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Text input action.
  final TextInputAction? textInputAction;

  const FormTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.type = FormTextFieldType.text,
    this.required = false,
    this.placeholder,
    this.errorText,
    this.helpText,
    this.autofillHint,
    this.obscureText = false,
    this.enabled = true,
    this.focusNode,
    this.onEditingComplete,
    this.textInputAction,
  });

  TextInputType get _keyboardType => switch (type) {
        FormTextFieldType.text => TextInputType.text,
        FormTextFieldType.email => TextInputType.emailAddress,
        FormTextFieldType.phone => TextInputType.phone,
        FormTextFieldType.url => TextInputType.url,
      };

  String? get _defaultAutofillHint => switch (type) {
        FormTextFieldType.text => null,
        FormTextFieldType.email => AutofillHints.email,
        FormTextFieldType.phone => AutofillHints.telephoneNumber,
        FormTextFieldType.url => AutofillHints.url,
      };

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '$label${required ? ' *' : ''}',
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray300,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Input field
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: _keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          textInputAction: textInputAction,
          autofillHints: autofillHint != null
              ? [autofillHint!]
              : _defaultAutofillHint != null
                  ? [_defaultAutofillHint!]
                  : null,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.bodyMD.copyWith(
              color: AppColors.gray500,
            ),
            filled: true,
            fillColor: AppColors.gray800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.blue500,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          style: AppTypography.bodyMD.copyWith(
            color: AppColors.textPrimary,
          ),
        ),

        // Help text (for screen readers)
        if (helpText != null && !hasError)
          Semantics(
            label: helpText,
            child: const SizedBox.shrink(),
          ),

        // Error message
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: AppTypography.bodySM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Reusable textarea component with label, validation, and accessibility.
///
/// Consolidates repeated label, textarea, help text, and error message patterns.
///
/// Usage:
/// ```dart
/// FormTextArea(
///   label: 'Your Message',
///   value: message,
///   onChanged: (value) => setState(() => message = value),
///   required: true,
///   rows: 5,
///   minLength: 10,
///   maxLength: 2000,
///   placeholder: 'Tell us about your needs...',
///   errorText: errors['message'],
///   helpText: 'Describe your organization\'s needs',
/// )
/// ```
class FormTextArea extends StatelessWidget {
  /// Label text displayed above the field.
  final String label;

  /// Current field value.
  final String value;

  /// Called when the field value changes.
  final ValueChanged<String> onChanged;

  /// Whether the field is required.
  final bool required;

  /// Placeholder text.
  final String? placeholder;

  /// Number of visible rows.
  final int rows;

  /// Minimum character length.
  final int? minLength;

  /// Maximum character length.
  final int? maxLength;

  /// Error message to display.
  final String? errorText;

  /// Screen reader help text.
  final String? helpText;

  /// Whether the field is enabled.
  final bool enabled;

  /// Focus node for the field.
  final FocusNode? focusNode;

  /// Whether to show character count.
  final bool showCharacterCount;

  const FormTextArea({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.placeholder,
    this.rows = 5,
    this.minLength,
    this.maxLength,
    this.errorText,
    this.helpText,
    this.enabled = true,
    this.focusNode,
    this.showCharacterCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '$label${required ? ' *' : ''}',
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray300,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Textarea field
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          enabled: enabled,
          focusNode: focusNode,
          maxLines: rows,
          minLines: rows,
          maxLength: maxLength,
          buildCounter: showCharacterCount && maxLength != null
              ? null
              : (context,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTypography.bodyMD.copyWith(
              color: AppColors.gray500,
            ),
            alignLabelWithHint: true,
            filled: true,
            fillColor: AppColors.gray800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.blue500,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.md),
          ),
          style: AppTypography.bodyMD.copyWith(
            color: AppColors.textPrimary,
          ),
        ),

        // Help text (for screen readers)
        if (helpText != null && !hasError)
          Semantics(
            label: helpText,
            child: const SizedBox.shrink(),
          ),

        // Error message
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: AppTypography.bodySM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Form select/dropdown field with label and validation.
class FormSelect<T> extends StatelessWidget {
  /// Label text displayed above the field.
  final String label;

  /// Current selected value.
  final T? value;

  /// Available options.
  final List<DropdownMenuItem<T>> items;

  /// Called when selection changes.
  final ValueChanged<T?> onChanged;

  /// Whether the field is required.
  final bool required;

  /// Placeholder text.
  final String? placeholder;

  /// Error message to display.
  final String? errorText;

  /// Whether the field is enabled.
  final bool enabled;

  const FormSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.placeholder,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '$label${required ? ' *' : ''}',
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray300,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Dropdown
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          hint: placeholder != null
              ? Text(
                  placeholder!,
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray500,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          dropdownColor: AppColors.gray800,
          style: AppTypography.bodyMD.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.gray800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.gray700,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.blue500,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),

        // Error message
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: AppTypography.bodySM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
