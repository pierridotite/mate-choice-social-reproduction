# Jointure Speed Dating Experiment (Fisman et al., 2006) x US Census ACS 2017-2021
# Ajoute, pour le code postal d'enfance de chaque participant (et de son partenaire) :
#   - le revenu médian des ménages (B19013) de la ZCTA
#   - l'indice de Gini des revenus (B19083) de la ZCTA
#   - la population de la ZCTA (B01003)
#
# Sources :
#   http://www.stat.columbia.edu/~gelman/arm/examples/speed.dating/Speed%20Dating%20Data.csv
#   https://www2.census.gov/programs-surveys/acs/summary_file/2021/table-based-SF/data/5YRData/

args <- commandArgs(trailingOnly = TRUE)
dir_in  <- if (length(args) >= 1) args[1] else "data-raw"
dir_out <- if (length(args) >= 2) args[2] else "data"
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)

# --- 1. Speed dating ---------------------------------------------------------
sd <- read.csv(file.path(dir_in, "speed_dating.csv"), stringsAsFactors = FALSE,
               fileEncoding = "latin1")

num <- function(x) suppressWarnings(as.numeric(gsub(",", "", x)))

# Les codes postaux ont été stockés comme nombres (virgule des milliers, zéros
# initiaux perdus) : "6,268" -> "06268". "0", vide ou < 3 chiffres = manquant.
clean_zip <- function(z) {
  z <- gsub("[^0-9]", "", z)
  z[z == "" | nchar(z) < 3 | nchar(z) > 5 | z == "0"] <- NA
  ifelse(is.na(z), NA, formatC(as.integer(z), width = 5, flag = "0"))
}
sd$zip5 <- clean_zip(sd$zipcode)
sd$income_2000 <- num(sd$income)   # revenu médian d'origine (Census 2000, fourni par les auteurs)

# --- 2. Census ACS 5 ans 2017-2021, niveau ZCTA ------------------------------
read_acs <- function(table, name_e, name_m) {
  x <- read.delim(file.path(dir_in, paste0("acs_", table, ".dat")), sep = "|",
                  colClasses = "character")
  x <- x[startsWith(x$GEO_ID, "860Z200US"), ]
  out <- data.frame(zip5 = sub("860Z200US", "", x$GEO_ID),
                    e = as.numeric(x[[2]]), m = as.numeric(x[[3]]))
  # Codes spéciaux du Census (valeurs négatives = non disponible / non fiable)
  out$e[out$e < 0] <- NA
  out$m[out$m < 0] <- NA
  names(out)[2:3] <- c(name_e, name_m)
  out
}
acs <- Reduce(function(a, b) merge(a, b, by = "zip5", all = TRUE), list(
  read_acs("b19013", "zip_median_income_2021", "zip_median_income_2021_moe"),
  read_acs("b19083", "zip_gini_2021", "zip_gini_2021_moe"),
  read_acs("b01003", "zip_population_2021", "zip_population_2021_moe")
))
write.csv(acs, file.path(dir_out, "census_acs2021_zcta.csv"), row.names = FALSE)

# --- 3. Table participants (1 ligne par iid) ---------------------------------
part <- sd[!duplicated(sd$iid), c("iid", "gender", "wave", "from", "zipcode", "zip5", "income_2000")]
part <- merge(part, acs, by = "zip5", all.x = TRUE, sort = FALSE)
part$census_match <- !is.na(part$zip5) & part$zip5 %in% acs$zip5
part <- part[order(part$iid), c("iid", "gender", "wave", "from", "zipcode", "zip5",
                                "census_match", "income_2000", setdiff(names(acs), "zip5"))]
write.csv(part, file.path(dir_out, "participants_census.csv"), row.names = FALSE, na = "")

# --- 4. Table des rencontres enrichie (1 ligne par couple orienté iid -> pid) --
keep <- c("iid", "zip5", "census_match", setdiff(names(acs), "zip5"))
self    <- part[, keep]
partner <- part[, keep]
names(partner) <- paste0(names(partner), "_o")          # même convention que le dataset (_o = partenaire)
names(partner)[1] <- "pid"

out <- merge(sd, self[, -2], by = "iid", all.x = TRUE, sort = FALSE)  # zip5 déjà présent dans sd
out <- merge(out, partner, by = "pid", all.x = TRUE, sort = FALSE)

# Variables de distance socio-économique entre les deux partenaires
out$diff_income_2021     <- out$zip_median_income_2021 - out$zip_median_income_2021_o
out$abs_diff_income_2021 <- abs(out$diff_income_2021)
out$diff_log_income_2021 <- log(out$zip_median_income_2021) - log(out$zip_median_income_2021_o)
out$diff_gini_2021       <- out$zip_gini_2021 - out$zip_gini_2021_o
out$abs_diff_gini_2021   <- abs(out$diff_gini_2021)

orig_cols <- names(sd)
out <- out[order(out$iid, out$pid), c(orig_cols, setdiff(names(out), orig_cols))]
write.csv(out, file.path(dir_out, "speed_dating_census.csv"), row.names = FALSE, na = "")

# --- 5. Bilan -----------------------------------------------------------------
cat("Rencontres :", nrow(out), "| participants :", nrow(part), "\n")
cat("Participants avec code postal exploitable :", sum(!is.na(part$zip5)), "\n")
cat("  dont trouvés dans les ZCTA du Census     :", sum(part$census_match), "\n")
cat("  avec revenu 2021 :", sum(!is.na(part$zip_median_income_2021)),
    "| avec Gini 2021 :", sum(!is.na(part$zip_gini_2021)), "\n")
cat("Rencontres avec Gini des deux partenaires :",
    sum(!is.na(out$abs_diff_gini_2021)), "\n")
ok <- complete.cases(part$income_2000, part$zip_median_income_2021)
cat("Corrélation revenu 2000 (auteurs) vs ACS 2021 :",
    round(cor(part$income_2000[ok], part$zip_median_income_2021[ok]), 3),
    "(n =", sum(ok), ")\n")
