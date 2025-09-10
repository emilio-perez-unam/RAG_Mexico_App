import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final bool isLoading;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: isLoading ? null : onSend,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: isLoading 
                  ? 'Esperando respuesta...' 
                  : 'Escribe tu consulta legal...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: isLoading 
              ? AppColors.textSecondary 
              : AppColors.primaryBlue,
            radius: 24,
            child: IconButton(
              icon: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
                size: 20,
              ),
              onPressed: isLoading 
                ? null 
                : () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}