# Only the palette table is needed, and the generator only writes files when it is run directly.
load(ARGV[0] ? File.expand_path(ARGV[0]) : File.join(__dir__, "gen_tropical.rb"))
palettes = PALETTES

def lab(h)
  lin = lambda do |v|
    v /= 255.0
    v > 0.04045 ? ((v + 0.055) / 1.055)**2.4 : v / 12.92
  end
  r, g, b = [1, 3, 5].map { |i| lin.(h[i, 2].to_i(16)) }
  x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
  y = 0.2126 * r + 0.7152 * g + 0.0722 * b
  z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
  f = ->(t) { t > 0.008856 ? t**(1.0 / 3) : 7.787 * t + 16.0 / 116 }
  fx, fy, fz = f.(x), f.(y), f.(z)
  [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)]
end

def delta_e(a, b)
  Math.sqrt(lab(a).zip(lab(b)).sum { |x, y| (x - y)**2 })
end

# Dark backgrounds and frames are close in absolute terms, so they get a tighter bar.
ROLES = { bg: 8, chrome: 12, accent: 25, keyword: 25, string: 25, function: 25, number: 25, type: 25 }

rows = []
palettes.combination(2) do |a, b|
  next if a[:appearance] != b[:appearance]
  close = ROLES.filter_map do |role, limit|
    format("%s (%.0f)", role, delta_e(a[role], b[role])) if delta_e(a[role], b[role]) < limit
  end
  rows << [close.size, a[:name], b[:name], close]
end

rows.sort.reverse_each do |n, a, b, close|
  puts "#{n} similar  #{a} / #{b}: #{close.join(", ")}" if n >= 2
end

CHROMATIC = %i[accent pop cursor sel search keyword string string_alt number function
               type property special param preproc red green yellow blue magenta cyan]
CODE = %i[keyword string string_alt number function type property special param preproc]
palettes.each do |p|
  swatches = p[:swatches].values
  off = CHROMATIC.reject { |role| swatches.include?(p[role]) } +
        p[:icons].each.with_index(1).filter_map { |c, i| "icon#{i}" unless swatches.include?(c) }
  puts "off-palette  #{p[:name]}: #{off.join(", ")}" unless off.empty?
  CODE.combination(2) do |a, b|
    d = delta_e(p[a], p[b])
    if d > 0 && d < 20 && [a, b].sort != %i[string string_alt]
      puts format("near-twin    %s: %s/%s (%.0f)", p[:name], a, b, d)
    end
  end
end

# At thumbnail size a theme is mostly its background, frame and status bar.
dark = palettes.select { |p| p[:appearance] == "dark" }
gap, a, b = dark.combination(2).map { |x, y|
  [%i[bg chrome accent].sum { |r| delta_e(x[r], y[r]) }, x[:name], y[:name]]
}.min
puts format("thumbnail    %s / %s only %.0f apart (want 75+)", a, b, gap) if gap < 75

puts
%i[accent keyword string].each do |role|
  puts "#{role.to_s.ljust(8)} #{palettes.map { |p| "#{p[:name][0, 10]}=#{p[role]}" }.join("  ")}"
end
