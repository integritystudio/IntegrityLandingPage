#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Script to add function coverage data to lcov.info.
///
/// Flutter's coverage only outputs line coverage, this adds function coverage
/// by parsing Dart source files and correlating with line hit data.
library;

import 'dart:io';

void main(List<String> args) {
  final lcovPath = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final lcovFile = File(lcovPath);

  if (!lcovFile.existsSync()) {
    stderr.writeln('Error: $lcovPath not found');
    exit(1);
  }

  final content = lcovFile.readAsStringSync();
  final enhanced = addFunctionCoverage(content);
  lcovFile.writeAsStringSync(enhanced);

  print('✅ Function coverage added to $lcovPath');
}

String addFunctionCoverage(String lcovContent) {
  final buffer = StringBuffer();
  final lines = lcovContent.split('\n');

  String? currentFile;
  final lineHits = <int, int>{};
  final recordLines = <String>[];

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      // New source file
      if (currentFile != null) {
        // Process previous file
        buffer.write(processFile(currentFile, lineHits, recordLines));
      }
      currentFile = line.substring(3);
      lineHits.clear();
      recordLines.clear();
      recordLines.add(line);
    } else if (line.startsWith('DA:')) {
      // Line data: DA:line_number,hit_count
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNum = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (lineNum != null && hits != null) {
          lineHits[lineNum] = hits;
        }
      }
      recordLines.add(line);
    } else if (line == 'end_of_record') {
      recordLines.add(line);
      if (currentFile != null) {
        buffer.write(processFile(currentFile, lineHits, recordLines));
      }
      currentFile = null;
      lineHits.clear();
      recordLines.clear();
    } else {
      recordLines.add(line);
    }
  }

  // Handle last file if no end_of_record
  if (currentFile != null && recordLines.isNotEmpty) {
    buffer.write(processFile(currentFile, lineHits, recordLines));
  }

  return buffer.toString();
}

String processFile(String filePath, Map<int, int> lineHits, List<String> recordLines) {
  final buffer = StringBuffer();
  final functions = extractFunctions(filePath);

  // Deduplicate function names by appending line number to duplicates
  final seenNames = <String, int>{};
  final uniqueFunctions = <FunctionInfo>[];

  for (final func in functions) {
    var uniqueName = func.name;
    if (seenNames.containsKey(func.name)) {
      // Append line number to make unique
      uniqueName = '${func.name}_L${func.lineNumber}';
    }
    seenNames[func.name] = (seenNames[func.name] ?? 0) + 1;
    uniqueFunctions.add(FunctionInfo(uniqueName, func.lineNumber, func.endLine));
  }

  // Write SF line
  buffer.writeln(recordLines.first);

  // Write FN lines (function name to line mapping)
  for (final func in uniqueFunctions) {
    buffer.writeln('FN:${func.lineNumber},${func.name}');
  }

  // Write FNDA lines (function hit data)
  var functionsHit = 0;
  for (final func in uniqueFunctions) {
    // A function is considered hit if its definition line or any line in its body is hit
    final isHit = isFunctionHit(func, lineHits);
    final hitCount = isHit ? 1 : 0;
    if (isHit) functionsHit++;
    buffer.writeln('FNDA:$hitCount,${func.name}');
  }

  // Write FNF (functions found) and FNH (functions hit)
  buffer.writeln('FNF:${uniqueFunctions.length}');
  buffer.writeln('FNH:$functionsHit');

  // Write remaining records (DA, LF, LH, end_of_record)
  for (var i = 1; i < recordLines.length; i++) {
    buffer.writeln(recordLines[i]);
  }

  return buffer.toString();
}

bool isFunctionHit(FunctionInfo func, Map<int, int> lineHits) {
  // Check if the function's start line or nearby lines are hit
  // We check a range because the function definition might span multiple lines
  for (var i = func.lineNumber; i <= func.lineNumber + 5 && i <= func.endLine; i++) {
    if (lineHits.containsKey(i) && lineHits[i]! > 0) {
      return true;
    }
  }
  return false;
}

List<FunctionInfo> extractFunctions(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return [];
  }

  final content = file.readAsStringSync();
  final lines = content.split('\n');
  final functions = <FunctionInfo>[];

  // Regex patterns for Dart functions/methods
  final patterns = [
    // Regular functions: returnType functionName(params) {
    RegExp(r'^\s*(?:static\s+)?(?:Future<[^>]+>|[A-Za-z_][A-Za-z0-9_<>,\s]*)\s+([a-z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*(?:async\s*)?[{=]'),
    // Constructors: ClassName(params) or ClassName.named(params)
    RegExp(r'^\s*([A-Z][a-zA-Z0-9_]*(?:\.[a-z_][a-zA-Z0-9_]*)?)\s*\([^)]*\)\s*(?::\s*[^{]+)?[{;]'),
    // Factory constructors
    RegExp(r'^\s*factory\s+([A-Z][a-zA-Z0-9_]*(?:\.[a-z_][a-zA-Z0-9_]*)?)\s*\([^)]*\)'),
    // Getters: type get name => or {
    RegExp(r'^\s*(?:static\s+)?(?:[A-Za-z_][A-Za-z0-9_<>,\s]*)\s+get\s+([a-z_][a-zA-Z0-9_]*)\s*[{=]'),
    // Setters: set name(value) {
    RegExp(r'^\s*(?:static\s+)?set\s+([a-z_][a-zA-Z0-9_]*)\s*\('),
    // Arrow functions in class: name(params) =>
    RegExp(r'^\s*(?:@override\s+)?(?:static\s+)?(?:Future<[^>]+>|[A-Za-z_][A-Za-z0-9_<>,\s]*)\s+([a-z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*=>'),
  ];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNum = i + 1; // LCOV uses 1-based line numbers

    // Skip comments and empty lines
    if (line.trim().startsWith('//') || line.trim().isEmpty) {
      continue;
    }

    // Try each pattern
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1);
        if (name != null && !_isKeyword(name)) {
          // Estimate end line (simple heuristic)
          final endLine = _findFunctionEnd(lines, i);
          functions.add(FunctionInfo(name, lineNum, endLine));
          break;
        }
      }
    }
  }

  return functions;
}

int _findFunctionEnd(List<String> lines, int startIndex) {
  var braceCount = 0;
  var started = false;

  for (var i = startIndex; i < lines.length; i++) {
    final line = lines[i];

    for (final char in line.split('')) {
      if (char == '{') {
        braceCount++;
        started = true;
      } else if (char == '}') {
        braceCount--;
        if (started && braceCount == 0) {
          return i + 1; // 1-based
        }
      }
    }

    // Handle arrow functions (end at semicolon)
    if (!started && line.contains('=>') && line.contains(';')) {
      return i + 1;
    }
  }

  return startIndex + 10; // Fallback
}

bool _isKeyword(String name) {
  const keywords = {
    'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default',
    'try', 'catch', 'finally', 'throw', 'return', 'break', 'continue',
    'new', 'const', 'final', 'var', 'void', 'null', 'true', 'false',
    'this', 'super', 'class', 'extends', 'implements', 'with', 'mixin',
    'abstract', 'static', 'async', 'await', 'yield', 'import', 'export',
    'library', 'part', 'typedef', 'enum', 'extension', 'on', 'is', 'as',
  };
  return keywords.contains(name);
}

class FunctionInfo {
  final String name;
  final int lineNumber;
  final int endLine;

  FunctionInfo(this.name, this.lineNumber, this.endLine);

  @override
  String toString() => '$name (line $lineNumber-$endLine)';
}
