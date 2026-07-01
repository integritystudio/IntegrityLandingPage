/// About section content.
library;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'models.dart';
import 'constants.dart';

/// About section content.
abstract final class AboutContentVariants {
  /// Current production content
  static final current = AboutContent(
    sectionId: 'about',
    title: 'About ${CompanyInfo.name}',
    subtitle: 'Building Trust in AI Systems',
    missionStatement:
        'Empower enterprises to build trustworthy AI systems through comprehensive '
        'observability and governance tools.',
    visionStatement:
        'To be the standard for enterprise AI observability, enabling organizations '
        'to deploy AI confidently while meeting regulatory requirements.',
    story: _companyStory,
    values: _values,
    team: _team,
    locationCity: CompanyInfo.locationCity,
    locationRegion: CompanyInfo.locationRegion,
    foundedYear: CompanyInfo.foundedYear,
  );

  static const _companyStory =
      '${CompanyInfo.name} was founded with a clear purpose: to solve the visibility problem '
      'in production AI systems. As LLMs and AI agents became critical to business operations, '
      'we saw teams struggling with black-box AI decisions, unpredictable costs, and looming '
      'regulatory requirements like the EU AI Act.\n\n'
      'Our founders built observability tools at scale before, and recognized that AI systems '
      'needed purpose-built monitoring—not retrofitted APM solutions. We designed ${CompanyInfo.name} '
      'from the ground up for the unique challenges of LLM applications: token-level cost attribution, '
      'multi-step agent tracing, and compliance documentation that satisfies auditors.\n\n'
      'Today, we help AI teams ship reliable, compliant applications faster. Our platform provides '
      'the visibility they need to debug issues, optimize costs, and demonstrate governance to '
      'stakeholders—all from a single pane of glass.';

  static const _values = [
    CompanyValueContent(
      icon: LucideIcons.eye,
      title: 'Transparency',
      description:
          'We believe AI systems should be observable and explainable. Every decision, '
          'every cost, every outcome should be visible to the teams responsible for them.',
    ),
    CompanyValueContent(
      icon: LucideIcons.shieldCheck,
      title: 'Trust',
      description:
          'Trust is earned through reliability, security, and accountability. We build tools '
          'that help our customers demonstrate trustworthiness to their users and regulators.',
    ),
    CompanyValueContent(
      icon: LucideIcons.users,
      title: 'Developer-First',
      description:
          "Great tools should get out of the developer's way. We prioritize clean APIs, "
          'fast integration, and minimal overhead so teams can focus on building.',
    ),
    CompanyValueContent(
      icon: LucideIcons.scale,
      title: 'Compliance by Design',
      description:
          "Regulatory requirements shouldn't be an afterthought. We embed compliance "
          'capabilities into the platform so governance happens automatically.',
    ),
  ];

  static final _team = [
    TeamMemberContent(
      name: 'Chase Hoffman',
      role: 'Co-Founder and President',
      bio:
          'Seasoned technology executive with deep expertise in scaling enterprise software companies. '
          'Focused on developing high-performance monitization systems and cost optimization that deliver exceptional customer success.',
      imageAlt: 'Chase Hoffman, Co-Founder and President of Integrity Studio',
      linkedInUrl: 'https://www.linkedin.com/in/hoffmanchase/',
      websiteUrl: 'https://www.hoffmanchase.com/',
    ),
    TeamMemberContent(
      name: 'Alyshia Ledlie',
      role: 'Founder and CEO',
      bio:
          'Deep experience building observability-first infrastructure at scale. Passionate about making '
          'AI systems transparent and trustworthy for enterprises navigating regulatory change.',
      imageAlt: 'Alyshia Ledlie, Founder and CEO of Integrity Studio',
      linkedInUrl: ExternalUrls.founderLinkedIn,
    ),
    TeamMemberContent(
      name: 'Chandra Srivastava',
      role: 'Co-founder & CMO',
      bio:
          'Marketing leader with experience driving growth at early stage B2B technology companies. '
          'Expert in positioning AI products for enterprise adoption and building category-defining brands.',
      imageAlt: 'Chandra Srivastava, Co-founder and CMO of Integrity Studio',
      linkedInUrl: 'https://www.linkedin.com/in/chandra-srivastava/',
      websiteUrl: 'https://www.chandrasrivastava.com/',
    ),
    TeamMemberContent(
      name: 'Micah Lindsay',
      role: 'Chief Data Scientist',
      bio:
          'Machine learning researcher focused on AI evaluation and observability. '
          'Developed novel approaches to precise hallucination detection and model performance analysis.',
      imageAlt: 'Micah Lindsay, Chief Data Scientist at Integrity Studio',
      linkedInUrl: 'https://www.linkedin.com/in/micahlindsey/',
      websiteUrl: 'http://www.micahlindsey.com/',
    ),
    TeamMemberContent(
      name: 'John Skelton',
      role: 'Head of Policy',
      bio:
          'Regulatory and compliance expert specializing in AI governance frameworks. '
          'Advises enterprises on EU AI Act preparation and responsible AI deployment.',
      imageAlt: 'John Skelton, Head of Policy at Integrity Studio',
    ),
    TeamMemberContent(
      name: 'Isabel Budenz',
      role: 'AI Compliance Counsel',
      bio:
          'International legal expert specializing in AI governance and EU AI Act compliance. '
          'Background in International Commercial Arbitration with multilingual research capabilities spanning German, Spanish, English, and French legal systems.',
      imageAlt: 'Isabel Budenz, AI Compliance Counsel at Integrity Studio',
    ),
  ];
}
