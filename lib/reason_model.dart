class ReasonModel {
  final String reason1;
  final String reason2;

  ReasonModel({required this.reason1, required this.reason2});
}

final List<ReasonModel> reasonList = [
  ReasonModel(reason1: "Chắc chắn xảy ra", reason2: "Chí mạng"),
  ReasonModel(reason1: "Khả năng cao xảy ra", reason2: "Rất nghiêm trọng"),
  ReasonModel(reason1: "Có thể xảy ra", reason2: "Nghiêm trọng"),
  ReasonModel(reason1: "Ít xảy ra", reason2: "Không nghiêm trọng"),
  ReasonModel(reason1: "Không xảy ra", reason2: "Nhẹ"),
];
