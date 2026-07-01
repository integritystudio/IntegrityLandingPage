import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';

/// Legal page type enum.
enum LegalPageType { privacy, terms, cookies, accessibility }

/// Legal page displaying Privacy Policy, Terms of Service, Cookies Policy,
/// or Accessibility Statement.
///
/// Provides consistent styling for legal content with:
/// - Responsive layout
/// - Proper heading hierarchy
/// - Section organization
/// - Back navigation
class LegalPage extends StatelessWidget {
  final LegalPageType type;
  final VoidCallback? onBack;

  const LegalPage({
    super.key,
    required this.type,
    this.onBack,
  });

  /// Factory constructor for Privacy Policy page.
  factory LegalPage.privacy({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.privacy,
        onBack: onBack,
      );

  /// Factory constructor for Terms of Service page.
  factory LegalPage.terms({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.terms,
        onBack: onBack,
      );

  /// Factory constructor for Cookies Policy page.
  factory LegalPage.cookies({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.cookies,
        onBack: onBack,
      );

  /// Factory constructor for Accessibility Statement page.
  factory LegalPage.accessibility({VoidCallback? onBack}) => LegalPage(
        type: LegalPageType.accessibility,
        onBack: onBack,
      );

  String get _title => switch (type) {
        LegalPageType.privacy => 'Privacy Policy',
        LegalPageType.terms => 'Terms of Service',
        LegalPageType.cookies => 'Cookie Policy',
        LegalPageType.accessibility => 'Accessibility Statement',
      };

  Widget get _content => switch (type) {
        LegalPageType.privacy => _PrivacyPolicyContent(),
        LegalPageType.terms => _TermsOfServiceContent(),
        LegalPageType.cookies => _CookiesPolicyContent(),
        LegalPageType.accessibility => _AccessibilityStatementContent(),
      };

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.gray900,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
            ),
            title: Text(
              _title,
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: onBack ?? () => context.go('/'),
                  child: Text(
                    'Back to Home',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: _HeroSection(
              type: type,
              isMobile: isMobile,
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _content,
              ),
            ),
          ),

          // Footer spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final LegalPageType type;
  final bool isMobile;

  const _HeroSection({required this.type, required this.isMobile});

  IconData get _icon => switch (type) {
        LegalPageType.privacy => LucideIcons.shield,
        LegalPageType.terms => LucideIcons.fileText,
        LegalPageType.cookies => LucideIcons.cookie,
        LegalPageType.accessibility => LucideIcons.accessibility,
      };

  String get _badge => switch (type) {
        LegalPageType.privacy => 'Your Privacy Matters',
        LegalPageType.terms => 'Legal Agreement',
        LegalPageType.cookies => 'Cookie Information',
        LegalPageType.accessibility => 'Inclusive Design',
      };

  String get _title => switch (type) {
        LegalPageType.privacy => 'Privacy Policy',
        LegalPageType.terms => 'Terms of Service',
        LegalPageType.cookies => 'Cookie Policy',
        LegalPageType.accessibility => 'Accessibility Statement',
      };

  String get _subtitle => switch (type) {
        LegalPageType.privacy =>
          'This policy describes how ${CompanyInfo.name} collects, uses, and protects your personal information. We comply with GDPR, CCPA/CPRA, and other relevant privacy regulations.',
        LegalPageType.terms =>
          'Please read these terms carefully before using the ${CompanyInfo.name} services.',
        LegalPageType.cookies =>
          'This policy explains how we use cookies and similar technologies on our website.',
        LegalPageType.accessibility =>
          'We are committed to ensuring digital accessibility for all users, including people with disabilities.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray900,
            AppColors.gray800.withValues(alpha: 0.5),
            AppColors.gray900,
          ],
        ),
      ),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icon,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _badge,
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              _title,
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 32)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Last updated
            Text(
              'Last updated: December 1, 2025',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                _subtitle,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Privacy Policy content.
class _PrivacyPolicyContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: '1. What Data Do We Collect?',
          content: '''
**Information You Provide Directly**

- **Contact Information**: Name, email address, phone number, organization name when you contact us or schedule a consultation
- **Communication Data**: Messages, feedback, and correspondence through our contact forms or email
- **Project Information**: Details about your organization's needs, goals, and challenges shared during consultations
- **Account Information**: Login credentials if you access client dashboards or project portals

**Information Collected Automatically**

- **Usage Data**: Pages visited, time spent, navigation paths
- **Device Information**: Browser type, operating system, screen resolution
- **IP Address**: Anonymized for analytics purposes
- **Cookies**: As described in our Cookie Policy

**Important**: During consulting engagements, we may access client systems and data only as authorized and necessary to provide our services. All client data remains owned by the client and is handled according to our consulting agreements.
''',
        ),
        _LegalSection(
          title: '2. How We Use Your Data',
          content: '''
We use your data to:

- Provide AI consulting, implementation, and observability services
- Respond to inquiries and schedule consultations
- Improve our website and service offerings
- Send relevant updates about our services (with your consent)
- Comply with legal obligations
- Analyze website performance and user experience

We do **not** sell your data, share it with third-party advertisers, or use it for purposes outside of providing ${CompanyInfo.name} services.
''',
        ),
        _LegalSection(
          title: '3. Legal Basis for Processing (GDPR)',
          content: '''
- **Consent**: When you submit contact forms or opt-in to communications
- **Contractual necessity**: Processing required to fulfill consulting services
- **Legitimate interests**: Website analytics and service improvement (balanced against your rights)
- **Legal obligation**: Compliance with applicable laws and regulations
''',
        ),
        _LegalSection(
          title: '4. Data Retention',
          content: '''
- **Contact form submissions**: Retained for 2 years unless you request deletion
- **Client project data**: Retained as specified in consulting agreements, typically 3 years post-engagement
- **Website analytics**: Anonymized data retained for 26 months
- **Communication records**: Retained for 5 years for legal compliance

You may request deletion of your data at any time by contacting us at ${CompanyInfo.privacyEmail}.
''',
        ),
        _LegalSection(
          title: '5. Your Rights',
          content: '''
Depending on your location, you may have the following rights:

- **Access**: Request a copy of your personal data
- **Rectification**: Correct inaccurate or incomplete data
- **Deletion**: Request deletion of your personal data ("right to be forgotten")
- **Restriction**: Limit how we process your data
- **Portability**: Receive your data in a portable format
- **Objection**: Object to certain types of processing
- **Withdraw consent**: Withdraw previously given consent at any time

**California residents**: Under CCPA/CPRA, you have additional rights including the right to know what personal information is collected and the right to opt-out of sale/sharing (note: we do not sell personal information).
''',
        ),
        _LegalSection(
          title: '6. Data Security',
          content: '''
We implement industry-standard security measures including:

- Encryption in transit (TLS 1.3) and at rest
- Secure access controls and authentication
- Regular security assessments and audits
- Employee training on data protection
- Incident response procedures

In the event of a data breach affecting your personal information, we will notify you and relevant authorities as required by law.
''',
        ),
        _LegalSection(
          title: '7. AI & Data Practices',
          content: '''
As an AI consultancy, we adhere to ethical AI principles:

- **Transparency**: We clearly explain how AI is used in our services
- **Client ownership**: All AI models and outputs developed for clients belong to the client
- **No training on client data**: We do not use client data to train AI models for other purposes
- **Bias mitigation**: We actively work to identify and reduce AI bias
- **Human oversight**: AI recommendations are reviewed by human experts

When we use AI tools (such as language models) to assist with consulting services, we ensure:
- Client data is processed according to tool provider privacy policies
- Sensitive data is anonymized before processing when possible
- Clients are informed about AI tool usage in their projects
''',
        ),
        _LegalSection(
          title: '8. Third-Party Services',
          content: '''
We use the following third-party services:

- **Google Analytics**: Website analytics (anonymized IP)
- **Calendly**: Consultation scheduling
- **Google Tag Manager**: Marketing and analytics tags
- **Meta Pixel**: Marketing analytics (for opted-in users)
- **Cloud hosting providers**: Secure data storage

Each third-party service has its own privacy policy governing their use of your data.
''',
        ),
        _LegalSection(
          title: '9. Children\'s Privacy',
          content: '''
Our services are directed to businesses and organizations, not individuals under 18. We do not knowingly collect personal information from children. If you believe we have inadvertently collected such information, please contact us immediately.
''',
        ),
        _LegalSection(
          title: '10. Changes to This Policy',
          content: '''
We may update this Privacy Policy periodically. Significant changes will be communicated via:

- Email notification to existing clients
- Prominent notice on our website
- Updated "Last Updated" date at the top of this policy
''',
        ),
        _LegalSection(
          title: 'Contact Us',
          content: '''
For privacy questions, data requests, or concerns:

- **Privacy Inquiries**: ${CompanyInfo.privacyEmail}
- **General Contact**: ${CompanyInfo.email}
- **Phone**: ${CompanyInfo.phone}
- **Location**: ${CompanyInfo.locationCity}, ${CompanyInfo.locationRegion}

We aim to respond to privacy inquiries within 5 business days.

By using ${CompanyInfo.name}'s website and services, you acknowledge that you have read and understood this Privacy Policy.
''',
        ),
      ],
    );
  }
}

/// Terms of Service content.
class _TermsOfServiceContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: '1. Agreement to Terms',
          content: '''
These Terms of Service ("Terms") constitute a legally binding agreement between you ("Client," "you," or "your") and ${CompanyInfo.name} ("Company," "we," "us," or "our") governing your use of our website and services.

By accessing our website or engaging our services, you acknowledge that you have read, understood, and agree to be bound by these Terms and our Privacy Policy. If you do not agree, you must not use our services.

**Important**: For consulting engagements, a separate Statement of Work (SOW) or Consulting Agreement may apply. In case of conflict, the specific agreement takes precedence over these general Terms.
''',
        ),
        _LegalSection(
          title: '2. Services Description',
          content: '''
${CompanyInfo.name} provides AI consulting services for nonprofits and mission-driven organizations, including:

- **AI Strategy & Implementation**: Strategic planning, tool selection, and deployment of AI solutions
- **Automation & Integration**: Workflow automation using tools like Airtable, Zapier, and Google Workspace
- **Compliance & Safety**: AI governance, privacy compliance, ethical AI implementation
- **Observability & Analytics**: KPI design, impact measurement, and reporting dashboards
- **Training & Support**: Team training, AI literacy workshops, ongoing technical support
- **Custom Solutions**: Bespoke AI and automation solutions tailored to your organization

**Website Services**: Our website provides information about our services and expertise, scheduling for consultations, resources and insights for nonprofits, and contact forms for inquiries.

We reserve the right to modify our service offerings at any time. Changes to active consulting engagements will be communicated directly and may require amendment to existing agreements.
''',
        ),
        _LegalSection(
          title: '3. Consulting Engagements',
          content: '''
**Engagement Process**:
1. Initial consultation to understand your needs
2. Proposal and Statement of Work (SOW) development
3. Agreement signing and project kickoff
4. Ongoing collaboration and deliverable reviews
5. Project completion and handoff

**Client Responsibilities**: Clients agree to provide accurate information about their organization and needs, grant necessary access to systems, data, and personnel as required, respond to requests and provide feedback in a timely manner, designate an authorized point of contact, and comply with all applicable laws regarding data we may access.

**Our Responsibilities**: ${CompanyInfo.name} agrees to provide services with professional care and competence, communicate project progress and any issues promptly, protect client confidential information, deliver agreed-upon work within specified timelines, and provide reasonable post-engagement support as specified in agreements.
''',
        ),
        _LegalSection(
          title: '4. Acceptable Use',
          content: '''
You may use our website and services only for lawful purposes consistent with these Terms.

**Prohibited Activities**: You agree not to misrepresent your identity, organization, or authority; provide false or misleading information; use our services for illegal activities; attempt to gain unauthorized access to our systems; interfere with or disrupt our website or services; copy, reproduce, or reverse engineer our proprietary materials; use our services to harm, deceive, or defraud others; or share confidential information with unauthorized parties.

**AI Ethics Requirements**: When we implement AI solutions for you, you agree to use AI tools ethically and responsibly, comply with AI-specific regulations, not use AI implementations to discriminate or cause harm, maintain appropriate human oversight of AI systems, and disclose AI use to affected stakeholders as required by law.
''',
        ),
        _LegalSection(
          title: '5. Intellectual Property',
          content: '''
**Our Intellectual Property**: ${CompanyInfo.name} retains all rights to our pre-existing intellectual property, including our proprietary methodologies and frameworks, training materials and templates, website content and branding, and software tools we've developed.

**Client Deliverables**: Unless otherwise specified in a consulting agreement, deliverables created specifically for your organization become your property upon full payment. This includes custom implementations and configurations, documentation specific to your systems, custom automations and workflows, and training materials developed for your team.

**Shared Knowledge**: General knowledge, skills, and experience gained during engagements remain our property and may be used to improve our services for other clients (without disclosing your confidential information).

**Trademarks**: "${CompanyInfo.name}" and our logo are trademarks. You may not use our trademarks without written consent. We may include your organization in our client list unless you object in writing.
''',
        ),
        _LegalSection(
          title: '6. Confidentiality',
          content: '''
**Definition**: "Confidential Information" includes all non-public information disclosed during an engagement, including business strategies, financial data, donor information, operational details, and technical systems.

**Our Obligations**: We agree to protect your confidential information with reasonable security measures, use confidential information only for providing agreed-upon services, not disclose confidential information to third parties without consent, and return or destroy confidential information upon engagement completion (upon request).

**Exceptions**: Confidentiality obligations do not apply to information that is or becomes publicly available through no fault of ours, was known to us before disclosure, is disclosed with your written consent, or must be disclosed by law or legal process.

**Duration**: Confidentiality obligations survive for 3 years after engagement completion, or longer if specified in a separate agreement.
''',
        ),
        _LegalSection(
          title: '7. Payment Terms',
          content: '''
**Fees**: Service fees are specified in individual proposals and Statements of Work. We offer project-based pricing (fixed fee for defined scope), retainer arrangements (monthly fee for ongoing support), and hourly consulting (time-based billing at agreed rates).

**Invoicing & Payment**: Invoices issued per schedule in the SOW (typically monthly or upon milestones). Payment due within 30 days of invoice date unless otherwise agreed. Accepted payment methods: ACH, credit card, check. Late payments may incur interest at 1.5% per month.

**Expenses**: Pre-approved expenses (travel, software licenses, etc.) will be billed at cost with documentation.

**Nonprofit Considerations**: We understand nonprofit budget constraints and offer flexible payment plans, pro bono or reduced-rate engagements for qualifying organizations, and grant-aligned payment schedules.
''',
        ),
        _LegalSection(
          title: '8. Termination',
          content: '''
**Termination for Convenience**: Either party may terminate an engagement with 30 days' written notice. Client remains responsible for payment for work completed through termination date.

**Termination for Cause**: Either party may terminate immediately if the other materially breaches these Terms or the engagement agreement, fails to cure a breach within 15 days of written notice, becomes insolvent or files for bankruptcy, or engages in illegal or unethical conduct.

**Effect of Termination**: All outstanding payments become due, we will provide reasonable transition assistance, confidentiality obligations survive termination, and you retain rights to completed deliverables paid in full.
''',
        ),
        _LegalSection(
          title: '9. Warranties & Disclaimers',
          content: '''
**Our Warranties**: We warrant that services will be performed professionally and competently, we have the right to provide the services offered, and deliverables will substantially conform to agreed specifications.

**Disclaimer**: EXCEPT AS EXPRESSLY PROVIDED, SERVICES ARE PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

WE DO NOT GUARANTEE SPECIFIC RESULTS, OUTCOMES, OR ROI FROM AI IMPLEMENTATIONS. SUCCESS DEPENDS ON MANY FACTORS INCLUDING CLIENT PARTICIPATION, DATA QUALITY, AND ORGANIZATIONAL READINESS.

**Third-Party Tools**: We often implement solutions using third-party tools (Airtable, Zapier, etc.). We do not warrant third-party services and are not responsible for their availability, changes, or limitations.
''',
        ),
        _LegalSection(
          title: '10. Limitation of Liability',
          content: '''
TO THE MAXIMUM EXTENT PERMITTED BY LAW, ${CompanyInfo.name} SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF PROFITS, DATA, OR GOODWILL.

OUR TOTAL LIABILITY FOR ANY CLAIMS SHALL NOT EXCEED THE FEES PAID BY YOU FOR THE SPECIFIC SERVICES GIVING RISE TO THE CLAIM DURING THE 12 MONTHS PRECEDING THE CLAIM.

**Exceptions**: These limitations do not apply to willful misconduct or gross negligence, breach of confidentiality obligations, your payment obligations, or claims that cannot be limited by law.
''',
        ),
        _LegalSection(
          title: '11. Indemnification',
          content: '''
You agree to indemnify and hold harmless ${CompanyInfo.name} from claims, damages, and expenses arising from:

- Your use of AI solutions we implement in violation of these Terms
- Your violation of applicable laws or third-party rights
- Misuse of confidential information or deliverables
- Claims related to your organization's data or donor information
''',
        ),
        _LegalSection(
          title: '12. Dispute Resolution',
          content: '''
**Informal Resolution**: We prefer to resolve disputes collaboratively. Please contact us at ${CompanyInfo.email} to discuss any concerns. We will work in good faith to resolve issues within 30 days.

**Mediation**: If informal resolution fails, parties agree to attempt mediation before pursuing other remedies.

**Governing Law**: These Terms are governed by the laws of the State of Texas, United States. Any legal proceedings shall be conducted in courts located in Travis County, Texas.
''',
        ),
        _LegalSection(
          title: '13. General Provisions',
          content: '''
**Entire Agreement**: These Terms, together with our Privacy Policy and any specific engagement agreements, constitute the entire agreement between parties.

**Amendments**: We may modify these Terms with notice. Continued use after changes constitutes acceptance. Changes do not affect existing engagement agreements without written amendment.

**Severability**: If any provision is found invalid, the remaining provisions continue in effect.

**No Waiver**: Failure to enforce any provision does not waive our right to enforce it later.

**Assignment**: You may not assign engagement agreements without our consent. We may assign to affiliates or successors with notice.

**Force Majeure**: Neither party is liable for delays due to circumstances beyond reasonable control, including natural disasters, pandemics, or government actions.
''',
        ),
        _LegalSection(
          title: 'Contact Information',
          content: '''
For questions about these Terms:

- **Email**: ${CompanyInfo.email}
- **Phone**: ${CompanyInfo.phone}
- **Website**: https://integritystudio.ai
''',
        ),
      ],
    );
  }
}

/// Cookies Policy content.
class _CookiesPolicyContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: '1. Introduction',
          content: '''
This Cookie Policy explains how ${CompanyInfo.name} ("we," "our," or "us") uses cookies and similar technologies on our website (https://integritystudio.ai/). This policy should be read alongside our Privacy Policy and Terms of Service.

By using our website, you consent to our use of cookies in accordance with this policy. You can manage your cookie preferences through your browser settings or our cookie consent banner.
''',
        ),
        _LegalSection(
          title: '2. What Are Cookies?',
          content: '''
Cookies are small text files placed on your device (computer, smartphone, or tablet) when you visit websites. They are widely used to make websites work efficiently and provide useful information to website owners.

**By Duration:**
- **Session Cookies**: Temporary cookies that expire when you close your browser
- **Persistent Cookies**: Remain on your device for a set period or until you delete them

**By Origin:**
- **First-Party Cookies**: Set directly by our website
- **Third-Party Cookies**: Set by external services we integrate with (analytics, scheduling, etc.)

**Similar Technologies**: We also use Local Storage (browser-based storage for preferences), Session Storage (temporary storage cleared when you close the tab), and Pixels/Web Beacons (small images used to track page views and conversions).
''',
        ),
        _LegalSection(
          title: '3. Cookies We Use',
          content: '''
Our website uses cookies for various purposes. Some are essential for the website to function, while others help us understand usage and improve your experience.

| Category | Purpose | Can Be Disabled? |
|----------|---------|------------------|
| Essential | Website functionality, security | No (required) |
| Analytics | Usage statistics, performance | Yes |
| Marketing | Ad performance, conversion tracking | Yes |
| Functional | Preferences, scheduling integration | Yes (may affect features) |
''',
        ),
        _LegalSection(
          title: '4. Essential Cookies',
          content: '''
Essential cookies are necessary for our website to function. Disabling these may prevent basic features from working correctly.

- **cookie_consent**: Remember your cookie preferences (1 year)
- **session_id**: Maintain session state (Session)
- **csrf_token**: Security - prevent cross-site attacks (Session)
''',
        ),
        _LegalSection(
          title: '5. Analytics Cookies',
          content: '''
We use analytics cookies to understand how visitors interact with our website, helping us improve content and user experience.

**Google Analytics (GA4)**
- **_ga**: Distinguish unique users (2 years)
- **_ga_***: Maintain session state (2 years)
- **_gid**: Distinguish users (24 hours)

**What We Track:**
- Pages visited and time on site
- How you found our website (referral source)
- Device type and browser
- Geographic location (country/region level)
- Interactions with content (scrolling, clicks)

**Privacy Note**: We have enabled IP anonymization in Google Analytics, so your full IP address is never stored. Analytics data is used only to improve our website and is not sold or shared for advertising purposes.
''',
        ),
        _LegalSection(
          title: '6. Marketing Cookies',
          content: '''
Marketing cookies help us understand the effectiveness of our advertising and reach people interested in our services.

**Meta Pixel (Facebook/Instagram)**
- **_fbp**: Identify browsers for ad targeting (3 months)
- **_fbc**: Track clicks from Facebook ads (3 months)

**Google Tag Manager**: We use Google Tag Manager to manage marketing tags. GTM itself does not collect personal data but enables other tracking tools we've described in this policy.

**Opting Out of Marketing Cookies**: You can opt out by declining cookies in our consent banner, adjusting your browser settings, or using industry opt-out tools like Digital Advertising Alliance (optout.aboutads.info), Facebook Ad Preferences, or Google Ad Settings.
''',
        ),
        _LegalSection(
          title: '7. Third-Party Cookies',
          content: '''
We integrate with third-party services that may set their own cookies. We have limited control over these cookies.

**Calendly (Scheduling)**
- Purpose: Enable consultation scheduling on our website
- Cookies: Session management, user preferences

**Google Fonts**
- Purpose: Load web fonts for typography
- Data Collected: IP address, browser info (minimal)

**Cloudflare (Hosting)**
- Purpose: Website hosting and delivery
- Cookies: Performance optimization, load balancing
''',
        ),
        _LegalSection(
          title: '8. Managing Cookies',
          content: '''
**Cookie Consent Banner**: When you first visit our website, you'll see a cookie consent banner. You can accept all cookies, accept only essential cookies, or customize your preferences.

**Browser Settings**: You can manage cookies through your browser:
- **Google Chrome**: Settings → Privacy and security → Cookies and other site data
- **Mozilla Firefox**: Settings → Privacy & Security → Cookies and Site Data
- **Safari**: Preferences → Privacy → Manage Website Data
- **Microsoft Edge**: Settings → Cookies and site permissions → Cookies and site data

**Impact of Disabling Cookies**:
- Essential cookies: May prevent website from working properly
- Analytics cookies: We won't be able to improve based on usage data
- Marketing cookies: You may still see ads, but they won't be personalized
- Functional cookies: Scheduling and other integrations may not work
''',
        ),
        _LegalSection(
          title: '9. Do Not Track (DNT)',
          content: '''
"Do Not Track" is a browser setting that requests websites not to track users. There is currently no universal standard for how websites should respond to DNT signals.

**Our Response**: We do not currently respond to DNT signals automatically. However, you can achieve similar results by declining non-essential cookies in our consent banner, using browser privacy settings, or installing privacy-focused browser extensions.

**Global Privacy Control (GPC)**: We are monitoring the development of Global Privacy Control and will update our practices as this standard matures.
''',
        ),
        _LegalSection(
          title: '10. Policy Updates',
          content: '''
We may update this Cookie Policy to reflect changes in our practices or for legal reasons.

**Notification**:
- Material changes: Updated cookie consent banner
- Minor updates: Updated "Last Updated" date

Your continued use of our website after changes constitutes acceptance of the updated policy.
''',
        ),
        _LegalSection(
          title: 'Contact Us',
          content: '''
If you have questions about our use of cookies:

- **Email**: ${CompanyInfo.privacyEmail}
- **General Contact**: ${CompanyInfo.email}

**Related Policies**: Privacy Policy, Terms of Service
''',
        ),
      ],
    );
  }
}

/// Accessibility Statement content.
class _AccessibilityStatementContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: 'Our Commitment to Accessibility',
          content: '''
${CompanyInfo.name} is committed to ensuring digital accessibility for all users, including people with disabilities. We believe that everyone should have equal access to information and technology, especially the nonprofits and mission-driven organizations we serve.

As an AI consultancy focused on empowering nonprofits, we understand the importance of inclusive design. We are dedicated to:

- Making our website usable by people with diverse abilities
- Adhering to accessibility best practices and standards
- Continuously improving our website's accessibility
- Listening to and addressing user feedback about accessibility
- Incorporating accessibility into the AI solutions we build for clients
- Training our team on accessibility principles and implementation

**Our Approach**: When we help organizations implement AI and automation, we prioritize accessible solutions that work for everyone in their communities. We believe technology should be an equalizer, not a barrier.
''',
        ),
        _LegalSection(
          title: 'Accessibility Standards',
          content: '''
${CompanyInfo.name} strives to conform to the Web Content Accessibility Guidelines (WCAG) 2.1 Level AA. These guidelines explain how to make web content more accessible for people with disabilities and improve usability for all users.

**WCAG 2.1 Level AA Compliance**

Our goal is to meet or exceed the following WCAG 2.1 principles:

- **Perceivable**: Information and user interface components must be presentable to users in ways they can perceive
- **Operable**: User interface components and navigation must be operable by all users
- **Understandable**: Information and operation of the user interface must be understandable
- **Robust**: Content must be robust enough to be interpreted by a wide variety of user agents, including assistive technologies
''',
        ),
        _LegalSection(
          title: 'Accessibility Features',
          content: '''
Our website includes the following accessibility features:

**Keyboard Navigation**
- Full keyboard accessibility for all interactive elements
- Logical tab order throughout the interface
- Visible focus indicators for keyboard users
- Skip navigation link to bypass repetitive content
- Keyboard shortcuts documented where applicable

**Screen Reader Support**
- Semantic HTML markup for proper content structure
- ARIA labels and landmarks for enhanced navigation
- Descriptive alt text for all meaningful images
- Clear heading hierarchy (H1 → H2 → H3) for easy navigation
- Form labels properly associated with inputs

**Visual Design**
- Sufficient color contrast ratios (minimum 4.5:1 for normal text, 3:1 for large text)
- Resizable text up to 200% without loss of functionality
- Text alternatives for color-coded information
- Responsive design that adapts to different screen sizes and orientations
- No content that flashes more than 3 times per second

**Forms and Interactions**
- Clear and descriptive form labels
- Error messages that are clear, specific, and announced to screen readers
- Required fields clearly marked
- Input validation with helpful guidance
- Sufficient time for users to complete actions

**Content Structure**
- Clear, concise language at an appropriate reading level
- Descriptive link text (avoiding "click here")
- Organized content with clear sections
- Consistent navigation across pages
''',
        ),
        _LegalSection(
          title: 'Testing and Compliance',
          content: '''
We regularly test our website for accessibility using:

- Automated accessibility testing tools (axe, Lighthouse, WAVE)
- Manual testing with screen readers (NVDA, JAWS, VoiceOver)
- Keyboard-only navigation testing
- Color contrast analysis tools
- Mobile accessibility testing on iOS and Android

Our development process includes accessibility reviews at every stage, from design to implementation to deployment. We use a pre-launch accessibility checklist to ensure compliance before publishing new content or features.
''',
        ),
        _LegalSection(
          title: 'Known Limitations',
          content: '''
Despite our best efforts, some limitations may exist. Areas we are actively working to improve:

- **Third-party content**: Embedded Calendly scheduling widget may have accessibility limitations outside our control
- **PDF documents**: Some older documents may not be fully accessible; we are working to remediate them
- **Complex animations**: We are adding reduced-motion alternatives for users who prefer minimal animation

We are committed to addressing these limitations and welcome feedback on any accessibility barriers you encounter.
''',
        ),
        _LegalSection(
          title: 'Feedback and Support',
          content: '''
We welcome your feedback on the accessibility of our website. If you encounter any accessibility barriers or have suggestions for improvement:

- Please let us know as soon as possible
- We will work with you to provide information in an accessible format
- We aim to respond to accessibility feedback within 3 business days
- We will work to resolve any issues in a timely manner

**Alternative Access**: If you have difficulty using any part of our website, we offer alternative ways to access information and services:

- **Phone support**: Call us at ${CompanyInfo.phone} for assistance with any information on our website
- **Email support**: Request information in accessible formats via email
- **Video call**: We can schedule a video consultation to walk through our services and answer questions
''',
        ),
        _LegalSection(
          title: 'Contact Us About Accessibility',
          content: '''
For accessibility questions, feedback, or to request assistance:

- **Email**: accessibility@integritystudio.ai
- **General Contact**: ${CompanyInfo.email}
- **Phone**: ${CompanyInfo.phone}

We are here to help ensure that everyone can effectively access information about ${CompanyInfo.name} and our AI consulting services.
''',
        ),
      ],
    );
  }
}

/// A legal section with title and content.
class _LegalSection extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingSM.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MarkdownText(content: content),
        ],
      ),
    );
  }
}

/// Simple markdown-like text rendering.
class _MarkdownText extends StatelessWidget {
  final String content;

  const _MarkdownText({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.trim().split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      } else if (line.trim().startsWith('- ')) {
        // Bullet point
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.blue400,
                  ),
                ),
                Expanded(
                  child: _parseInlineFormatting(
                    line.trim().substring(2),
                    context,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.trim().startsWith('**') && line.trim().endsWith('**')) {
        // Bold heading-like line
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              line.trim().replaceAll('**', ''),
              style: AppTypography.bodyMD.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else {
        // Regular paragraph
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _parseInlineFormatting(line.trim(), context),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _parseInlineFormatting(String text, BuildContext context) {
    // Simple bold text parsing
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final matches = boldPattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: AppTypography.bodyMD.copyWith(
          color: AppColors.gray300,
          height: 1.6,
        ),
      );
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTypography.bodyMD.copyWith(
            color: AppColors.gray300,
            height: 1.6,
          ),
        ));
      }
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: AppTypography.bodyMD.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.6,
        ),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTypography.bodyMD.copyWith(
          color: AppColors.gray300,
          height: 1.6,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
