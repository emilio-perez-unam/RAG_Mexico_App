import 'package:flutter/material.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  
  const SearchResultsScreen({
    super.key,
    required this.query,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  bool? _isHelpful;
  final List<bool> _expandedSources = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: 1440,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            right: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Stack(
          children: [
            // Left Sidebar (could be navigation or filters)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 272,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  border: Border(
                    right: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                // Add sidebar content here if needed
              ),
            ),
            
            // Main Content Area
            Positioned(
              left: 272,
              top: 0,
              child: Container(
                width: 896,
                height: 1421,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    width: 1,
                    color: const Color(0xFFE0E0E0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header with title and confidence badge
                      Padding(
                        padding: const EdgeInsets.all(25),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Búsqueda Legal México RAG',
                              style: TextStyle(
                                color: Color(0xFF003366),
                                fontSize: 20,
                                fontFamily: 'Open Sans',
                                fontWeight: FontWeight.w600,
                                height: 1.40,
                              ),
                            ),
                            Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '85% conf.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Open Sans',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Main content sections
                      Padding(
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Respuesta Legal Section
                            _buildSection(
                              title: 'Respuesta Legal',
                              content: [
                                _buildParagraphWithCitations(
                                  'La responsabilidad civil en México surge cuando una persona causa daño a otra, ya sea por negligencia o intención, obligando al responsable a reparar el daño causado',
                                  ' [CPDF Art. 1915]',
                                  ' . Este principio se aplica tanto en relaciones contractuales como extracontractuales, siendo necesario demostrar la existencia de un daño, una conducta ilícita y un nexo causal entre ambos.',
                                ),
                                const SizedBox(height: 16),
                                _buildParagraphWithCitations(
                                  'El Código Civil Federal establece que la reparación del daño debe ser integral, comprendiendo tanto el daño material como el moral',
                                  ' [CPDF Art. 1916]',
                                  ' . La Suprema Corte ha determinado que la cuantificación del daño moral debe considerar los derechos lesionados, el grado de responsabilidad y la situación económica de las partes',
                                  citation2: ' [SCJN Tesis 2a./J. 128/2019]',
                                  suffix2: ' .',
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Los requisitos para ejercer la acción de responsabilidad civil son:',
                                  style: TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 16,
                                    fontFamily: 'Open Sans',
                                    fontWeight: FontWeight.w400,
                                    height: 1.50,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildBulletList([
                                  'Existencia de un hecho u omisión ilícito',
                                  'Daño causado (patrimonial o moral)',
                                  'Relación de causalidad entre el hecho y el daño',
                                  'Culpa o negligencia del responsable (en casos de responsabilidad subjetiva)',
                                ]),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Fundamento Jurídico Section
                            _buildSection(
                              title: 'Fundamento Jurídico',
                              content: [
                                _buildParagraphWithCitations(
                                  'El fundamento principal se encuentra en el Código Civil Federal, artículos 1910 al 1934, que regulan la responsabilidad civil extracontractual',
                                  ' [CPDF Arts. 1910-1934]',
                                  ' . El artículo 1915 específicamente establece: "La reparación del daño debe consistir en el restablecimiento de la situación anterior a él, y cuando ello sea imposible, en el pago de daños y perjuicios."',
                                ),
                                const SizedBox(height: 16),
                                _buildParagraphWithCitations(
                                  'La jurisprudencia de la Suprema Corte ha desarrollado estos conceptos, como se aprecia en la tesis',
                                  ' [SCJN Tesis 1a./J. 31/2017] [SCJN Tesis 2a./J. 128/2019]',
                                  ' que establece los parámetros para cuantificar el daño moral, y la tesis que define los alcances de la responsabilidad objetiva en actividades riesgosas.',
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Doctrina Aplicable Section
                            _buildSection(
                              title: 'Doctrina Aplicable',
                              content: [
                                _buildParagraphWithCitations(
                                  'La teoría de la responsabilidad civil en México ha sido influenciada por doctrinas europeas y latinoamericanas. Kelsen, en su obra Teoría Pura del Derecho, establece que la responsabilidad surge como consecuencia de la violación de un deber jurídico',
                                  ' [Kelsen, Teoría Pura - UNAM p.234]',
                                  ' .',
                                ),
                                const SizedBox(height: 16),
                                _buildParagraphWithCitations(
                                  'García Máynez, por su parte, distingue entre responsabilidad subjetiva, basada en la culpa, y objetiva, fundamentada en el riesgo creado',
                                  ' [García Máynez, Introducción al Derecho - UNAM p.372]',
                                  ' . Esta distinción es fundamental para comprender el sistema dual de responsabilidad civil adoptado por la legislación mexicana.',
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Source Citations
                            _buildSourceCard(
                              'Código Civil Federal',
                              Icons.book,
                              0,
                            ),
                            const SizedBox(height: 16),
                            _buildSourceCard(
                              'SCJN Tesis 2a./J. 128/2019',
                              Icons.gavel,
                              1,
                            ),
                            const SizedBox(height: 16),
                            _buildSourceCard(
                              'Kelsen, Teoría Pura del Derecho - UNAM',
                              Icons.menu_book,
                              2,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Feedback Section
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '¿Fue útil esta respuesta?',
                                        style: TextStyle(
                                          color: Color(0xFF2C2C2C),
                                          fontSize: 14,
                                          fontFamily: 'Open Sans',
                                          fontWeight: FontWeight.w400,
                                          height: 1.43,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      _buildFeedbackButton('Sí', _isHelpful == true),
                                      const SizedBox(width: 12),
                                      _buildFeedbackButton('No', _isHelpful == false),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.flag_outlined, size: 14),
                                        label: const Text('Reportar error en cita'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFF003366),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Open Sans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Row(
                                    children: [
                                      Text(
                                        'Generado: 14/07/2025 10:30',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                          fontFamily: 'Open Sans',
                                          fontWeight: FontWeight.w400,
                                          height: 1.33,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(
                                        Icons.info_outline,
                                        size: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Esta respuesta fue generada por inteligencia artificial y puede contener imprecisiones. '
                                          'La información proporcionada no constituye asesoría legal y no debe utilizarse como '
                                          'sustituto del consejo de un profesional del derecho calificado.',
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                            fontFamily: 'Open Sans',
                                            fontWeight: FontWeight.w400,
                                            height: 1.33,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // Copy functionality
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copiar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF003366),
                                    side: const BorderSide(color: Color(0xFF003366)),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // Share functionality
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('Compartir'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006847),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required List<Widget> content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF006847),
            fontSize: 18,
            fontFamily: 'Open Sans',
            fontWeight: FontWeight.w600,
            height: 1.56,
          ),
        ),
        const SizedBox(height: 24),
        ...content,
      ],
    );
  }
  
  Widget _buildParagraphWithCitations(
    String text,
    String citation,
    String suffix, {
    String? citation2,
    String? suffix2,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 16,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          TextSpan(
            text: citation,
            style: const TextStyle(
              color: Color(0xFF003366),
              fontSize: 16,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          TextSpan(
            text: suffix,
            style: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 16,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          if (citation2 != null)
            TextSpan(
              text: citation2,
              style: const TextStyle(
                color: Color(0xFF003366),
                fontSize: 16,
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w400,
                height: 1.50,
              ),
            ),
          if (suffix2 != null)
            TextSpan(
              text: suffix2,
              style: const TextStyle(
                color: Color(0xFF2C2C2C),
                fontSize: 16,
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w400,
                height: 1.50,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            item,
            style: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontSize: 16,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.w400,
            ),
          ),
        )).toList(),
      ),
    );
  }
  
  Widget _buildSourceCard(String title, IconData icon, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _expandedSources[index] = !_expandedSources[index];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF2C2C2C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2C2C2C),
                        fontSize: 16,
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w600,
                        height: 1.50,
                      ),
                    ),
                  ),
                  Icon(
                    _expandedSources[index] ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF666666),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeedbackButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _isHelpful = label == 'Sí';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF666666),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF2C2C2C),
                fontSize: 14,
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}