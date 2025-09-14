import 'package:calculator/features/calculator/logic/calculator_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Calculator extends StatefulWidget {
  const Calculator({super.key});
  @override
  State<Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<Calculator> {
  final logic = CalculatorLogic();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  bool _isSelected(Op op) => logic.pending == op && logic.overwrite;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 24;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(height: topPadding),
            // DISPLAY AREA
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (logic.justEvaluated && logic.lastExpression.isNotEmpty)
                      Text(
                        logic.lastExpression,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white.withAlpha(153),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Text(
                        logic.justEvaluated ? logic.display : logic.preview,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 88,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    // iOS-like colors
    const numBg = Color(0xFF303030);
    const funcBg = Color(0xFF5B5B5B);
    const opBg = Color(0xFFFE9101);
    const decimalLabel = ','; // UI shows comma; logic inserts '.'

    Widget key({
      required Widget child,
      required VoidCallback onTap,
      Color bg = numBg,
      Color fg = Colors.white,
      bool selected = false,
    }) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () {
                onTap();
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : bg,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: selected ? opBg : fg,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Text t(String s) => Text(s);

    final clearLabel = logic.showC ? 'C' : 'AC';

    return Column(
      children: [
        // Row 1: Backspace, C/AC, %, ÷
        Row(
          children: [
            key(
              child: const Icon(Icons.backspace_outlined, color: Colors.white),
              bg: funcBg,
              onTap: logic.tapBackspace,
            ),
            key(child: t(clearLabel), bg: funcBg, onTap: logic.tapClear),
            key(child: t('%'), bg: funcBg, onTap: logic.tapPercent),
            key(
              child: t('÷'),
              bg: opBg,
              selected: _isSelected(Op.div),
              onTap: () => logic.tapOperator(Op.div),
            ),
          ],
        ),
        // Row 2
        Row(
          children: [
            key(child: t('7'), onTap: () => logic.tapDigit('7')),
            key(child: t('8'), onTap: () => logic.tapDigit('8')),
            key(child: t('9'), onTap: () => logic.tapDigit('9')),
            key(
              child: t('×'),
              bg: opBg,
              selected: _isSelected(Op.mul),
              onTap: () => logic.tapOperator(Op.mul),
            ),
          ],
        ),
        // Row 3
        Row(
          children: [
            key(child: t('4'), onTap: () => logic.tapDigit('4')),
            key(child: t('5'), onTap: () => logic.tapDigit('5')),
            key(child: t('6'), onTap: () => logic.tapDigit('6')),
            key(
              child: t('−'),
              bg: opBg,
              selected: _isSelected(Op.sub),
              onTap: () => logic.tapOperator(Op.sub),
            ),
          ],
        ),
        // Row 4
        Row(
          children: [
            key(child: t('1'), onTap: () => logic.tapDigit('1')),
            key(child: t('2'), onTap: () => logic.tapDigit('2')),
            key(child: t('3'), onTap: () => logic.tapDigit('3')),
            key(
              child: t('+'),
              bg: opBg,
              selected: _isSelected(Op.add),
              onTap: () => logic.tapOperator(Op.add),
            ),
          ],
        ),
        // Row 5
        Row(
          children: [
            key(child: t('+/−'), bg: numBg, onTap: logic.tapToggleSign),
            key(child: t('0'), onTap: () => logic.tapDigit('0')),
            key(child: t(decimalLabel), onTap: logic.tapDot),
            key(child: t('='), bg: opBg, onTap: logic.tapEquals),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
