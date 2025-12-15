import 'package:http/http.dart' as http;

class SttController {
  int currentStt = 0;

  Future<int> fetchStt(String group) async {
    final res = await http.get(
      Uri.parse("http://localhost:9299/api/stt/$group"),
    );
    currentStt = int.parse(res.body);
    return currentStt;
  }

  Future<int> nextStt(String group) async {
    final res = await http.post(
      Uri.parse("http://localhost:9299/api/stt/$group/next"),
    );
    currentStt = int.parse(res.body);
    return currentStt;
  }
}
