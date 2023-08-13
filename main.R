library(basedosdados)
library(tidyverse)
library(ggrepel)

# Again using flamengadas project
set_billing_id("flamengadas")

# Obrigado, Base dos Dados, me poupou de um web scrapping
# Para carregar o dado direto no R
df <- basedosdados::read_sql("SELECT ano_campeonato, data, rodada, estadio,
                              publico, time_man, time_vis, colocacao_man,
                              publico_max, colocacao_vis
                             from basedosdados.mundo_transfermarkt_competicoes.
                             brasileirao_serie_a
                             WHERE ano_campeonato > 2017")

glimpse(df)

# Breaks for fill scale
my_breaks <- c(.5, 1, 1.5, 2, 3, 3.5)

df %>%
  filter(time_man != 'Flamengo', # Flamengo is not home
         publico > 0) %>% # Excluding matches without supporters,
  # mainly during pandemics
  mutate(ocupacao = publico/publico_max,
         VisFla = (time_vis == 'Flamengo')) %>%
  group_by(time_man, VisFla) %>%
  summarise(ocupacao_media = mean(ocupacao, na.rm = T)) %>%
  ungroup() %>%
  pivot_wider(id_cols = time_man,
              names_from = VisFla,
              values_from = ocupacao_media) %>%
  ggplot(aes(x = `FALSE`, y = `TRUE`, fill = `TRUE`/`FALSE`)) +
  geom_point(shape = 21, size = 5) +
  geom_text_repel(aes(label = time_man)) +
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
  theme_minimal()
ggsave('attendance.png')
