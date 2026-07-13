# =============================================================================
# Olofsson et al. (2014) Area-Adjusted Estimation for Multiple LULC Maps
# Computes: Wi, pij, p_hat, A_adj, SE, 95% CI for up to N maps
# =============================================================================

library(tidyverse)
library(lubridate)

# =============================================================================
# SECTION 1: HOW TO FORMAT YOUR INPUTS
# =============================================================================
#
# You need two objects per map:
#
#   1. confusion_matrix — a square numeric matrix of SAMPLE COUNTS (not %)
#      - Rows = map (predicted) classes
#      - Columns = reference (true) classes
#      - Row and column ORDER must match
#      - Classes with NO validation samples should still have a row/col of zeros
#
#      Example for 7 classes (0–6):
#
#        cm <- matrix(c(
#          0, 0, 0, 0, 0, 0, 0,   # class 0
#          0,20, 0, 0, 0, 0, 0,   # class 1
#          0, 2,13, 0, 0, 1, 0,   # class 2
#          0, 0, 0,20, 0, 0, 0,   # class 3
#          0, 0, 0, 0,20, 0, 0,   # class 4
#          0, 1, 0, 0, 0,18, 1,   # class 5
#          0, 0, 2, 0, 0, 1,12    # class 6
#        ), nrow = 7, byrow = TRUE)
#
#   2. area_km2 — a named numeric vector of MAPPED AREAS in km²
#      - One value per class, in the SAME ORDER as the confusion matrix rows
#      - Names should match class labels you want to appear in output
#
#        area_km2 <- c(
#          "Class 0" = 6945.54,
#          "Class 1" =  113.74,
#          ...
#        )
#
# For 9 maps, store each pair in a named list (see Section 2 below).
# =============================================================================


# =============================================================================
# SECTION 2: INPUT YOUR 9 MAPS HERE
# =============================================================================
# Replace the placeholder entries with your actual data.
# Follow the format shown in Section 1 exactly.
# Each list entry is one map: list(cm = <matrix>, area_km2 = <named vector>)

maps <- list(

  g_mar22 = list(
    cm = matrix(c(
      20, 0, 0, 0, 0, 0,
      2, 13, 0, 0, 1, 0,
      0, 0, 20, 0, 0, 0,
      0, 0, 0, 20, 0, 0,
      1, 0, 0, 0, 18, 1,
      0, 2, 0, 0, 1, 12
    ), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  113.744,
      "Class 2" =   60.975,
      "Class 3" =   39.603,
      "Class 4" =  290.157,
      "Class 5" =   71.032,
      "Class 6" =   38.073
    )
  ),

  g_mar23 = list(
    cm = matrix(c(
      20, 0, 0, 0, 0, 0,
      0, 16, 0, 0, 4, 0,
      0, 0, 18, 0, 2, 0,
      0, 0, 0, 20, 0, 0,
      2, 0, 0, 0, 19, 0,
      0, 1, 2, 0, 1, 14), nrow = 6, byrow = TRUE),  # <-- replace with your data
    area_km2 = c(
      "Class 1" =  144.238,
      "Class 2" =   73.932,
      "Class 3" =   32.668,
      "Class 4" =  252.664,
      "Class 5" =   74.808,
      "Class 6" =   35.453
    )
  ),

  g_mar25 = list(
    cm = matrix(c(
      20, 0, 0, 0, 0, 0,
      2, 15, 0, 0, 3, 0,
      0, 1, 17, 0, 2, 1,
      0, 0, 0, 20, 0, 0,
      4, 0, 0, 0, 16, 0,
      0, 0, 0, 1, 1, 17), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  153.946,
      "Class 2" =   77.035,
      "Class 3" =   19.935,
      "Class 4" =  245.646,
      "Class 5" =   66.456,
      "Class 6" =   64.752
    )
  ),

  s_mar22 = list(
    cm = matrix(c(
      15, 0, 0, 0, 0, 0,
      2, 6, 0, 2, 0, 3,
      0, 0, 12, 0, 0, 3,
      0, 4, 1, 9, 0, 1,
      0, 0, 0, 0, 15, 0,
      1, 2, 2, 0, 0, 12), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  24.033,
      "Class 2" =   6.063,
      "Class 3" =   2.482,
      "Class 4" =  18.284,
      "Class 5" =   2.741,
      "Class 6" =   3.571
    )
  ),

  s_mar23 = list(
    cm = matrix(c(
      14, 0, 1, 0, 0, 0,
      1, 5, 1, 2, 0, 0,
      1, 0, 8, 0, 0, 6,
      0, 4, 0, 9, 1, 0,
      0, 0, 0, 1, 10, 1,
      0, 5, 0, 0, 0, 10), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  24.859,
      "Class 2" =   8.751,
      "Class 3" =   3.493,
      "Class 4" =  24.329,
      "Class 5" =   2.705,
      "Class 6" =   5.651
    )
  ),

  s_mar25 = list(
    cm = matrix(c(
      15, 0, 0, 0, 0, 0,
      8, 2, 0, 0, 0, 0,
      0, 2, 10, 0, 0, 3,
      1, 4, 0, 9, 0, 1,
      0, 0, 0, 1, 12, 0,
      3, 1, 0, 0, 0, 12), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  29.998,
      "Class 2" =   9.127,
      "Class 3" =   2.240,
      "Class 4" =  23.396,
      "Class 5" =   5.089,
      "Class 6" =   5.990
    )
  ),

  c_mar22 = list(
    cm = matrix(c(
      16, 0, 0, 0, 0, 0,
      2, 11, 1, 0, 0, 1,
      0, 0, 14, 0, 0, 1,
      0, 1, 0, 13, 1, 0,
      0, 0, 0, 0, 14, 0,
      0, 2, 0, 1, 1, 11), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  30.448,
      "Class 2" =   32.681,
      "Class 3" =   8.376,
      "Class 4" =  140.27,
      "Class 5" =   81.695,
      "Class 6" =   20.762
    )
  ),

  c_mar23 = list(
    cm = matrix(c(
      15, 0, 0, 0, 0, 0,
      0, 13, 0, 1, 0, 1,
      0, 0, 12, 0, 1, 2,
      0, 0, 0, 15, 0, 0,
      0, 0, 0, 5, 7, 2,
      2, 2, 0, 1, 1, 9), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  36.441,
      "Class 2" =   30.365,
      "Class 3" =   9.22,
      "Class 4" =  102.681,
      "Class 5" =   54.674,
      "Class 6" =   25.105
    )
  ),

  c_mar25 = list(
    cm = matrix(c(
      15, 0, 0, 0, 0, 0,
      2, 15, 1, 0, 0, 0,
      0, 0, 8, 1, 2, 1,
      1, 1, 0, 12, 0, 1,
      0, 0, 0, 1, 13, 0,
      0, 2, 0, 3, 1, 9), nrow = 6, byrow = TRUE),
    area_km2 = c(
      "Class 1" =  40.138,
      "Class 2" =   25.117,
      "Class 3" =   8.203,
      "Class 4" =  77.584,
      "Class 5" =   94.968,
      "Class 6" =   26.441
    )
  )

)


# =============================================================================
# SECTION 3: CORE OLOFSSON FUNCTION
# =============================================================================
# Takes one (cm, area_km2) pair and returns a tidy tibble of results.
# You do not need to edit this section.

olofsson_estimates <- function(cm, area_km2, map_name = "map") {

  n_classes  <- nrow(cm)
  class_names <- names(area_km2)
  A_total    <- sum(area_km2)

  # --- Step 2a: stratum weights Wi = Ai / A ---
  W <- area_km2 / A_total                          # length n_classes

  # --- Step 2b: row totals and cell proportions pij = nij / ni. ---
  row_totals <- rowSums(cm)                        # ni. for each stratum i
  # Avoid division by zero for strata with no samples
  pij <- sweep(cm, 1, ifelse(row_totals > 0, row_totals, 1), FUN = "/")

  # --- Step 3: area-adjusted proportion for each class j ---
  # p_hat_j = sum_i(Wi * pij)  — column-wise weighted sum
  p_hat <- colSums(sweep(pij, 1, W, FUN = "*"))   # length n_classes

  # Adjusted area in km²
  A_adj <- p_hat * A_total

  # --- Step 4: variance of p_hat_j ---
  # V(p_hat_j) = sum_i [ Wi^2 * pij*(1-pij) / (ni. - 1) ]
  # Only include strata where ni. > 1 (need at least 2 samples for variance)
  denom   <- ifelse(row_totals > 1, row_totals - 1, NA_real_)
  W2      <- W^2

  var_p_hat <- sapply(seq_len(n_classes), function(j) {
    terms <- W2 * (pij[, j] * (1 - pij[, j])) / denom
    sum(terms, na.rm = TRUE)
  })

  # Standard error of area estimate (km²)
  SE_area <- sqrt(var_p_hat) * A_total

  # --- Step 5: 95% confidence interval ---
  CI_95 <- 1.96 * SE_area

  # --- Accuracy metrics (reported separately, not as error bars) ---
  UA <- ifelse(row_totals > 0, diag(cm) / row_totals, NA_real_)
  col_totals <- colSums(cm)
  PA <- ifelse(col_totals > 0, diag(cm) / col_totals, NA_real_)
  OA <- sum(diag(cm)) / sum(cm)

  # --- Assemble tidy output tibble ---
  tibble(
    map          = map_name,
    class        = class_names,
    has_samples  = row_totals > 0,
    mapped_area  = area_km2,
    W_i          = W,
    row_total_n  = row_totals,
    p_hat_j      = p_hat,
    A_adj        = A_adj,
    SE_area      = SE_area,
    CI_95        = CI_95,
    CI_lower     = A_adj - CI_95,
    CI_upper     = A_adj + CI_95,
    UA           = UA,
    PA           = PA,
    OA           = OA
  )
}


# =============================================================================
# SECTION 4: RUN ACROSS ALL 9 MAPS
# =============================================================================

results_all <- imap_dfr(
  maps,
  ~ olofsson_estimates(
      cm        = .x$cm,
      area_km2  = .x$area_km2,
      map_name  = .y           # uses the list name (map_1, map_2, ...)
  )
)


# =============================================================================
# SECTION 5: INSPECT RESULTS
# =============================================================================

# Full results table — all maps, all classes
print(results_all)

# Classes with no validation samples (flagged — treat estimates with caution)
results_all |>
  filter(!has_samples) |>
  select(map, class)

# Wide summary: adjusted area ± CI for each class, one row per map
summary_wide <- results_all |>
  filter(has_samples) |>
  mutate(area_ci = paste0(round(A_adj, 1), " ± ", round(CI_95, 1))) |>
  select(map, class, area_ci) |>
  pivot_wider(names_from = class, values_from = area_ci)

print(summary_wide)

# Per-map overall accuracy
results_all |>
  distinct(map, OA) |>
  mutate(OA_pct = round(OA * 100, 1))

# =============================================================================
# SECTION 6: EXPORT
# =============================================================================

write_csv(results_all, "/Users/vedikakalra/Documents/WCT/sand-classification/olofsson_results_all_maps.csv")

# Plotting-ready subset: exclude classes with no samples
results_plot <- results_all |>
  filter(has_samples)

# results_plot is what you'll pass to ggplot2 in the next step

#Used the error matrix and area for each of the classes in the formula given in Olofsson 2014 to find the area-adjusted error for each of the classes.
results_clean <- results_plot%>%
  separate(map, c("river_abbr", "year_abbr"), sep = "_")%>%
  separate(year_abbr, c("month", "year"), sep = -2)%>%
  mutate(year = paste0("20", year))%>%
  mutate(year = as.integer(year))

ghaghra_results <- results_clean%>%
  filter(river_abbr == "g")%>%
  mutate(class_name = recode(class,
    "Class 1" = "Fresh sand",
    "Class 2" = "Cucurbit",
    "Class 3" = "Wet sand",
    "Class 4" = "Agriculture",
    "Class 5" = "Fallow", 
    "Class 6" = "Scrubs"
  ))%>%
 ggplot(aes(x =factor(year), y = A_adj, fill = class_name, group = class_name))+
   geom_col(position = position_dodge(width = 0.75),
            width = 0.7)+
   geom_errorbar(aes(ymin = CI_lower, ymax = CI_upper),
     position = position_dodge(width = 0.75),
     width = 0.25,
     color = "grey30",
     linewidth = 0.6)+
  scale_fill_manual(
    values = c(
      "Fresh sand" = "#ffc800",
      "Wet sand" = "#23649f",
      "Cucurbit" = "#99ca3c",
      "Agriculture" = "#319300",
      "Fallow" = "#ff4d00",
      "Scrubs" = "#a17e25"
  ))+
  theme_minimal()+
  labs(
    title    = "Areal change in sand habitats: Ghaghra",
    subtitle = "Adjusted areas with 95% confidence interval error bars (Olofsson et al. 2014)",
    x        = "Year",
    y        = "Area (km²)",
    fill = "Class"
  )+
  theme(
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 10, face = "italic")
  )
  
chambal_results <- results_clean%>%
  filter(river_abbr == "c")%>%
  mutate(class_name = recode(class,
                             "Class 1" = "Fresh sand",
                             "Class 2" = "Sand mine",
                             "Class 3" = "Wet sand",
                             "Class 4" = "Fallow",
                             "Class 5" = "Vegetated sand", 
                             "Class 6" = "Bedrock"
  ))%>%
  ggplot(aes(x =factor(year), y = A_adj, fill = class_name, group = class_name))+
  geom_col(position = position_dodge(width = 0.75),
           width = 0.7)+
  geom_errorbar(aes(ymin = CI_lower, ymax = CI_upper),
                position = position_dodge(width = 0.75),
                width = 0.25,
                color = "grey30",
                linewidth = 0.6)+
  scale_fill_manual(
    values = c(
      "Fresh sand" = "#ffc800",
      "Sand mine" = "#371d10",
      "Wet sand" = "#23649f",
      "Fallow" = "#ff4d00",
      "Vegetated sand" = "#99ca3c",
      "Bedrock" = "#c4c4c4"
    ))+
  theme_minimal()+
  labs(
    title    = "Areal change in sand habitats: Chambal",
    subtitle = "Adjusted areas with 95% confidence interval error bars (Olofsson et al. 2014)",
    x        = "Year",
    y        = "Area (km²)",
    fill = "Class"
  )+
  theme(
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 10, face = "italic")
  )
  
son_results <- results_clean%>%
  filter(river_abbr == "s")%>%
  mutate(class_name = recode(class,
                             "Class 1" = "Fresh sand",
                             "Class 2" = "Sand mine",
                             "Class 3" = "Wet sand",
                             "Class 4" = "Fallow",
                             "Class 5" = "Vegetated sand", 
                             "Class 6" = "Bedrock"
  ))%>%
  ggplot(aes(x =factor(year), y = A_adj, fill = class_name, group = class_name))+
  geom_col(position = position_dodge(width = 0.75),
           width = 0.7)+
  geom_errorbar(aes(ymin = CI_lower, ymax = CI_upper),
                position = position_dodge(width = 0.75),
                width = 0.25,
                color = "grey30",
                linewidth = 0.6)+
  scale_fill_manual(
    values = c(
      "Fresh sand" = "#ffc800",
      "Sand mine" = "#371d10",
      "Wet sand" = "#23649f",
      "Fallow" = "#ff4d00",
      "Vegetated sand" = "#99ca3c",
      "Bedrock" = "#c4c4c4"
    ))+
  theme_minimal()+
  labs(
    title    = "Areal change in sand habitats: Son",
    subtitle = "Adjusted areas with 95% confidence interval error bars (Olofsson et al. 2014)",
    x        = "Year",
    y        = "Area (km²)",
    fill = "Class"
  )+
  theme(
    plot.title = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 10, face = "italic")
  )

print(chambal_results)
print(son_results)
print(ghaghra_results)

ggsave(
  filename = "/Users/vedikakalra/Documents/WCT/sand-classification/son-area-change.png",
  plot = son_results,
  width = 8,
  height = 6,
  dpi = 300
)

ggsave(
  filename = "/Users/vedikakalra/Documents/WCT/sand-classification/chambal-area-change.png",
  plot = chambal_results,
  width = 8,
  height = 6,
  dpi = 300
)

ggsave(
  filename = "/Users/vedikakalra/Documents/WCT/sand-classification/ghaghra-area-change.png",
  plot = ghaghra_results,
  width = 8,
  height = 6,
  dpi = 300
)

freshSand <- results_clean%>%
  filter(class == c("Class 1"))%>%
  mutate(river = recode(river_abbr,
                             "c" = "Chambal",
                             "g" = "Ghaghra",
                             "s" = "Son"
                             ))%>%
  ggplot(aes(x =factor(river), y = A_adj, fill = factor(year), group = factor(year)))+
  geom_col(position = position_dodge(width = 0.75),
                    width = 0.7)+
  geom_errorbar(aes(ymin = CI_lower, ymax = CI_upper),
                position = position_dodge(width = 0.75),
                width = 0.25,
                color = "grey30",
                linewidth = 0.6)+
  theme_minimal()+
  scale_fill_brewer(palette = "YlOrBr")+
  labs(
    title = "Areal change in fresh sand habitat for each river across years",
    subtitle = "Adjusted areas with 95% confidence interval error bars (Olofsson et al.2014)",
    x = NULL,
    y = "Area (km²)",
    fill = "Year"
  )+
  facet_wrap(~river, scale = "free", ncol  = 3)+
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(face = "italic", size = 10),
    axis.text.x = element_blank(),
    panel.background = element_rect(color = "gray30",
                                    linewidth = 1),
    strip.text = element_text(face = "bold"))
    
print(freshSand)

ggsave(filename = "/Users/vedikakalra/Documents/WCT/sand-classification/fresh-sand-area.png",
       plot = freshSand,
       width = 8,
       height = 6,
       dpi = 300
)

threat <- results_clean%>%
  filter(class == "Class 2")%>%
  mutate(river = recode(river_abbr,
                        "g" = "Ghaghra (Cucurbit farming)",
                        "s" = "Son (Sand mining)",
                        "c" = "Chambal (Sand mining)"))%>%
  ggplot(aes(x = factor(river), y = A_adj, fill = factor(year), group = factor(year)))+
  geom_col(position = position_dodge(width = 0.75), width = 0.7)+
  geom_errorbar(aes(ymin= CI_lower, ymax = CI_upper),
                position = position_dodge(width = 0.75),
                width = 0.25,
                color = "grey30",
                linewidth = 0.6)+
  theme_minimal()+
  labs(
    x = NULL,
    y = "Area (km²)",
    title = "Areal change in threat affecting habitat for each river",
    subtitle = "Adjusted areas with 95% confidence interval error bars (Olofsson et al. 2014)",
    fill = "Year"
  )+
  scale_fill_brewer(palette = "Reds")+
  facet_wrap(~river, scale = "free", ncol = 3)+
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(face = "italic", size = 10),
    axis.text.x = element_blank(),
    strip.text = element_text(face = "bold"),
    panel.background = element_rect(linewidth = 1, color = "gray30")
  )

print(threat)

ggsave(filename = "/Users/vedikakalra/Documents/WCT/sand-classification/threats-area.png",
       plot = threat,
       width = 8,
       height = 6,
       dpi = 300)

mine <- results_clean%>%
  filter(class == "Class 2")

