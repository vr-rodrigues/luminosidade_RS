# Carregar bibliotecas necessárias
library(raster)
library(rgdal)
library(RColorBrewer)
library(sp)
library(ggplot2)
library(viridis)

#setwd(seudiretorio)

# Ler o shapefile do estado (exemplo com municípios do RS)
rs_municipios <- readOGR('./mapa_ibge/RS_Municipios_2022.shp')

# Definir as áreas de interesse
areas <- c("Porto Alegre", "Canoas", "Rio Grande do Sul")

# Carregar os arquivos TIFF dos dias 100 e 130
tiff_day_100 <- raster('./tif/output_day_100.tif')
tiff_day_100[tiff_day_100 > 100] <- 100

tiff_day_130 <- raster('./tif/output_day_130.tif')
tiff_day_130[tiff_day_130 > 100] <- 100

# Loop pelas áreas
for (area in areas) {
  
  # Filtrar o shapefile para a área atual
  if (area == "Rio Grande do Sul") {
    area_shape <- rs_municipios
  } else {
    area_shape <- rs_municipios[rs_municipios$NM_MUN == area, ]
  }
  
  # Recortar e mascarar para a região do município ou estado
  crop_100 <- crop(tiff_day_100, area_shape)
  mask_100 <- mask(crop_100, area_shape)
  crop_130 <- crop(tiff_day_130, area_shape)
  mask_130 <- mask(crop_130, area_shape)
  
  # Calcular a delta (diferença) entre os dois dias
  delta <- mask_130 - mask_100
  
  # Converter raster para dataframe para uso com ggplot2
  delta_df <- as.data.frame(rasterToPoints(delta))
  colnames(delta_df) <- c("lon", "lat", "delta")
  
  # Plotar o raster da delta com o shapefile do município
  plot <- ggplot() +
    geom_raster(data = delta_df, aes(x = lon, y = lat, fill = delta)) +
    scale_fill_gradientn(colors = colorRampPalette(c("red", "gray", "blue"))(200),
                         limits = c(-100, 100), name = "Variação") +
    geom_path(data = fortify(area_shape), aes(x = long, y = lat, group = group), color = "black", size = 0.5) +
    ggtitle(paste("Delta de Luminosidade: 9/abril vs 9/maio -", area)) +
    xlab("Longitude") +
    ylab("Latitude") +
    theme_classic() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
      axis.title = element_text(size = 12),
      axis.text = element_text(size = 10),
      legend.position = "right",
      legend.title = element_text(size = 10),
      legend.text = element_text(size = 8)
    ) +
    coord_equal()
  
  # Exportar o gráfico para um arquivo
  ggsave(filename = paste0("grafico/delta/Delta_Luminosidade_", gsub(" ", "_", area), ".png"), plot = plot, width = 10, height = 8, dpi = 300)
}