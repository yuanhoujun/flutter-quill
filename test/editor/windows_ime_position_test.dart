import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Windows IME anchor follows caret without inline composition',
      (tester) async {
    final controller = QuillController.basic();
    final focus = FocusNode();
    final key = GlobalKey<EditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: Scaffold(
          body: QuillEditor.basic(
        controller: controller,
        focusNode: focus,
        config: QuillEditorConfig(editorKey: key),
      )),
    ));
    focus.requestFocus();
    await tester.pump();
    await tester.pump();

    Map<dynamic, dynamic> lastAnchor() => tester.testTextInput.log
        .lastWhere((call) => call.method == 'TextInput.setMarkedTextRect')
        .arguments as Map<dynamic, dynamic>;
    void expectAnchorAt(int offset) {
      final expected = key.currentState!.renderEditor
          .getLocalRectForCaret(TextPosition(offset: offset));
      final actual = lastAnchor();
      expect(actual['x'], closeTo(expected.left, 0.01));
      expect(actual['y'], closeTo(expected.top, 0.01));
      expect(actual['height'], closeTo(expected.height, 0.01));
    }

    expectAnchorAt(0);
    final initialY = lastAnchor()['y'] as double;
    const text = 'First line\nSecond line\nThird line\n';
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length - 1),
      composing: TextRange.empty,
    ));
    await tester.pump();
    await tester.pump();
    expectAnchorAt(text.length - 1);
    expect(lastAnchor()['y'] as double, greaterThan(initialY));

    controller.updateSelection(
        const TextSelection.collapsed(offset: 5), ChangeSource.local);
    await tester.pump();
    await tester.pump();
    expectAnchorAt(5);

    // Microsoft Pinyin-style active composition must stay at its range start.
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: 16),
      composing: TextRange(start: 11, end: 16),
    ));
    await tester.pump();
    await tester.pump();
    expectAnchorAt(11);

    // A collapsed composing range is not active composition.
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length - 1),
      composing: TextRange.collapsed(0),
    ));
    await tester.pump();
    await tester.pump();
    expectAnchorAt(text.length - 1);

    focus.unfocus();
    await tester.pump();
    tester.testTextInput.log.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setMarkedTextRect'),
        isEmpty);
    expect(tester.takeException(), isNull);
    focus.dispose();
    controller.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
