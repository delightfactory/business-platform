export function parsePeopleCsv(text) {
  const rows = []; let row = []; let cell = ''; let quoted = false; let afterQuote = false;
  let physicalLine = 1; let recordStartLine = 1;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') { cell += '"'; i += 1; }
      else if (char === '"') { quoted = false; afterQuote = true; }
      else {
        cell += char;
        if (char === '\r') {
          if (text[i + 1] === '\n') { cell += '\n'; i += 1; }
          physicalLine += 1;
        } else if (char === '\n') physicalLine += 1;
      }
    } else if (char === '"') {
      if (cell.length !== 0 || afterQuote) return 'تنسيق علامات الاقتباس غير صالح. صحح الملف ثم أعد الفحص.';
      quoted = true;
    } else if (char === ',' || char === '\n' || char === '\r') {
      row.push(cell); cell = ''; afterQuote = false;
      if (char === ',') continue;
      if (char === '\r' && text[i + 1] === '\n') i += 1;
      if (row.some((value) => value.length > 4000)) return 'أحد الحقول أطول من الحد المسموح.';
      rows.push({ line: recordStartLine, cells: row }); row = [];
      physicalLine += 1; recordStartLine = physicalLine;
      if (rows.length > 101) return 'يسمح الملف بحد أقصى 100 صف.';
    } else {
      if (afterQuote && !/\s/.test(char)) return 'يوجد نص بعد علامة إغلاق الاقتباس. صحح الملف ثم أعد الفحص.';
      cell += char;
    }
  }
  if (quoted) return 'يوجد اقتباس غير مغلق في الملف. صحح الملف ثم أعد الفحص.';
  if (cell.length > 4000) return 'أحد الحقول أطول من الحد المسموح.';
  if (cell.length > 0 || row.length > 0) { row.push(cell); rows.push({ line: recordStartLine, cells: row }); }
  if (rows.length > 101) return 'يسمح الملف بحد أقصى 100 صف.';
  return rows;
}
