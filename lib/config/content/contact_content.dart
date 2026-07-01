/// Contact section content.
library;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'models.dart';
import 'constants.dart';

/// Contact section content.
abstract final class ContactContentVariants {
  // Contact form field names
  static const firstNameFieldName = 'firstName';
  static const lastNameFieldName = 'lastName';
  static const emailFieldName = 'email';
  static const companyFieldName = 'company';
  static const companySizeFieldName = 'companySize';
  static const useCaseFieldName = 'useCase';
  static const messageFieldName = 'message';

  // Contact form field labels
  static const firstNameLabel = 'First Name';
  static const lastNameLabel = 'Last Name';
  static const emailLabel = 'Work Email';
  static const companyLabel = 'Company';
  static const companySizeLabel = 'Company Size';
  static const useCaseLabel = 'Primary Interest';
  static const messageLabel = 'Message';

  // Contact form field placeholders
  static const firstNamePlaceholder = 'John';
  static const lastNamePlaceholder = 'Smith';
  static const emailPlaceholder = 'john@company.com';
  static const companyPlaceholder = 'Acme Inc.';
  static const selectPlaceholder = 'Select...';
  static const messagePlaceholder = 'Tell us about your AI observability needs...';

  // Contact form field types
  static const textFieldType = 'text';
  static const emailFieldType = 'email';
  static const selectFieldType = 'select';
  static const textareaFieldType = 'textarea';

  // Contact form options
  static const companySizeOptions = [
    '1-10 employees',
    '11-50 employees',
    '51-200 employees',
    '201-1,000 employees',
    '1,000+ employees',
  ];

  static const useCaseOptions = [
    'LLM Monitoring & Cost Tracking',
    'Agent Observability',
    'EU AI Act Compliance',
    'General AI Observability',
    'Enterprise Evaluation',
    'Partnership Inquiry',
  ];

  // Contact methods labels
  static const emailMethodLabel = 'Email';
  static const scheduleADemoMethodLabel = 'Schedule a Demo';
  static const phoneMethodLabel = 'Phone';
  static const locationMethodLabel = 'Location';
  static const linkedinMethodLabel = 'LinkedIn';
  static const githubMethodLabel = 'GitHub';

  // Contact methods values
  static const scheduleADemoMethodValue = 'Book a 15-minute call';
  static const linkedinMethodValue = 'Follow us';
  static const githubMethodValue = 'integritystudio';

  // Contact page content
  static const sectionId = 'contact';
  static const contentTitle = 'Get in Touch';
  static const contentSubtitle = "Let's discuss how we can help";
  static const contentDescription =
      "Whether you're evaluating AI observability solutions, have questions about "
      'EU AI Act compliance, or want to see a demo, our team is here to help. '
      "Reach out and we'll respond within one business day.";

  // Contact page hero content
  static const heroBadge = "We're Here to Help";
  static const heroHeadline = 'Get in Touch';
  static const heroSubheadline =
      'Have questions about AI observability? Need help with integration? '
      'Our team is ready to assist you.';

  /// Current production content
  static final current = ContactContent(
    sectionId: sectionId,
    title: contentTitle,
    subtitle: contentSubtitle,
    description: contentDescription,
    formFields: _formFields,
    contactMethods: _contactMethods,
    formSubmitText: CTAText.sendMessage,
    formSuccessMessage: FormMessages.contactSuccess,
    formErrorMessage: FormMessages.contactError,
    calendlyUrl: ExternalUrls.calendlyDemo,
    calendlyCtaText: CTAText.scheduledDemo,
  );

  static const _formFields = [
    ContactFormFieldContent(
      name: firstNameFieldName,
      label: firstNameLabel,
      placeholder: firstNamePlaceholder,
      type: textFieldType,
      required: true,
    ),
    ContactFormFieldContent(
      name: lastNameFieldName,
      label: lastNameLabel,
      placeholder: lastNamePlaceholder,
      type: textFieldType,
      required: true,
    ),
    ContactFormFieldContent(
      name: emailFieldName,
      label: emailLabel,
      placeholder: emailPlaceholder,
      type: emailFieldType,
      required: true,
    ),
    ContactFormFieldContent(
      name: companyFieldName,
      label: companyLabel,
      placeholder: companyPlaceholder,
      type: textFieldType,
      required: true,
    ),
    ContactFormFieldContent(
      name: companySizeFieldName,
      label: companySizeLabel,
      placeholder: selectPlaceholder,
      type: selectFieldType,
      required: true,
      options: companySizeOptions,
    ),
    ContactFormFieldContent(
      name: useCaseFieldName,
      label: useCaseLabel,
      placeholder: selectPlaceholder,
      type: selectFieldType,
      required: true,
      options: useCaseOptions,
    ),
    ContactFormFieldContent(
      name: messageFieldName,
      label: messageLabel,
      placeholder: messagePlaceholder,
      type: textareaFieldType,
      required: false,
    ),
  ];

  static final _contactMethods = [
    ContactMethodContent(
      icon: LucideIcons.mail,
      label: emailMethodLabel,
      value: CompanyInfo.email,
      url: 'mailto:${CompanyInfo.email}',
      isPrimary: true,
    ),
    ContactMethodContent(
      icon: LucideIcons.calendar,
      label: scheduleADemoMethodLabel,
      value: scheduleADemoMethodValue,
      url: ExternalUrls.calendlyDemo,
      isPrimary: true,
    ),
    ContactMethodContent(
      icon: LucideIcons.phone,
      label: phoneMethodLabel,
      value: CompanyInfo.phone,
      url: 'tel:${CompanyInfo.phone}',
    ),
    ContactMethodContent(
      icon: LucideIcons.mapPin,
      label: locationMethodLabel,
      value: '${CompanyInfo.locationCity}, ${CompanyInfo.locationRegion}',
      url: ExternalUrls.googleMaps,
    ),
    ContactMethodContent(
      icon: LucideIcons.briefcase,
      label: linkedinMethodLabel,
      value: linkedinMethodValue,
      url: ExternalUrls.linkedIn,
    ),
    ContactMethodContent(
      icon: LucideIcons.code,
      label: githubMethodLabel,
      value: githubMethodValue,
      url: ExternalUrls.github,
    ),
  ];
}
