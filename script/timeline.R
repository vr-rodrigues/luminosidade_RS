# Carregar bibliotecas necessárias
library(raster)
library(rgdal)
library(ggplot2)
library(zoo)
library(lubridate)
library(ggthemes)

#setwd(seudiretorio)


# Ler o shapefile do estado (exemplo com municípios do RS)
rs_municipios <- readOGR('./mapa_ibge/RS_Municipios_2022.shp')

# Definir os municípios de interesse
areas <- c("Porto Alegre", "Canoas", "Rio Grande do Sul")

# Função para converter dia do ano em data real
dia_para_data <- function(dia) {
  as.Date("2024-01-01") + days(dia - 1)
}

# Data do alerta Guaiba (2 de maio de 2024)
data_alerta <- as.Date("2024-05-02")

for (area in areas) {
  
  # Filtrar o shapefile para a área atual
  if (area == "Rio Grande do Sul") {
    area_shape <- rs_municipios  # Unir todos os municípios para representar o estado inteiro
  } else {
    area_shape <- rs_municipios[rs_municipios$NM_MUN == area, ]
  }
  
  # Inicializar vetores para armazenar a soma e contagem dos valores de luminosidade
  luminosity_sums <- numeric()
  dates <- numeric()
  
  # Inicializar contador de dias processados
  dia <- 0
  
  # Loop pelos dias
  for (day in 100:130) {
    if (day == 116) {
      next  # Pular o processamento para o dia 116
    }
    
    dia <- dia + 1  # Incrementar o contador de dias processados após a verificação
    dates <- c(dates, day)  # Armazenando os dias processados
    
    # Carregar o arquivo TIFF do dia específico
    tiff_path <- sprintf('./tif/output_day_%d.tif', day)
    tiff_raster <- raster(tiff_path)
    
    # Aplicar limites aos valores de pixel
    tiff_raster[tiff_raster > 100] <- 100
    
    # Recortar e mascarar para a região do município
    crop_mun <- crop(tiff_raster, area_shape)
    mask_mun <- mask(crop_mun, area_shape)
    
    # Substituir NA por 0
    values(mask_mun)[is.na(values(mask_mun))] <- 0
    
    # Calcular a soma dos valores de luminosidade para este dia
    luminosity_sums[dia] <- sum(values(mask_mun))
  }
  
  # Calcular a média de luminosidade para cada dia
  luminosity_counts <- length(mask_mun@data@values)
  luminosity_means <- luminosity_sums / luminosity_counts
  
  # Criar um dataframe para os dados
  data <- data.frame(Day = dates, Luminosity = luminosity_means)
  
  # Calcular a média móvel de 3 dias
  data$MovingAverage <- rollapply(data$Luminosity, width = 3, FUN = mean, partial = TRUE, align = 'right')
  
  # Filtrar os dados para os dias após o dia 100
  data_ <- data[data$Day > 100, ]
  
  # Adicionar coluna de datas reais
  data_$Date <- dia_para_data(data_$Day)
  
  # Visualização com ggplot2
  plot <- ggplot(data_, aes(x = Date, y = MovingAverage)) +
    geom_line(color = "black", size = 1) +
    geom_vline(xintercept = data_alerta, linetype = "dashed", color = "red", size = 0.8) +
    annotate("text", x = data_alerta, y = max(data_$MovingAverage, na.rm = TRUE), 
             label = "Alerta Guaíba - 2,55m", color = "red", hjust = -0.1, vjust = 1.5, size = 5) +
    labs(title = paste("Luminosidade em", area),
         x = "Data", y = "M.M. 3 Dias - Luminosidade Média") +
    theme_classic() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
      axis.title = element_text(size = 14),
      axis.text = element_text(size = 12),
      panel.grid.major = element_line(color = "grey80", size = 0.5),
      panel.grid.minor = element_line(color = "grey90", size = 0.25)
    )
  
  # Exportar o gráfico para um arquivo
  ggsave(filename = paste0("grafico/timeline/Timeline_Luminosidade_", area, ".png"), plot = plot, width = 10, height = 8, dpi = 300)
}
