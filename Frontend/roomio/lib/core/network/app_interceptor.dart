import 'package:dio/dio.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/auth/domain/usecase/get_new_token.dart';
import 'package:roomio/injection_container.dart';

class AppInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;
  
  // Dùng callback để báo ra ngoài khi token chết hẳn, giữ Clean Code không gọi Bloc trực tiếp
  final Function() onUnauthorized;

  AppInterceptor(this._secureStorage , {required this.onUnauthorized});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 1. Lấy token từ ổ cứng
    final token = await _secureStorage.getAccessToken();
    
    // 2. Tự động gắn token vào Header của mọi request
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    // 3. Cho phép request tiếp tục chạy lên server
    super.onRequest(options, handler);
  }

@override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _secureStorage.getRefreshToken();
      
      // Nếu có Refresh Token thì đi đổi Token mới
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final getNewTokenUseCase = sl<GetNewTokenUseCase>();
        final dataState = await getNewTokenUseCase(refreshToken);

        if (dataState is DataSuccess) {
          // Lưu token mới vào két sắt
          final newToken = dataState.data!;
          await _secureStorage.saveAccessToken(
             newToken
          );

          // Sửa lại cái API vừa bị lỗi bằng Token mới
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

          try {
            // Tạo một Dio độc lập (không chứa Interceptor này) để chạy lại API đó
            final retryDio = Dio();
            final response = await retryDio.fetch(err.requestOptions);
            
            // Trả kết quả thành công về cho UI, UI không hề hay biết đã có lỗi xảy ra!
            return handler.resolve(response); 
          } catch (e) {
            // Nếu gọi lại vẫn lỗi thì bỏ tay
            return handler.next(err);
          }
        }
      }

      // NẾU CHẠY ĐẾN ĐÂY: Có nghĩa là Refresh Token cũng chết, hoặc lấy token thất bại.
      await _secureStorage.clearAll(); // Xóa sạch ổ cứng
      onUnauthorized(); // Hét lên cho Bloc biết để đá user ra ngoài!
    }

    // Nếu không phải lỗi 401 thì ném lỗi ra như bình thường
    super.onError(err, handler);
  }
}