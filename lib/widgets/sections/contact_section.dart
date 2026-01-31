import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../../services/contact_service.dart';
import '../common/alert.dart';
import '../common/cards.dart';
import '../common/containers.dart';
import '../common/buttons.dart';
import '../common/form_fields.dart';
import '../common/x_icon.dart';

/// Contact section with form and contact methods.
///
/// Designed for enterprise lead capture with qualification fields.
///
/// Features:
/// - Contact form with validation
/// - Multiple contact methods (email, calendar, social)
/// - Calendly integration for demo scheduling
/// - Success/error messaging
///
/// Usage:
/// ```dart
/// ContactSection(
///   content: ContactContent.current, // or AppContent.contact
///   onFormSubmit: (data) => submitToBackend(data),
/// )
/// ```
class ContactSection extends StatefulWidget {
  final ContactContent content;
  final Future<bool> Function(Map<String, String>)? onFormSubmit;

  const ContactSection({
    super.key,
    this.content = const ContactContent(
      sectionId: 'contact',
      title: 'Contact',
      subtitle: '',
      description: '',
      formFields: [],
      contactMethods: [],
      formSubmitText: 'Submit',
      formSuccessMessage: 'Thank you!',
      formErrorMessage: 'Error',
      calendlyUrl: '',
      calendlyCtaText: 'Schedule Demo',
    ),
    this.onFormSubmit,
  });

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection> {
  final _formKey = GlobalKey<FormState>();
  final _formData = <String, String>{};
  final _fieldErrors = <String, String>{};
  bool _isSubmitting = false;
  bool? _submitSuccess;
  String? _successMessage;
  String? _errorMessage;

  // Use content from widget or fallback to AppContent
  ContactContent get _content =>
      widget.content.formFields.isEmpty ? AppContent.contact : widget.content;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      id: _content.sectionId,
      backgroundColor: AppColors.gray800,
      child: Column(
        children: [
          // Section header
          SectionTitle(
            title: _content.title,
            subtitle: _content.subtitle,
          ),

          if (_content.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                _content.description,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
          ],

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Contact form and methods
          isMobile
              ? _buildMobileLayout(context)
              : _buildDesktopLayout(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contact form (2/3 width)
        Expanded(
          flex: 2,
          child: _buildContactForm(context),
        ),
        const SizedBox(width: AppSpacing.xxl),
        // Contact methods (1/3 width)
        Expanded(
          flex: 1,
          child: _buildContactMethods(context),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildContactMethods(context),
        const SizedBox(height: AppSpacing.xxl),
        _buildContactForm(context),
      ],
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.secondary,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send us a message',
              style: AppTypography.headingSM,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Form fields
            ..._buildFormFields(),

            const SizedBox(height: AppSpacing.lg),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: _isSubmitting ? 'Sending...' : _content.formSubmitText,
                onPressed: _isSubmitting ? null : _handleSubmit,
              ),
            ),

            // Success/error message using Alert widget
            if (_submitSuccess != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Alert(
                variant:
                    _submitSuccess! ? AlertVariant.success : AlertVariant.error,
                message: _submitSuccess!
                    ? (_successMessage ?? _content.formSuccessMessage)
                    : (_errorMessage ?? _content.formErrorMessage),
                dismissible: true,
                onDismiss: () => setState(() => _submitSuccess = null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final fields = <Widget>[];
    final formFields = _content.formFields;

    // Group fields in rows of 2 for name fields
    for (int i = 0; i < formFields.length; i++) {
      final field = formFields[i];

      // Check if we can pair this field with the next one
      final canPair = i + 1 < formFields.length &&
          field.type == 'text' &&
          formFields[i + 1].type == 'text' &&
          (field.name.contains('Name') || field.name.contains('first') ||
              field.name.contains('last'));

      if (canPair) {
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: _buildField(field)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildField(formFields[i + 1])),
              ],
            ),
          ),
        );
        i++; // Skip the next field since we already added it
      } else {
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildField(field),
          ),
        );
      }
    }

    return fields;
  }

  Widget _buildField(ContactFormFieldContent field) {
    switch (field.type) {
      case 'select':
        return FormSelect<String>(
          label: field.label,
          value: _formData[field.name],
          items: field.options
                  ?.map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ))
                  .toList() ??
              [],
          required: field.required,
          placeholder: field.placeholder,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _formData[field.name] = value;
                _fieldErrors.remove(field.name);
              });
            }
          },
        );

      case 'textarea':
        return FormTextArea(
          label: field.label,
          value: _formData[field.name] ?? '',
          required: field.required,
          placeholder: field.placeholder,
          rows: 4,
          minLength: 10,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            setState(() {
              _formData[field.name] = value;
              _fieldErrors.remove(field.name);
            });
          },
        );

      case 'email':
        return FormTextField(
          label: field.label,
          value: _formData[field.name] ?? '',
          type: FormTextFieldType.email,
          required: field.required,
          placeholder: field.placeholder,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            setState(() {
              _formData[field.name] = value;
              _fieldErrors.remove(field.name);
            });
          },
        );

      case 'phone':
        return FormTextField(
          label: field.label,
          value: _formData[field.name] ?? '',
          type: FormTextFieldType.phone,
          required: field.required,
          placeholder: field.placeholder,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            setState(() {
              _formData[field.name] = value;
              _fieldErrors.remove(field.name);
            });
          },
        );

      case 'url':
        return FormTextField(
          label: field.label,
          value: _formData[field.name] ?? '',
          type: FormTextFieldType.url,
          required: field.required,
          placeholder: field.placeholder,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            setState(() {
              _formData[field.name] = value;
              _fieldErrors.remove(field.name);
            });
          },
        );

      default:
        return FormTextField(
          label: field.label,
          value: _formData[field.name] ?? '',
          type: FormTextFieldType.text,
          required: field.required,
          placeholder: field.placeholder,
          errorText: _fieldErrors[field.name],
          onChanged: (value) {
            setState(() {
              _formData[field.name] = value;
              _fieldErrors.remove(field.name);
            });
          },
        );
    }
  }

  Widget _buildContactMethods(BuildContext context) {
    final primaryMethods =
        _content.contactMethods.where((m) => m.isPrimary).toList();
    final secondaryMethods =
        _content.contactMethods.where((m) => !m.isPrimary).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary contact methods
        GlassCard(
          tier: GlassCardTier.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get in touch',
                style: AppTypography.headingSM,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...primaryMethods.map((method) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _ContactMethodItem(
                      method: method,
                      isPrimary: true,
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Schedule demo CTA
        if (_content.calendlyUrl.isNotEmpty)
          GlassCard(
            tier: GlassCardTier.primary,
            child: Column(
              children: [
                GradientIconContainer(
                  icon: Icons.video_call_outlined,
                  size: 56,
                  iconSize: 28,
                  borderRadius: AppSpacing.radiusMD,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Want a Live Demo?',
                  style: AppTypography.headingSM,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'See the platform in action with a personalized walkthrough.',
                  style: AppTypography.bodySM,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: _content.calendlyCtaText,
                    onPressed: () async {
                      AnalyticsService.trackCTAClick(
                        buttonName: _content.calendlyCtaText,
                        location: 'contact_section',
                      );
                      final uri = Uri.parse(_content.calendlyUrl);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.lg),

        // Secondary contact methods (social links)
        if (secondaryMethods.isNotEmpty)
          GlassCard(
            tier: GlassCardTier.tertiary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow us',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: secondaryMethods
                      .map((method) => _ContactMethodItem(
                            method: method,
                            isPrimary: false,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Validate form using ContactService.
  bool _validateForm() {
    // Build ContactFormData from form fields
    final formData = ContactFormData(
      name: _formData['name'] ?? _formData['firstName'] ?? '',
      email: _formData['email'] ?? '',
      organization: _formData['organization'] ?? _formData['company'],
      message: _formData['message'] ?? '',
    );

    final errors = ContactService.validateForm(formData);

    setState(() {
      _fieldErrors.clear();
      if (errors.name != null) {
        _fieldErrors['name'] = errors.name!;
        _fieldErrors['firstName'] = errors.name!;
      }
      if (errors.email != null) _fieldErrors['email'] = errors.email!;
      if (errors.organization != null) {
        _fieldErrors['organization'] = errors.organization!;
        _fieldErrors['company'] = errors.organization!;
      }
      if (errors.message != null) _fieldErrors['message'] = errors.message!;
    });

    return !errors.hasErrors;
  }

  Future<void> _handleSubmit() async {
    // Validate using ContactService
    if (!_validateForm()) return;

    setState(() {
      _isSubmitting = true;
      _submitSuccess = null;
      _successMessage = null;
      _errorMessage = null;
    });

    AnalyticsService.trackFormSubmit('contact_form');

    try {
      if (widget.onFormSubmit != null) {
        final success = await widget.onFormSubmit!(_formData);
        setState(() {
          _isSubmitting = false;
          _submitSuccess = success;
        });
      } else {
        // Use ContactService for submission
        final formData = ContactFormData(
          name: _formData['name'] ?? _formData['firstName'] ?? '',
          email: _formData['email'] ?? '',
          organization: _formData['organization'] ?? _formData['company'],
          message: _formData['message'] ?? '',
        );

        final payload = ContactFormPayload(formData: formData);
        final response = await ContactService.submitForm(payload);

        setState(() {
          _isSubmitting = false;
          switch (response) {
            case ContactFormSuccess(:final message):
              _submitSuccess = true;
              _successMessage = message;
              // Track Facebook Pixel events on success
              FacebookPixelService.trackContact(
                email: formData.email,
                name: formData.name,
              );
              FacebookPixelService.trackLead(email: formData.email);
              // Clear form on success
              _formData.clear();
            case ContactFormError(:final error, :final fieldErrors):
              _submitSuccess = false;
              _errorMessage = error;
              if (fieldErrors != null) {
                _fieldErrors.addAll(fieldErrors);
              }
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _submitSuccess = false;
        _errorMessage = e.toString();
      });
    }
  }
}

/// Individual contact method item.
class _ContactMethodItem extends StatelessWidget {
  final ContactMethodContent method;
  final bool isPrimary;

  const _ContactMethodItem({
    required this.method,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPrimary) {
      // Compact social link button
      return Tooltip(
        message: method.label,
        child: InkWell(
          onTap: method.url != null
              ? () async {
                  final uri = Uri.parse(method.url!);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          child: method.label == 'X'
              ? _buildXIconContainer(
                  color: AppColors.gray700.withValues(alpha: 0.5),
                  size: 44,
                  iconSize: 20,
                  iconColor: AppColors.gray300,
                )
              : GradientIconContainer.solid(
                  icon: method.icon,
                  color: AppColors.gray700.withValues(alpha: 0.5),
                  size: 44,
                  iconSize: 20,
                  iconColor: AppColors.gray300,
                ),
        ),
      );
    }

    // Primary contact method with full details
    return InkWell(
      onTap: method.url != null
          ? () async {
              final uri = Uri.parse(method.url!);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Row(
        children: [
          GradientIconContainer.translucent(
            icon: method.icon,
            color: AppColors.blue500,
            iconColor: AppColors.blue400,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.label,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  method.value,
                  style: AppTypography.bodyMD.copyWith(
                    color: method.url != null
                        ? AppColors.blue400
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (method.url != null)
            const Icon(
              Icons.arrow_forward,
              size: 18,
              color: AppColors.gray500,
            ),
        ],
      ),
    );
  }

  /// Builds a container for the X icon that matches GradientIconContainer.solid style.
  Widget _buildXIconContainer({
    required Color color,
    required double size,
    required double iconSize,
    required Color iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Center(
        child: XIcon(size: iconSize, color: iconColor),
      ),
    );
  }
}
