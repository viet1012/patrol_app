/// Mã plant đặc biệt: xem dữ liệu của TẤT CẢ nhà máy.
/// Backend hiểu plant/fac = 'SPC' là không lọc theo nhà máy.
const String kAllPlantCode = 'SPC';

bool isAllPlant(String? plant) => plant?.trim() == kAllPlantCode;
