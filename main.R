library(basedosdados)
library(tidyverse)
library(ggrepel)

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

df %>%
  filter(time_man != 'Flamengo',
         publico > 0) %>%
  mutate(ocupacao = publico/publico_max,
         VisFla = (time_vis == 'Flamengo')) %>%
  group_by(time_man, VisFla) %>%
  summarise(ocupacao_media = mean(ocupacao, na.rm = T)) %>%
  ungroup() %>%
  pivot_wider(id_cols = time_man,
              names_from = VisFla,
              values_from = ocupacao_media) %>%
  ggplot(aes(x = `FALSE`, y = `TRUE`, fill = `TRUE`/`FALSE`)) +
  geom_point(shape = 21) +
  geom_text_repel(aes(label = time_man)) +
  geom_abline(slope = 1, linetype = 'dashed') +
  lims(x = c(0,1), y = c(0,1)) +
  labs(x = 'Ocupação média sem Flamengo',
       y = 'Ocupação média com Flamengo')

