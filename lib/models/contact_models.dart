import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact_models.freezed.dart';

/// Contact form data model.
@Freezed(fromJson: false, toJson: false)
abstract class ContactFormData with _$ContactFormData {
  const ContactFormData._();

  const factory ContactFormData({
    required String name,
    required String email,
    String? organization,
    String? message,
    String? companySize,
    String? useCase,
    String? ref,
  }) = _ContactFormData;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        if (organization != null) 'organization': organization,
        if (message != null) 'message': message,
        if (companySize != null) 'companySize': companySize,
        if (useCase != null) 'useCase': useCase,
        if (ref != null) 'ref': ref,
      };
}
