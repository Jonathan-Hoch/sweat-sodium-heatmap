# ===============================================
# Sweat Sodium Loss: Passive vs. Active Interventions
# Fully reproducible in R — no Canva edits needed
# ===============================================

# install packages if needed (run once)
# install.packages(c("ggplot2", "dplyr", "tidyr", "viridisLite", "showtext"))

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(viridisLite)
  library(showtext)
})

font_add("Arial", regular = "arial.ttf")
showtext_auto()

# ======= USER CONTROLS =======
X_MIN <- 30; X_MAX <- 45
Y_RH_MIN <- 20; Y_RH_MAX <- 90
STEP <- 0.25

NA_MG_PER_L <- 920

ADD_WBGT_CONTOURS <- TRUE
WBGT_PASSIVE <- 28
WBGT_ACTIVE  <- 26

CUTS   <- c(0, 1000, 1250, 1500, 1750, 2000, 2250, Inf)
LABELS <- c("<1000", "1000-1250", "1250-1500", "1500-1750",
            "1750-2000", "2000-2250", ">2250")

PALETTE      <- viridis(length(LABELS))
LEGEND_TITLE <- "Estimated Sodium Loss (mg·h-1)"

# ======= HELPER FUNCTIONS =======
es_kPa <- function(Tc) 0.6108 * exp(17.27 * Tc / (Tc + 237.3))

Td_from_T_RH <- function(Tc, RH01) {
  a <- 17.27; b <- 237.3
  gamma <- log(pmax(pmin(RH01, 1), 1e-6)) + (a * Tc) / (b + Tc)
  (b * gamma) / (a - gamma)
}

wetbulb_from_T_RH <- function(Tc, RH01) {
  RHp <- RH01 * 100
  Tc * atan(0.151977 * sqrt(RHp + 8.313659)) +
    atan(Tc + RHp) - atan(RHp - 1.676331) +
    0.00391838 * (RHp)^(3/2) * atan(0.023101 * RHp) - 4.686035
}

wbgt_shade_from_T_Td <- function(Tc, Td) {
  RH01 <- pmin(pmax(es_kPa(Td) / es_kPa(Tc), 0), 1)
  Tw   <- wetbulb_from_T_RH(Tc, RH01)
  0.7 * Tw + 0.3 * Tc
}

# ======= SWEAT MODEL =======
loss_mgph_intervention <- function(Tc, Td, intensity = c("passive_intense", "active_moderate"),
                                   na_mg_L = NA_MG_PER_L) {
  intensity <- match.arg(intensity)
  RH01  <- pmin(pmax(es_kPa(Td) / es_kPa(Tc), 0), 1)
  Tw    <- wetbulb_from_T_RH(Tc, RH01)
  WBGT  <- 0.7 * Tw + 0.3 * Tc
  WBGT_LOW <- 22; WBGT_HIGH <- 31

  if (intensity == "passive_intense") {
    sweat_Lph <- 1.0 + (1.5 - 1.0) * (WBGT - WBGT_LOW) / (WBGT_HIGH - WBGT_LOW)
    sweat_Lph <- pmax(1.0, pmin(sweat_Lph, 1.5))
  } else {
    sweat_Lph <- 1.5 + (2.5 - 1.5) * (WBGT - WBGT_LOW) / (WBGT_HIGH - WBGT_LOW)
    sweat_Lph <- pmax(1.5, pmin(sweat_Lph, 3.0))
  }
  sweat_Lph * na_mg_L
}

# ======= BUILD GRID =======
T_vals  <- seq(X_MIN, X_MAX, by = STEP)
RH_vals <- seq(Y_RH_MIN / 100, Y_RH_MAX / 100, by = STEP / 100)

grid <- expand.grid(T = T_vals, RH01 = RH_vals) |>
  as_tibble() |>
  mutate(
    Td                   = Td_from_T_RH(T, RH01),
    WBGT                 = wbgt_shade_from_T_Td(T, Td),
    rate_passive_intense = loss_mgph_intervention(T, Td, "passive_intense"),
    rate_active_moderate = loss_mgph_intervention(T, Td, "active_moderate"),
    RHpct                = RH01 * 100
  )

panel_levels <- c("Passive (1-2 METs)", "Active (3-5 METs)")

df_long <- grid |>
  select(T, RHpct, rate_passive_intense, rate_active_moderate) |>
  pivot_longer(c(rate_passive_intense, rate_active_moderate),
               names_to = "panel", values_to = "val") |>
  mutate(
    panel = factor(
      ifelse(panel == "rate_passive_intense", panel_levels[1], panel_levels[2]),
      levels = panel_levels
    ),
    band = cut(val, breaks = CUTS, labels = LABELS, include.lowest = TRUE, right = FALSE)
  )

# ======= PLOT =======
p <- ggplot(df_long, aes(T, RHpct)) +
  geom_raster(aes(fill = band)) +
  scale_fill_manual(
    values = PALETTE, breaks = LABELS, labels = LABELS,
    drop = FALSE, name = LEGEND_TITLE
  ) +
  scale_x_continuous(
    name   = "Dry-Bulb Temperature (°C)",
    breaks = c(30, 35, 40, 45)
  ) +
  scale_y_continuous(
    name   = "Relative Humidity (%)",
    breaks = seq(20, 90, by = 20)
  ) +
  facet_wrap(~ panel, nrow = 1) +
  coord_fixed(ratio = 0.35) +
  labs(
    title = "Sweat Sodium Loss: Comparing Intense Passive vs. Active Interventions"
  ) +
  theme_minimal(base_size = 12, base_family = "Arial") +
  theme(
    panel.grid      = element_blank(),
    strip.text      = element_text(face = "bold", size = 12, family = "Arial"),
    legend.position = "right",
    legend.title    = element_text(size = 11, family = "Arial"),
    legend.text     = element_text(size = 10, family = "Arial"),
    plot.title      = element_text(face = "bold", size = 13, family = "Arial"),
    axis.title      = element_text(size = 11, family = "Arial"),
    axis.text       = element_text(size = 10, family = "Arial"),
    plot.margin     = margin(t = 10, r = 10, b = 10, l = 10)
  ) +
  guides(fill = guide_legend(keyheight = unit(10, "pt"), keywidth = unit(18, "pt")))

# ======= WBGT CONTOURS =======
if (ADD_WBGT_CONTOURS) {
  df_wbgt_passive <- grid |>
    select(T, RHpct, WBGT) |>
    distinct() |>
    mutate(panel = factor(panel_levels[1], levels = panel_levels))

  df_wbgt_active <- grid |>
    select(T, RHpct, WBGT) |>
    distinct() |>
    mutate(panel = factor(panel_levels[2], levels = panel_levels))

  p <- p +
    stat_contour(data = df_wbgt_passive,
                 aes(x = T, y = RHpct, z = WBGT),
                 breaks = WBGT_PASSIVE, color = "white", linewidth = 0.5, alpha = 0.9) +
    stat_contour(data = df_wbgt_active,
                 aes(x = T, y = RHpct, z = WBGT),
                 breaks = WBGT_ACTIVE, color = "white", linewidth = 0.5, alpha = 0.9)
}

# ======= SAVE =======
ggsave("sweat_sodium_loss.png", p, width = 10, height = 5.5, dpi = 300)
cat("Saved: sweat_sodium_loss.png\n")

print(p)
