import 'package:elcora_fast/utils/input_sanitizer.dart';

/// 🛡️ Helper de sécurité pour les opérations de base de données
class SecurityHelper {
  /// Sanitizer un Map de données avant insertion/update en base
  static Map<String, dynamic> sanitizeData(
    Map<String, dynamic> data, {
    List<String>? excludeFields, // Champs à exclure de la sanitization (ex: password)
    bool strict = true,
  }) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Exclure certains champs de la sanitization
      if (excludeFields != null && excludeFields.contains(key)) {
        sanitized[key] = value;
        continue;
      }
      
      // Sanitizer selon le type
      if (value is String) {
        final result = InputSanitizer.validateAndSanitize(
          value,
          strict: strict,
          fieldName: key,
        );
        
        if (!result.isValid) {
          throw SecurityException(
            'Le champ "$key" contient des caractères non autorisés: ${result.errorMessage}',
          );
        }
        
        sanitized[key] = result.sanitizedValue;
      } else if (value is Map) {
        // Récursif pour les objets imbriqués
        sanitized[key] = sanitizeData(
          Map<String, dynamic>.from(value),
          excludeFields: excludeFields,
          strict: strict,
        );
      } else if (value is List) {
        // Sanitizer chaque élément de la liste
        sanitized[key] = value.map((item) {
          if (item is String) {
            final result = InputSanitizer.validateAndSanitize(
              item,
              strict: strict,
              fieldName: key,
            );
            if (!result.isValid) {
              throw SecurityException(
                'Un élément du champ "$key" contient des caractères non autorisés: ${result.errorMessage}',
              );
            }
            return result.sanitizedValue;
          } else if (item is Map) {
            return sanitizeData(
              Map<String, dynamic>.from(item),
              excludeFields: excludeFields,
              strict: strict,
            );
          }
          return item;
        }).toList();
      } else {
        // Autres types (num, bool, etc.) - pas de sanitization nécessaire
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }

  /// Valider un Map de données avant insertion/update
  static void validateData(
    Map<String, dynamic> data, {
    Map<String, List<ValidationRule>>? fieldRules,
  }) {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is String && fieldRules != null && fieldRules.containsKey(key)) {
        for (final rule in fieldRules[key]!) {
          if (!_validateRule(rule, value)) {
            throw SecurityException(
              'Le champ "$key" ne respecte pas la règle: ${rule.message ?? "validation échouée"}',
            );
          }
        }
      }
    }
  }

  /// Valider une règle
  static bool _validateRule(ValidationRule rule, String value) {
    switch (rule.type) {
      case ValidationType.required:
        return value.trim().isNotEmpty;
      case ValidationType.minLength:
        return value.length >= (rule.value as int);
      case ValidationType.maxLength:
        return value.length <= (rule.value as int);
      case ValidationType.email:
        return InputSanitizer.isValidEmailSafe(value);
      case ValidationType.phone:
        return InputSanitizer.isValidPhoneSafe(value);
      default:
        return true;
    }
  }
}

/// Exception de sécurité
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}

/// Règle de validation simplifiée
class ValidationRule {
  final ValidationType type;
  final dynamic value;
  final String? message;

  const ValidationRule({
    required this.type,
    this.value,
    this.message,
  });
}

/// Types de validation
enum ValidationType {
  required,
  email,
  phone,
  minLength,
  maxLength,
  sqlInjection,
  xss,
}




