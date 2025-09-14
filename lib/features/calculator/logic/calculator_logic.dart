// ignore_for_file: curly_braces_in_flow_control_structures, unused_element, unused_field

enum Op { add, sub, mul, div }

class CalculatorLogic {
  // -------- core display/state --------
  String _display = '0';
  double? _acc;
  Op? _pending; // last key'd operator (for highlight)
  bool _overwrite = true;

  // repeat "="
  Op? _lastOp;
  double? _lastOperand;

  // expression preview / history
  String _expression = '';
  String _lastExpression = '';
  bool _justEvaluated = false;

  // current-entry flags
  bool _curIsPercent = false;

  // backspace-undo (operator)
  String _exprBeforeLastOp = '';
  String _lastTypedRaw = '';
  bool _lastTypedWasPercent = false;
  bool _canUndoOperatorBackspace = false;

  // -------- NEW: tokenized expression for precedence --------
  final List<double> _vals = []; // finalized values (left to right)
  final List<Op> _opsList = []; // operators between values
  final List<bool> _valIsPercent = []; // whether that value was typed with %

  // snapshots for undo (after adding "operand + op")
  List<double> _valsBeforeOp = [];
  List<Op> _opsBeforeOp = [];
  List<bool> _percBeforeOp = [];

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
    // also reflect inside tokens if there is a trailing operator
    if (_opsList.isNotEmpty && _overwrite) {
      _opsList[_opsList.length - 1] = _symbolToOp(sym);
    }
  }

  Op _symbolToOp(String sym) {
    switch (sym) {
      case '+':
        return Op.add;
      case '−':
        return Op.sub;
      case '×':
        return Op.mul;
      case '÷':
        return Op.div;
      default:
        return Op.add;
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
      _clearTokens();
    }
  }

  void _clearTokens() {
    _vals.clear();
    _opsList.clear();
    _valIsPercent.clear();
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

  // -------- inputs ----------
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

  // +/- behavior (blocked right after an operator)
  void tapToggleSign() {
    if (_overwrite && _endsWithOp()) return;

    final last = _lastOpSymbol();

    if (last == null) {
      if (_display.startsWith('-'))
        _display = _display.substring(1);
      else if (!_isZero)
        _display = '-$_display';
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
      if (_display.startsWith('-'))
        _display = _display.substring(1);
      else if (!_isZero)
        _display = '-$_display';
      _overwrite = false;
      return;
    }

    // × or ÷
    if (_display.startsWith('-'))
      _display = _display.substring(1);
    else if (!_isZero)
      _display = '-$_display';
    _overwrite = false;
  }

  // Percent: mark current entry as percent; evaluate on = or operator (with precedence rules)
  void tapPercent() {
    if (_overwrite) _overwrite = false;
    _curIsPercent = true;
    _canUndoOperatorBackspace = false;
  }

  void tapBackspace() {
    // right after an operator → remove op & restore prior operand, then delete one char
    if (_overwrite && _endsWithOp() && _canUndoOperatorBackspace) {
      _expression = _exprBeforeLastOp;
      _pending = null;
      _overwrite = false;
      _curIsPercent = _lastTypedWasPercent;
      _display = _lastTypedRaw.isEmpty ? '0' : _lastTypedRaw;

      // restore tokens snapshot
      _vals
        ..clear()
        ..addAll(_valsBeforeOp);
      _opsList
        ..clear()
        ..addAll(_opsBeforeOp);
      _valIsPercent
        ..clear()
        ..addAll(_percBeforeOp);

      if (_display.length <= 1 ||
          (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
        _overwrite = true;
      } else {
        _display = _display.substring(0, _display.length - 1);
      }

      _canUndoOperatorBackspace = false;
      _justEvaluated = false;
      return;
    }

    // normal backspace
    if (_overwrite) return;
    if (_display.length <= 1 ||
        (_display.length == 2 && _display.startsWith('-'))) {
      _display = '0';
      _overwrite = true;
    } else {
      _display = _display.substring(0, _display.length - 1);
    }
  }

  // -------- math helpers ----------
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

  // With +/−: percent of left; With ×/÷: plain percent
  double _resolvePercentForPair(
    double left,
    double rhs,
    Op opBetween,
    bool rhsIsPercent,
  ) {
    if (!rhsIsPercent) return rhs;
    if (opBetween == Op.add || opBetween == Op.sub) {
      return left * (rhs / 100.0); // percent of left
    }
    return rhs / 100.0; // × or ÷
  }

  // Two-pass evaluation with precedence.
  // Returns (result, lastAddSubOp, lastAddSubRightValueUsed) for repeat "=".
  ({double result, Op? lastOp, double? lastRhs, String builtLastExpr})
  _evaluateWithPrecedence({
    required List<double> vals,
    required List<Op> ops,
    required List<bool> perc, // perc[i] corresponds to vals[i]
    bool expandPercentInHistory = true,
  }) {
    if (vals.isEmpty) {
      return (result: 0.0, lastOp: null, lastRhs: null, builtLastExpr: '');
    }

    // Pass 1: collapse × / ÷
    final List<double> segVals = [];
    final List<Op> segOps = []; // only + or −
    final List<bool> segRhsPercent = []; // percent flag for RHS of each +/−

    double cur = vals[0];
    // If first value was typed as percent *and* there was no op before, treat as plain fraction.
    if (perc[0]) cur = cur / 100.0;

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      double next = vals[i + 1];
      final nextIsPercent = perc[i + 1];

      if (op == Op.mul || op == Op.div) {
        // for ×/÷: percent means plain fraction
        if (nextIsPercent) next = next / 100.0;
        cur = _apply(cur, next, op);
      } else {
        // boundary of + / −
        segVals.add(cur); // completed segment
        segOps.add(op); // op to apply to the upcoming segment
        segRhsPercent.add(nextIsPercent);
        cur = next; // start new segment with next
      }
    }
    segVals.add(cur); // last segment

    // Pass 2: apply + / − left→right; percent of *left sum* for RHS if flagged
    double sum = segVals[0];
    Op? lastUsedOp;
    double? lastUsedRhs;
    String history = '';

    // Build a readable history if needed (fallback to expression if built elsewhere)
    // We'll build: v0 op rhs1 op rhs2 ...; When rhs has percent for +/− we render (left×p)
    history = _fmt(segVals[0]);

    for (int i = 0; i < segOps.length; i++) {
      final op = segOps[i];
      final rhsBase = segVals[i + 1];
      final rhsIsPercentOfLeft = segRhsPercent[i];

      final rhsEval = _resolvePercentForPair(
        sum,
        rhsBase,
        op,
        rhsIsPercentOfLeft,
      );

      // history piece
      String rhsShown;
      if (rhsIsPercentOfLeft && expandPercentInHistory) {
        // show (left × pAsFraction)
        rhsShown = '(${_fmt(sum)}×${_fmt(rhsBase / 100.0)})';
      } else {
        rhsShown = _fmt(rhsEval);
      }

      history += '${_sym(op)}$rhsShown';

      sum = _apply(sum, rhsEval, op);
      lastUsedOp = op;
      lastUsedRhs = rhsEval;
    }

    return (
      result: sum,
      lastOp: lastUsedOp,
      lastRhs: lastUsedRhs,
      builtLastExpr: history,
    );
  }

  // -------- operators (now precedence-aware) ----------
  void tapOperator(Op op) {
    final sym = _sym(op);

    // Build preview expression text
    if (_justEvaluated) {
      _expression = '${_fmt(_current)}$sym';
      _justEvaluated = false;
      _canUndoOperatorBackspace = false;
      // tokens reset to start from current result
      _clearTokens();
      _vals.add(_current);
      _valIsPercent.add(false);
      _opsList.add(op); // we record the operator; RHS to come later
    } else if (_expression.isEmpty) {
      // first chunk
      final firstLabel = _curIsPercent ? '$_display%' : _display;
      _exprBeforeLastOp = '';
      _lastTypedRaw = _display;
      _lastTypedWasPercent = _curIsPercent;
      _expression = '$firstLabel$sym';
      _canUndoOperatorBackspace = true;

      // tokens: push first value
      final firstVal = _curIsPercent ? (_current / 100.0) : _current;
      _clearTokens();
      _vals.add(firstVal);
      _valIsPercent.add(false); // normalized
      _opsList.add(op);
    } else {
      if (_overwrite) {
        _replaceLastOp(sym); // also updates last op in tokens
        _canUndoOperatorBackspace = false;
      } else {
        final prevOp = _lastOpSymbol();
        final operandShown = _formatOperandForOp(
          _display,
          prevOp,
          _curIsPercent,
        );

        // snapshot tokens before append (for backspace-undo)
        _valsBeforeOp = List<double>.from(_vals);
        _opsBeforeOp = List<Op>.from(_opsList);
        _percBeforeOp = List<bool>.from(_valIsPercent);

        _exprBeforeLastOp = _expression;
        _lastTypedRaw = _display;
        _lastTypedWasPercent = _curIsPercent;

        _expression += '$operandShown$sym';
        _canUndoOperatorBackspace = true;

        // tokens: append current value (+ its percent flag), then new op
        _vals.add(_current);
        _valIsPercent.add(_curIsPercent);
        _opsList.add(op);
      }
    }

    // update UI state
    _pending = op;
    _lastOp = null;
    _lastOperand = null;
    _overwrite = true;
    _curIsPercent = false;

    // no immediate math here — precedence evaluation happens on '='
    // but keep display in sync with firstVal for nicer feel
    if (_vals.isNotEmpty && _opsList.length == 1 && _vals.length == 1) {
      _setDisplayFrom(_vals[0]);
    }
  }

  void tapEquals() {
    // Standalone "%": N% => N/100
    if (_opsList.isEmpty && _pending == null && _curIsPercent) {
      _lastExpression = '$_display%';
      final res = _current / 100.0;
      _acc = res;
      _setDisplayFrom(res);
      _overwrite = true;
      _justEvaluated = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;
      _clearTokens();
      _vals.add(res);
      _valIsPercent.add(false);
      return;
    }

    // If right after an operator (no RHS typed) → drop trailing op, don't compute
    if (_pending != null && _overwrite) {
      if (_endsWithOp())
        _expression = _expression.substring(0, _expression.length - 1);
      _lastExpression = _expression.isEmpty
          ? (_vals.isNotEmpty ? _fmt(_vals[0]) : _fmt(_current))
          : _expression;
      _expression = '';
      _pending = null;
      _lastOp = null;
      _lastOperand = null;
      _overwrite = true;
      _justEvaluated = true;
      _curIsPercent = false;
      _canUndoOperatorBackspace = false;

      // keep tokens as-is; display already shows current
      if (_vals.isEmpty) {
        _clearTokens();
        _vals.add(_current);
        _valIsPercent.add(false);
      }
      return;
    }

    // Build working copies of tokens for evaluation
    final vals = List<double>.from(_vals);
    final ops = List<Op>.from(_opsList);
    final perc = List<bool>.from(_valIsPercent);

    // Append current entry as final value if user just typed it
    if (_pending != null && !_overwrite) {
      vals.add(_current);
      perc.add(_curIsPercent);
    }

    // Guard: need ops < vals to evaluate; else (e.g., number→op→=) handled above
    if (vals.isEmpty) {
      final res = _current;
      _acc = res;
      _setDisplayFrom(res);
      _lastExpression = _fmt(res);
      _finalizeAfterEquals(res, lastOp: null, lastRhs: null);
      return;
    }
    while (ops.length >= vals.length && ops.isNotEmpty) {
      ops.removeLast(); // safety: trim stray last op
    }

    // Evaluate with precedence
    final eval = _evaluateWithPrecedence(vals: vals, ops: ops, perc: perc);

    // Build lastExpression: prefer nice history from eval if our preview exists
    _lastExpression = _expression.isNotEmpty
        ? (_overwrite
              ? _expression // unusual path; but keep as-is
              : _expression +
                    _formatOperandForOp(
                      _display,
                      _lastOpSymbol() ?? '+',
                      _curIsPercent,
                    ))
        : eval.builtLastExpr;

    // Set display/result
    final res = eval.result;
    _acc = res;
    _setDisplayFrom(res);

    // store for repeat "=" if meaningful
    _lastOp = eval.lastOp;
    _lastOperand = eval.lastRhs;

    // finalize
    _finalizeAfterEquals(res, lastOp: _lastOp, lastRhs: _lastOperand);
  }

  void _finalizeAfterEquals(double res, {Op? lastOp, double? lastRhs}) {
    _pending = null;
    _overwrite = true;
    _justEvaluated = true;
    _expression = '';
    _curIsPercent = false;
    _canUndoOperatorBackspace = false;

    // reset tokens to start from result
    _clearTokens();
    _vals.add(res);
    _valIsPercent.add(false);
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
      _clearTokens();
    }
  }
}
