# ...existing code...
require 'roo'
require 'date'

ods = Roo::OpenOffice.new("NOAA_Solar_Calculations_day.ods")
sheet = ods.sheet(0)

puts "Formulas in row 3:"
(sheet.first_column..sheet.last_column).each do |col|
  formula = sheet.formula(3, col)
  next unless formula && !formula.to_s.empty?
  col_label = begin
    Roo::Utils.number_to_letter(col)
  rescue StandardError
    col
  end
  puts "#{col_label}3 -> #{formula}"
end
#
# ...existing code...
# Added: evaluate formulas after substituting B3,B4,B5,B7 with initial values
# Edit the values below to the initial numbers you want to use
initials = {
  'B3' => 40.0,   # example: latitude (degrees) plus to North
  'B4' => -122.0,   # example: longitude (degrees) plus to East
  'B5' => -7,   # example: timezone or elevation
  'B7' => Date.today    # example: date-related value
}

# Build regex for cell refs like $B$3, B3, b3
def cell_ref_pattern(col, row)
  Regexp.new("\\$?#{Regexp.escape(col)}\\$?#{Regexp.escape(row.to_s)}\\b", Regexp::IGNORECASE)
end

# Convert a single Excel formula string into a Ruby expression, substituting initial cell values
# ...existing code...
def excel_formula_to_ruby(formula_str, initials, sheet, memo = {})
  return nil unless formula_str && !formula_str.to_s.empty?
  s = formula_str.to_s.dup
  s.sub!(/^=/, '') # drop leading '='

  # Normalize ODS/LibreOffice bracketed refs like "[.A4]" or "[A4]" -> "A4"
  s.gsub!(/\[\.\$?([A-Z]+)\$?(\d+)\]/i, '\1\2')
  s.gsub!(/\[\$?([A-Z]+)\$?(\d+)\]/i, '\1\2')

  # Normalize sheet-qualified refs like "Sheet1.A4" -> "A4"
  s.gsub!(/[A-Za-z0-9_]+\.\$?([A-Z]+)\$?(\d+)/, '\1\2')

  # Convert semicolon separators (locale) to commas
  s.gsub!(';', ',')

  # Helper: convert column letters to number (1-based)
  col_to_index = lambda do |col_letters|
    begin
      Roo::Utils.letter_to_number(col_letters.upcase)
    rescue StandardError
      # simple fallback
      col_letters.upcase.chars.reduce(0) { |acc, ch| acc * 26 + (ch.ord - 64) }
    end
  end

  # Find all cell refs like $A$4, A4, etc.
  refs = s.scan(/\$?([A-Za-z]+)\$?(\d+)/).map { |col, row| [col.upcase, row.to_i] }.uniq

  # Replace each referenced cell with a numeric literal where possible
  refs.each do |col, row|
    ref_key = "#{col}#{row}"
    # If initial override provided, use it
    if initials.key?(ref_key)
      val = initials[ref_key]
      val_str = if val.is_a?(Date) then val.jd.to_f.to_s else (val.to_f.to_s) end
      # replace occurrences with numeric string (match variants with $ and bracket forms)
      s.gsub!(/\$?#{col}\$?#{row}\b/i, val_str)
      s.gsub!(/\[\.\$?#{col}\$?\$?#{row}\]/i, val_str)
      next
    end

    # If memoized resolution exists, reuse it
    if memo.key?(ref_key)
      s.gsub!(/\$?#{col}\$?#{row}\b/i, memo[ref_key].to_s)
      next
    end

    # Attempt to read the sheet: if that cell has a formula, recursively resolve it;
    # otherwise read its value.
    begin
      col_index = col_to_index.call(col)
      cell_formula = sheet.formula(row, col_index) rescue nil
      if cell_formula && !cell_formula.to_s.empty?
        # recursively convert that formula and evaluate to numeric
        inner_expr = excel_formula_to_ruby(cell_formula, initials, sheet, memo)
        resolved = inner_expr ? safe_eval(inner_expr) : nil
      else
        # read raw value
        raw = sheet.cell(row, col_index) rescue nil
        if raw.is_a?(Date)
          resolved = raw.jd.to_f
        elsif raw.nil?
          resolved = nil
        elsif raw.is_a?(Numeric)
          resolved = raw.to_f
        elsif raw.to_s =~ /\A-?\d+(\.\d+)?\z/
          resolved = raw.to_f
        else
          # non-numeric text -> leave as-is (can't resolve)
          resolved = nil
        end
      end
    rescue StandardError
      resolved = nil
    end

    if resolved.nil?
      # leave token unchanged if cannot resolve
      next
    else
      # memoize and replace occurrences with numeric string (ensure decimal)
      valstr = resolved.to_f.to_s
      memo[ref_key] = valstr
      s.gsub!(/\$?#{col}\$?#{row}\b/i, valstr)
    end
  end

  # Now that numeric tokens are in place, protect any remaining cell-like tokens from numeric normalization
  placeholder_map = {}
  s.gsub!(/\$?([A-Za-z]+)\$?(\d+)/) do |m|
    ph = "___UNRESOLVED_#{$1}#{$2}___"
    placeholder_map[ph] = m
    ph
  end

  # Convert IF(condition, true_val, false_val) -> ((condition) ? (true_val) : (false_val))
  while s =~ /\bIF\(([^()]*?),([^()]*?),([^()]*?)\)/i
    s.gsub!(/\bIF\(([^()]*?),([^()]*?),([^()]*?)\)/i) { "((#{$1}) ? (#{$2}) : (#{$3}))" }
  end

  # Common Excel -> Ruby conversions
  s.gsub!(/\^/, '**')
  func_map = {
    /\bSIN\(/i  => 'Math.sin(',
    /\bCOS\(/i  => 'Math.cos(',
    /\bTAN\(/i  => 'Math.tan(',
    /\bASIN\(/i => 'Math.asin(',
    /\bACOS\(/i => 'Math.acos(',
    /\bATAN2\(/i=> 'Math.atan2(',
    /\bATAN\(/i => 'Math.atan(',
    /\bEXP\(/i  => 'Math.exp(',
    /\bLN\(/i   => 'Math.log(',
    /\bLOG\(/i  => 'Math.log10(',
    /\bSQRT\(/i => 'Math.sqrt(',
    /\bABS\(/i  => '('
  }
  func_map.each { |pat, repl| s.gsub!(pat, repl) }

  while s =~ /ABS\(([^()]*?)\)/i
    s.gsub!(/ABS\(([^()]*?)\)/i) { "(#{$1}).abs" }
  end

  # Ensure integer literals gain a decimal point (avoid integer-division surprises),
  # but don't touch digits adjacent to letters/dots (we protected unresolved tokens).
  s.gsub!(/(?<![\w.])(-?\d+)(?![\w.])/) { |n| n.include?('.') ? n : "#{n}.0" }

  # Restore any unresolved placeholders back to their original token (so they remain symbolic)
  placeholder_map.each do |ph, orig|
    s.gsub!(ph, orig)
  end

  # Final cleanup
  s.gsub!(/[\[\]]/, '')
  s.gsub!(/(^|[^\w])\.(?=\w)/, '\1')

  s
end
# ...existing code...
def safe_eval(expr)
  begin
    # evaluate in a minimal context; Math module is available
    result = eval(expr)
    return result
  rescue StandardError => e
    return "ERROR: #{e.class}: #{e.message} (expr: #{expr})"
  end
end

# Iterate all formulas on the sheet and evaluate those that reference the given initials
(sheet.first_row..sheet.last_row).each do |r|
  (sheet.first_column..sheet.last_column).each do |c|
    f = sheet.formula(r, c)
    next unless f && !f.to_s.empty?
    # check if formula mentions any of the initials
    mentions = initials.keys.any? { |ref| f.to_s =~ /#{Regexp.escape(ref)}/i }
    next unless mentions

    col_label = begin
      Roo::Utils.number_to_letter(c)
    rescue StandardError
      c
    end
    #ruby_expr = excel_formula_to_ruby(f, initials)
    ruby_expr = excel_formula_to_ruby(f, initials, sheet)
    evaluated = ruby_expr ? safe_eval(ruby_expr) : "no expression"
    puts "#{col_label}#{r}:"
    puts "  excel: #{f}"
    puts "  ruby:  #{ruby_expr}"
    puts "  =>    #{evaluated}"
  end
end
# ...existing code...
