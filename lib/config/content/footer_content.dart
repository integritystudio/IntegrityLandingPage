/// Footer section content.
library;

import 'models.dart';
import 'constants.dart';

/// Footer content.
abstract final class FooterContentVariants {
  static final current = FooterContent(
    companyName: CompanyInfo.name,
    tagline: CompanyInfo.tagline,
    copyright: CompanyInfo.copyright,
    linkGroups: _linkGroups,
    privacyLink: Routes.privacy,
    termsLink: Routes.terms,
    cookiesLink: Routes.cookies,
    accessibilityLink: Routes.accessibility,
    cookieSettingsLabel: 'Cookie Settings',
  );

  static const _linkGroups = [
    FooterLinkGroup(
      title: 'Product',
      links: [
        FooterLink(label: 'Features', url: '/features'),
        FooterLink(label: 'Pricing', url: Routes.pricing),
        FooterLink(label: 'Documentation', url: Routes.docs),
      ],
    ),
    FooterLinkGroup(
      title: 'Company',
      links: [
        FooterLink(label: 'About', url: Routes.about),
        FooterLink(label: 'Blog', url: Routes.blog),
        FooterLink(label: 'Careers', url: Routes.careers),
        FooterLink(label: 'Contact', url: Routes.contact),
      ],
    ),
    FooterLinkGroup(
      title: 'Resources',
      links: [
        FooterLink(label: 'EU AI Act Guide', url: ExternalUrls.euAiAct),
        FooterLink(label: 'API Reference', url: Routes.api),
        FooterLink(
          label: 'Status',
          url: ExternalUrls.statusPage,
          isExternal: true,
        ),
        FooterLink(label: 'Support', url: Routes.contact),
      ],
    ),
  ];
}
