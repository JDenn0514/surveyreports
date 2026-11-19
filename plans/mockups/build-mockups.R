# build-mockups.R
#
# Builds style variants of the finished export_crosstab() and
# export_topline() output, from plans/spec-export-metadata.md (v0.27.0) and
# its test-spec. It writes with openxlsx2 directly. It does not call the
# package's export functions. The estimates come from surveycore on the
# bundled ns_wave1 dataset (Nationscape wave 1, a non-probability design).
#
# Run from the package root:
#   Rscript plans/mockups/build-mockups.R
#
# One function, build_variant(), writes the three workbooks from a style
# list. The content of each workbook (rows, headings, notes, sample-size
# rows, About sheet, withheld lines, interval strings) is the same in every
# variant. Only the styling changes.
#
# Files written to plans/mockups/variants/, for each variant X in A, B, C,
# D, B1, B2 and B3:
#   X-crosstab.xlsx          layout = "per_question", variance = "ci",
#                            variance_display = "cell", withheld_note =
#                            "once", every other argument at its default
#   X-crosstab-stacked.xlsx  layout = "stacked", variance = NULL,
#                            withheld_note = "every", every other
#                            argument at its default
#   X-topline.xlsx           export_topline() defaults: show_n = TRUE,
#                            show_eff_n = FALSE, variance = NULL
#   README.md                one style table per variant, written from the
#                            style lists in section 6
#
# The content choices where the spec is silent are entries in
# plans/mockups/spec-gaps.md. Each variant settles gaps 1 to 7 (styling) in
# its own way. The README records how.

stopifnot(file.exists("DESCRIPTION"))
suppressMessages(devtools::load_all(".", quiet = TRUE))

out_dir <- file.path("plans", "mockups", "variants")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Non-ASCII characters, built from their code points.
TIMES <- intToUtf8(0xD7L) # multiplication sign, spec 3.8
EN_DASH <- intToUtf8(0x2013L) # interval separator, spec 3.12
EM_DASH <- intToUtf8(0x2014L) # in the ESS glossary text, spec 3.15

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- 1. Design and metadata ------------------------------------------------

single_var <- "pres_approval"
sata_vars <- paste0(
  "news_sources_",
  c("facebook", "cnn", "msnbc", "fox", "network", "npr")
)
bat_vars <- paste0(
  "group_favorability_",
  c("whites", "blacks", "latinos", "asians")
)
banner <- c("gender", "pid3")
inter_vars <- c("gender", "pid3")
min_eff_n <- 100
decimals <- 1L
conf_level <- 0.95
universe_text <- "Asked of all respondents."

d <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)

# Dataset metadata, so the cover sheet has a survey block. The values come
# from the ns_wave1 documentation in R/data.R.
d <- surveycore::set_survey_name(d, "Democracy Fund + UCLA Nationscape")
d <- surveycore::set_data_name(d, "ns_wave1")
d <- surveycore::set_vendor(d, "Lucid")
d <- surveycore::set_field_dates(d, "2019-07-18", "2019-07-24")
d <- surveycore::set_field_period(d, "Wave 1")

# A universe on the single question and on every battery member, so the
# base-note row shows (spec 3.6). The SATA block has none, so its block shows
# the case with no base-note row.
d <- surveycore::set_universe(
  d,
  variable = single_var,
  universe = universe_text
)
for (v in bat_vars) {
  d <- surveycore::set_universe(d, variable = v, universe = universe_text)
}
# news_sources_* is coded Yes = 1 / No = 2 and classifies as a battery
# unless it is marked SATA.
d <- surveycore::set_sata(d, variable = sata_vars)

all_vars <- c(single_var, sata_vars, bat_vars)
classify <- surveycore::classify_question_type(d, tidyselect::all_of(all_vars))
stopifnot(
  all(classify$type[classify$variable %in% sata_vars] == "sata"),
  all(classify$type[classify$variable %in% bat_vars] == "battery"),
  classify$type[classify$variable == single_var] == "single"
)

meta_of <- function(v) attr(ns_wave1[[v]], "label")
preface_of <- function(v) attr(ns_wave1[[v]], "question_preface")

# A banner column as a factor of its value labels, in code order.
labelled_factor <- function(design, col) {
  x <- design@data[[col]]
  labs <- surveycore::extract_val_labels(design, tidyselect::all_of(col))[[
    col
  ]]
  factor(names(labs)[match(as.vector(x), unname(labs))], levels = names(labs))
}

d_int <- d
d_int@data[["..interaction.."]] <- interaction(
  labelled_factor(d, inter_vars[[1L]]),
  labelled_factor(d, inter_vars[[2L]]),
  sep = paste0(" ", TIMES, " "),
  drop = TRUE
)

# ---- 2. Estimates ------------------------------------------------------------

# get_freqs() rows for one variable, normalised to level / value / pct / n /
# ci_low / ci_high. `level` is NA for the full sample.
freq_rows <- function(design, var, group = NULL) {
  res <- suppressWarnings(
    if (is.null(group)) {
      surveycore::get_freqs(
        design,
        !!rlang::sym(var),
        variance = "ci",
        conf_level = conf_level
      )
    } else {
      surveycore::get_freqs(
        design,
        !!rlang::sym(var),
        group = !!rlang::sym(group),
        variance = "ci",
        conf_level = conf_level
      )
    }
  )
  data.frame(
    level = if (is.null(group)) NA_character_ else as.character(res[[group]]),
    value = as.character(res[[var]]),
    pct = res$pct,
    n = res$n,
    ci_low = res$ci_low,
    ci_high = res$ci_high,
    stringsAsFactors = FALSE
  )
}

eff_rows <- function(design, group = NULL) {
  res <- suppressWarnings(
    if (is.null(group)) {
      surveycore::get_effective_n(design)
    } else {
      surveycore::get_effective_n(design, group = !!rlang::sym(group))
    }
  )
  data.frame(
    level = if (is.null(group)) NA_character_ else as.character(res[[group]]),
    n = as.integer(res$n),
    n_eff = as.numeric(res$n_eff),
    stringsAsFactors = FALSE
  )
}

freqs <- lapply(all_vars, function(v) {
  list(
    total = freq_rows(d, v),
    gender = freq_rows(d, v, "gender"),
    pid3 = freq_rows(d, v, "pid3"),
    inter = freq_rows(d_int, v, "..interaction..")
  )
})
names(freqs) <- all_vars

eff <- list(
  total = eff_rows(d),
  gender = eff_rows(d, "gender"),
  pid3 = eff_rows(d, "pid3"),
  inter = eff_rows(d_int, "..interaction..")
)

# Withholding (spec 3.5): the floor test is n_eff < min_eff_n, on every banner
# level and every crossed cell. banner_var carries the column name, or the
# names joined by the multiplication sign for an interaction.
banner_var_name <- c(
  gender = "gender",
  pid3 = "pid3",
  inter = paste(inter_vars, collapse = paste0(" ", TIMES, " "))
)
withheld <- do.call(
  rbind,
  lapply(c("gender", "pid3", "inter"), function(k) {
    e <- eff[[k]]
    idx <- which(e$n_eff < min_eff_n)
    data.frame(
      level = e$level[idx],
      banner_var = rep(banner_var_name[[k]], length(idx)),
      n_eff = e$n_eff[idx],
      stringsAsFactors = FALSE
    )
  })
)
stopifnot(nrow(withheld) >= 1L)

# One wording for the cover sheet, the block footer and the console warning
# (spec 3.14). The exact sentence is not in the spec - spec-gaps.md.
withheld_lines <- paste0(
  withheld$level,
  " (",
  withheld$banner_var,
  "): effective sample size ",
  formatC(withheld$n_eff, format = "f", digits = 1L)
)

# The column groups, withheld levels already absent (spec 3.5, 3.8, 3.9).
total_label <- "Full Sample" # NULL default, design has no domain column
kept <- function(k) setdiff(eff[[k]]$level, withheld$level)
col_groups <- list(
  list(key = "total", spanner = "", levels = total_label),
  list(key = "gender", spanner = meta_of("gender"), levels = kept("gender")),
  list(key = "pid3", spanner = meta_of("pid3"), levels = kept("pid3")),
  list(
    key = "inter",
    spanner = paste(
      vapply(inter_vars, meta_of, character(1L)),
      collapse = paste0(" ", TIMES, " ")
    ),
    levels = kept("inter")
  )
)
col_groups <- Filter(function(g) length(g$levels) > 0L, col_groups)

# The counts frame of spec 3.4: one row per rendered data column, in order.
counts <- do.call(
  rbind,
  lapply(col_groups, function(g) {
    e <- eff[[g$key]]
    if (g$key == "total") {
      return(data.frame(level = g$levels, n = e$n, n_eff = e$n_eff))
    }
    idx <- match(g$levels, e$level)
    data.frame(level = g$levels, n = e$n[idx], n_eff = e$n_eff[idx])
  })
)

# ---- 3. Cell formatters (spec 3.3, 3.12) ------------------------------------

fmt_pct <- function(p, decimals, has_rows) {
  if (!has_rows || is.na(p)) {
    return("-")
  }
  pp <- p * 100
  if (pp == 0) {
    return("0%")
  }
  half <- 0.5 * 10^-decimals
  if (pp > 0 && pp < half) {
    return(paste0(
      "<",
      formatC(10^-decimals, format = "f", digits = decimals),
      "%"
    ))
  }
  if (pp > 100 - half && pp < 100) {
    return(paste0(
      ">",
      formatC(100 - 10^-decimals, format = "f", digits = decimals),
      "%"
    ))
  }
  paste0(round(pp, decimals), "%")
}

fmt_variance <- function(row, variance, decimals, has_rows) {
  if (is.null(variance) || !has_rows) {
    return("")
  }
  if (identical(variance, "se")) {
    return(paste0("(", fmt_pct(row$se[[1L]], decimals, TRUE), ")"))
  }
  paste0(
    "(",
    fmt_pct(row$ci_low[[1L]], decimals, TRUE),
    " ",
    EN_DASH,
    " ",
    fmt_pct(row$ci_high[[1L]], decimals, TRUE),
    ")"
  )
}

# The get_freqs() rows for one cell: one variable, one column, one value.
cell_rows <- function(var, key, level, value) {
  f <- freqs[[var]][[key]]
  if (key == "total") {
    return(f[f$value == value, , drop = FALSE])
  }
  f[f$level == level & f$value == value, , drop = FALSE]
}

# ---- 4. Blocks -----------------------------------------------------------

# A block: its title, base note, label headings, and data rows. Each data
# row carries its label cells, its variable and the response value whose
# percentage it shows. A SATA row shows the "Yes" value of its item.
response_values <- function(var) unique(freqs[[var]]$total$value)

block_single <- list(
  kind = "single",
  name = single_var,
  title = meta_of(single_var),
  base_note = universe_text,
  label_heads = "Response",
  rows = lapply(response_values(single_var), function(val) {
    list(labels = val, var = single_var, value = val)
  })
)

block_sata <- list(
  kind = "sata",
  name = sata_vars[[1L]],
  title = preface_of(sata_vars[[1L]]),
  base_note = NULL,
  label_heads = "Item",
  rows = lapply(sata_vars, function(v) {
    list(labels = meta_of(v), var = v, value = "Yes")
  })
)

bat_rows <- list()
for (v in bat_vars) {
  vals <- response_values(v)
  for (j in seq_along(vals)) {
    item <- if (j == 1L) meta_of(v) else ""
    bat_rows[[length(bat_rows) + 1L]] <- list(
      labels = c(item, vals[[j]]),
      var = v,
      value = vals[[j]]
    )
  }
}
block_battery <- list(
  kind = "battery",
  name = bat_vars[[1L]],
  title = preface_of(bat_vars[[1L]]),
  base_note = universe_text,
  label_heads = c("Item", "Response"),
  rows = bat_rows
)

blocks <- list(block_single, block_sata, block_battery)

levels_flat <- unlist(lapply(col_groups, function(g) g$levels))
keys_flat <- unlist(lapply(col_groups, function(g) {
  rep(g$key, length(g$levels))
}))
n_cols_of <- function(blk) length(blk$label_heads) + length(levels_flat)

# ---- 5. Style engine -----------------------------------------------------
#
# A writer puts the content in the sheet and records the role of each row in
# a layout list. style_table() turns a layout and a style list into marks in
# a per-sheet registry: one record per cell, with its font, fill, borders,
# alignment, wrap and number format. finish_sheet() turns each distinct
# record into one cell style and assigns it, then sets the row heights.

argb <- function(hex) openxlsx2::wb_color(hex = paste0("FF", hex))

# Line height in points for a font size.
line_pt <- function(size) size * 1.35

# The number of lines a text takes in a cell `width` characters wide. A
# greedy word wrap, with a narrower line for bold text.
text_lines <- function(text, width, size, bold = FALSE) {
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(1L)
  }
  cpl <- max(1, floor((width - 1) * (11 / size) * if (bold) 0.9 else 1))
  total <- 0L
  for (para in strsplit(text, "\n", fixed = TRUE)[[1L]]) {
    n <- 1L
    cur <- 0L
    for (w in strsplit(para, " ", fixed = TRUE)[[1L]]) {
      len <- nchar(w)
      if (cur == 0L) {
        cur <- len
      } else if (cur + 1L + len <= cpl) {
        cur <- cur + 1L + len
      } else {
        n <- n + 1L
        cur <- len
      }
      while (cur > cpl) {
        n <- n + 1L
        cur <- cur - cpl
      }
    }
    total <- total + n
  }
  total
}

# Row height in points that fits `text` in the element `spec`.
fit_spec <- function(text, width, spec, st, min_lines = 1L) {
  size <- spec$size %||% st$size
  n <- max(min_lines, text_lines(text, width, size, isTRUE(spec$bold)))
  ceiling(n * line_pt(size) + st$pad)
}

reg_new <- function() {
  e <- new.env(parent = emptyenv())
  e$cells <- list()
  e$heights <- numeric(0)
  e
}

# Set attributes on every cell of rows x cols. A NULL attribute changes
# nothing, so a style field left out of a variant leaves the cell alone.
reg_mark <- function(reg, rows, cols, ...) {
  attrs <- Filter(Negate(is.null), list(...))
  rows <- rows[!is.na(rows)]
  if (length(attrs) == 0L || length(rows) == 0L || length(cols) == 0L) {
    return(invisible(reg))
  }
  for (r in rows) {
    for (cc in cols) {
      key <- paste0(r, ":", cc)
      cur <- reg$cells[[key]] %||% list(r = r, c = cc)
      cur[names(attrs)] <- attrs
      reg$cells[[key]] <- cur
    }
  }
  invisible(reg)
}

SPEC_FIELDS <- c(
  "size",
  "bold",
  "italic",
  "color",
  "fill",
  "h",
  "v",
  "wrap",
  "indent",
  "numfmt"
)

# Mark an element spec on rows x cols, with optional overrides.
reg_spec <- function(reg, rows, cols, spec = list(), ...) {
  over <- Filter(Negate(is.null), list(...))
  attrs <- spec[intersect(names(spec), SPEC_FIELDS)]
  attrs[names(over)] <- over
  do.call(reg_mark, c(list(reg, rows, cols), attrs))
}

reg_border <- function(reg, rows, cols, side, value) {
  if (is.null(value)) {
    return(invisible(reg))
  }
  args <- list(reg, rows, cols)
  args[[side]] <- value
  do.call(reg_mark, args)
}

reg_box <- function(reg, rows, cols, value) {
  if (is.null(value)) {
    return(invisible(reg))
  }
  reg_border(reg, min(rows), cols, "bt", value)
  reg_border(reg, max(rows), cols, "bb", value)
  reg_border(reg, rows, min(cols), "bl", value)
  reg_border(reg, rows, max(cols), "br", value)
}

reg_height <- function(reg, row, h) {
  key <- as.character(row)
  reg$heights[[key]] <- max(reg$heights[key], h, na.rm = TRUE)
  invisible(reg)
}

# A per-workbook cache of cell styles already registered.
new_ctx <- function() {
  e <- new.env(parent = emptyenv())
  e$xf <- list()
  e$n <- 0L
  e$numfmt <- list("#,##0" = "3", "0" = "1")
  e$next_numfmt <- 164L
  e
}

xf_id <- function(wb, s, sig, ctx) {
  if (!is.null(ctx$xf[[sig]])) {
    return(ctx$xf[[sig]])
  }
  ctx$n <- ctx$n + 1L
  k <- ctx$n
  sm <- wb$styles_mgr
  sm$add(
    openxlsx2::create_font(
      name = s$font,
      sz = as.character(s$size),
      b = if (isTRUE(s$bold)) "1" else "",
      i = if (isTRUE(s$italic)) "1" else "",
      color = argb(s$color),
      scheme = "",
      family = ""
    ),
    paste0("font", k)
  )
  font_id <- sm$get_font_id(paste0("font", k))
  fill_id <- ""
  if (nzchar(s$fill)) {
    sm$add(
      openxlsx2::create_fill(pattern_type = "solid", fg_color = argb(s$fill)),
      paste0("fill", k)
    )
    fill_id <- sm$get_fill_id(paste0("fill", k))
  }
  border_id <- ""
  sides <- c(top = "bt", bottom = "bb", left = "bl", right = "br")
  b_args <- list()
  for (side in names(sides)) {
    val <- s[[sides[[side]]]]
    if (nzchar(val)) {
      parts <- strsplit(val, ":", fixed = TRUE)[[1L]]
      b_args[[side]] <- parts[[1L]]
      b_args[[paste0(side, "_color")]] <- argb(parts[[2L]])
    }
  }
  if (length(b_args) > 0L) {
    sm$add(do.call(openxlsx2::create_border, b_args), paste0("border", k))
    border_id <- sm$get_border_id(paste0("border", k))
  }
  numfmt_id <- ""
  if (nzchar(s$numfmt)) {
    if (is.null(ctx$numfmt[[s$numfmt]])) {
      id <- ctx$next_numfmt
      ctx$next_numfmt <- id + 1L
      sm$add(
        openxlsx2::create_numfmt(numFmtId = id, formatCode = s$numfmt),
        paste0("numfmt", k)
      )
      ctx$numfmt[[s$numfmt]] <- as.character(id)
    }
    numfmt_id <- ctx$numfmt[[s$numfmt]]
  }
  sm$add(
    openxlsx2::create_cell_style(
      border_id = border_id,
      fill_id = fill_id,
      font_id = font_id,
      num_fmt_id = numfmt_id,
      horizontal = s$h,
      vertical = s$v,
      wrap_text = if (isTRUE(s$wrap)) "1" else "",
      indent = if (s$indent > 0) as.character(s$indent) else ""
    ),
    paste0("xf", k)
  )
  ctx$xf[[sig]] <- sm$get_xf_id(paste0("xf", k))
  ctx$xf[[sig]]
}

# Apply the registry of one sheet and set its row heights. Each sheet is
# added with its gridlines hidden; wb_set_grid_lines() would drop the
# freeze pane.
finish_sheet <- function(wb, sheet, reg, st, ctx) {
  defaults <- list(
    font = st$font,
    size = st$size,
    bold = FALSE,
    italic = FALSE,
    color = st$text,
    fill = "",
    h = "",
    v = "",
    wrap = FALSE,
    indent = 0,
    numfmt = "",
    bt = "",
    bb = "",
    bl = "",
    br = ""
  )
  cells <- reg$cells
  sigs <- character(length(cells))
  refs <- character(length(cells))
  specs <- list()
  for (i in seq_along(cells)) {
    cell <- cells[[i]]
    full <- defaults
    keys <- intersect(names(cell), names(defaults))
    full[keys] <- cell[keys]
    sigs[[i]] <- paste(unlist(full), collapse = "|")
    refs[[i]] <- paste0(openxlsx2::int2col(cell$c), cell$r)
    specs[[sigs[[i]]]] <- full
  }
  for (sig in unique(sigs)) {
    id <- xf_id(wb, specs[[sig]], sig, ctx)
    wb <- openxlsx2::wb_set_cell_style(
      wb,
      sheet = sheet,
      dims = paste(refs[sigs == sig], collapse = ","),
      style = id
    )
  }
  if (length(reg$heights) > 0L) {
    wb <- openxlsx2::wb_set_row_heights(
      wb,
      sheet = sheet,
      rows = as.integer(names(reg$heights)),
      heights = unname(reg$heights)
    )
  }
  wb
}

new_workbook <- function(st) {
  wb <- openxlsx2::wb_workbook()
  wb <- openxlsx2::wb_set_base_font(
    wb,
    font_size = st$size,
    font_name = st$font,
    font_color = argb(st$text)
  )
  # A font tied to the theme scheme shows the theme font, not its name.
  wb$styles_mgr$styles$fonts[[1L]] <- sub(
    "<scheme val=\"minor\"/>",
    "",
    wb$styles_mgr$styles$fonts[[1L]],
    fixed = TRUE
  )
  wb
}

new_layout <- function(n_cols, n_labels) {
  list(
    n_cols = n_cols,
    n_labels = n_labels,
    block_top = NA_integer_,
    title_rows = integer(),
    subtitle_rows = integer(),
    note_rows = integer(),
    withheld_rows = integer(),
    spanner_row = NA_integer_,
    heading_row = NA_integer_,
    sample_rows = integer(),
    sample_fmt = character(),
    body_rows = integer(),
    stripe = integer(),
    var_rows = integer(),
    items = list(),
    item_label_rows = integer(),
    total_row = NA_integer_,
    groups = list(),
    numfmt = list(),
    table_top = NA_integer_,
    table_bottom = NA_integer_,
    tint = TRUE,
    about = FALSE,
    label_bold_rows = integer()
  )
}

# The tint of the i-th labelled column group, or NULL.
group_tint <- function(st, i) {
  if (length(st$tints) == 0L) {
    return(NULL)
  }
  st$tints[[(i - 1L) %% length(st$tints) + 1L]]
}

# Mark every cell of one block from its layout and the style list.
style_table <- function(reg, lay, st) {
  allc <- seq_len(lay$n_cols)
  labc <- seq_len(lay$n_labels)
  datc <- setdiff(allc, labc)
  ru <- st$rules

  # Text rows: titles, subtitles, notes, withheld lines.
  reg_spec(reg, lay$title_rows, allc, st$title)
  reg_spec(reg, lay$subtitle_rows, allc, st$subtitle)
  reg_spec(reg, lay$note_rows, allc, st$note)
  reg_spec(reg, lay$withheld_rows, allc, st$withheld)
  if (is.na(lay$heading_row)) {
    return(invisible(reg))
  }

  text_groups <- Filter(function(g) nzchar(g$text), lay$groups)
  total_cols <- unlist(lapply(
    Filter(function(g) isTRUE(g$total), lay$groups),
    function(g) g$cols
  ))

  # Spanner row.
  sr <- lay$spanner_row
  if (!is.na(sr)) {
    reg_spec(reg, sr, allc, st$spanner_empty)
    for (i in seq_along(text_groups)) {
      g <- text_groups[[i]]
      reg_spec(reg, sr, g$cols, st$spanner, fill = group_tint(st, i))
    }
  }

  # Heading row.
  hr <- lay$heading_row
  head_h_lab <- if (lay$about) "left" else st$heading$label_h
  head_h_dat <- if (lay$about) "left" else st$heading$data_h
  reg_spec(reg, hr, labc, st$heading, h = head_h_lab)
  reg_spec(reg, hr, datc, st$heading, h = head_h_dat)
  if (isTRUE(st$heading$tint) && lay$tint) {
    for (i in seq_along(text_groups)) {
      reg_mark(reg, hr, text_groups[[i]]$cols, fill = group_tint(st, i))
    }
  }
  reg_mark(reg, hr, total_cols, fill = st$total_col$head_fill)

  # Sample-size rows.
  for (i in seq_along(lay$sample_rows)) {
    r <- lay$sample_rows[[i]]
    reg_spec(reg, r, labc, st$sample, h = "left", v = "center")
    reg_mark(reg, r, labc, fill = st$label$fill)
    reg_spec(
      reg,
      r,
      datc,
      st$sample,
      h = st$data$h,
      v = "center",
      numfmt = lay$sample_fmt[[i]]
    )
  }
  reg_mark(reg, lay$sample_rows, total_cols, fill = st$total_col$fill)

  # Body rows: label cells, data cells, zebra stripe, Total column.
  body_v <- if (lay$about) "top" else NULL
  body_h <- if (lay$about) "left" else NULL
  for (i in seq_along(lay$body_rows)) {
    r <- lay$body_rows[[i]]
    reg_spec(reg, r, labc, st$label, v = body_v)
    reg_spec(reg, r, datc, st$data, h = body_h, v = body_v)
    for (cc in names(lay$numfmt)) {
      reg_mark(reg, r, as.integer(cc), numfmt = lay$numfmt[[cc]])
    }
    if (!is.null(st$zebra) && lay$stripe[[i]] %% 2L == 0L) {
      reg_mark(reg, r, allc, fill = st$zebra)
    }
  }
  reg_spec(
    reg,
    lay$var_rows,
    datc,
    st$data,
    size = st$interval$size,
    color = st$interval$color
  )
  reg_spec(reg, lay$item_label_rows, 1L, st$item)
  reg_mark(reg, lay$label_bold_rows, 1L, bold = TRUE)
  reg_mark(reg, lay$body_rows, total_cols, fill = st$total_col$fill)

  # Topline Total row.
  tr <- lay$total_row
  if (!is.na(tr)) {
    reg_spec(reg, tr, labc, st$label)
    reg_spec(reg, tr, datc, st$data)
    for (cc in names(lay$numfmt)) {
      reg_mark(reg, tr, as.integer(cc), numfmt = lay$numfmt[[cc]])
    }
    reg_spec(reg, tr, allc, st$total_row)
  }

  # Rules, from the widest to the most specific.
  top <- lay$table_top
  bot <- lay$table_bottom
  trows <- top:bot
  if (!is.null(ru$grid)) {
    for (side in c("bt", "bb", "bl", "br")) {
      reg_border(reg, trows, allc, side, ru$grid)
    }
  }
  if (length(lay$body_rows) > 1L) {
    reg_border(reg, head(lay$body_rows, -1L), allc, "bb", ru$row)
  }
  if (length(lay$sample_rows) > 1L) {
    reg_border(reg, head(lay$sample_rows, -1L), allc, "bb", ru$row)
  }
  if (length(lay$items) > 1L) {
    for (it in head(lay$items, -1L)) {
      reg_border(reg, max(it), allc, "bb", ru$item)
    }
  }
  reg_border(reg, top, allc, "bt", ru$top)
  reg_border(reg, hr, allc, "bb", ru$heading_under)
  if (length(lay$sample_rows) > 0L && max(lay$sample_rows) < bot) {
    reg_border(reg, max(lay$sample_rows), allc, "bb", ru$sample_under)
  }
  if (!is.na(tr)) {
    reg_border(reg, tr, allc, "bt", ru$total_above)
  }
  reg_border(reg, bot, allc, "bb", ru$bottom)
  if (!is.null(ru$group_v)) {
    for (g in lay$groups) {
      reg_border(reg, trows, min(g$cols), "bl", ru$group_v)
    }
  }
  if (!is.na(sr)) {
    for (g in text_groups) {
      reg_border(reg, sr, g$cols, "bb", ru$spanner_under)
      reg_box(reg, sr, g$cols, ru$spanner_box)
      reg_border(reg, sr, g$cols, "bb", ru$band_sep)
    }
  }
  if (!is.null(ru$band_sep)) {
    for (g in lay$groups) {
      reg_border(reg, c(sr, hr), min(g$cols), "bl", ru$band_sep)
    }
  }
  if (!is.null(ru$box)) {
    from <- if (identical(ru$box_from, "block")) lay$block_top else top
    reg_box(reg, from:bot, allc, ru$box)
  }
  # Column-group rules (B1 to B3). They come after the block box, so they
  # win where the two meet. They are not drawn on the About sheet.
  if (!lay$about) {
    for (g in lay$groups) {
      reg_border(reg, trows, min(g$cols), "bl", ru$group_edge)
      if (!isTRUE(g$total)) {
        reg_box(reg, trows, g$cols, ru$group_box)
      }
    }
    for (g in Filter(function(g) isTRUE(g$total), lay$groups)) {
      reg_box(reg, trows, g$cols, ru$total_box)
    }
  }
  invisible(reg)
}

# ---- 6. Variant style lists -----------------------------------------------
#
# Every element spec takes the fields size, bold, italic, color (text, hex
# without #), fill (hex), h and v (alignment), wrap and indent. A field left
# out leaves the cell at the workbook default: the base font, black text, no
# fill, no border, general alignment. A rule value is "style:hex", where
# style is an Excel border style (hair, thin, medium).

widths_spec <- list(
  label = 44,
  battery = 20,
  data = 12,
  data_ci = 15 + 2 * decimals,
  topline = 10
)

style_A <- list(
  id = "A",
  name = "Clean rules",
  summary = paste(
    "No fills. Black text, bold headings, and horizontal rules only:",
    "a medium rule above the table, under the heading row and under the",
    "last row, hairlines between rows. Rows carry 6 pt of extra height."
  ),
  good_for = paste(
    "Reports that are printed or pasted into a document, where the table",
    "should read like a journal table."
  ),
  font = "Aptos",
  size = 11,
  text = "000000",
  pad = 6,
  title = list(
    size = 12,
    bold = TRUE,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  subtitle = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  note = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  withheld = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  spanner = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  spanner_empty = list(),
  tints = NULL,
  heading = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    v = "bottom",
    wrap = TRUE,
    label_h = "left",
    data_h = "right"
  ),
  label = list(
    size = 11,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  item = list(bold = TRUE, v = "top"),
  data = list(
    size = 11,
    color = "000000",
    h = "right",
    v = "center",
    wrap = TRUE
  ),
  interval = list(size = 9, color = "595959"),
  total_col = list(),
  total_row = list(bold = TRUE),
  sample = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    fmt_n = "#,##0",
    fmt_eff = "#,##0.0"
  ),
  zebra = NULL,
  battery_label = "first",
  rules = list(
    top = "medium:000000",
    spanner_under = "thin:000000",
    heading_under = "medium:000000",
    row = "hair:A6A6A6",
    item = "thin:7F7F7F",
    sample_under = "thin:7F7F7F",
    total_above = "thin:000000",
    bottom = "medium:000000"
  ),
  widths = widths_spec,
  about = list(a = 44, b = 90)
)

NAVY <- "1F3864"
style_B <- list(
  id = "B",
  name = "Banded header",
  summary = paste(
    "A solid navy band with white bold text across the spanner and heading",
    "rows, light blue zebra stripes on the response rows, and a thin grey",
    "box around each block from its title to its last row."
  ),
  good_for = paste(
    "Workbooks read on screen, where a reader scrolls many blocks and needs",
    "each header and each row to stand out."
  ),
  font = "Calibri",
  size = 11,
  text = "000000",
  pad = 4,
  title = list(
    size = 12,
    bold = TRUE,
    color = NAVY,
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  subtitle = list(
    size = 11,
    bold = TRUE,
    color = NAVY,
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  note = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  withheld = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  spanner = list(
    size = 11,
    bold = TRUE,
    color = "FFFFFF",
    fill = NAVY,
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  spanner_empty = list(fill = NAVY, color = "FFFFFF"),
  tints = NULL,
  heading = list(
    size = 11,
    bold = TRUE,
    color = "FFFFFF",
    fill = NAVY,
    v = "center",
    wrap = TRUE,
    label_h = "left",
    data_h = "center"
  ),
  label = list(
    size = 11,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  item = list(bold = TRUE, v = "top"),
  data = list(
    size = 11,
    color = "000000",
    h = "right",
    v = "center",
    wrap = TRUE
  ),
  interval = list(size = 9, color = "595959"),
  total_col = list(),
  total_row = list(bold = TRUE),
  sample = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    fmt_n = "#,##0",
    fmt_eff = "#,##0.0"
  ),
  zebra = "E8EEF7",
  battery_label = "first",
  rules = list(
    band_sep = "thin:FFFFFF",
    sample_under = paste0("thin:", NAVY),
    total_above = paste0("thin:", NAVY),
    box = "thin:7F7F7F",
    box_from = "block"
  ),
  widths = widths_spec,
  about = list(a = 44, b = 90)
)

style_C <- list(
  id = "C",
  name = "Full grid",
  summary = paste(
    "A thin grey border on every cell of the table, a dark outline around",
    "the table and around each spanner, grey fills on the spanner, heading",
    "and label column, and a light blue Total column. Battery item labels",
    "are merged down their rows."
  ),
  good_for = paste(
    "Analysts who copy cells out of the workbook or check numbers cell by",
    "cell, where the grid keeps the eye on the right row and column."
  ),
  font = "Calibri",
  size = 11,
  text = "000000",
  pad = 2,
  title = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  subtitle = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  note = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  withheld = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  spanner = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    fill = "D9D9D9",
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  spanner_empty = list(fill = "D9D9D9"),
  tints = NULL,
  heading = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    fill = "D9D9D9",
    v = "center",
    wrap = TRUE,
    label_h = "left",
    data_h = "center"
  ),
  label = list(
    size = 11,
    color = "000000",
    fill = "F2F2F2",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  item = list(bold = TRUE, v = "center"),
  data = list(
    size = 11,
    color = "000000",
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  interval = list(size = 10, color = "595959"),
  total_col = list(fill = "DDEBF7", head_fill = "BDD7EE"),
  total_row = list(bold = TRUE, fill = "F2F2F2"),
  sample = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    fmt_n = "0",
    fmt_eff = "0.0"
  ),
  zebra = NULL,
  battery_label = "merge",
  rules = list(
    grid = "thin:A6A6A6",
    heading_under = "thin:404040",
    spanner_box = "thin:404040",
    box = "thin:404040",
    box_from = "table"
  ),
  widths = widths_spec,
  about = list(a = 44, b = 90)
)

ACCENT <- "1F4E79"
style_D <- list(
  id = "D",
  name = "Report accent",
  summary = paste(
    "A dark blue title bar with white text across each block, spanners and",
    "headings shaded in alternating light blue and light orange per banner",
    "group, a blue vertical rule at the start of each column group, and the",
    "sample-size rows in a muted grey fill."
  ),
  good_for = paste(
    "Client-facing deliverables, where the banner groups must read apart at",
    "a glance and the workbook carries a house look."
  ),
  font = "Aptos",
  size = 11,
  text = "000000",
  pad = 4,
  title = list(
    size = 12,
    bold = TRUE,
    color = "FFFFFF",
    fill = ACCENT,
    h = "left",
    v = "center",
    wrap = TRUE,
    indent = 1
  ),
  subtitle = list(
    size = 11,
    bold = TRUE,
    color = ACCENT,
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  note = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  withheld = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  spanner = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  spanner_empty = list(),
  tints = c("DEEBF7", "FCE4D6"),
  heading = list(
    size = 11,
    bold = TRUE,
    color = "000000",
    fill = "F2F2F2",
    v = "center",
    wrap = TRUE,
    label_h = "left",
    data_h = "center",
    tint = TRUE
  ),
  label = list(
    size = 11,
    color = "000000",
    h = "left",
    v = "center",
    wrap = TRUE
  ),
  item = list(bold = TRUE, color = ACCENT, v = "top"),
  data = list(
    size = 11,
    color = "000000",
    h = "center",
    v = "center",
    wrap = TRUE
  ),
  interval = list(size = 9, color = "595959"),
  total_col = list(),
  total_row = list(bold = TRUE, fill = "EDEDED"),
  sample = list(
    size = 10,
    italic = TRUE,
    color = "404040",
    fill = "EDEDED",
    fmt_n = "#,##0",
    fmt_eff = "#,##0.0"
  ),
  zebra = NULL,
  battery_label = "first",
  rules = list(
    heading_under = paste0("medium:", ACCENT),
    row = "thin:D9D9D9",
    item = "thin:7F7F7F",
    total_above = paste0("thin:", ACCENT),
    bottom = paste0("medium:", ACCENT),
    group_v = paste0("thin:", ACCENT)
  ),
  widths = widths_spec,
  about = list(a = 44, b = 90)
)

# B1 to B3 revise B. The four shared changes: the navy band moves to the
# title row; the zebra stripes stay; the interval sits on its own line in
# the estimate cell; the panes freeze the heading rows and the label columns.
style_B_rev <- style_B
style_B_rev$title <- list(
  size = 12,
  bold = TRUE,
  color = "FFFFFF",
  fill = NAVY,
  h = "left",
  v = "center",
  wrap = TRUE,
  indent = 1
)
style_B_rev$spanner <- list(
  size = 11,
  bold = TRUE,
  color = NAVY,
  fill = "C8D4E6",
  h = "center",
  v = "center",
  wrap = TRUE
)
style_B_rev$spanner_empty <- list()
style_B_rev$heading <- list(
  size = 11,
  bold = TRUE,
  color = NAVY,
  fill = "DDE5F0",
  v = "center",
  wrap = TRUE,
  label_h = "left",
  data_h = "center"
)
style_B_rev$zebra <- "EDF1F8"
style_B_rev$freeze_labels <- TRUE
style_B_rev$rules <- list(
  heading_under = paste0("medium:", NAVY),
  sample_under = paste0("thin:", NAVY),
  total_above = paste0("thin:", NAVY),
  box = "thin:7F7F7F",
  box_from = "block"
)

style_B1 <- style_B_rev
style_B1$id <- "B1"
style_B1$name <- "Banded title, group rules"
style_B1$summary <- paste(
  "B with the navy band on the title row only, a blue-grey spanner and",
  "heading with a navy rule under the heading, and a medium navy vertical",
  "rule at the left edge of each column group."
)
style_B1$good_for <- paste(
  "Wide banners, where a plain rule is enough to tell one banner variable",
  "from the next."
)
style_B1$rules$group_edge <- paste0("medium:", NAVY)

style_B2 <- style_B1
style_B2$id <- "B2"
style_B2$name <- "Banded title, tinted groups"
style_B2$summary <- paste(
  "B1, plus spanner cells that alternate light blue and light grey by",
  "column group, so each group reads as one unit."
)
style_B2$good_for <- paste(
  "Banners with many groups of similar size, where the eye needs colour",
  "as well as a rule to find the group edges."
)
style_B2$tints <- c("D0E2F5", "E3E3E3")

style_B3 <- style_B_rev
style_B3$id <- "B3"
style_B3$name <- "Banded title, boxed groups"
style_B3$summary <- paste(
  "B with the navy band on the title row only, a thin navy box around",
  "each column group from the spanner row to the last row, and a medium",
  "navy box around the Total column."
)
style_B3$good_for <- paste(
  "Readers who compare a subgroup with the full sample, since the Total",
  "column stands apart and each group is closed on both sides."
)
style_B3$rules$group_box <- paste0("thin:", NAVY)
style_B3$rules$total_box <- paste0("medium:", NAVY)

styles <- list(
  style_A,
  style_B,
  style_C,
  style_D,
  style_B1,
  style_B2,
  style_B3
)

# ---- 7. Crosstab writers -------------------------------------------------

dims_of <- function(rows, cols) openxlsx2::wb_dims(rows = rows, cols = cols)

# Write a text in column A and merge it across the block.
write_merged <- function(wb, sheet, text, row, n_cols) {
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = text,
    start_row = row,
    start_col = 1L
  )
  if (n_cols > 1L) {
    wb <- openxlsx2::wb_merge_cells(
      wb,
      sheet = sheet,
      dims = dims_of(row, 1:n_cols)
    )
  }
  wb
}

# The two sample-size rows (spec 3.4).
write_sample_size_rows <- function(wb, sheet, row, n_labels, counts, st) {
  specs <- list(
    list(label = "Unweighted sample size", values = counts$n),
    list(
      label = "Effective sample size",
      values = round(counts$n_eff, 1L)
    )
  )
  fmts <- c(st$sample$fmt_n, st$sample$fmt_eff)
  rows <- integer()
  for (s in specs) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = s$label,
      start_row = row,
      start_col = 1L
    )
    if (length(s$values) > 0L) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = as.data.frame(matrix(s$values, nrow = 1L)),
        start_row = row,
        start_col = n_labels + 1L,
        col_names = FALSE
      )
    }
    rows <- c(rows, row)
    row <- row + 1L
  }
  list(wb = wb, next_row = row, rows = rows, fmts = fmts)
}

legend_text <- function(variance, conf_level) {
  if (is.null(variance)) {
    return(NULL)
  }
  if (identical(variance, "se")) {
    return("Percentages; standard error in parentheses.")
  }
  paste0(
    "Percentages; ",
    format(conf_level * 100),
    "% confidence interval in parentheses."
  )
}

# One question block of a crosstab sheet. Returns the next free row.
write_crosstab_block <- function(
  wb,
  sheet,
  reg,
  start_row,
  blk,
  opt,
  st,
  w,
  freeze_col = length(blk$label_heads) + 1L
) {
  n_labels <- length(blk$label_heads)
  n_cols <- n_cols_of(blk)
  data_cols <- n_labels + seq_along(levels_flat)
  block_w <- sum(w[seq_len(n_cols)])
  lay <- new_layout(n_cols, n_labels)
  lay$block_top <- start_row

  row <- start_row
  # Row 1: the question text or group preface (spec 3.16).
  wb <- write_merged(wb, sheet, blk$title, row, n_cols)
  lay$title_rows <- row
  reg_height(reg, row, fit_spec(blk$title, block_w, st$title, st))
  row <- row + 1L
  # Row 2: the base note.
  if (!is.null(blk$base_note)) {
    wb <- write_merged(wb, sheet, blk$base_note, row, n_cols)
    lay$note_rows <- c(lay$note_rows, row)
    reg_height(reg, row, fit_spec(blk$base_note, block_w, st$note, st))
    row <- row + 1L
  }
  # Row 3: the variance legend (spec 3.12).
  legend <- legend_text(opt$variance, conf_level)
  if (!is.null(legend)) {
    wb <- write_merged(wb, sheet, legend, row, n_cols)
    lay$note_rows <- c(lay$note_rows, row)
    reg_height(reg, row, fit_spec(legend, block_w, st$note, st))
    row <- row + 1L
  }

  # Row 4: the spanner row. Row 5: the heading row.
  spanner_row <- row
  heading_row <- row + 1L
  spanner_h <- fit_spec("", 10, st$spanner, st, min_lines = 2L)
  col <- n_labels + 1L
  for (g in col_groups) {
    span <- col:(col + length(g$levels) - 1L)
    if (nzchar(g$spanner)) {
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = g$spanner,
        start_row = spanner_row,
        start_col = col
      )
      spanner_h <- max(
        spanner_h,
        fit_spec(g$spanner, sum(w[span]), st$spanner, st, min_lines = 2L)
      )
    }
    if (length(span) > 1L) {
      wb <- openxlsx2::wb_merge_cells(
        wb,
        sheet = sheet,
        dims = dims_of(spanner_row, span)
      )
    }
    lay$groups[[length(lay$groups) + 1L]] <- list(
      cols = span,
      text = g$spanner,
      total = g$key == "total"
    )
    col <- col + length(g$levels)
  }
  reg_height(reg, spanner_row, spanner_h)
  heads <- c(blk$label_heads, levels_flat)
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = as.data.frame(matrix(heads, nrow = 1L)),
    start_row = heading_row,
    start_col = 1L,
    col_names = FALSE
  )
  heading_h <- max(vapply(
    seq_along(heads),
    function(k) fit_spec(heads[[k]], w[[k]], st$heading, st, min_lines = 2L),
    numeric(1L)
  ))
  reg_height(reg, heading_row, heading_h)
  lay$spanner_row <- spanner_row
  lay$heading_row <- heading_row
  lay$table_top <- spanner_row
  row <- heading_row + 1L

  # Rows 6 and 7: the sample-size rows under "top".
  add_sample_rows <- function(wb, row) {
    ss <- write_sample_size_rows(wb, sheet, row, n_labels, counts, st)
    lay$sample_rows <<- ss$rows
    lay$sample_fmt <<- ss$fmts
    for (r in ss$rows) {
      reg_height(reg, r, fit_spec("x", w[[1L]], st$sample, st))
    }
    ss
  }
  if (opt$sample_size_display == "top") {
    ss <- add_sample_rows(wb, row)
    wb <- ss$wb
    row <- ss$next_row
  }

  # One freeze pane per sheet, from its first block (spec 3.16). A style
  # with freeze_labels also freezes the label columns, to the left of
  # freeze_col.
  if (start_row == 1L && opt$sample_size_display != "bottom") {
    wb <- openxlsx2::wb_freeze_pane(
      wb,
      sheet = sheet,
      first_active_row = row,
      first_active_col = if (isTRUE(st$freeze_labels)) freeze_col else NULL
    )
  }

  # Rows 8...k: the estimate rows.
  in_cell <- !is.null(opt$variance) && opt$variance_display == "cell"
  in_row <- !is.null(opt$variance) && opt$variance_display == "row"
  item_rows <- list()
  stripe <- 0L
  last_var <- ""
  for (r in blk$rows) {
    if (blk$kind != "battery" || r$var != last_var) {
      stripe <- stripe + 1L
    }
    if (blk$kind == "battery") {
      if (r$var != last_var) {
        lay$item_label_rows <- c(lay$item_label_rows, row)
      }
      item_rows[[r$var]] <- c(item_rows[[r$var]], row)
    }
    last_var <- r$var
    row_h <- 0
    for (k in seq_along(r$labels)) {
      if (nzchar(r$labels[[k]])) {
        wb <- openxlsx2::wb_add_data(
          wb,
          sheet = sheet,
          x = r$labels[[k]],
          start_row = row,
          start_col = k
        )
      }
      spec <- if (blk$kind == "battery" && k == 1L) {
        utils::modifyList(st$label, st$item)
      } else {
        st$label
      }
      row_h <- max(row_h, fit_spec(r$labels[[k]], w[[k]], spec, st))
    }
    var_strings <- character(length(levels_flat))
    for (j in seq_along(levels_flat)) {
      rows <- cell_rows(r$var, keys_flat[[j]], levels_flat[[j]], r$value)
      has_rows <- nrow(rows) > 0L && rows$n[[1L]] > 0L
      est <- fmt_pct(if (has_rows) rows$pct[[1L]] else NA, decimals, has_rows)
      vs <- fmt_variance(rows, opt$variance, decimals, has_rows)
      var_strings[[j]] <- vs
      x <- if (in_cell && nzchar(vs)) {
        openxlsx2::fmt_txt(
          est,
          font = st$font,
          size = st$data$size,
          color = argb(st$data$color)
        ) +
          openxlsx2::fmt_txt(
            paste0("\n", vs),
            font = st$font,
            size = st$interval$size,
            color = argb(st$interval$color)
          )
      } else {
        est
      }
      wb <- openxlsx2::wb_add_data(
        wb,
        sheet = sheet,
        x = x,
        start_row = row,
        start_col = data_cols[[j]]
      )
    }
    if (in_cell) {
      row_h <- max(
        row_h,
        ceiling(
          line_pt(st$data$size) + line_pt(st$interval$size) + st$pad
        )
      )
    }
    reg_height(reg, row, row_h)
    lay$body_rows <- c(lay$body_rows, row)
    lay$stripe <- c(lay$stripe, stripe)
    row <- row + 1L
    if (in_row) {
      for (j in seq_along(levels_flat)) {
        if (nzchar(var_strings[[j]])) {
          wb <- openxlsx2::wb_add_data(
            wb,
            sheet = sheet,
            x = var_strings[[j]],
            start_row = row,
            start_col = data_cols[[j]]
          )
        }
      }
      reg_height(reg, row, fit_spec("x", 10, st$interval, st))
      lay$body_rows <- c(lay$body_rows, row)
      lay$var_rows <- c(lay$var_rows, row)
      lay$stripe <- c(lay$stripe, stripe)
      row <- row + 1L
    }
  }
  lay$items <- unname(item_rows)
  if (blk$kind == "battery" && identical(st$battery_label, "merge")) {
    for (it in lay$items) {
      if (length(it) > 1L) {
        wb <- openxlsx2::wb_merge_cells(
          wb,
          sheet = sheet,
          dims = dims_of(min(it):max(it), 1L)
        )
      }
    }
  }

  # Rows k+1...: the sample-size rows under "bottom".
  if (opt$sample_size_display == "bottom") {
    ss <- add_sample_rows(wb, row)
    wb <- ss$wb
    row <- ss$next_row
  }
  lay$table_bottom <- row - 1L

  # Rows k+2...: the withheld lines under withheld_note = "every".
  if (opt$withheld_note == "every") {
    for (line in withheld_lines) {
      wb <- write_merged(wb, sheet, line, row, n_cols)
      lay$withheld_rows <- c(lay$withheld_rows, row)
      reg_height(reg, row, fit_spec(line, block_w, st$withheld, st))
      row <- row + 1L
    }
  }

  style_table(reg, lay, st)
  list(wb = wb, next_row = row, n_cols = n_cols)
}

# Column widths (spec 3.16), from the style list.
crosstab_widths <- function(n_cols, has_battery, layout, opt, st) {
  data_width <- if (identical(opt$variance, "ci")) {
    st$widths$data_ci
  } else {
    st$widths$data
  }
  widths <- rep(data_width, n_cols)
  widths[[1L]] <- st$widths$label
  if (has_battery) {
    widths[[2L]] <- if (layout == "stacked") {
      max(st$widths$battery, data_width)
    } else {
      st$widths$battery
    }
  }
  widths
}

# ---- 8. Cover sheet (spec 3.14, 3.15) -------------------------------------

glossary_all <- c(
  "Unweighted sample size" = paste(
    "The number of people who answered. It does not change when weights are",
    "applied. Report text writes this as N for the full sample and n for a",
    "subgroup."
  ),
  "Effective sample size (ESS)" = paste(
    "The sample size left after weighting. Weights make some people count for",
    "more than others, and that costs precision, so this number is smaller",
    "than the unweighted sample size",
    EM_DASH,
    "the more the weights vary, the smaller it gets. It adjusts for the",
    "weights alone. It does not adjust for clustered sampling, so on a",
    "clustered survey the true precision is lower than this number suggests."
  ),
  "Why a column is missing" = paste(
    "A subgroup whose effective sample size falls below the minimum is not",
    "shown. The minimum for this workbook is listed above. The test is on the",
    "size of the subgroup itself, not on how many of its members answered any",
    "one question, so a question that many people skipped can still be shown",
    "for a subgroup that clears the minimum."
  ),
  "Percentages" = paste(
    "Each percentage is based on the people who answered that question, which",
    "can be fewer than the sample size shown above the table. A value that is",
    "not zero but rounds to zero at the shown precision reads <0.1%. A value",
    "below 100 that rounds to 100 reads >99.9%. A true zero reads 0%. A dash",
    "means the answer was not chosen in that column, or was never offered",
    "there."
  ),
  "Confidence intervals" = paste(
    "The interval is a normal approximation. For a very rare or a",
    "near-unanimous answer a bound can fall below 0 percent or rise above 100",
    "percent. That is a property of the approximation, not a count of people."
  )
)

# The display label of a dataset key: the key with "_" as a space, in
# sentence case. survey_name -> "Survey name".
key_label <- function(key) {
  s <- gsub("_", " ", key)
  paste0(toupper(substr(s, 1L, 1L)), substr(s, 2L, nchar(s)))
}

# The About sheet: up to three sections, one blank row between them. Each
# section is styled as a two-column table: the Key / Value row or the
# section heading is its heading row.
write_cover_sheet <- function(
  wb,
  reg,
  st,
  withheld_block,
  has_banner,
  string_cells,
  variance
) {
  sheet <- "About"
  meta <- surveycore::extract_dataset_metadata(d, format = "data_frame")
  sections <- list(list(
    head = c("Key", "Value"),
    body = lapply(seq_len(nrow(meta)), function(i) {
      c(key_label(meta$key[[i]]), meta$value[[i]])
    }),
    bold_body = FALSE
  ))
  if (withheld_block) {
    lines <- if (length(withheld_lines) > 0L) withheld_lines else "None"
    sections[[2L]] <- list(
      head = c("Subgroups not shown", NA_character_),
      body = c(
        list(c("Minimum effective sample size", format(min_eff_n))),
        lapply(lines, function(l) c(l, NA_character_))
      ),
      bold_body = FALSE
    )
  }
  keep <- c(
    "Unweighted sample size" = TRUE,
    "Effective sample size (ESS)" = TRUE,
    "Why a column is missing" = min_eff_n > 0 && has_banner,
    "Percentages" = string_cells,
    "Confidence intervals" = identical(variance, "ci")
  )
  sections[[length(sections) + 1L]] <- list(
    head = c("What these numbers mean", NA_character_),
    body = lapply(names(keep)[keep], function(t) c(t, glossary_all[[t]])),
    bold_body = TRUE
  )

  a_w <- st$about$a
  b_w <- st$about$b
  rows <- list()
  row <- 1L
  for (i in seq_along(sections)) {
    s <- sections[[i]]
    if (i > 1L) {
      rows[[length(rows) + 1L]] <- c(NA_character_, NA_character_)
      row <- row + 1L
    }
    lay <- new_layout(2L, 1L)
    lay$groups <- list(list(cols = 2L, text = "", total = FALSE))
    lay$tint <- FALSE
    lay$about <- TRUE
    lay$block_top <- row
    lay$table_top <- row
    lay$heading_row <- row
    rows[[length(rows) + 1L]] <- s$head
    reg_height(reg, row, fit_spec(s$head[[1L]], a_w, st$heading, st))
    row <- row + 1L
    for (j in seq_along(s$body)) {
      b <- s$body[[j]]
      rows[[length(rows) + 1L]] <- b
      a_spec <- if (s$bold_body) c(st$label, list(bold = TRUE)) else st$label
      h <- fit_spec(b[[1L]], a_w, a_spec, st)
      if (!is.na(b[[2L]])) {
        h <- max(h, fit_spec(b[[2L]], b_w, st$data, st))
      }
      reg_height(reg, row, h)
      lay$body_rows <- c(lay$body_rows, row)
      lay$stripe <- c(lay$stripe, j)
      row <- row + 1L
    }
    if (s$bold_body) {
      lay$label_bold_rows <- lay$body_rows
    }
    lay$table_bottom <- row - 1L
    style_table(reg, lay, st)
  }

  m <- do.call(rbind, rows)
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = as.data.frame(m, stringsAsFactors = FALSE),
    start_row = 1L,
    start_col = 1L,
    col_names = FALSE,
    na.strings = NULL
  )
  openxlsx2::wb_set_col_widths(
    wb,
    sheet = sheet,
    cols = 1:2,
    widths = c(a_w, b_w)
  )
}

add_about_sheet <- function(wb, st, ctx, ...) {
  wb <- openxlsx2::wb_add_worksheet(wb, "About", grid_lines = FALSE)
  reg <- reg_new()
  wb <- write_cover_sheet(wb, reg, st, ...)
  finish_sheet(wb, "About", reg, st, ctx)
}

# ---- 9. Crosstab files -----------------------------------------------------

build_crosstab <- function(file, layout, opt, st) {
  ctx <- new_ctx()
  wb <- new_workbook(st)
  wb <- add_about_sheet(
    wb,
    st,
    ctx,
    withheld_block = opt$withheld_note == "once" && min_eff_n > 0,
    has_banner = TRUE,
    string_cells = TRUE,
    variance = opt$variance
  )
  if (layout == "per_question") {
    for (blk in blocks) {
      wb <- openxlsx2::wb_add_worksheet(wb, blk$name, grid_lines = FALSE)
      reg <- reg_new()
      w <- crosstab_widths(
        n_cols_of(blk),
        blk$kind == "battery",
        layout,
        opt,
        st
      )
      res <- write_crosstab_block(wb, blk$name, reg, 1L, blk, opt, st, w)
      wb <- openxlsx2::wb_set_col_widths(
        res$wb,
        sheet = blk$name,
        cols = seq_along(w),
        widths = w
      )
      wb <- finish_sheet(wb, blk$name, reg, st, ctx)
    }
  } else {
    sheet <- "Crosstab"
    wb <- openxlsx2::wb_add_worksheet(wb, sheet, grid_lines = FALSE)
    reg <- reg_new()
    widest <- max(vapply(blocks, n_cols_of, numeric(1L)))
    has_battery <- any(vapply(
      blocks,
      function(b) b$kind == "battery",
      logical(1L)
    ))
    w <- crosstab_widths(widest, has_battery, layout, opt, st)
    # The stacked sheet freezes column A, and column B too when a battery
    # is on the sheet, because the battery block uses B as a label column.
    freeze_col <- if (has_battery) 3L else 2L
    row <- 1L
    for (blk in blocks) {
      res <- write_crosstab_block(
        wb,
        sheet,
        reg,
        row,
        blk,
        opt,
        st,
        w,
        freeze_col = freeze_col
      )
      wb <- res$wb
      row <- res$next_row + 1L # one blank row between blocks
    }
    wb <- openxlsx2::wb_set_col_widths(
      wb,
      sheet = sheet,
      cols = seq_along(w),
      widths = w
    )
    wb <- finish_sheet(wb, sheet, reg, st, ctx)
  }
  openxlsx2::wb_save(wb, file, overwrite = TRUE)
  invisible(file)
}

opt_per_question <- list(
  variance = "ci",
  variance_display = "cell",
  sample_size_display = "top",
  withheld_note = "once"
)
opt_stacked <- list(
  variance = NULL,
  variance_display = "cell",
  sample_size_display = "top",
  withheld_note = "every"
)

# ---- 10. Topline file -----------------------------------------------------
# export_topline() keeps its current content (spec 1.3, 4.1, 4.2): a
# numeric percentage, an N column, a "Total" row of "100%". It gains the
# About sheet. Its glossary holds the two sample-size entries.

topline_tab <- function(var) {
  tot <- freqs[[var]]$total
  data.frame(
    label = tot$value,
    pct = round(tot$pct * 100, decimals),
    n = tot$n
  )
}

# One topline table: an optional title (or subtitle) and base note, the
# heading row, one row per entry of `tab`, and an optional Total row.
write_topline_table <- function(
  wb,
  sheet,
  reg,
  start_row,
  st,
  w,
  title,
  title_kind,
  base_note,
  heads,
  tab,
  total
) {
  n_cols <- 3L
  block_w <- sum(w)
  lay <- new_layout(n_cols, 1L)
  lay$block_top <- start_row
  row <- start_row
  title_spec <- st[[title_kind]]
  wb <- write_merged(wb, sheet, title, row, n_cols)
  lay[[paste0(title_kind, "_rows")]] <- row
  reg_height(reg, row, fit_spec(title, block_w, title_spec, st))
  row <- row + 1L
  if (!is.null(base_note)) {
    wb <- write_merged(wb, sheet, base_note, row, n_cols)
    lay$note_rows <- row
    reg_height(reg, row, fit_spec(base_note, block_w, st$note, st))
    row <- row + 1L
  }
  if (is.null(heads)) {
    style_table(reg, lay, st)
    return(list(wb = wb, next_row = row))
  }
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = as.data.frame(matrix(heads, nrow = 1L)),
    start_row = row,
    col_names = FALSE
  )
  lay$heading_row <- row
  lay$table_top <- row
  reg_height(reg, row, fit_spec(heads[[1L]], w[[1L]], st$heading, st))
  row <- row + 1L
  wb <- openxlsx2::wb_add_data(
    wb,
    sheet = sheet,
    x = tab,
    start_row = row,
    col_names = FALSE
  )
  for (i in seq_len(nrow(tab))) {
    reg_height(reg, row, fit_spec(tab$label[[i]], w[[1L]], st$label, st))
    lay$body_rows <- c(lay$body_rows, row)
    lay$stripe <- c(lay$stripe, i)
    row <- row + 1L
  }
  if (total) {
    wb <- openxlsx2::wb_add_data(
      wb,
      sheet = sheet,
      x = data.frame(a = "Total", b = "100%", c = sum(tab$n)),
      start_row = row,
      col_names = FALSE
    )
    lay$total_row <- row
    reg_height(reg, row, fit_spec("Total", w[[1L]], st$total_row, st))
    row <- row + 1L
  }
  lay$table_bottom <- row - 1L
  lay$groups <- list(list(cols = 2:3, text = "", total = FALSE))
  lay$numfmt <- list("3" = st$sample$fmt_n)
  style_table(reg, lay, st)
  list(wb = wb, next_row = row)
}

build_topline <- function(file, st) {
  ctx <- new_ctx()
  wb <- new_workbook(st)
  wb <- add_about_sheet(
    wb,
    st,
    ctx,
    withheld_block = FALSE,
    has_banner = FALSE,
    string_cells = FALSE,
    variance = NULL
  )
  sheet <- "Topline"
  wb <- openxlsx2::wb_add_worksheet(wb, sheet, grid_lines = FALSE)
  reg <- reg_new()
  w <- c(st$widths$label, st$widths$topline, st$widths$topline)
  row <- 1L
  tbl <- function(wb, row, ...) {
    write_topline_table(wb, sheet, reg, row, st, w, ...)
  }

  # Single-response block.
  res <- tbl(
    wb,
    row,
    title = meta_of(single_var),
    title_kind = "title",
    base_note = universe_text,
    heads = c("Response", "%", "N"),
    tab = topline_tab(single_var),
    total = TRUE
  )
  row <- res$next_row + 1L

  # SATA block: one row per item, the "Yes" percentage and its N.
  sata_tab <- do.call(
    rbind,
    lapply(sata_vars, function(v) {
      yes <- freqs[[v]]$total[freqs[[v]]$total$value == "Yes", ]
      data.frame(
        label = meta_of(v),
        pct = round(yes$pct * 100, decimals),
        n = yes$n
      )
    })
  )
  res <- tbl(
    res$wb,
    row,
    title = preface_of(sata_vars[[1L]]),
    title_kind = "title",
    base_note = NULL,
    heads = c("Item", "%", "N"),
    tab = sata_tab,
    total = FALSE
  )
  row <- res$next_row + 1L

  # Battery block: the preface, the block base note, then one table per item.
  res <- tbl(
    res$wb,
    row,
    title = preface_of(bat_vars[[1L]]),
    title_kind = "title",
    base_note = universe_text,
    heads = NULL,
    tab = NULL,
    total = FALSE
  )
  row <- res$next_row
  for (v in bat_vars) {
    res <- tbl(
      res$wb,
      row,
      title = meta_of(v),
      title_kind = "subtitle",
      base_note = NULL,
      heads = c("Response", "%", "N"),
      tab = topline_tab(v),
      total = TRUE
    )
    row <- res$next_row + 1L
  }
  wb <- openxlsx2::wb_set_col_widths(
    res$wb,
    sheet = sheet,
    cols = 1:3,
    widths = w
  )
  wb <- finish_sheet(wb, sheet, reg, st, ctx)
  openxlsx2::wb_save(wb, file, overwrite = TRUE)
  invisible(file)
}

# ---- 11. One variant: three files -------------------------------------------

build_variant <- function(st, dir) {
  files <- file.path(
    dir,
    paste0(
      st$id,
      c("-crosstab.xlsx", "-crosstab-stacked.xlsx", "-topline.xlsx")
    )
  )
  build_crosstab(files[[1L]], "per_question", opt_per_question, st)
  build_crosstab(files[[2L]], "stacked", opt_stacked, st)
  build_topline(files[[3L]], st)
  invisible(files)
}

# ---- 12. README: one style table per variant -------------------------------

doc_hex <- function(x) {
  if (length(x) == 0L) {
    return("none")
  }
  ifelse(nzchar(x), paste0("#", x), "none")
}

doc_rule_txt <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  p <- strsplit(x, ":", fixed = TRUE)[[1L]]
  paste0(p[[1L]], " #", p[[2L]])
}

doc_bi <- function(spec) {
  x <- c(if (isTRUE(spec$bold)) "bold", if (isTRUE(spec$italic)) "italic")
  if (length(x) > 0L) paste(x, collapse = " ") else "regular"
}

doc_row <- function(
  st,
  element,
  spec,
  fill = NULL,
  border = NULL,
  align = NULL,
  merge = "no",
  hw = "-"
) {
  al <- align %||%
    paste0(spec$h %||% "general", ", ", spec$v %||% "bottom")
  if (!is.null(spec$indent)) {
    al <- paste0(al, ", indent ", spec$indent)
  }
  c(
    element,
    st$font,
    format(spec$size %||% st$size),
    doc_bi(spec),
    doc_hex(spec$color %||% st$text),
    fill %||% doc_hex(spec$fill),
    if (length(border) > 0L) paste(border, collapse = "; ") else "none",
    al,
    if (isTRUE(spec$wrap)) "on" else "off",
    merge,
    hw
  )
}

doc_rule <- function(element, value, where) {
  if (is.null(value)) {
    return(NULL)
  }
  c(
    element,
    "-",
    "-",
    "-",
    "-",
    "-",
    paste(doc_rule_txt(value), where),
    rep("-", 4L)
  )
}

doc_variant <- function(st) {
  ru <- st$rules
  fit <- "fit to text"
  spanner_fill <- if (length(st$tints) > 0L) {
    paste(
      "alternates by labelled group:",
      paste(doc_hex(st$tints), collapse = ", ")
    )
  } else {
    NULL
  }
  heading_data_fill <- if (isTRUE(st$heading$tint)) {
    paste(
      "the group's spanner tint;",
      doc_hex(st$heading$fill),
      "over Total, on the topline and on the About sheet"
    )
  } else {
    NULL
  }
  item_spec <- utils::modifyList(st$label, st$item)
  item_merge <- if (identical(st$battery_label, "merge")) {
    "column A merged down the item's rows"
  } else {
    "no; written on the item's first row only"
  }
  sample_lab <- st$sample
  sample_lab$h <- "left"
  sample_lab$v <- "center"
  sample_lab$fill <- st$sample$fill %||% st$label$fill
  sample_num <- st$sample
  sample_num$h <- st$data$h
  sample_num$v <- "center"
  about_head <- st$heading
  about_head$h <- "left"
  about_key <- st$label
  about_key$v <- "top"
  about_val <- st$data
  about_val$h <- "left"
  about_val$v <- "top"
  total_row <- utils::modifyList(st$data, st$total_row)
  head_lab <- st$heading
  head_lab$h <- st$heading$label_h
  head_dat <- st$heading
  head_dat$h <- st$heading$data_h

  rows <- list(
    c(
      "Workbook base font",
      st$font,
      format(st$size),
      "regular",
      doc_hex(st$text),
      "none",
      "none; gridlines hidden on every sheet",
      rep("-", 4L)
    ),
    doc_row(
      st,
      "Title row (question text or group preface)",
      st$title,
      merge = "across the block",
      hw = fit
    ),
    doc_row(
      st,
      "Base-note and legend rows",
      st$note,
      merge = "across the block",
      hw = fit
    ),
    doc_row(
      st,
      "Withheld line under a block (stacked file)",
      st$withheld,
      merge = "across the block",
      hw = fit
    ),
    doc_row(
      st,
      "Spanner cell with a label",
      st$spanner,
      fill = spanner_fill,
      border = c(
        if (!is.null(ru$spanner_under)) {
          paste("bottom", doc_rule_txt(ru$spanner_under))
        },
        if (!is.null(ru$spanner_box)) {
          paste("box", doc_rule_txt(ru$spanner_box))
        }
      ),
      merge = "across the group's columns",
      hw = "fit to text, at least 2 lines"
    ),
    c(
      "Spanner cell, empty (over the label columns and Total)",
      "-",
      "-",
      "-",
      if (is.null(st$spanner_empty$color)) {
        "-"
      } else {
        doc_hex(st$spanner_empty$color)
      },
      doc_hex(st$spanner_empty$fill),
      "none",
      "-",
      "-",
      "no",
      "-"
    ),
    doc_row(
      st,
      "Heading cell, label columns (Response, Item)",
      head_lab,
      border = c(
        if (!is.null(ru$heading_under)) {
          paste("bottom", doc_rule_txt(ru$heading_under))
        }
      ),
      hw = "fit to text, at least 2 lines"
    ),
    doc_row(
      st,
      "Heading cell, data columns",
      head_dat,
      fill = heading_data_fill,
      border = c(
        if (!is.null(ru$heading_under)) {
          paste("bottom", doc_rule_txt(ru$heading_under))
        }
      ),
      hw = "same row"
    ),
    if (!is.null(st$total_col$head_fill)) {
      doc_row(
        st,
        "Heading cell, Total column",
        utils::modifyList(head_dat, list(fill = st$total_col$head_fill)),
        border = c(
          if (!is.null(ru$heading_under)) {
            paste("bottom", doc_rule_txt(ru$heading_under))
          }
        ),
        hw = "same row"
      )
    },
    doc_row(
      st,
      "Sample-size label cells",
      sample_lab,
      hw = "fit to text"
    ),
    doc_row(
      st,
      paste0(
        "Sample-size numbers (unweighted `",
        st$sample$fmt_n,
        "`, effective `",
        st$sample$fmt_eff,
        "`)"
      ),
      sample_num,
      hw = "same row"
    ),
    doc_row(
      st,
      "Label cells (response or item)",
      st$label,
      hw = fit
    ),
    doc_row(
      st,
      "Battery item label (column A)",
      item_spec,
      merge = item_merge,
      hw = fit
    ),
    doc_row(
      st,
      "Estimate cell (percentage string)",
      st$data,
      hw = if (st$pad > 0) {
        paste0(
          "1 line; with an interval 1.35 x (",
          st$data$size,
          " + ",
          st$interval$size,
          ") + ",
          st$pad,
          " pt"
        )
      }
    ),
    c(
      "Interval line (second rich-text run of the estimate cell)",
      st$font,
      format(st$interval$size),
      "regular",
      doc_hex(st$interval$color),
      "-",
      "-",
      "second line of the cell",
      "on",
      "-",
      "-"
    ),
    if (!is.null(st$total_col$fill)) {
      c(
        "Total column, body and sample-size cells",
        rep("-", 4L),
        doc_hex(st$total_col$fill),
        rep("-", 5L)
      )
    },
    if (!is.null(st$zebra)) {
      c(
        paste(
          "Zebra stripe: all cells of every second response row",
          "(in a battery, of every second item); topline and About body",
          "rows by row"
        ),
        rep("-", 4L),
        doc_hex(st$zebra),
        rep("-", 5L)
      )
    },
    doc_row(
      st,
      "Topline battery item heading",
      st$subtitle,
      merge = "across the 3 columns",
      hw = fit
    ),
    doc_row(
      st,
      "Topline Total row",
      total_row,
      border = c(
        if (!is.null(ru$total_above)) {
          paste("top", doc_rule_txt(ru$total_above))
        }
      ),
      align = "label left; numbers as estimate cells",
      hw = fit
    ),
    doc_rule(
      "Rule: table top",
      ru$top,
      "on top of the spanner row (topline: heading row)"
    ),
    doc_rule(
      "Rule: between body rows",
      ru$row,
      "bottom of every response row and sample-size row except the last"
    ),
    doc_rule(
      "Rule: between battery items",
      ru$item,
      "bottom of the last row of each item except the last item"
    ),
    doc_rule(
      "Rule: under the sample-size rows",
      ru$sample_under,
      "bottom of the last sample-size row"
    ),
    doc_rule("Rule: table bottom", ru$bottom, "bottom of the last table row"),
    doc_rule(
      "Rule: grid",
      ru$grid,
      "all four sides of every cell from the spanner row to the last table row"
    ),
    doc_rule(
      "Rule: column groups",
      ru$group_v,
      paste(
        "left side of the first column of each group (Total included),",
        "spanner row to last table row; About: left side of column B"
      )
    ),
    doc_rule(
      "Rule: band separators",
      ru$band_sep,
      paste(
        "left side of the first column of each group (Total included) in",
        "the spanner and heading rows, and bottom of each labelled spanner;",
        "About: left side of B in the heading row"
      )
    ),
    doc_rule(
      "Rule: block box",
      ru$box,
      if (identical(ru$box_from, "block")) {
        "outline from the title row to the last table row"
      } else {
        "outline from the spanner row to the last table row"
      }
    ),
    doc_rule(
      "Rule: column-group edge",
      ru$group_edge,
      paste(
        "left side of the first column of each group (Total included),",
        "spanner row to last table row; drawn after the block box;",
        "topline: left side of B; not on the About sheet"
      )
    ),
    doc_rule(
      "Rule: column-group box",
      ru$group_box,
      paste(
        "outline of each group except Total, spanner row to last table row;",
        "drawn after the block box; topline: outline of B:C; not on the",
        "About sheet"
      )
    ),
    doc_rule(
      "Rule: Total column box",
      ru$total_box,
      "outline of the Total column, spanner row to last table row; drawn last"
    ),
    c(
      "Freeze pane",
      rep("-", 9L),
      if (isTRUE(st$freeze_labels)) {
        paste(
          "rows above the first data row of the first block, and the label",
          "columns: A on single-response and SATA sheets, A:B on battery",
          "sheets; stacked sheet A:B (the battery block uses B as a label",
          "column); topline none"
        )
      } else {
        "rows above the first data row of the first block; no columns; topline none"
      }
    ),
    doc_row(
      st,
      "About: Key / Value row and section headings",
      about_head,
      border = c(
        if (!is.null(ru$heading_under)) {
          paste("bottom", doc_rule_txt(ru$heading_under))
        }
      ),
      merge = "no (spec 3.14)",
      hw = fit
    ),
    doc_row(
      st,
      "About: column A (keys; glossary terms bold)",
      about_key,
      hw = fit
    ),
    doc_row(
      st,
      "About: column B (values, glossary paragraphs)",
      about_val,
      hw = fit
    ),
    c(
      "Column widths",
      rep("-", 9L),
      paste0(
        "crosstab A ",
        st$widths$label,
        ", battery B ",
        st$widths$battery,
        ", data ",
        st$widths$data,
        " (",
        st$widths$data_ci,
        " under variance = ci); topline A ",
        st$widths$label,
        ", B and C ",
        st$widths$topline,
        "; About A ",
        st$about$a,
        ", B ",
        st$about$b
      )
    ),
    c(
      "Row heights",
      rep("-", 9L),
      paste0(
        "every table row set: lines x 1.35 x font size + ",
        st$pad,
        " pt"
      )
    )
  )
  rows <- Filter(Negate(is.null), rows)
  head <- c(
    "Element",
    "Font",
    "Size",
    "Bold/italic",
    "Colour",
    "Fill",
    "Border",
    "Alignment (h, v)",
    "Wrap",
    "Merge",
    "Height or width"
  )
  tab <- vapply(
    c(list(head, rep("---", length(head))), rows),
    function(r) paste0("| ", paste(r, collapse = " | "), " |"),
    character(1L)
  )
  gaps <- c(
    paste0(
      "- Gap 1 (alignment): data cells ",
      st$data$h,
      "; data headings ",
      st$heading$data_h,
      "."
    ),
    paste0(
      "- Gap 2 (About column B): width ",
      st$about$b,
      ", wrap on, top-aligned."
    ),
    "- Gap 3 (spanner): bold, centered, wrap on, at least two lines high.",
    "- Gap 4 (bold, borders, fill): as the summary above and the table say.",
    paste0(
      "- Gap 5 (interval line): ",
      st$interval$size,
      " pt, ",
      doc_hex(st$interval$color),
      "."
    ),
    paste0("- Gap 6 (battery item label): ", item_merge, "."),
    paste0(
      "- Gap 7 (sample-size numbers): `",
      st$sample$fmt_n,
      "` and `",
      st$sample$fmt_eff,
      "`."
    )
  )
  c(
    paste0("## ", st$id, ". ", st$name),
    "",
    st$summary,
    "",
    paste0("**Good for:** ", st$good_for),
    "",
    "How it settles the styling gaps (spec-gaps.md, 1 to 7):",
    "",
    gaps,
    "",
    tab,
    ""
  )
}

write_readme <- function(styles, dir) {
  intro <- c(
    "# Style variants of the mockup workbooks",
    "",
    "Written by `plans/mockups/build-mockups.R`. Do not edit by hand:",
    "change the style lists in section 6 of the script and run it again.",
    "",
    "Each variant is three files: `X-crosstab.xlsx` (per-question layout,",
    "intervals in the cell, withheld lines once on the About sheet),",
    "`X-crosstab-stacked.xlsx` (one Crosstab sheet, no intervals, withheld",
    "lines under each block) and `X-topline.xlsx`. The content of the files",
    "is the same in every variant. Only the styling changes.",
    "",
    paste(
      "B1, B2 and B3 revise B with four shared changes: the navy band",
      "moves to the title row; the zebra stripes stay; the interval sits",
      "on its own line in the estimate cell; the panes freeze the heading",
      "rows and the label columns. They differ only in how the column",
      "groups are set apart."
    ),
    "",
    "## What every variant shares",
    "",
    "- One font family across the workbook. Colours are hex RGB.",
    "- Every data cell (percentages, intervals, sample sizes) is right-",
    "  aligned or centered, as the variant's table says.",
    "- Title, base-note, legend and withheld rows are merged across the",
    "  block, wrap on, with the row height fitted to the text.",
    "- Each spanner is merged over its group's columns, centered, wrap on,",
    "  and its row is at least two lines high.",
    "- The heading row and the label columns wrap.",
    "- The interval line is a second rich-text run, smaller and lighter",
    "  than the estimate.",
    "- The freeze pane is below the last sample-size row of the first",
    "  block. B1 to B3 also freeze the label columns. The topline has no",
    "  freeze pane.",
    "- The About sheet has no merged cells (spec 3.14). Each section is a",
    "  small two-column table in the variant's heading and body styles.",
    "- Gridlines are hidden on every sheet.",
    "",
    "Row heights: Excel does not fit merged cells, so the script sets every",
    "table row. A row is the largest of its cells, where a cell needs",
    "`lines x 1.35 x font size + pad` points. `lines` comes from a word wrap",
    "at `(column width - 1) x 11 / font size` characters per line, 10 per",
    "cent fewer for bold text. Spanner and heading rows take at least two",
    "lines. `pad` is set per variant.",
    "",
    "A border is written `style #colour`, with an Excel border style",
    "(hair, thin, medium). A dash means the element takes the value of the",
    "cell it sits in.",
    ""
  )
  body <- unlist(lapply(styles, doc_variant))
  writeLines(c(intro, body), file.path(dir, "README.md"), useBytes = TRUE)
}

# ---- 13. Build and check -----------------------------------------------------

all_files <- unlist(lapply(styles, build_variant, dir = out_dir))
write_readme(styles, out_dir)

for (f in all_files) {
  wb <- openxlsx2::wb_load(f)
  cat(basename(f), ":", paste(wb$get_sheet_names(), collapse = ", "), "\n")
}
cat("Withheld subgroups:\n")
print(withheld)
