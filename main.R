library(basedosdados)
library(tidyverse)
library(ggrepel)

my_theme <- theme_minimal() +
  theme(plot.background = element_rect(fill = 'white', color = "black", linewidth = 1),
        panel.background = element_rect(fill = 'white'),
        legend.position = c(0.95, 0.95),
        legend.title = element_blank(),
        legend.justification = c("right", "top"),
        legend.box.background = element_rect(color = "black", linewidth = 0.3),
        legend.box.margin = margin(6, 6, 6, 6))

# Defina o seu projeto no Google Cloud
set_billing_id("attendance-458722")

# Para carregar o dado direto no R
query <- "
SELECT
    dados.ano_campeonato as ano_campeonato,
    dados.data as data,
    dados.rodada as rodada,
    dados.estadio as estadio,
    dados.publico as publico,
    dados.publico_max as publico_max,
    dados.time_mandante as time_mandante,
    dados.time_visitante as time_visitante,
    dados.colocacao_mandante as colocacao_mandante,
    dados.colocacao_visitante as colocacao_visitante,
    dados.valor_equipe_titular_mandante as valor_equipe_titular_mandante,
    dados.valor_equipe_titular_visitante as valor_equipe_titular_visitante,
    dados.idade_media_titular_mandante as idade_media_titular_mandante,
    dados.idade_media_titular_visitante as idade_media_titular_visitante
FROM `basedosdados.mundo_transfermarkt_competicoes.brasileirao_serie_a` AS dados
"

df <- read_sql(query, billing_project_id = get_billing_id())

write_csv(df, 'df.csv')
#df <- read_csv('df.csv')

casa <- df %>%
  group_by(ano_campeonato, estadio, time_mandante) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  group_by(ano_campeonato, time_mandante) %>%
  arrange(desc(n)) %>%
  slice_head(n = 1) %>%  # Keeps only the first row of each group
  ungroup() %>%
  select(ano_campeonato, time_mandante, casa = estadio)

df_clean <- df %>%
  left_join(casa, by = c("ano_campeonato", "time_mandante")) %>%
  mutate(ocupacao = publico / publico_max,
         Flamengo = ifelse(time_visitante == "Flamengo", 1, 0),
         Palmeiras = ifelse(time_visitante == "Palmeiras", 1, 0),
         Corinthians = ifelse(time_visitante == "Corinthians", 1, 0)) %>%
  filter(time_mandante != "Flamengo",
         ocupacao != 0,
         estadio == casa) %>%
  select(ano_campeonato, data, rodada, estadio, time_mandante, time_visitante,
         colocacao_mandante, colocacao_visitante, idade_media_titular_mandante,
         idade_media_titular_visitante, ocupacao, Flamengo, Palmeiras, Corinthians) %>%
  mutate(Post = ifelse(ano_campeonato >= 2019, 1, 0)) %>%
  mutate(PostFlamengo = Post*Flamengo) %>%
  filter(!(ano_campeonato %in% c(2020, 2021))) %>%
  na.omit()

# EDA

df_clean <- df_clean %>%
  mutate(group = ifelse(Flamengo == 1, "Flamengo", "Outros"))

# Calculate medians for each group
medians <- df_clean %>%
  group_by(group) %>%
  summarise(median_val = median(ocupacao))

df_clean %>%
  ggplot(aes(x = ocupacao, fill = group)) +
    geom_density(alpha = 0.6) +
  # Vertical median lines
  geom_vline(data = medians, 
             aes(xintercept = median_val, color = group),
             linetype = "dashed", 
             linewidth = 1,
             show.legend = FALSE) +
  # Median value labels
  geom_text(data = medians,
            aes(x = median_val, y = Inf, 
                label = paste("Median:", round(median_val, 2)),
                color = group),
            vjust = 1.5, hjust = -0.1,
            show.legend = FALSE) +
  labs(y = '', x = 'Ocupação') +
  scale_color_manual(values = c("Flamengo" = "#c3281e", "Outros" = "Black")) +
  scale_fill_manual(values = c("Flamengo" = "#c3281e", "Outros" = "Black")) +
  my_theme + theme(legend.title = element_blank())
  
ggplot(df_clean, aes(y = ocupacao, x = group, fill = group)) +
  geom_boxplot(alpha = 0.6) +
  labs(x = '', y = 'Ocupação') +
  guides(fill="none") +
  scale_fill_manual(values = c("Flamengo" = "#c3281e", "Outros" = "Black")) +
  my_theme

df_clean %>%
  group_by(time_visitante, group) %>%
  summarise(ocupacao = mean(ocupacao)) %>%
  ungroup() %>%
  arrange(desc(ocupacao)) %>%  # Sort by ocupacao in descending order
  slice_head(n = 5) %>%        # Keep only the top 5 rows
  ggplot(aes(x = reorder(time_visitante, -ocupacao),
             y = ocupacao,
             fill = group)) + 
  geom_col() +
  labs(x = "Time Visitante", y = "Ocupação Média") +
  guides(fill="none") +
  scale_fill_manual(values = c("Flamengo" = "#c3281e", "Outros" = "Black")) +
  my_theme

df_clean %>%
  group_by(ano_campeonato, Flamengo, group) %>%
  summarise(
    ocupacao_mean = mean(ocupacao, na.rm = TRUE),
    ocupacao_sd = sd(ocupacao, na.rm = TRUE),
    n = n(),
    ocupacao_se = ocupacao_sd / sqrt(n)
  ) %>%
  ungroup() %>%
  ggplot(aes(
    y = ocupacao_mean,
    x = ano_campeonato,
    group = group,
    color = group
  )) +
  # Vertical line for Jorge Jesus
  geom_vline(aes(xintercept = 2019), linetype = "dashed", color = "gray50") +
  # Jorge Jesus label
  annotate("text", x = 2019, y = Inf, 
           label = "Jorge Jesus", vjust = 1.5, hjust = -0.1) +
  # Points for means
  geom_point(size = 3) +
  # Error bars (using standard error)
  geom_errorbar(aes(
    ymin = ocupacao_mean - ocupacao_se,
    ymax = ocupacao_mean + ocupacao_se
  ), width = 0.2) +
  # Labels and colors
  labs(x = "", y = "Ocupação") +
  scale_color_manual(values = c("Flamengo" = "#c3281e", "Outros" = "Black")) +
  my_theme +
  theme(legend.position = c(0.95, 0.2))

# Breaks for fill scale
my_breaks <- c(.5, 1, 1.5, 2, 3, 3.5)

df_clean %>%
  filter(time_mandante != 'Flamengo', # Flamengo is not home
         ocupacao > 0) %>% # Excluding matches without supporters,
  # mainly during pandemics
  mutate(VisFla = (time_visitante == 'Flamengo')) %>%
  group_by(time_mandante, VisFla) %>%
  summarise(ocupacao_media = mean(ocupacao, na.rm = T)) %>%
  ungroup() %>%
  pivot_wider(id_cols = time_mandante,
              names_from = VisFla,
              values_from = ocupacao_media) %>%
  ggplot(aes(x = `FALSE`, y = `TRUE`, fill = `TRUE`/`FALSE`)) +
  geom_point(shape = 21, size = 5) +
  geom_text_repel(aes(label = time_mandante)) +
  geom_abline(slope = 1, linetype = 'dashed') +
  annotate("text", x = .75 + .25/2 + .025, y = .75 + .25/2 - .025,
           label = "f(x) = x") +
  lims(x = c(0,1), y = c(0,1)) +
  scale_fill_gradient(name = "Razão", trans = "log10",
                      breaks = my_breaks, labels = my_breaks,
                      low = "#f8d5d3", high = "#c3281e") +
  scale_y_continuous(labels = scales::percent,
                     name = 'Ocupação média com Flamengo') +
  scale_x_continuous(labels = scales::percent,
                     name = 'Ocupação média sem Flamengo') +
  labs(title = 'Vimos pelo Flamengo!',
       subtitle = paste0('Flamengo eleva ocupação média dos estádios','\n',
                         '*Período com restrições de capacidade pode afetar números')) +
  my_theme + 
  theme(legend.position = c(0.95, 0.4),
        legend.title = element_text())
ggsave('attendance.png')

# T-test to evaluate whether Flamengo attendance is higher

t.test(df_clean$ocupacao[df_clean$Flamengo == 1],
       df_clean$ocupacao[df_clean$Flamengo == 0],
       alternative = "greater", var.equal = FALSE)

# Adjust dataset for regression exercises

df_reg <- df_clean %>%
  mutate(
    ano_campeonato = factor(ano_campeonato),
    time_mandante = factor(time_mandante),
    InvColocacaoMandante = 1/as.numeric(colocacao_mandante),
    InvColocacaoVisitante = 1/as.numeric(colocacao_visitante),
    ColocacaoMandante = as.numeric(colocacao_mandante),
    ColocacaoVisitante = as.numeric(colocacao_visitante)
  )

# Regression setups

mod1 <- lm(ocupacao ~ ano_campeonato + time_mandante + Flamengo +
     InvColocacaoMandante +
     InvColocacaoVisitante, data = df_reg)

summary(mod1)

library(lmtest)
library(sandwich)
library(modelsummary)


# Assuming your model is named 'model'
mod1_robust_se <- sqrt(diag(vcovHC(mod1, type = "HC1")))  # HC1 gives Stata-like robust SEs

# Placebo

lm(ocupacao ~ ano_campeonato + time_mandante + Palmeiras +
     InvColocacaoMandante +
     InvColocacaoVisitante, data = df_reg) %>%
  summary()

lm(ocupacao ~ ano_campeonato + time_mandante + Corinthians +
     InvColocacaoMandante +
     InvColocacaoVisitante, data = df_reg) %>%
  summary()

mod4 <- lm(ocupacao ~ ano_campeonato + time_mandante + Flamengo +
     Palmeiras + Corinthians +
     InvColocacaoMandante +
     InvColocacaoVisitante, data = df_reg)

modelsummary(list(mod1, mod4),
             vcov = "HC1",
             coef_map = c("Flamengo", "Palmeiras", "Corinthians", 
                          "InvColocacaoMandante", "InvColocacaoVisitante"),
             stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
             output = "html",
             title = "Regression Results",
             notes = "Heteroskedasticity-robust standard errors in parentheses")
