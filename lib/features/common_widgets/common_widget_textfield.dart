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
  bool _hasError = false;
  String? _errorText;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.unfocus();
      },
      child: Container(
        padding:
            widget.containerPadding ??
            EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: _hasError ? 18 : 14,
            ),
        decoration: BoxDecoration(
          color: textColor_F5F9FF,
          border: Border.all(
            color: _hasError
                ? containerErrorBorderColor
                : _isFocused
                ? textFormFieldContainerFocusedBorderColor
                : textFormFieldContainerBorderColor,
            width: _hasError || _isFocused ? 2 : 1,
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
                    //Emoji blocking
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

                      setState(() {
                        _hasError = error != null;
                        _errorText = error;
                      });
                    },
                    validator: (value) {
                      final String? error = widget.validator != null
                          ? widget.validator!(value)
                          : value!.trim().isEmpty
                          ? widget.errorMessage ?? 'Please enter ${widget.hint}'
                          : null;

                      setState(() {
                        _hasError = error != null;
                        _errorText = error;
                      });
                      return error;
                    },
                    decoration: InputDecoration(
                      contentPadding: widget.contentPadding,
                      constraints: widget.constraints,
                      counter: SizedBox(),
                      hintText: widget.hint,
                      border: InputBorder.none,
                      errorText: _errorText == null ? null : '',
                      errorStyle: TextStyle(fontSize: 0),
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
                  child: widget.suffixWidget ?? SizedBox(),
                ),
              ],
            ),
            if (_hasError && _errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(_errorText!, style: textFieldErrorTextStyle),
              ),
          ],
        ),
      ),
    );
  }
}
