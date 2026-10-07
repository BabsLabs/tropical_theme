require "json"
require "pathname"
require "zlib"

SCRATCH = Pathname(__dir__)
ZED_ORIG = SCRATCH / "tropical.zed.orig.json"
ZED = SCRATCH / "zed"
ZED_OUT = ZED / "themes/tropical.json"
EXT = SCRATCH / "vscode"
# VS Code caches manifests per installed version, so every regeneration needs a new one.
VERSION = "1.0.0"

# chrome = title/activity bar, accent = VS Code's status bar unless `status` names another role (Zed's is
# always chrome), pop = badges and remote/debug items,
# icons = the six signature colours used for bracket pairs, indent guides, Zed accents and collaborators.
# Every chromatic role names one of the palette's swatches, so each colour has exactly one definition;
# surfaces and text stay literal region-tinted neutrals. The 6th icon colours Zed's AI agent, so it is
# never a green or red that would read as a diff.
def resolve(d)
  pick = ->(v) { v.is_a?(String) ? d[:swatches].fetch(v.to_sym, v) : v }
  d.transform_values { |v| v.is_a?(Array) ? v.map(&pick) : pick.(v) }
end

PALETTES = [
  {
    name: "Jungle", slug: "jungle", appearance: "dark",
    swatches: {
      toucan_beak: "#ffd400", scarlet_macaw: "#ff2a2a", monstera: "#a6ff00", new_leaf: "#d4ff80",
      banana: "#ffe600", macaw_blue: "#00b3ff", papaya: "#ff8800", hibiscus: "#ff5cc8",
      orchid: "#c58bff", jungle_pool: "#1ff2d5",
    },
    bg: "#03200c", panel: "#021507", chrome: "#0a0c08", elevated: "#0a3016", element: "#082a12",
    fg: "#f2ffe9", muted: "#b8e0a8", placeholder: "#6f9e62", disabled: "#3f6a36",
    border: "#10401d", accent: "toucan_beak", pop: "scarlet_macaw", cursor: "monstera", sel: "toucan_beak",
    hover: "#0a3317", active: "#0e3f1e", selected: "#124b25", active_line: "#072a11",
    comment: "#6f9e62", doc: "#8fbf80",
    keyword: "scarlet_macaw", string: "monstera", string_alt: "new_leaf", number: "banana",
    function: "papaya", type: "macaw_blue", property: "jungle_pool", special: "orchid",
    param: "hibiscus", preproc: "macaw_blue", punct: "#9fd08c", bracket: "#d8f5cc",
    icons: ["banana", "macaw_blue", "scarlet_macaw", "monstera", "papaya", "hibiscus"],
    black: "#0a3016", red: "scarlet_macaw", green: "monstera", yellow: "banana",
    blue: "macaw_blue", magenta: "hibiscus", cyan: "jungle_pool", white: "#f2ffe9",
    search: "banana", keyword_style: "bold",
  },
  {
    name: "Rainforest", slug: "rainforest", appearance: "dark",
    swatches: {
      morpho_blue: "#1e90ff", morpho_shimmer: "#4da6ff", tree_frog: "#4dff5a", frog_leaf: "#a6ffae",
      frog_eye: "#ff3d57", frog_feet: "#ff8f1f", frog_flank: "#b19cff", golden_frog: "#ffe135",
      bromeliad: "#ff70c0", rain_pool: "#4de8d0", canopy_mist: "#a8e6dc",
    },
    bg: "#041c1a", panel: "#031411", chrome: "#0a1f52", elevated: "#0a2d28", element: "#082620",
    fg: "#e6fff8", muted: "#a3d9cc", placeholder: "#5f9488", disabled: "#3b675e",
    border: "#0f3d35", accent: "morpho_blue", pop: "golden_frog", cursor: "frog_eye", sel: "morpho_blue",
    hover: "#0b2e29", active: "#0e3832", selected: "#12443c", active_line: "#082521",
    comment: "#5f9488", doc: "#7cb0a4",
    keyword: "morpho_shimmer", string: "tree_frog", string_alt: "frog_leaf", number: "bromeliad",
    function: "golden_frog", type: "frog_feet", property: "canopy_mist", special: "frog_eye",
    param: "frog_flank", preproc: "rain_pool", punct: "#8cc2b6", bracket: "#c9efe6",
    icons: ["morpho_shimmer", "tree_frog", "golden_frog", "frog_eye", "frog_feet", "frog_flank"],
    black: "#0a2d28", red: "frog_eye", green: "tree_frog", yellow: "golden_frog",
    blue: "morpho_shimmer", magenta: "frog_flank", cyan: "rain_pool", white: "#e6fff8",
    search: "golden_frog", keyword_style: "italic",
  },
  {
    name: "Cloud Forest", slug: "cloud-forest", appearance: "dark",
    swatches: {
      quetzal: "#1fd67f", quetzal_sheen: "#2fe89a", quetzal_breast: "#ff3d6e", orchid: "#e0a8ff",
      orchid_pale: "#f0d0ff", sapphire: "#7aa2ff", sabrewing: "#8f7bff", gorget: "#ff4fb0",
      bromeliad_gold: "#ffd166", moss: "#c9e36a", fog: "#b8d8e8", cascade: "#6fe3d6",
    },
    bg: "#131c1f", panel: "#0e1517", chrome: "#0a4a37", elevated: "#1b262a", element: "#182226",
    fg: "#eef5f7", muted: "#b3c5ca", placeholder: "#71858b", disabled: "#475a60",
    border: "#243338", accent: "quetzal", pop: "sabrewing", cursor: "quetzal_breast", sel: "quetzal",
    hover: "#1c282c", active: "#223137", selected: "#283a41", active_line: "#172226",
    comment: "#7a8f96", doc: "#93a7ad",
    keyword: "quetzal_sheen", string: "orchid", string_alt: "orchid_pale", number: "bromeliad_gold",
    function: "sapphire", type: "quetzal_breast", property: "fog", special: "gorget",
    param: "moss", preproc: "sabrewing", punct: "#9fb3b8", bracket: "#d6e4e8",
    icons: ["quetzal_sheen", "quetzal_breast", "sapphire", "bromeliad_gold", "orchid", "gorget"],
    black: "#1b262a", red: "quetzal_breast", green: "quetzal_sheen", yellow: "bromeliad_gold",
    blue: "sapphire", magenta: "orchid", cyan: "cascade", white: "#eef5f7",
    search: "bromeliad_gold", keyword_style: "bold", type_style: "italic",
  },
  {
    name: "Pantanal", slug: "pantanal", appearance: "light",
    swatches: {
      water_hyacinth: "#6f3ff5", hyacinth_macaw: "#2340b0", eye_ring: "#ffd21f", eye_ring_deep: "#8a6600",
      floating_fern: "#1a7a3a", lily_pad: "#0f7358", jabiru: "#c8102e", victoria_lily: "#c2185b",
      toco_beak: "#b04e00", caiman: "#5c6b12", capybara: "#8a5a2b", floodwater: "#00797a",
    },
    bg: "#edf6f3", panel: "#d8ebe2", chrome: "#2340b0", elevated: "#ffffff", element: "#e4f1eb",
    fg: "#122a33", muted: "#40606b", placeholder: "#6a8791", disabled: "#aabfc6",
    border: "#c6ddd3", accent: "water_hyacinth", pop: "eye_ring", cursor: "jabiru", sel: "water_hyacinth",
    hover: "#e0efe8", active: "#d0e6dc", selected: "#d6d0ff", active_line: "#e5f2ec",
    comment: "#6f8a92", doc: "#5f7a82",
    keyword: "hyacinth_macaw", string: "floating_fern", string_alt: "lily_pad", number: "victoria_lily",
    function: "toco_beak", type: "water_hyacinth", property: "caiman", special: "jabiru",
    param: "capybara", preproc: "water_hyacinth", punct: "#50656c", bracket: "#2a3f47",
    icons: ["hyacinth_macaw", "eye_ring_deep", "jabiru", "water_hyacinth", "floating_fern", "capybara"],
    black: "#122a33", red: "jabiru", green: "floating_fern", yellow: "eye_ring_deep",
    blue: "hyacinth_macaw", magenta: "water_hyacinth", cyan: "floodwater", white: "#e0edf2",
    search: "eye_ring", keyword_style: "bold",
  },
  {
    name: "Cenote", slug: "cenote", appearance: "dark",
    swatches: {
      turquoise: "#1feab8", sunbeam: "#ffc94a", limestone: "#f0d8a8", limestone_pale: "#fff0cc",
      vine: "#a6e36a", motmot_rufous: "#ff8a4c", motmot_blue: "#8fb8ff", sky: "#a8d4ff",
      orchid: "#d0b0ff", tillandsia: "#ff8fd0", heliconia: "#ff6b6b",
    },
    bg: "#06363f", panel: "#042a31", chrome: "#0b2f7a", elevated: "#0a4450", element: "#083d48",
    fg: "#effbf8", muted: "#a9d8d2", placeholder: "#669e99", disabled: "#3f716e",
    border: "#0e4f5a", accent: "turquoise", pop: "motmot_rufous", cursor: "sunbeam", sel: "turquoise",
    hover: "#0a414b", active: "#0d4b56", selected: "#105662", active_line: "#083c46",
    comment: "#6fa5a0", doc: "#8dbdb8",
    keyword: "sunbeam", string: "limestone", string_alt: "limestone_pale", number: "heliconia",
    function: "turquoise", type: "vine", property: "sky", special: "tillandsia",
    param: "orchid", preproc: "turquoise", punct: "#9cc9c4", bracket: "#d8f0ec",
    icons: ["turquoise", "sunbeam", "motmot_blue", "motmot_rufous", "vine", "limestone"],
    black: "#0a4450", red: "heliconia", green: "vine", yellow: "sunbeam",
    blue: "motmot_blue", magenta: "orchid", cyan: "turquoise", white: "#effbf8",
    search: "sunbeam", keyword_style: "bold",
  },
  {
    name: "Mangroves", slug: "mangroves", appearance: "dark",
    swatches: {
      sunset: "#ff7a1a", spoonbill: "#ff9fcf", spoonbill_pale: "#ffc9e4", kingfisher: "#2ad4e8",
      fiddler_claw: "#ffe14d", tannin: "#ffb347", propagule: "#a8e05f", dusk: "#d8a7ff",
      egret: "#f0dfbd", tree_crab: "#ff5a36", tide: "#4db0ff",
    },
    bg: "#231507", panel: "#1a0f04", chrome: "#5a2d06", elevated: "#2f1e0c", element: "#2a190a",
    fg: "#fbeede", muted: "#d9c2a0", placeholder: "#9a8163", disabled: "#62503a",
    border: "#3f2a14", accent: "sunset", pop: "spoonbill", cursor: "kingfisher", sel: "sunset",
    hover: "#2e1d0c", active: "#382410", selected: "#452c13", active_line: "#2a1a09",
    comment: "#9a8163", doc: "#b09878",
    keyword: "sunset", string: "spoonbill", string_alt: "spoonbill_pale", number: "fiddler_claw",
    function: "kingfisher", type: "tannin", property: "egret", special: "dusk",
    param: "propagule", preproc: "kingfisher", punct: "#c0a582", bracket: "#f0dfc2",
    icons: ["sunset", "spoonbill", "kingfisher", "fiddler_claw", "propagule", "tannin"],
    black: "#2f1e0c", red: "tree_crab", green: "propagule", yellow: "fiddler_claw",
    blue: "tide", magenta: "spoonbill", cyan: "kingfisher", white: "#fbeede",
    search: "fiddler_claw", keyword_style: "bold",
  },
  {
    name: "Beach", slug: "beach", appearance: "light",
    swatches: {
      sun: "#ffc300", sun_deep: "#8a6200", deep_water: "#0057a8", umbrella: "#c9184a",
      turquoise: "#007a87", shallows: "#00c2d1", sea_glass: "#11734f", palm: "#2b7a0b",
      starfish: "#b54a00", driftwood: "#7a5230", bougainvillea: "#b5179e",
    },
    bg: "#fffaf0", panel: "#f3e2c0", chrome: "#005f8f", elevated: "#ffffff", element: "#fbf0da",
    fg: "#12263a", muted: "#43586b", placeholder: "#6f7f8c", disabled: "#b3b9bd",
    border: "#e8d4ab", accent: "sun", pop: "umbrella", cursor: "umbrella", sel: "shallows",
    hover: "#f5e8cc", active: "#efdcb5", selected: "#c3eef2", active_line: "#fdf3df",
    comment: "#857f6f", doc: "#716b5c",
    keyword: "umbrella", string: "turquoise", string_alt: "sea_glass", number: "starfish",
    function: "deep_water", type: "palm", property: "driftwood", special: "bougainvillea",
    param: "sun_deep", preproc: "deep_water", punct: "#566573", bracket: "#2c3e50",
    icons: ["deep_water", "umbrella", "turquoise", "starfish", "palm", "sun_deep"],
    black: "#12263a", red: "umbrella", green: "palm", yellow: "sun_deep",
    blue: "deep_water", magenta: "bougainvillea", cyan: "turquoise", white: "#efe3c8",
    search: "sun", keyword_style: "bold",
  },
  {
    name: "Coral Reef", slug: "coral-reef", appearance: "dark",
    swatches: {
      coral: "#ff5c8a", yellow_tang: "#ffe01a", yellow_tang_pale: "#fff08a", clownfish: "#ff9a2e",
      parrotfish: "#5dffb0", giant_clam: "#29e6e6", royal_gramma: "#b98cff", nudibranch: "#ff4fd8",
      tang_blue: "#4da3ff", sea_foam: "#c4ecff", sea_grass: "#8dff8a",
    },
    bg: "#012c47", panel: "#001f33", chrome: "#0047d4", elevated: "#063d5f", element: "#043656",
    fg: "#eefaff", muted: "#a6d4ea", placeholder: "#5f93b0", disabled: "#3a6a85",
    border: "#0a4a6e", accent: "coral", pop: "clownfish", cursor: "yellow_tang", sel: "giant_clam",
    hover: "#053a5a", active: "#084566", selected: "#0b5075", active_line: "#023554",
    comment: "#6f9bb5", doc: "#8fb5cc",
    keyword: "coral", string: "yellow_tang", string_alt: "yellow_tang_pale", number: "clownfish",
    function: "parrotfish", type: "royal_gramma", property: "sea_foam", special: "nudibranch",
    param: "giant_clam", preproc: "tang_blue", punct: "#8fb9d0", bracket: "#d6ecf7",
    icons: ["clownfish", "tang_blue", "yellow_tang", "coral", "parrotfish", "royal_gramma"],
    black: "#0a4566", red: "coral", green: "sea_grass", yellow: "yellow_tang",
    blue: "tang_blue", magenta: "nudibranch", cyan: "giant_clam", white: "#eefaff",
    search: "yellow_tang", keyword_style: "bold",
  },
  {
    # The only theme without bold: it glows rather than shouts.
    name: "Bioluminescent Bay", slug: "bioluminescent-bay", appearance: "dark",
    swatches: {
      plankton: "#00e5ff", plankton_pale: "#8ff4ff", sea_sparkle: "#39ffb6", milky_way: "#b18cff",
      comb_jelly: "#ff6be6", starlight: "#7aa8ff", lantern: "#ffb38a", moon: "#ffd98a",
      moonlit_foam: "#cfe8ff", ember: "#ff5c7a",
    },
    bg: "#03070f", panel: "#010409", chrome: "#24115e", elevated: "#0a1224", element: "#08101f",
    fg: "#e6f7ff", muted: "#9ec3d6", placeholder: "#5a7d91", disabled: "#34505f",
    border: "#10223a", accent: "plankton", pop: "comb_jelly", cursor: "sea_sparkle", sel: "plankton",
    hover: "#0b1830", active: "#0f1f3b", selected: "#122848", active_line: "#060d1a",
    comment: "#5a7d91", doc: "#7897aa",
    keyword: "milky_way", string: "plankton", string_alt: "plankton_pale", number: "moon",
    function: "sea_sparkle", type: "comb_jelly", property: "moonlit_foam", special: "starlight",
    param: "lantern", preproc: "starlight", punct: "#88a9bd", bracket: "#d2e7f2",
    icons: ["plankton", "sea_sparkle", "milky_way", "comb_jelly", "moon", "starlight"],
    black: "#0a1224", red: "ember", green: "sea_sparkle", yellow: "moon",
    blue: "starlight", magenta: "comb_jelly", cyan: "plankton", white: "#e6f7ff",
    search: "moon", keyword_style: nil, type_style: "italic",
  },
  {
    # Red, black and sulfur, with no orange: that belongs to Mangroves. Kawah Ijen's blue sulfur
    # fire and volcanic lightning supply the cool colours.
    name: "Volcano", slug: "volcano", appearance: "dark",
    swatches: {
      lava: "#ff2a1a", lava_glow: "#ff5a47", lava_pale: "#ff9a8a", sulfur: "#ffe14d",
      sulfur_crystal: "#fff2a8", lehua: "#ff6b9d", lightning: "#b48cff", ijen_flame: "#7ab8ff",
      fern: "#9be36a", pele_gold: "#e8c170", steam: "#cfc3bf", acid_lake: "#a0f0e0",
    },
    bg: "#0f0e0e", panel: "#080707", chrome: "#3a3636", elevated: "#1e1a1a", element: "#1a1616",
    fg: "#fff3ec", muted: "#d9b8ad", placeholder: "#9a7a72", disabled: "#634a45",
    border: "#332929", accent: "lava", pop: "sulfur", cursor: "sulfur_crystal", sel: "lava",
    hover: "#221c1c", active: "#2b2323", selected: "#372b2b", active_line: "#1a1616",
    comment: "#8f7a75", doc: "#a88f89",
    keyword: "sulfur", string: "lava_glow", string_alt: "lava_pale", number: "lehua",
    function: "lightning", type: "ijen_flame", property: "steam", special: "pele_gold",
    param: "fern", preproc: "ijen_flame", punct: "#b89e97", bracket: "#ecd8d1",
    icons: ["lava", "sulfur", "lehua", "ijen_flame", "fern", "lightning"],
    black: "#211b1b", red: "lava", green: "fern", yellow: "sulfur",
    blue: "ijen_flame", magenta: "lehua", cyan: "acid_lake", white: "#fff3ec",
    search: "sulfur", keyword_style: "bold", type_style: "bold",
  },
  {
    # The cup frames it (espresso, roasted bean, latte) and cupping notes colour the code, all at
    # one CIELAB lightness so no colour glares. Crema keywords and the roasted-bean frame keep it
    # apart from Mangroves, whose background it shares. Mustard reads olive on brown, so crema leans amber.
    name: "Coffee Highlands", slug: "coffee-highlands", appearance: "dark",
    swatches: {
      crema: "#f7b552", coffee_cherry: "#ff7f7c", cinnamon_roast: "#fc935b", honey: "#eacc7b",
      hazelnut: "#dcb79a", blueberry: "#9bb4fd", blackcurrant: "#db9ee5", steam: "#b8c9d6",
      latte: "#efcfa8", coffee_leaf: "#9ccf7e", wet_mill: "#7fc6bd",
    },
    bg: "#26140e", panel: "#1d0e09", chrome: "#4a2618", elevated: "#36201a", element: "#2f1a12",
    fg: "#fff1e0", muted: "#ead3b8", placeholder: "#b09078", disabled: "#6f4d3c",
    border: "#4c2e20", accent: "latte", pop: "coffee_cherry", cursor: "crema", sel: "crema",
    hover: "#361f16", active: "#41271b", selected: "#573321", active_line: "#2f1911",
    comment: "#b09078", doc: "#c9a88c",
    keyword: "crema", string: "coffee_cherry", string_alt: "honey", number: "honey",
    function: "cinnamon_roast", type: "blueberry", property: "hazelnut", special: "blackcurrant",
    param: "steam", preproc: "blueberry", punct: "#d9bb9d", bracket: "#f5e1c8",
    icons: ["crema", "blueberry", "coffee_cherry", "honey", "cinnamon_roast", "blackcurrant"],
    black: "#36201a", red: "coffee_cherry", green: "coffee_leaf", yellow: "honey",
    blue: "blueberry", magenta: "blackcurrant", cyan: "wet_mill", white: "#fff1e0",
    search: "honey", keyword_style: "bold", status: "chrome",
  },
].map { |d| resolve(d) }

def rgb(h)
  h = h.delete_prefix("#")
  [0, 2, 4].map { |i| h[i, 2].to_i(16) }
end

def mix(a, b, t)
  "#" + rgb(a).zip(rgb(b)).map { |x, y| format("%02x", (x + (y - x) * t).round(half: :even)) }.join
end

def luminance(h)
  chan = lambda do |v|
    v /= 255.0
    v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4
  end
  r, g, b = rgb(h).map(&chan)
  0.2126 * r + 0.7152 * g + 0.0722 * b
end

def contrast(a, b)
  lb, la = [luminance(a), luminance(b)].minmax
  (la + 0.05) / (lb + 0.05)
end

DERIVED = %i[border_variant line_number invisible guide active_guide error warning info success modified
             type_style param_style status zed_chrome shadow]

Palette = Struct.new(*(PALETTES.flat_map(&:keys) | DERIVED), keyword_init: true) do
  def dark? = appearance == "dark"

  def on(c)
    darkest, lightest = dark? ? [bg, fg] : [fg, bg]
    contrast(c, darkest) >= contrast(c, lightest) ? darkest : lightest
  end

  def bright(c) = dark? ? mix(c, "#ffffff", 0.35) : mix(c, "#000000", 0.2)
  def dim(c) = mix(c, bg, 0.35)
end

def derive(d)
  p = Palette.new(**d)
  dark = p.dark?
  p.border_variant = mix(p.bg, p.border, 0.6)
  p.line_number = mix(p.bg, p.fg, dark ? 0.4 : 0.55)
  p.invisible = mix(p.bg, p.fg, 0.15)
  p.guide = mix(p.bg, p.fg, 0.08)
  p.active_guide = mix(p.bg, p.fg, 0.3)
  p.error, p.warning, p.info, p.success, p.modified = p.red, p.yellow, p.blue, p.green, p.preproc
  p.param_style = d.fetch(:param_style, "italic")
  p.status = p[d.fetch(:status, "accent")]
  # Zed paints title/status bar text with the one global text colour, so light themes can't use their dark chrome.
  p.zed_chrome = contrast(p.fg, p.chrome) >= 4.5 ? p.chrome : p.panel
  p.shadow = dark ? "#00000066" : p.fg + "22"
  p
end

def zed_style(color, style)
  out = { color: color }
  out[:font_weight] = 700 if style&.include?("bold")
  out[:font_style] = "italic" if style&.include?("italic")
  out
end

def zed_theme(p)
  ansi = {}
  %w[red green yellow blue magenta cyan].each do |key|
    c = p[key]
    ansi[key], ansi["bright_#{key}"], ansi["dim_#{key}"] = c, p.bright(c), p.dim(c)
  end
  ansi["black"], ansi["bright_black"], ansi["dim_black"] = p.black, p.comment, p.dim(p.black)
  ansi["white"], ansi["bright_white"], ansi["dim_white"] = p.white, p.bright(p.white), p.dim(p.white)

  status = ->(key, c, border = nil) { { "#{key}": c, "#{key}.background": c + "1a", "#{key}.border": border || c } }

  style = {
    background: p.bg, foreground: p.fg, accent: p.cursor,
    accents: p.icons,
    border: p.border, "border.variant": p.border_variant, "border.focused": p.cursor,
    "border.selected": p.cursor, "border.transparent": "#00000000",
    "border.disabled": mix(p.bg, p.border, 0.5),
    "elevated_surface.background": p.elevated, "surface.background": p.panel,
    "element.background": p.element, "element.hover": p.hover, "element.active": p.active,
    "element.selected": p.selected, "element.disabled": mix(p.bg, p.element, 0.5),
    "drop_target.background": p.cursor + "33",
    "ghost_element.background": "#00000000", "ghost_element.hover": p.hover,
    "ghost_element.active": p.active, "ghost_element.selected": p.selected,
    "ghost_element.disabled": mix(p.bg, p.element, 0.5),
    text: p.fg, "text.muted": p.muted, "text.placeholder": p.placeholder,
    "text.disabled": p.disabled, "text.accent": p.cursor,
    icon: p.fg, "icon.muted": p.muted, "icon.disabled": p.disabled,
    "icon.placeholder": p.placeholder, "icon.accent": p.cursor,
    "status_bar.background": p.zed_chrome, "title_bar.background": p.zed_chrome,
    "title_bar.inactive_background": p.zed_chrome, "toolbar.background": p.bg,
    "tab_bar.background": p.panel, "tab.inactive_background": p.panel,
    "tab.active_background": p.bg, "panel.background": p.panel,
    "panel.focused_border": p.cursor, "pane.focused_border": p.cursor,
    "search.match_background": p.search + "40", "search.active_match_background": p.search + "80",
    "scrollbar.thumb.background": p.muted + "33", "scrollbar.thumb.hover_background": p.muted + "66",
    "scrollbar.thumb.border": "#00000000", "scrollbar.track.background": "#00000000",
    "scrollbar.track.border": p.border_variant,
    "editor.foreground": p.fg, "editor.background": p.bg, "editor.gutter.background": p.bg,
    "editor.subheader.background": p.elevated, "editor.active_line.background": p.active_line,
    "editor.highlighted_line.background": p.hover, "editor.line_number": p.line_number,
    "editor.active_line_number": p.cursor, "editor.invisible": p.invisible,
    "editor.wrap_guide": p.guide, "editor.active_wrap_guide": p.border,
    "editor.indent_guide": p.guide, "editor.indent_guide_active": p.active_guide,
    "editor.document_highlight.read_background": p.string + "26",
    "editor.document_highlight.write_background": p.function + "26",
    "editor.document_highlight.bracket_background": p.cursor + "26",
    "terminal.background": p.bg, "terminal.foreground": p.fg,
    "terminal.bright_foreground": p.fg, "terminal.dim_foreground": p.muted,
    **ansi.to_h { |k, v| [:"terminal.ansi.#{k}", v] },
    "link_text.hover": p.cursor,
    **status.("conflict", p.warning), **status.("created", p.success),
    **status.("deleted", p.error), **status.("modified", p.modified),
    **status.("error", p.error), **status.("warning", p.warning), **status.("info", p.info),
    **status.("hint", p.placeholder, p.border_variant), **status.("success", p.success),
    hidden: p.disabled, ignored: p.placeholder, renamed: p.info, unreachable: p.placeholder,
    "version_control.word_added": p.success + "40", "version_control.word_deleted": p.error + "40",
    "version_control.conflict_marker.ours": p.success + "26",
    "version_control.conflict_marker.theirs": p.info + "26",
    players: [
      { cursor: p.cursor, background: p.cursor, selection: p.sel + "40" },
      *p.icons.map { |c| { cursor: c, background: c, selection: c + "40" } },
    ],
    syntax: {
      comment: { color: p.comment, font_style: "italic" },
      "comment.doc": { color: p.doc, font_style: "italic" },
      keyword: zed_style(p.keyword, p.keyword_style),
      string: { color: p.string },
      "string.escape": { color: p.number },
      "string.regex": { color: p.string_alt },
      "string.special": { color: p.string_alt },
      number: { color: p.number },
      boolean: { color: p.number },
      constant: { color: p.number },
      function: { color: p.function },
      "function.method": { color: p.function },
      type: zed_style(p.type, p.type_style),
      constructor: zed_style(p.type, p.type_style),
      variable: { color: p.fg },
      "variable.parameter": zed_style(p.param, p.param_style),
      "variable.special": { color: p.special },
      property: { color: p.property },
      attribute: { color: p.property },
      tag: zed_style(p.type, p.type_style),
      operator: { color: p.fg },
      punctuation: { color: p.punct },
      "punctuation.bracket": { color: p.bracket },
      "punctuation.delimiter": { color: p.punct },
      "punctuation.special": { color: p.keyword },
      label: { color: p.string },
      enum: zed_style(p.type, p.type_style),
      variant: { color: p.number },
      embedded: { color: p.fg },
      link_uri: { color: p.string },
      link_text: { color: p.cyan, font_style: "italic" },
      emphasis: { color: p.fg, font_style: "italic" },
      "emphasis.strong": { color: p.fg, font_weight: 700 },
      title: { color: p.keyword, font_weight: 700 },
      preproc: { color: p.preproc },
      "text.literal": { color: p.string_alt },
      "punctuation.list_marker": { color: p.keyword },
      primary: { color: p.fg },
    },
  }
  { name: "Tropical #{p.name}", appearance: p.appearance, style: style }
end

def vscode_theme(p)
  ansi_names = %w[black red green yellow blue magenta cyan white]
  terminal = {}
  ansi_names.each do |key|
    c = p[key]
    terminal[:"terminal.ansi#{key.capitalize}"] = c
    terminal[:"terminal.ansiBright#{key.capitalize}"] = key == "black" ? p.comment : p.bright(c)
  end

  on_chrome, on_accent, on_pop, on_status = p.on(p.chrome), p.on(p.accent), p.on(p.pop), p.on(p.status)
  brackets = {}
  p.icons.each.with_index(1) do |c, i|
    brackets[:"editorBracketHighlight.foreground#{i}"] = c
    brackets[:"editorBracketPairGuide.activeBackground#{i}"] = c + "99"
    # VS Code drops an indent level unless both of its colours are set.
    brackets[:"editorIndentGuide.background#{i}"] = c + (p.dark? ? "33" : "4d")
    brackets[:"editorIndentGuide.activeBackground#{i}"] = c + "b3"
  end

  symbol_icons = {
    array: p.type, boolean: p.number, class: p.type, color: p.special, constant: p.number,
    constructor: p.type, enumerator: p.type, enumeratorMember: p.number, event: p.special,
    field: p.property, file: p.muted, folder: p.muted, function: p.function,
    interface: p.type, key: p.property, keyword: p.keyword, method: p.function,
    module: p.preproc, namespace: p.preproc, null: p.number, number: p.number,
    object: p.type, operator: p.fg, package: p.preproc, property: p.property,
    reference: p.special, snippet: p.cursor, string: p.string, struct: p.type,
    text: p.fg, typeParameter: p.param, unit: p.number, variable: p.param,
  }

  colors = {
    foreground: p.fg, descriptionForeground: p.muted, disabledForeground: p.disabled,
    errorForeground: p.error, "icon.foreground": p.fg, focusBorder: p.cursor + "aa",
    "selection.background": p.sel + "55", "widget.shadow": p.shadow,
    "textLink.foreground": p.cursor, "textLink.activeForeground": p.cursor, "sash.hoverBorder": p.cursor,

    "titleBar.activeBackground": p.chrome, "titleBar.inactiveBackground": p.chrome,
    "titleBar.activeForeground": on_chrome, "titleBar.inactiveForeground": on_chrome + "99",
    "titleBar.border": p.chrome,
    "activityBar.background": p.chrome, "activityBar.foreground": on_chrome,
    "activityBar.inactiveForeground": on_chrome + "88", "activityBar.activeBorder": p.accent,
    "activityBar.border": p.chrome,
    "activityBarBadge.background": p.pop, "activityBarBadge.foreground": on_pop,
    "sideBar.background": p.panel, "sideBar.foreground": p.fg, "sideBar.border": p.border,
    "sideBarTitle.foreground": p.muted, "sideBarSectionHeader.background": p.panel,
    "sideBarSectionHeader.border": p.border,
    "statusBar.background": p.status, "statusBar.foreground": on_status, "statusBar.border": p.status,
    "statusBar.noFolderBackground": p.status,
    "statusBar.debuggingBackground": p.pop, "statusBar.debuggingForeground": on_pop,
    "statusBarItem.hoverBackground": mix(p.status, on_status, 0.2),
    "statusBarItem.remoteBackground": p.pop, "statusBarItem.remoteForeground": on_pop,
    "panel.background": p.panel, "panel.border": p.border,
    "panelTitle.activeForeground": p.fg, "panelTitle.inactiveForeground": p.placeholder,
    "panelTitle.activeBorder": p.accent,
    "editorGroup.border": p.border, "editorGroupHeader.tabsBackground": p.panel,
    "editorGroupHeader.tabsBorder": p.border,
    "tab.activeBackground": p.bg, "tab.inactiveBackground": p.panel,
    "tab.activeForeground": p.fg, "tab.inactiveForeground": p.placeholder,
    "tab.border": p.border, "tab.activeBorderTop": p.accent, "tab.hoverBackground": p.hover,
    "breadcrumb.background": p.bg, "breadcrumb.foreground": p.muted, "breadcrumb.focusForeground": p.fg,

    "editorWidget.background": p.elevated, "editorWidget.border": p.border,
    "editorHoverWidget.background": p.elevated, "editorHoverWidget.border": p.border,
    "editorSuggestWidget.background": p.elevated, "editorSuggestWidget.border": p.border,
    "editorSuggestWidget.selectedBackground": p.selected, "editorSuggestWidget.highlightForeground": p.cursor,
    "quickInput.background": p.elevated, "quickInputList.focusBackground": p.selected,
    "menu.background": p.elevated, "menu.foreground": p.fg,
    "menu.selectionBackground": p.selected, "menu.border": p.border,
    "notifications.background": p.elevated, "notifications.border": p.border,
    "notificationCenterHeader.background": p.panel,
    "peekView.border": p.accent, "peekViewEditor.background": p.elevated,
    "peekViewResult.background": p.panel, "peekViewTitle.background": p.panel,
    "debugToolBar.background": p.elevated,
    "input.background": p.element, "input.foreground": p.fg,
    "input.placeholderForeground": p.placeholder, "input.border": p.border,
    "inputOption.activeBorder": p.cursor,
    "dropdown.background": p.element, "dropdown.foreground": p.fg, "dropdown.border": p.border,
    "button.background": p.accent, "button.foreground": on_accent,
    "button.hoverBackground": mix(p.accent, on_accent, 0.15),
    "button.secondaryBackground": p.element, "button.secondaryForeground": p.fg,
    "button.secondaryHoverBackground": p.hover,
    "badge.background": p.pop, "badge.foreground": on_pop, "progressBar.background": p.cursor,

    "list.hoverBackground": p.hover, "list.focusBackground": p.active,
    "list.activeSelectionBackground": p.selected, "list.activeSelectionForeground": p.fg,
    "list.inactiveSelectionBackground": p.selected, "list.dropBackground": p.accent + "33",
    "list.highlightForeground": p.cursor, "list.errorForeground": p.error,
    "list.warningForeground": p.warning,
    "toolbar.hoverBackground": p.hover, "toolbar.activeBackground": p.active,
    "scrollbarSlider.background": p.muted + "33", "scrollbarSlider.hoverBackground": p.muted + "55",
    "scrollbarSlider.activeBackground": p.muted + "77", "scrollbar.shadow": p.shadow,

    "editor.background": p.bg, "editor.foreground": p.fg, "editorGutter.background": p.bg,
    "editorCursor.foreground": p.cursor,
    "editor.selectionBackground": p.sel + "40", "editor.inactiveSelectionBackground": p.sel + "26",
    "editor.selectionHighlightBackground": p.sel + "26",
    "editor.lineHighlightBackground": p.active_line, "editor.lineHighlightBorder": p.active_line,
    "editor.rangeHighlightBackground": p.hover,
    "editor.findMatchBackground": p.search + "80", "editor.findMatchHighlightBackground": p.search + "40",
    "editor.wordHighlightBackground": p.string + "26",
    "editor.wordHighlightStrongBackground": p.function + "26",
    "editorLineNumber.foreground": p.line_number, "editorLineNumber.activeForeground": p.cursor,
    "editorWhitespace.foreground": p.invisible, "editorRuler.foreground": p.guide,
    "editorBracketMatch.background": p.cursor + "26", "editorBracketMatch.border": p.cursor + "80",
    "editorBracketHighlight.unexpectedBracket.foreground": p.error,
    **brackets,
    "editorLink.activeForeground": p.cursor, "editorOverviewRuler.border": p.border,
    "editorInlayHint.foreground": p.placeholder, "editorInlayHint.background": p.placeholder + "1a",
    "editorCodeLens.foreground": p.placeholder,
    "editorGutter.foldingControlForeground": p.cursor,
    "editorLightBulb.foreground": p.number, "editorLightBulbAutoFix.foreground": p.string,
    "editorStickyScroll.background": p.panel, "editorStickyScroll.border": p.border,
    "editorStickyScrollHover.background": p.hover,
    "editorGhostText.foreground": p.placeholder, "editor.hoverHighlightBackground": p.sel + "26",
    "editorOverviewRuler.errorForeground": p.error, "editorOverviewRuler.warningForeground": p.warning,
    "editorOverviewRuler.findMatchForeground": p.search + "99",
    "editorOverviewRuler.selectionHighlightForeground": p.sel + "99",

    "pickerGroup.foreground": p.cursor, "pickerGroup.border": p.border,
    "keybindingLabel.background": p.element, "keybindingLabel.foreground": p.muted,
    "keybindingLabel.border": p.border, "keybindingLabel.bottomBorder": p.border,
    "textPreformat.foreground": p.string_alt, "textBlockQuote.border": p.accent + "80",
    "textCodeBlock.background": p.panel, "tree.indentGuidesStroke": p.border,
    **%w[error warning info].to_h { |k| [:"inputValidation.#{k}Background", p.elevated] },
    "inputValidation.errorBorder": p.error, "inputValidation.warningBorder": p.warning,
    "inputValidation.infoBorder": p.info,
    "diffEditor.diagonalFill": p.border,
    "merge.currentHeaderBackground": p.success + "66", "merge.currentContentBackground": p.success + "1a",
    "merge.incomingHeaderBackground": p.info + "66", "merge.incomingContentBackground": p.info + "1a",
    **p.icons.first(5).each.with_index(1).to_h { |c, i| [:"scmGraph.foreground#{i}", c] },
    "scmGraph.historyItemRefColor": p.cursor, "scmGraph.historyItemRemoteRefColor": p.pop,
    "terminalCommandDecoration.defaultBackground": p.placeholder,
    "terminalCommandDecoration.successBackground": p.success,
    "terminalCommandDecoration.errorBackground": p.error,

    **symbol_icons.to_h { |k, v| [:"symbolIcon.#{k}Foreground", v] },

    "editorError.foreground": p.error, "editorWarning.foreground": p.warning,
    "editorInfo.foreground": p.info, "editorHint.foreground": p.placeholder,
    "problemsErrorIcon.foreground": p.error, "problemsWarningIcon.foreground": p.warning,
    "problemsInfoIcon.foreground": p.info,
    "notificationsErrorIcon.foreground": p.error, "notificationsWarningIcon.foreground": p.warning,
    "notificationsInfoIcon.foreground": p.info,
    "testing.iconPassed": p.success, "testing.iconFailed": p.error, "testing.iconErrored": p.error,
    "testing.iconQueued": p.warning, "testing.iconSkipped": p.placeholder, "testing.iconUnset": p.placeholder,
    "debugIcon.breakpointForeground": p.error,
    "charts.foreground": p.fg, "charts.lines": p.border, "charts.red": p.red, "charts.blue": p.blue,
    "charts.yellow": p.yellow, "charts.orange": p.accent, "charts.green": p.green, "charts.purple": p.magenta,
    "settings.modifiedItemIndicator": p.modified,

    "editorGutter.addedBackground": p.success, "editorGutter.modifiedBackground": p.modified,
    "editorGutter.deletedBackground": p.error,
    "diffEditor.insertedTextBackground": p.success + "26", "diffEditor.removedTextBackground": p.error + "26",
    "diffEditor.insertedLineBackground": p.success + "14", "diffEditor.removedLineBackground": p.error + "14",
    "gitDecoration.addedResourceForeground": p.success,
    "gitDecoration.untrackedResourceForeground": p.success,
    "gitDecoration.modifiedResourceForeground": p.modified,
    "gitDecoration.deletedResourceForeground": p.error,
    "gitDecoration.renamedResourceForeground": p.info,
    "gitDecoration.conflictingResourceForeground": p.warning,
    "gitDecoration.ignoredResourceForeground": p.placeholder,
    "gitDecoration.stageModifiedResourceForeground": p.modified,
    "gitDecoration.stageDeletedResourceForeground": p.error,
    "gitDecoration.submoduleResourceForeground": p.info,

    "terminal.background": p.bg, "terminal.foreground": p.fg, "terminalCursor.foreground": p.cursor,
    "terminal.selectionBackground": p.sel + "40",
    **terminal,
  }

  tok = lambda do |name, scope, color, style = nil|
    settings = { foreground: color }
    settings[:fontStyle] = style unless style.nil?
    { name: name, scope: scope, settings: settings }
  end

  tokens = [
    tok.("Comment", %w[comment punctuation.definition.comment], p.comment, "italic"),
    tok.("Doc comment", %w[comment.block.documentation comment.line.documentation], p.doc, "italic"),
    tok.("Keyword", %w[keyword storage.type storage.modifier], p.keyword, p.keyword_style),
    tok.("Operator", %w[keyword.operator], p.fg, ""),
    tok.("String", %w[string punctuation.definition.string], p.string),
    tok.("String escape", %w[constant.character.escape], p.number),
    tok.("Regex / symbol", %w[string.regexp constant.other.symbol], p.string_alt),
    tok.("Number, boolean, constant",
         %w[constant.numeric constant.language constant variable.other.constant variable.other.enummember],
         p.number),
    # Zed captures every Ruby constant (`User`, `rescue Foo`) as a type, so match it.
    tok.("Ruby constant", %w[variable.other.constant.ruby], p.type, p.type_style),
    tok.("Function", %w[entity.name.function support.function], p.function),
    tok.("Type, constructor, tag",
         %w[entity.name.type entity.name.class entity.name.namespace entity.other.inherited-class
            support.type support.class entity.name.function.constructor entity.name.tag],
         p.type, p.type_style),
    tok.("Variable", %w[variable], p.fg),
    tok.("Parameter", %w[variable.parameter], p.param, p.param_style),
    tok.("Special variable (self, this, @ivars)",
         %w[variable.language variable.other.readwrite.instance variable.other.readwrite.class],
         p.special),
    tok.("Property, attribute",
         %w[variable.other.property variable.other.object.property support.variable.property
            support.type.property-name meta.property-name entity.other.attribute-name],
         p.property),
    tok.("YAML key", %w[entity.name.tag.yaml], p.property),
    tok.("Punctuation", %w[punctuation], p.punct),
    tok.("Brackets",
         %w[meta.brace punctuation.bracket punctuation.section punctuation.definition.block
            punctuation.definition.parameters punctuation.definition.arguments],
         p.bracket),
    tok.("Interpolation punctuation",
         %w[punctuation.section.embedded punctuation.definition.template-expression], p.keyword),
    tok.("Label", %w[entity.name.label], p.string),
    tok.("Preprocessor", %w[meta.preprocessor keyword.control.directive punctuation.definition.directive],
         p.preproc),
    tok.("Markup heading", %w[markup.heading entity.name.section punctuation.definition.heading],
         p.keyword, "bold"),
    tok.("Markup emphasis", %w[markup.italic], p.fg, "italic"),
    tok.("Markup strong", %w[markup.bold], p.fg, "bold"),
    tok.("Markup code", %w[markup.inline.raw markup.fenced_code.block], p.string_alt),
    tok.("Markup quote", %w[markup.quote], p.comment, "italic"),
    tok.("Link URI", %w[markup.underline.link], p.string),
    tok.("Link text", %w[string.other.link.title string.other.link.description], p.cyan, "italic"),
    tok.("Diff inserted", %w[markup.inserted], p.success),
    tok.("Diff deleted", %w[markup.deleted], p.error),
    tok.("Diff changed", %w[markup.changed], p.modified),
  ]
  {
    "$schema": "vscode://schemas/color-theme",
    name: "Tropical #{p.name}",
    semanticHighlighting: true,
    semanticTokenColors: {
      parameter: { foreground: p.param, fontStyle: p.param_style || "" },
      selfParameter: p.special,
      enumMember: p.number,
      # VS Code maps readonly to variable.other.constant, which would paint every JS `const` like a number.
      "variable.readonly": p.fg,
      "property.readonly": p.property,
      # ruby-lsp sends `self` as a defaultLibrary variable; Zed colours it as variable.special.
      "variable.defaultLibrary:ruby": p.special,
      "*.deprecated": { strikethrough: true },
    },
    colors: colors,
    tokenColors: tokens,
  }
end

def check_contrast(p)
  warnings = []
  text_roles = %i[fg muted keyword string string_alt number function type
                  property special param preproc punct bracket]
  text_roles.each do |role|
    ratio = contrast(p[role], p.bg)
    warnings << format("%s %.2f", role, ratio) if ratio < 4.5
  end
  p.icons.each.with_index(1) do |c, i|
    warnings << format("bracket%d %.2f", i, contrast(c, p.bg)) if contrast(c, p.bg) < 4.5
  end
  %i[comment doc line_number placeholder cursor].each do |role|
    ratio = contrast(p[role], p.bg)
    warnings << format("%s %.2f", role, ratio) if ratio < 3
  end
  %i[chrome accent pop status].each do |role|
    c = p[role]
    warnings << format("text on %s %.2f", role, contrast(p.on(c), c)) if contrast(p.on(c), c) < 4.5
  end
  warnings << "zed chrome" if contrast(p.fg, p.zed_chrome) < 4.5
  warnings
end

# A .vsix is a zip, which Ruby's standard library can't write, so this builds one by hand: each entry is a
# local header followed by its deflated data, and a central directory listing every entry closes the file.
def write_zip(path, entries)
  zip, directory = "".b, "".b
  entries.each do |name, data, time = Time.now|
    deflater = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
    packed = deflater.deflate(data, Zlib::FINISH)
    deflater.close
    dos_time = time.hour << 11 | time.min << 5 | time.sec / 2
    dos_date = (time.year - 1980) << 9 | time.month << 5 | time.day
    # Version needed, flags, method (8 is deflate), time, date, CRC, both sizes and the name's length.
    fields = [20, 0, 8, dos_time, dos_date, Zlib.crc32(data), packed.bytesize, data.bytesize, name.bytesize]
    directory << [0x02014b50, 20, *fields, 0, 0, 0, 0, 0, zip.bytesize].pack("VvvvvvvVVVvvvvvVV") << name.b
    zip << [0x04034b50, *fields, 0].pack("VvvvvvVVVvv") << name.b << packed
  end
  offset = zip.bytesize
  zip << directory << [0x06054b50, 0, 0, entries.size, entries.size, directory.bytesize, offset, 0].pack("VvvvvVVv")
  path.binwrite(zip)
end

# audit.rb loads this file for PALETTES alone, so stop here unless it's being run.
return unless __FILE__ == $PROGRAM_NAME

palettes = PALETTES.map { |d| derive(d) }

palettes.each do |p|
  warnings = check_contrast(p)
  puts "#{p.name.ljust(12)} contrast: #{warnings.empty? ? "all ok" : warnings.join(", ")}"
end

# Splice the generated Zed themes in after the hand-made one so its formatting survives.
orig = ZED_ORIG.read
close = orig.rindex("]")
generated = palettes.map do |p|
  JSON.pretty_generate(zed_theme(p)).lines(chomp: true).map { |line| "    " + line }.join("\n")
end.join(",\n")
ZED_OUT.write(orig[...close].rstrip + ",\n" + generated + "\n  " + orig[close..])
extension_toml = ZED / "extension.toml"
extension_toml.write(extension_toml.read.gsub(/^version = ".*"$/, %(version = "#{VERSION}")))

manifest = JSON.parse((EXT / "package.json").read)
manifest["version"] = VERSION
original_entry = manifest["contributes"]["themes"][0]
manifest["contributes"]["themes"] = [original_entry] + palettes.map { |p|
  {
    label: "Tropical #{p.name}",
    uiTheme: p.dark? ? "vs-dark" : "vs",
    path: "./themes/tropical-#{p.slug}-color-theme.json",
  }
}
(EXT / "package.json").write(JSON.pretty_generate(manifest) + "\n")

# Drop theme files from earlier generations that no longer have a palette.
keep = [File.basename(original_entry["path"])] + palettes.map { |p| "tropical-#{p.slug}-color-theme.json" }
(EXT / "themes").glob("*.json").each do |stale|
  next if keep.include?(stale.basename.to_s)
  stale.delete
  puts "removed #{stale.basename}"
end
palettes.each do |p|
  (EXT / "themes/tropical-#{p.slug}-color-theme.json").write(JSON.pretty_generate(vscode_theme(p)) + "\n")
end

vsix = SCRATCH / "#{manifest["name"]}-#{VERSION}.vsix"
content_types = [
  '<?xml version="1.0" encoding="utf-8"?>',
  '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
  '<Default Extension=".json" ContentType="application/json"/>',
  '<Default Extension=".png" ContentType="image/png"/>',
  '<Default Extension=".md" ContentType="text/markdown"/>',
  '<Default Extension=".vsixmanifest" ContentType="text/xml"/>',
  '</Types>',
].join
vsix_manifest = [
  '<?xml version="1.0" encoding="utf-8"?>',
  '<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">',
  %(<Metadata><Identity Language="en-US" Id="#{manifest["name"]}" Version="#{VERSION}" ),
  %(Publisher="#{manifest["publisher"]}"/><DisplayName>#{manifest["displayName"]}</DisplayName>),
  %(<Description>#{manifest["description"]}</Description><Categories>Themes</Categories>),
  %(<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="#{manifest["engines"]["vscode"]}"/>),
  '</Properties></Metadata>',
  '<Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>',
  '<Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" ',
  'Path="extension/package.json" Addressable="true"/></Assets></PackageManifest>',
].join
files = [*EXT.glob("**/*.json"), *EXT.glob("**/*.png"), EXT / "README.md"].sort
write_zip(vsix, [
  ["[Content_Types].xml", content_types],
  ["extension.vsixmanifest", vsix_manifest],
  *files.map { |f| ["extension/#{f.relative_path_from(EXT)}", f.binread, f.mtime] },
])
puts "written #{vsix.basename}"
