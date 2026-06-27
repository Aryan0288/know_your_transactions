import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';

import 'common_colors.dart';

class CustomTextFormField extends StatefulWidget {
  const CustomTextFormField({
    super.key,
    this.heading,
    required this.hint,
    required this.controller,
    this.validator,
    this.constraints,
    this.maxLength,
    this.maxLines,
    this.errorMessage,
    this.keyboardType,
    this.enable = true,
    this.readOnly,
    this.suffixWidget,
    this.inputFormatters,
    this.allowSpecialChar = false,
    this.textCapitalization,
    this.contentPadding,
    this.focusNode,
    this.containerPadding,
  });

  final String? heading;
  final String hint;
  final String? errorMessage;
  final BoxConstraints? constraints;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool? enable;
  final bool? allowSpecialChar;
  final TextCapitalization? textCapitalization;
  final bool? readOnly;
  final int? maxLength;
  final int? maxLines;
  final Widget? suffixWidget;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? containerPadding;
  final FocusNode? focusNode;

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  late final FocusNode _focusNode;
  final ValueNotifier<bool> _isFocusedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    _isFocusedNotifier.value = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _isFocusedNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.unfocus();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_isFocusedNotifier, _errorNotifier]),
        builder: (context, child) {
          final isFocused = _isFocusedNotifier.value;
          final errorText = _errorNotifier.value;
          final hasError = errorText != null;

          return Container(
            padding: widget.containerPadding ??
                EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: hasError ? 18 : 14,
                ),
            decoration: BoxDecoration(
              color: textColor_F5F9FF,
              border: Border.all(
                color: hasError
                    ? containerErrorBorderColor
                    : isFocused
                        ? textFormFieldContainerFocusedBorderColor
                        : textFormFieldContainerBorderColor,
                width: hasError || isFocused ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        textCapitalization:
                            widget.textCapitalization ?? TextCapitalization.none,
                        focusNode: _focusNode,
                        readOnly: widget.readOnly ?? false,
                        style: textFieldEnteredTextStyle,
                        maxLength: widget.maxLength,
                        maxLines: widget.maxLines,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: widget.enable,
                        cursorColor: textFieldCursorColor,
                        cursorWidth: 1,
                        keyboardType: widget.keyboardType ?? TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp(
                              r'[\u{1F600}-\u{1F64F}]|' // Emoticons
                              r'[\u{1F300}-\u{1F5FF}]|' // Symbols & pictographs
                              r'[\u{1F680}-\u{1F6FF}]|' // Transport & map symbols
                              r'[\u{2600}-\u{26FF}]|' // Misc symbols
                              r'[\u{2700}-\u{27BF}]|' // Dingbats
                              r'[\u{1F900}-\u{1F9FF}]|' // Supplemental pictographs
                              r'[\u{1FA70}-\u{1FAFF}]', // Extended pictographs
                              unicode: true,
                            ),
                            replacementString: '',
                          ),
                          if (!widget.allowSpecialChar!)
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s@._-]'),
                            ),
                          ...?widget.inputFormatters,
                        ],
                        controller: widget.controller,
                        autovalidateMode: AutovalidateMode.disabled,
                        onChanged: (value) {
                          final String? error = widget.validator != null
                              ? widget.validator!(value)
                              : value.trim().isEmpty
                                  ? widget.errorMessage ?? 'Please enter ${widget.hint}'
                                  : null;

                          _errorNotifier.value = error;
                        },
                        validator: (value) {
                          final String? error = widget.validator != null
                              ? widget.validator!(value)
                              : value!.trim().isEmpty
                                  ? widget.errorMessage ?? 'Please enter ${widget.hint}'
                                  : null;

                          _errorNotifier.value = error;
                          return error;
                        },
                        decoration: InputDecoration(
                          contentPadding: widget.contentPadding,
                          constraints: widget.constraints,
                          counter: const SizedBox(),
                          hintText: widget.hint,
                          border: InputBorder.none,
                          errorText: errorText == null ? null : '',
                          errorStyle: const TextStyle(fontSize: 0),
                          errorBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          hintStyle: textFieldHintTextStyle,
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: widget.suffixWidget ?? const SizedBox(),
                    ),
                  ],
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(errorText, style: textFieldErrorTextStyle),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
