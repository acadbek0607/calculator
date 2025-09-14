enum Op { add, sub, mul, div }

class CalculatorLogic {
  String _display = '0';
  double? _acc;
  Op? _pending;
  bool _overwrite = true;

  Op? _lastOp;
  double? _lastOperand;

  // Expression preview / history
  String _expression = '';
  String _lastExpression = '';
  bool _justEvaluated = false;

  // Current entry marked as percent?
  bool _curIsPercent = false;

  // ---- support for backspace-after-operator undo ----
  String _exprBeforeLastOp = '';
  String _lastTypedRaw = '';
  bool _lastTypedWasPercent = false;
  bool _canUndoOperatorBackspace = false;

  // ---- getters for UI ----
  String get display => _display;
  Op? get pending => _pending;
  bool get overwrite => _overwrite;
  bool get showC => !_isZero || !_overwrite;

  // Live big line (preview)
  String get preview {
    final prevOp = _lastOpSymbol();
    if (_overwrite) return _expression;
    final shown = _formatOperandForOp(_display, prevOp, _curIsPercent);
    return (_expression.isEmpty ? '' : _expression) + shown;
  }

  String get lastExpression => _lastExpression;
  bool get justEvaluated => _justEvaluated;

  // ---- internals ----
  bool get _isZero => _display == '0' || _display == '-0';
  double get _current => double.tryParse(_display) ?? 0.0;

  String _fmt(double v) {
    final s = v.toStringAsFixed(12);
    final trimmed = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
    return trimmed.length <= 12 ? trimmed : v.toStringAsExponential(8);
  }

  void _setDisplayFrom(double v) => _display = _fmt(v);

  String _sym(Op op) {
    switch (op) {
      case Op.add:
        return '+';
      case Op.sub:
        return '−';
      case Op.mul:
        return '×';
      case Op.div:
        return '÷';
    }
  }

  bool _endsWithOp() {
    if (_expression.isEmpty) return false;
    final ch = _expression[_expression.length - 1];
    return ch == '÷' || ch == '×' || ch == '−' || ch == '+';
  }

  String? _lastOpSymbol() =>
      _endsWithOp() ? _expression[_expression.length - 1] : null;

  void _replaceLastOp(String sym) {
    if (_endsWithOp()) {
      _expression = _expression.substring(0, _expression.length - 1) + sym;
    }
  }

  void _resetForNewCalcIfNeeded() {
    if (_justEvaluated && _pending == null) {
      _acc = null;
      _pending = null;
      _lastOp = null;
      _lastOperand = null;
      _expression = '';
      _justEvaluated = false;
      _display = '0';
      _overwrite = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
    }
  }

  // If prev op is +/×/÷ or it's the first token, negative is wrapped as (−n); add % if requested.
  String _formatOperandForOp(String value, String? prevOp, bool isPercent) {
    String s = value;
    if ((prevOp == '+' || prevOp == '×' || prevOp == '÷' || prevOp == null) &&
        s.startsWith('-')) {
      s = '(-${s.substring(1)})';
    }
    if (isPercent) s += '%';
    return s;
  }

  String _formatOperandValueForOp(double val, String prevOp) {
    String s = _fmt(val);
    if ((prevOp == '+' || prevOp == '×' || prevOp == '÷') &&
        s.startsWith('-')) {
      s = '(-${s.substring(1)})';
    }
    return s;
  }

  // Percent numeric value depending on the pending op
  double _resolvePercentValue(double rhs) {
    if (_curIsPercent) {
      if ((_pending == Op.add || _pending == Op.sub) && _acc != null) {
        return (_acc ?? 0.0) * (rhs / 100.0); // percent of left
      }
      return rhs / 100.0; // plain percent
    }
    return rhs;
  }

  // ---- inputs ----
  void tapDigit(String d) {
    _resetForNewCalcIfNeeded();
    if (_overwrite || _display == '0') {
      _display = d;
    } else if (_display.length < 12) {
      _display += d;
    }
    _overwrite = false;
    _curIsPercent = false;
    _canUndoOperatorBackspace = false;
  }

  void tapDot() {
    _resetForNewCalcIfNeeded();
    if (_overwrite) {
      _display = '0.';
      _overwrite = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
    _curIsPercent = false;
    _canUndoOperatorBackspace = false;
  }

  // +/- behavior (block right after op)
  void tapToggleSign() {
    if (_overwrite && _endsWithOp()) return; // blocked immediately after op

    final last = _lastOpSymbol();

    if (last == null) {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else if (!_isZero) {
        _display = '-$_display';
      }
      _overwrite = false;
      return;
    }

    if (last == '−') {
      _replaceLastOp('+');
      _pending = Op.add;
      if (_display.startsWith('-')) _display = _display.substring(1);
      _overwrite = false;
      return;
    }

    if (last == '+') {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else if (!_isZero) {
        _display = '-$_display';
      }
      _overwrite = false;
      return;
    }

    if (_display.startsWith('-')) {
      _display = _display.substring(1);
    } else if (!_isZero) {
      _display = '-$_display';
    }
    _overwrite = false;
  }

  // Percent: mark current entry as percent; evaluate on = or op
  void tapPercent() {
    if (_overwrite) _overwrite = false;
    _curIsPercent = true;
    _canUndoOperatorBackspace = false;
  }

  void tapBackspace() {
    // Special: right after an operator → remove the operator and revert to last typed, then delete one char
    if (_overwrite && _endsWithOp() && _canUndoOperatorBackspace) {
      _expression = _exprBeforeLastOp;
      _pending = null;
      _overwrite = false;
      _curIsPercent = _lastTypedWasPercent;
      _display = _lastTypedRaw.isEmpty ? '0' : _lastTypedRaw;

      // if (_display.length <= 1 ||
      //     (_display.length == 2 && _display.startsWith('-'))) {
      //   _display = '0';
      //   _overwrite = true;
      // } else {
      //   _display = _display.substring(0, _display.length - 1);
      // }

      _canUndoOperatorBackspace = false;
      _justEvaluated = false;
      return;
    }

    // Normal backspace on current entry
    if (_overwrite) return;
    if (_display.length <= 1 ||
        (_display.length == 2 && _display.startsWith('-'))) {
      _display = '0';
      _overwrite = true;
    } else {
      _display = _display.substring(0, _display.length - 1);
    }
  }

  // ---- ops (immediate execution) ----
  double _apply(double a, double b, Op op) {
    switch (op) {
      case Op.add:
        return a + b;
      case Op.sub:
        return a - b;
      case Op.mul:
        return a * b;
      case Op.div:
        return b == 0
            ? (a.isNegative ? double.negativeInfinity : double.infinity)
            : a / b;
    }
  }

  void _commitPendingWith(double rhs) {
    final res = _apply(_acc ?? 0.0, rhs, _pending!);
    _acc = res;
    _setDisplayFrom(res);
  }

  void tapOperator(Op op) {
    final sym = _sym(op);

    // Build expression and remember state for possible backspace undo
    if (_justEvaluated) {
      _expression = '${_fmt(_current)}$sym';
      _justEvaluated = false;
      _canUndoOperatorBackspace = false;
    } else if (_expression.isEmpty) {
      final first = _curIsPercent ? '$_display%' : _display;
      _exprBeforeLastOp = '';
      _lastTypedRaw = _display;
      _lastTypedWasPercent = _curIsPercent;
      _expression = '$first$sym';
      _canUndoOperatorBackspace = true;
    } else {
      if (_overwrite) {
        _replaceLastOp(sym);
        _canUndoOperatorBackspace = false; // nothing new typed to undo
      } else {
        final prevOp = _lastOpSymbol();
        final operandShown = _formatOperandForOp(
          _display,
          prevOp,
          _curIsPercent,
        );
        _exprBeforeLastOp = _expression;
        _lastTypedRaw = _display;
        _lastTypedWasPercent = _curIsPercent;
        _expression += '$operandShown$sym';
        _canUndoOperatorBackspace = true;
      }
    }

    // Value to use (handle percent-of-left for + / −)
    final curVal = _resolvePercentValue(_current);

    if (_pending != null && !_overwrite) {
      _commitPendingWith(curVal);
    } else if (_pending == null) {
      _acc = curVal;
      _setDisplayFrom(_acc!);
    }

    _pending = op;
    _lastOp = null;
    _lastOperand = null;
    _overwrite = true;
    _curIsPercent = false;
  }

  void tapEquals() {
    // Standalone "%": N% => N/100
    if (_pending == null && _curIsPercent) {
      _lastExpression = '$_display%';
      final res = _current / 100.0;
      _acc = res;
      _setDisplayFrom(res);
      _overwrite = true;
      _justEvaluated = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
      return;
    }

    // NEW RULES:
    // 1) If we are right after an operator (no RHS typed), '=' should NOT compute.
    //    Drop the trailing operator and finalize on the current accumulator/value.
    if (_pending != null && _overwrite) {
      if (_endsWithOp()) {
        _expression = _expression.substring(
          0,
          _expression.length - 1,
        ); // drop trailing op
      }
      // Show expression without the trailing operator if any; if empty, show the current value.
      _lastExpression = _expression.isEmpty
          ? _fmt(_acc ?? _current)
          : _expression;
      _expression = '';
      _pending = null;
      _lastOp = null;
      _lastOperand = null;
      _overwrite = true;
      _justEvaluated = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
      // display already holds _acc (or current number for first op case)
      return;
    }

    if (_pending != null) {
      final opSym = _lastOpSymbol() ?? _sym(_pending!);

      double rhsVal;
      String rhsShown;

      if (!_overwrite) {
        // user just entered RHS
        final rawPercent = _current / 100.0;
        final usingPercentOfLeft =
            _curIsPercent &&
            (_pending == Op.add || _pending == Op.sub) &&
            _acc != null;

        rhsVal = _resolvePercentValue(_current);
        if (_curIsPercent) {
          if (usingPercentOfLeft) {
            rhsShown = '(${_fmt(_acc ?? 0)}×${_fmt(rawPercent)})';
          } else {
            rhsShown = '$_display%';
          }
        } else {
          rhsShown = _formatOperandForOp(_display, opSym, false);
        }
      } else {
        // repeat '=' or '=' after operator without new rhs is handled above
        final baseRhs = _lastOperand ?? _current;
        final rawPercent = baseRhs / 100.0;
        final usingPercentOfLeft =
            _curIsPercent &&
            (_pending == Op.add || _pending == Op.sub) &&
            _acc != null;

        rhsVal = _resolvePercentValue(baseRhs);
        if (_curIsPercent && usingPercentOfLeft) {
          rhsShown = '(${_fmt(_acc ?? 0)}×${_fmt(rawPercent)})';
        } else {
          rhsShown = _formatOperandValueForOp(rhsVal, opSym);
        }
      }

      final leftPart = _expression.isEmpty
          ? '${_fmt(_acc ?? 0)}$opSym'
          : _expression;
      _lastExpression = leftPart + rhsShown;

      _commitPendingWith(rhsVal);
      _lastOp = _pending;
      _lastOperand = rhsVal;
      _pending = null;
      _overwrite = true;
      _justEvaluated = true;
      _expression = '';
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
      return;
    }

    // Repeat "="
    if (_lastOp != null && _lastOperand != null) {
      final opSym = _sym(_lastOp!);
      _lastExpression =
          '${_fmt(_current)}$opSym${_formatOperandValueForOp(_lastOperand!, opSym)}';
      final res = _apply(_current, _lastOperand!, _lastOp!);
      _acc = res;
      _setDisplayFrom(res);
      _overwrite = true;
      _justEvaluated = true;
      _canUndoOperatorBackspace = false;
    }
  }

  void tapClear() {
    if (!_isZero || !_overwrite) {
      _display = '0';
      _overwrite = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
    } else {
      _display = '0';
      _acc = null;
      _pending = null;
      _lastOp = null;
      _lastOperand = null;
      _overwrite = true;
      _expression = '';
      _lastExpression = '';
      _justEvaluated = false;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
    }
  }
}
