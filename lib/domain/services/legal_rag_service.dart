import 'dart:convert';
import 'package:legal_rag_mexico/data/datasources/remote/deepseek_datasource.dart';

/// Service class for handling legal RAG (Retrieval-Augmented Generation) operations
class LegalRagService {
  final DeepSeekDatasource _deepSeekDatasource;

  /// Constructor requiring API key
  LegalRagService({required String apiKey})
      : _deepSeekDatasource = DeepSeekDatasource(apiKey: apiKey);

  /// Alternative constructor using configuration
  LegalRagService.withConfig(DeepSeekConfig config)
      : _deepSeekDatasource = DeepSeekDatasource(apiKey: config.apiKey);

  /// Process a general legal query
  Future<String> processLegalQuery(String query) async {
    try {
      // FIXED: Use positional parameter instead of named
      final response = await _deepSeekDatasource.sendMessage(query);

      return response.content;
    } catch (e) {
      throw Exception('Failed to process legal query: $e');
    }
  }

  /// Analyze a specific Mexican law article
  Future<String> analyzeLawArticle({
    required String articleNumber,
    required String lawName,
    required String articleContent,
    required String question,
  }) async {
    try {
      final prompt = '''
Analiza el siguiente artículo de la legislación mexicana:

Ley: $lawName
Artículo: $articleNumber

Contenido del artículo:
$articleContent

Pregunta: $question

Por favor proporciona:
1. Interpretación del artículo
2. Aplicación práctica
3. Jurisprudencia relevante (si aplica)
4. Consideraciones importantes
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      return response.contentWithoutThinking;
    } catch (e) {
      throw Exception('Failed to analyze law article: $e');
    }
  }

  /// Search for relevant legal precedents
  Future<String> searchLegalPrecedents({
    required String caseDescription,
    String? jurisdiction,
    String? legalArea,
  }) async {
    try {
      final prompt = '''
Busca precedentes legales relevantes para el siguiente caso:

Descripción del caso: $caseDescription
${jurisdiction != null ? 'Jurisdicción: $jurisdiction' : ''}
${legalArea != null ? 'Área legal: $legalArea' : ''}

Proporciona:
1. Casos similares anteriores
2. Criterios jurisprudenciales aplicables
3. Tesis relevantes
4. Recomendaciones basadas en precedentes
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      return response.content;
    } catch (e) {
      throw Exception('Failed to search legal precedents: $e');
    }
  }

  /// Generate a legal document based on requirements
  Future<String> generateLegalDocument({
    required String documentType,
    required Map<String, String> parameters,
    String? template,
  }) async {
    try {
      final parametersStr =
          parameters.entries.map((e) => '${e.key}: ${e.value}').join('\n');

      final prompt = '''
Genera un documento legal de tipo: $documentType

Parámetros del documento:
$parametersStr

${template != null ? 'Plantilla base:\n$template\n' : ''}

Requisitos:
- Cumplir con la normativa mexicana vigente
- Incluir todas las cláusulas necesarias
- Usar lenguaje jurídico apropiado
- Incluir espacios para firmas y datos faltantes marcados con [___]
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      return response.contentWithoutThinking;
    } catch (e) {
      throw Exception('Failed to generate legal document: $e');
    }
  }

  /// Analyze a legal contract
  Future<ContractAnalysis> analyzeContract({
    required String contractContent,
    required List<String> focusAreas,
  }) async {
    try {
      final areasStr = focusAreas.join(', ');

      final prompt = '''
Analiza el siguiente contrato enfocándote en: $areasStr

[Contenido del Contrato]
$contractContent
[Fin del Contrato]

Proporciona un análisis estructurado que incluya:
1. RESUMEN EJECUTIVO
2. PARTES INVOLUCRADAS
3. OBLIGACIONES PRINCIPALES
4. RIESGOS IDENTIFICADOS
5. CLÁUSULAS PROBLEMÁTICAS
6. RECOMENDACIONES
7. CUMPLIMIENTO NORMATIVO

Formato tu respuesta en JSON con estas secciones.
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      // Parse the JSON response
      try {
        final jsonStr =
            _extractJsonFromResponse(response.contentWithoutThinking);
        final json = jsonDecode(jsonStr);
        return ContractAnalysis.fromJson(json);
      } catch (e) {
        // Fallback to text analysis if JSON parsing fails
        return ContractAnalysis(
          executiveSummary: response.contentWithoutThinking,
          parties: [],
          mainObligations: [],
          identifiedRisks: [],
          problematicClauses: [],
          recommendations: [],
          regulatoryCompliance: '',
        );
      }
    } catch (e) {
      throw Exception('Failed to analyze contract: $e');
    }
  }

  /// Answer legal questions with citations
  Future<LegalAnswer> answerLegalQuestion({
    required String question,
    List<String>? relevantLaws,
    bool includeCitations = true,
  }) async {
    try {
      final prompt = '''
Responde la siguiente pregunta legal según el derecho mexicano:

Pregunta: $question

${relevantLaws != null ? 'Leyes relevantes a considerar: ${relevantLaws.join(', ')}\n' : ''}

Estructura tu respuesta así:
1. RESPUESTA DIRECTA: [Respuesta concisa a la pregunta]
2. FUNDAMENTO LEGAL: [Artículos y leyes aplicables]
3. EXPLICACIÓN DETALLADA: [Análisis completo]
4. EXCEPCIONES: [Si aplican]
5. RECOMENDACIONES: [Acciones sugeridas]

${includeCitations ? 'Incluye citas específicas de artículos y leyes.' : ''}
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      return LegalAnswer(
        question: question,
        answer: response.contentWithoutThinking,
        timestamp: DateTime.now(),
        model: response.model,
      );
    } catch (e) {
      throw Exception('Failed to answer legal question: $e');
    }
  }

  /// Compare different laws or legal frameworks
  Future<String> compareLaws({
    required List<String> laws,
    required String comparisonFocus,
  }) async {
    try {
      final lawsList = laws.map((law) => '- $law').join('\n');

      final prompt = '''
Compara las siguientes leyes o marcos legales:
$lawsList

Enfoque de comparación: $comparisonFocus

Proporciona:
1. Tabla comparativa de aspectos clave
2. Similitudes principales
3. Diferencias fundamentales
4. Implicaciones prácticas
5. Recomendaciones según el contexto
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      return response.content;
    } catch (e) {
      throw Exception('Failed to compare laws: $e');
    }
  }

  /// Calculate legal deadlines based on Mexican law
  Future<LegalDeadlines> calculateDeadlines({
    required String procedureType,
    required DateTime startDate,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      final prompt = '''
Calcula los plazos legales para: $procedureType

Fecha de inicio: ${startDate.toIso8601String()}
${additionalParams != null ? 'Parámetros adicionales: ${jsonEncode(additionalParams)}' : ''}

Considera:
- Días hábiles según la ley mexicana
- Días festivos oficiales
- Plazos procesales aplicables

Proporciona:
1. Cada plazo con su fecha límite
2. Base legal de cada plazo
3. Consecuencias de incumplimiento
4. Acciones requeridas para cada fecha

Formato la respuesta como JSON con estructura:
{
  "plazos": [
    {
      "nombre": "...",
      "fechaLimite": "YYYY-MM-DD",
      "diasHabiles": 0,
      "baseLegal": "...",
      "consecuencias": "...",
      "acciones": ["..."]
    }
  ]
}
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      try {
        final jsonStr =
            _extractJsonFromResponse(response.contentWithoutThinking);
        final json = jsonDecode(jsonStr);
        return LegalDeadlines.fromJson(json, startDate);
      } catch (e) {
        throw Exception('Failed to parse deadlines response: $e');
      }
    } catch (e) {
      throw Exception('Failed to calculate deadlines: $e');
    }
  }

  /// Continue a multi-turn legal consultation
  Future<String> continueConsultation({
    required String message,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    try {
      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        message,
        previousMessages: conversationHistory,
      );

      return response.content;
    } catch (e) {
      throw Exception('Failed to continue consultation: $e');
    }
  }

  /// Get legal term definitions
  Future<String> defineLegalTerm({
    required String term,
    String? context,
    bool includeExamples = true,
  }) async {
    try {
      final prompt = '''
Define el siguiente término legal en el contexto del derecho mexicano:

Término: $term
${context != null ? 'Contexto: $context' : ''}

Incluye:
1. Definición formal
2. Origen y fundamento legal
3. Aplicación práctica
${includeExamples ? '4. Ejemplos concretos' : ''}
5. Términos relacionados
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(prompt);

      return response.content;
    } catch (e) {
      throw Exception('Failed to define legal term: $e');
    }
  }

  /// Validate if a legal procedure is correct
  Future<ProcedureValidation> validateProcedure({
    required String procedureDescription,
    required String procedureType,
  }) async {
    try {
      final prompt = '''
Valida si el siguiente procedimiento es correcto según la ley mexicana:

Tipo de procedimiento: $procedureType

Descripción del procedimiento:
$procedureDescription

Evalúa:
1. Cumplimiento de requisitos legales
2. Orden correcto de pasos
3. Plazos respetados
4. Documentación necesaria
5. Autoridades competentes

Responde en formato JSON:
{
  "esValido": true/false,
  "requisitosLegales": {"cumple": true/false, "detalles": "..."},
  "ordenPasos": {"correcto": true/false, "observaciones": "..."},
  "plazos": {"respetados": true/false, "detalles": "..."},
  "documentacion": {"completa": true/false, "faltante": ["..."]},
  "autoridadesCompetentes": {"correctas": true/false, "observaciones": "..."},
  "recomendaciones": ["..."]
}
''';

      // FIXED: Use positional parameter
      final response = await _deepSeekDatasource.sendMessage(
        prompt,
        enforceThinking: true,
      );

      try {
        final jsonStr =
            _extractJsonFromResponse(response.contentWithoutThinking);
        final json = jsonDecode(jsonStr);
        return ProcedureValidation.fromJson(json);
      } catch (e) {
        throw Exception('Failed to parse validation response: $e');
      }
    } catch (e) {
      throw Exception('Failed to validate procedure: $e');
    }
  }

  /// Extract JSON from response text
  String _extractJsonFromResponse(String response) {
    // Try to find JSON content between code blocks or in the response
    final jsonPattern = RegExp(
        r'```json\s*([\s\S]*?)\s*```|```\s*([\s\S]*?)\s*```|\{[\s\S]*\}',
        multiLine: true);
    final match = jsonPattern.firstMatch(response);

    if (match != null) {
      // Return the first non-null group (either from json code block or raw JSON)
      return match.group(1) ?? match.group(2) ?? match.group(0) ?? response;
    }

    // If no pattern found, try to extract JSON starting from first {
    final startIndex = response.indexOf('{');
    final endIndex = response.lastIndexOf('}');

    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return response.substring(startIndex, endIndex + 1);
    }

    return response;
  }

  /// Clean up resources
  void dispose() {
    _deepSeekDatasource.dispose();
  }
}

// Data models for structured responses

class ContractAnalysis {
  final String executiveSummary;
  final List<String> parties;
  final List<String> mainObligations;
  final List<String> identifiedRisks;
  final List<String> problematicClauses;
  final List<String> recommendations;
  final String regulatoryCompliance;

  ContractAnalysis({
    required this.executiveSummary,
    required this.parties,
    required this.mainObligations,
    required this.identifiedRisks,
    required this.problematicClauses,
    required this.recommendations,
    required this.regulatoryCompliance,
  });

  factory ContractAnalysis.fromJson(Map<String, dynamic> json) {
    return ContractAnalysis(
      executiveSummary: json['RESUMEN_EJECUTIVO'] ?? '',
      parties: List<String>.from(json['PARTES_INVOLUCRADAS'] ?? []),
      mainObligations:
          List<String>.from(json['OBLIGACIONES_PRINCIPALES'] ?? []),
      identifiedRisks: List<String>.from(json['RIESGOS_IDENTIFICADOS'] ?? []),
      problematicClauses:
          List<String>.from(json['CLAUSULAS_PROBLEMATICAS'] ?? []),
      recommendations: List<String>.from(json['RECOMENDACIONES'] ?? []),
      regulatoryCompliance: json['CUMPLIMIENTO_NORMATIVO'] ?? '',
    );
  }
}

class LegalAnswer {
  final String question;
  final String answer;
  final DateTime timestamp;
  final String model;

  LegalAnswer({
    required this.question,
    required this.answer,
    required this.timestamp,
    required this.model,
  });
}

class LegalDeadlines {
  final List<Deadline> deadlines;
  final DateTime startDate;

  LegalDeadlines({
    required this.deadlines,
    required this.startDate,
  });

  factory LegalDeadlines.fromJson(
      Map<String, dynamic> json, DateTime startDate) {
    final deadlinesList =
        (json['plazos'] as List).map((d) => Deadline.fromJson(d)).toList();

    return LegalDeadlines(
      deadlines: deadlinesList,
      startDate: startDate,
    );
  }
}

class Deadline {
  final String name;
  final DateTime deadline;
  final int businessDays;
  final String legalBasis;
  final String consequences;
  final List<String> requiredActions;

  Deadline({
    required this.name,
    required this.deadline,
    required this.businessDays,
    required this.legalBasis,
    required this.consequences,
    required this.requiredActions,
  });

  factory Deadline.fromJson(Map<String, dynamic> json) {
    return Deadline(
      name: json['nombre'],
      deadline: DateTime.parse(json['fechaLimite']),
      businessDays: json['diasHabiles'],
      legalBasis: json['baseLegal'],
      consequences: json['consecuencias'],
      requiredActions: List<String>.from(json['acciones'] ?? []),
    );
  }
}

class ProcedureValidation {
  final bool isValid;
  final ValidationDetail legalRequirements;
  final ValidationDetail stepOrder;
  final ValidationDetail deadlines;
  final DocumentationValidation documentation;
  final ValidationDetail competentAuthorities;
  final List<String> recommendations;

  ProcedureValidation({
    required this.isValid,
    required this.legalRequirements,
    required this.stepOrder,
    required this.deadlines,
    required this.documentation,
    required this.competentAuthorities,
    required this.recommendations,
  });

  factory ProcedureValidation.fromJson(Map<String, dynamic> json) {
    return ProcedureValidation(
      isValid: json['esValido'],
      legalRequirements: ValidationDetail.fromJson(json['requisitosLegales']),
      stepOrder: ValidationDetail.fromJson(json['ordenPasos']),
      deadlines: ValidationDetail.fromJson(json['plazos']),
      documentation: DocumentationValidation.fromJson(json['documentacion']),
      competentAuthorities:
          ValidationDetail.fromJson(json['autoridadesCompetentes']),
      recommendations: List<String>.from(json['recomendaciones'] ?? []),
    );
  }
}

class ValidationDetail {
  final bool isValid;
  final String details;

  ValidationDetail({required this.isValid, required this.details});

  factory ValidationDetail.fromJson(Map<String, dynamic> json) {
    return ValidationDetail(
      isValid: json['cumple'] ??
          json['correcto'] ??
          json['respetados'] ??
          json['correctas'] ??
          false,
      details: json['detalles'] ?? json['observaciones'] ?? '',
    );
  }
}

class DocumentationValidation {
  final bool isComplete;
  final List<String> missingDocuments;

  DocumentationValidation({
    required this.isComplete,
    required this.missingDocuments,
  });

  factory DocumentationValidation.fromJson(Map<String, dynamic> json) {
    return DocumentationValidation(
      isComplete: json['completa'] ?? false,
      missingDocuments: List<String>.from(json['faltante'] ?? []),
    );
  }
}
