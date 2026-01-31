/// Contact section content.
library;

import 'package:lucide_icons/lucide_icons.dart';
import 'models.dart';
import 'constants.dart';

/// Contact section content.
abstract final class ContactContentVariants {
  /// Current production content
  static const current = ContactContent(
    sectionId: 'contact',
    title: 'Get in Touch',
    subtitle: "Let's discuss how we can help",
    description:
        "Whether you're evaluating AI observability solutions, have questions about "
        'EU AI Act compliance, or want to see a demo, our team is here to help. '
        "Reach out and we'll respond within one business day.",
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
      name: 'firstName',
      label: 'First Name',
      placeholder: 'John',
      type: 'text',
      required: true,
    ),
    ContactFormFieldContent(
      name: 'lastName',
      label: 'Last Name',
      placeholder: 'Smith',
      type: 'text',
      required: true,
    ),
    ContactFormFieldContent(
      name: 'email',
      label: 'Work Email',
      placeholder: 'john@company.com',
      type: 'email',
      required: true,
    ),
    ContactFormFieldContent(
      name: 'company',
      label: 'Company',
      placeholder: 'Acme Inc.',
      type: 'text',
      required: true,
    ),
    ContactFormFieldContent(
      name: 'companySize',
      label: 'Company Size',
      placeholder: 'Select...',
      type: 'select',
      required: true,
      options: [
        '1-10 employees',
        '11-50 employees',
        '51-200 employees',
        '201-1,000 employees',
        '1,000+ employees',
      ],
    ),
    ContactFormFieldContent(
      name: 'useCase',
      label: 'Primary Interest',
      placeholder: 'Select...',
      type: 'select',
      required: true,
      options: [
        'LLM Monitoring & Cost Tracking',
        'Agent Observability',
        'EU AI Act Compliance',
        'General AI Observability',
        'Enterprise Evaluation',
        'Partnership Inquiry',
      ],
    ),
    ContactFormFieldContent(
      name: 'message',
      label: 'Message',
      placeholder: 'Tell us about your AI observability needs...',
      type: 'textarea',
      required: false,
    ),
  ];

  static const _contactMethods = [
    ContactMethodContent(
      icon: LucideIcons.mail,
      label: 'Email',
      value: CompanyInfo.email,
      url: 'mailto:${CompanyInfo.email}',
      isPrimary: true,
    ),
    ContactMethodContent(
      icon: LucideIcons.calendar,
      label: 'Schedule a Demo',
      value: 'Book a 15-minute call',
      url: ExternalUrls.calendlyDemo,
      isPrimary: true,
    ),
    ContactMethodContent(
      icon: LucideIcons.phone,
      label: 'Phone',
      value: CompanyInfo.phone,
      url: 'tel:${CompanyInfo.phone}',
    ),
    ContactMethodContent(
      icon: LucideIcons.mapPin,
      label: 'Location',
      value: '${CompanyInfo.locationCity}, ${CompanyInfo.locationRegion}',
      url: ExternalUrls.googleMaps,
    ),
    ContactMethodContent(
      icon: LucideIcons.linkedin,
      label: 'LinkedIn',
      value: 'Follow us',
      url: ExternalUrls.linkedIn,
    ),
    ContactMethodContent(
      // Note: LucideIcons.twitter is a placeholder; XIcon widget is used via
      // label-based special casing in contact_section.dart
      icon: LucideIcons.twitter,
      label: 'X',
      value: '@integritystudio',
      url: ExternalUrls.x,
    ),
    ContactMethodContent(
      icon: LucideIcons.github,
      label: 'GitHub',
      value: 'integritystudio',
      url: ExternalUrls.github,
    ),
  ];
}
