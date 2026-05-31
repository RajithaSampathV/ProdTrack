import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withAlpha(10) // subtle opacity
              : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: _isFocused
                ? Colors.blueAccent.withAlpha(200)
                : (isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(25)),
            width: 1.5,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused
                  ? Colors.blueAccent
                  : (isDark ? Colors.white.withAlpha(150) : Colors.black.withAlpha(130)),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused
                  ? Colors.blueAccent
                  : (isDark ? Colors.white.withAlpha(100) : Colors.black.withAlpha(100)),
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: isDark ? Colors.white.withAlpha(100) : Colors.black.withAlpha(100),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          ),
        ),
      ),
    );
  }
}
