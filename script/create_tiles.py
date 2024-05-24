import numpy as np
import h5py
import glob
import re
import rasterio
from rasterio.transform import from_origin

# Função para extrair a posição do grid
def get_position(filename):
    match = re.search(r'h(\d+)v(\d+)', filename)
    if match:
        code = f'h{match.group(1)}v{match.group(2)}'
        return grid_positions.get(code, (float('inf'), float('inf')))
    return (float('inf'), float('inf'))

# Posições de grid pré-definidas
grid_positions = {'h12v11': (0, 0), 'h12v12': (1, 0), 'h13v11': (0, 1)}  # Limitado aos tiles especificados

# Coordenadas fixas
lat_min, lat_max = -40.0, -20.0
lon_min, lon_max = -60.0, -40.0
limite_superior = 10000

for day in range(97, 133):
    if day == 116:
        continue 

    # Carrega os arquivos para o dia específico
    h5files = glob.glob(f'./luminosidadeRS/{day}/*.h5')
    h5files = [file for file in h5files if 'h13v12' not in file]  # Excluindo o tile 'h13v12'
    h5files_sorted = sorted(h5files, key=get_position)

    # Combina os dados
    with h5py.File(h5files_sorted[0], 'r') as h5f:
        dnb_ds = h5f['HDFEOS/GRIDS/VNP_Grid_DNB/Data Fields/Gap_Filled_DNB_BRDF-Corrected_NTL']  # Usando o mesmo campo de dados do Código 1
        dnb_combined = np.zeros((2 * dnb_ds.shape[0], 2 * dnb_ds.shape[1]), dtype=dnb_ds.dtype)

    for h5file in h5files_sorted:
        with h5py.File(h5file, 'r') as h5f:
            dnb_ds = h5f['HDFEOS/GRIDS/VNP_Grid_DNB/Data Fields/Gap_Filled_DNB_BRDF-Corrected_NTL']
            pos = get_position(h5file)
            dnb_combined[pos[0] * dnb_ds.shape[0]:(pos[0] + 1) * dnb_ds.shape[0],
                          pos[1] * dnb_ds.shape[1]:(pos[1] + 1) * dnb_ds.shape[1]] = dnb_ds[:]

    dnb_clipped = np.clip(dnb_combined, None, limite_superior)  # Clipping os valores altos

    # Configuração da transformação e salvamento em TIFF para cada dia
    transform = from_origin(lon_min, lat_max, (lon_max - lon_min) / dnb_combined.shape[1], (lat_max - lat_min) / dnb_combined.shape[0])
    with rasterio.open(
        f'output_day_{day}.tif', 'w', driver='GTiff',
        height=dnb_clipped.shape[0], width=dnb_clipped.shape[1],
        count=1, dtype=dnb_clipped.dtype,
        crs='+proj=latlong', transform=transform
    ) as dst:
        dst.write(dnb_clipped, 1)
    
    print(day)
