import { z } from 'zod';
import {
  MAX_COMPANY_SIZE_LENGTH,
  MAX_EMAIL_LENGTH,
  MAX_MESSAGE_LENGTH,
  MAX_NAME_LENGTH,
  MAX_ORGANIZATION_LENGTH,
  MAX_USE_CASE_LENGTH,
} from '../../constants';

/**
 * Email validation using a pattern that matches RFC 5321 subset:
 * - Local part: 1-64 chars, alphanumeric + . _ % + -
 * - No leading/trailing/consecutive dots in local part
 * - Domain: valid labels, 2+ char TLD, no leading/trailing hyphens
 */
const EMAIL_REGEX = /^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/;

export const ContactFormSchema = z.object({
  name: z
    .string({ invalid_type_error: 'Name is required' })
    .trim()
    .min(1, 'Name is required')
    .max(MAX_NAME_LENGTH, `Name must be under ${MAX_NAME_LENGTH} characters`),
  email: z
    .string({ invalid_type_error: 'Email is required' })
    .min(1, 'Email is required')
    .max(MAX_EMAIL_LENGTH, `Email must be under ${MAX_EMAIL_LENGTH} characters`)
    .refine((email) => EMAIL_REGEX.test(email), 'Invalid email format'),
  organization: z
    .string()
    .max(MAX_ORGANIZATION_LENGTH, `Organization must be under ${MAX_ORGANIZATION_LENGTH} characters`)
    .optional()
    .transform((val) => val || undefined),
  message: z
    .string()
    .max(MAX_MESSAGE_LENGTH, `Message must be under ${MAX_MESSAGE_LENGTH} characters`)
    .optional()
    .transform((val) => val || undefined),
  companySize: z
    .string()
    .max(MAX_COMPANY_SIZE_LENGTH, `Company size must be under ${MAX_COMPANY_SIZE_LENGTH} characters`)
    .optional()
    .transform((val) => val || undefined),
  useCase: z
    .string()
    .max(MAX_USE_CASE_LENGTH, `Use case must be under ${MAX_USE_CASE_LENGTH} characters`)
    .optional()
    .transform((val) => val || undefined),
});

export type ContactFormData = z.infer<typeof ContactFormSchema>;

/**
 * Validate contact form data using Zod schema.
 * Returns null on success, error message string on failure.
 */
export function validateContactForm(data: unknown): string | null {
  const result = ContactFormSchema.safeParse(data);
  if (!result.success) {
    // Return first error message (matches original validateForm behavior)
    return result.error.issues[0]?.message || 'Validation failed';
  }
  return null;
}
